// libqohos.so — Native helper that launches the Qt application on a dedicated
// C++ thread, completely bypassing the NAPI layer.
//
// Background: calling QPA startQtApplication from the ArkTS main thread
// deadlocks because the NAPI call context prevents TSFN dispatch.  Calling
// NAPI functions from a C++ thread also crashes.  So we replicate what
// startQtApplication does internally: set env vars, dlopen libentry.so,
// dlsym its main(), and run it on a fresh pthread — all in pure C/C++.
#include "napi/native_api.h"
#include <pthread.h>
#include <dlfcn.h>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <atomic>
#include <hilog/log.h>
#include <mutex>

#undef LOG_TAG
#define LOG_TAG "SciDAVisNative"
#define LOG_DOMAIN 0x0000

// ── Structured chain logging ─────────────────────────────────────────────
// Uniform tag + correlation id so a single hilog filter
//   hilog -x | grep SciDAVisChain
// shows the full trigger -> boundary -> failure -> result path of a native
// operation.  Phase is one of: "trigger", "boundary", "failure", "result".
// These macros only emit logs; they never change control flow.
#define CHAIN_TAG "SciDAVisChain"
static std::atomic<uint32_t> g_chainSeq{0};
static inline uint32_t NextCid() { return g_chainSeq.fetch_add(1) + 1; }
#define CHAIN_LOG(cid, phase, fmt, ...)                                       \
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, CHAIN_TAG,                       \
               "[cid=%{public}u][%{public}s] " fmt, (cid), (phase), ##__VA_ARGS__)
#define CHAIN_ERR(cid, phase, fmt, ...)                                       \
  OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, CHAIN_TAG,                      \
               "[cid=%{public}u][%{public}s] " fmt, (cid), (phase), ##__VA_ARGS__)

// Argument bundle handed to the Qt launcher thread; carries the startup
// correlation id so the C++ thread's logs join the StartQtNative trigger.
struct QtThreadArg {
  uint32_t cid;
  std::string dirs;
};

// ETS → Qt left-button injection (the QPA plugin drops left-button mouse
// events; see scidavis_inject_mouse in scidavis/src/main.cpp).
typedef void (*inject_mouse_fn_t)(float, float, int, int);
static void *g_appHandle = nullptr;              // dlopen handle of libentry.so
static inject_mouse_fn_t g_injectMouse = nullptr;
static std::mutex g_injectMutex;

// ── Qt → ArkTS event channel ─────────────────────────────────────────────
// libentry.so exports scidavis_set_event_sink(cb); Qt code pushes JSON
// events through scidavis_emit which end up in the registered C trampoline
// below.  The trampoline hops onto the JS thread via a threadsafe function
// so the ArkTS callback given to onQtEvent(cb) runs safely.
typedef void (*event_sink_cb_t)(const char *);
typedef void (*set_event_sink_fn_t)(event_sink_cb_t);
static napi_threadsafe_function g_eventTsfn = nullptr;
static std::mutex g_eventMutex;
static bool g_sinkWanted = false;    // onQtEvent called before dlopen finished
static bool g_sinkRegistered = false;

static void EventSinkTrampoline(const char *json) {
  // Called from arbitrary Qt threads; nonblocking so Qt never stalls.
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "qt event -> tsfn: %{public}.200s", json ? json : "(null)");
  if (!g_eventTsfn) return;
  char *copy = strdup(json ? json : "{}");
  if (napi_call_threadsafe_function(g_eventTsfn, copy, napi_tsfn_nonblocking) != napi_ok)
    free(copy);
}

// Runs on the JS thread: invoke the ArkTS callback with the JSON string.
static void CallJsEventCallback(napi_env env, napi_value js_cb, void *, void *data) {
  char *json = static_cast<char *>(data);
  if (env && js_cb) {
    napi_value undefined, arg;
    napi_get_undefined(env, &undefined);
    napi_create_string_utf8(env, json ? json : "{}", NAPI_AUTO_LENGTH, &arg);
    napi_call_function(env, undefined, js_cb, 1, &arg, nullptr);
  }
  free(json);
}

// Register the trampoline with libentry.so once both sides are ready.
// Safe to call repeatedly (onQtEvent and qt_thread_func race on startup).
static void TryRegisterEventSink() {
  std::lock_guard<std::mutex> lock(g_eventMutex);
  if (g_sinkRegistered || !g_sinkWanted || !g_appHandle || !g_eventTsfn) return;
  auto set_sink = reinterpret_cast<set_event_sink_fn_t>(
      dlsym(g_appHandle, "scidavis_set_event_sink"));
  if (!set_sink) {
    OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                 "onQtEvent: dlsym scidavis_set_event_sink failed: %{public}s", dlerror());
    return;
  }
  set_sink(EventSinkTrampoline);
  g_sinkRegistered = true;
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "Qt event sink registered");
}

// ── Environment variable setup (extracted so it can also run from ArkTS) ───
// Set Qt env vars early so they are in effect before QPA plugin init,
// dlopen, and QApplication construction.  Called from both preloadLibs()
// (ArkTS thread) and qt_thread_func (C++ thread, belt-and-braces).
static void SetupQtEnv(const std::string &bundleCodeDir,
                       const std::string &cacheDir,
                       const std::string &qmlDir) {
  std::string libsDir = bundleCodeDir + "/libs/arm64";

  // CRITICAL: Platform plugin path must point to the SAME directory as the
  // NAPI module (libs/arm64/) so that dlopen returns the same library
  // instance.  If Qt loads platforms/libplugins_platforms_qopenharmony.so
  // (a separate copy), the XComponent surface (given to the root copy)
  // won't be visible to the Qt platform plugin → black screen.
  setenv("QT_QPA_PLATFORM_PLUGIN_PATH", libsDir.c_str(), 1);
  setenv("QT_PLUGIN_PATH", libsDir.c_str(), 1);
  setenv("QT_HARMONY_BUNDLED_LIBS_PATH", libsDir.c_str(), 1);
  setenv("QT_HARMONY_CACHE_DIR", cacheDir.c_str(), 1);
  setenv("QT_HARMONY_QML_CACHE_DIR", qmlDir.c_str(), 1);
  setenv("QML_DISABLE_DISK_CACHE", "1", 1);
  setenv("QT_NO_SYNTHESIZED_ITALIC", "1", 1);
  setenv("QT_QPA_FONTDIR", "/system/fonts", 1);
  setenv("QT_ENABLE_HIGHDPI_SCALING", "0", 1);
  setenv("QT_LOGGING_RULES", "qt.scaling=true", 1);

  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "SetupQtEnv: libs=%{public}s cache=%{public}s",
               libsDir.c_str(), cacheDir.c_str());
}

// ── Thread that starts Qt purely in C++ (no NAPI) ────────────────────────
static void *qt_thread_func(void *arg) {
  QtThreadArg *bundle = static_cast<QtThreadArg *>(arg);
  uint32_t cid = bundle->cid;
  std::string dirs_str_safe(bundle->dirs);
  delete bundle;

  CHAIN_LOG(cid, "boundary", "qt_thread_func entered (crossing into Qt/C++)");

  // Parse tab-separated: bundleCodeDir \t cacheDir \t qmlDir
  std::string bundleCodeDir, cacheDir, qmlDir;
  {
    size_t p1 = dirs_str_safe.find('\t');
    size_t p2 = (p1 != std::string::npos) ? dirs_str_safe.find('\t', p1 + 1) : std::string::npos;
    if (p1 != std::string::npos && p2 != std::string::npos) {
      bundleCodeDir = dirs_str_safe.substr(0, p1);
      cacheDir      = dirs_str_safe.substr(p1 + 1, p2 - p1 - 1);
      qmlDir        = dirs_str_safe.substr(p2 + 1);
    } else {
      CHAIN_ERR(cid, "failure", "bad dirs format: %{public}s", dirs_str_safe.c_str());
      OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "bad dirs format");
      return nullptr;
    }
  }

  std::string libsDir = bundleCodeDir + "/libs/arm64";

  CHAIN_LOG(cid, "boundary", "libs=%{public}s cache=%{public}s",
            libsDir.c_str(), cacheDir.c_str());
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "C++ thread: libs=%{public}s cache=%{public}s", libsDir.c_str(), cacheDir.c_str());

  // Env vars are already set by preloadLibs() on the ArkTS thread.
  // Belt-and-braces: re-set here in case preloadLibs was skipped.
  SetupQtEnv(bundleCodeDir, cacheDir, qmlDir);

  // ── Load the Qt application binary ──────────────────────────────────
  std::string appLib = libsDir + "/libentry.so";
  CHAIN_LOG(cid, "boundary", "dlopen %{public}s", appLib.c_str());
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "C++ thread: dlopen %{public}s", appLib.c_str());

  void *handle = dlopen(appLib.c_str(), RTLD_NOW);
  if (!handle) {
    CHAIN_ERR(cid, "failure", "dlopen failed: %{public}s", dlerror());
    OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                 "C++ thread: dlopen failed: %{public}s", dlerror());
    return nullptr;
  }
  g_appHandle = handle;
  TryRegisterEventSink();  // in case onQtEvent was called before dlopen

  dlerror();  // clear
  typedef int (*main_fn_t)(int, char **);
  main_fn_t main_fn = reinterpret_cast<main_fn_t>(dlsym(handle, "main"));
  const char *err = dlerror();
  if (err || !main_fn) {
    CHAIN_ERR(cid, "failure", "dlsym main failed: %{public}s", err ? err : "null");
    OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                 "C++ thread: dlsym main failed: %{public}s", err ? err : "null");
    return nullptr;
  }

  CHAIN_LOG(cid, "boundary", "calling Qt main()");
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "C++ thread: calling Qt main()");
  char arg0[] = "SciDAVis";
  char *argv[] = { arg0, nullptr };
  int rc = main_fn(1, argv);
  CHAIN_LOG(cid, "result", "Qt main() returned %{public}d", rc);
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "C++ thread: Qt main() returned %{public}d", rc);
  return nullptr;
}

// Map an OHOS language tag (e.g. "zh-Hans", "zh-Hant-TW") to a POSIX locale
// and export it via LANG/LC_ALL.  OHOS does not populate these env vars for
// native processes, so without this QLocale::system() is "C" and the Qt
// QTranslator (main.cpp) never loads the Chinese .qm.  Must run before the
// Qt thread constructs QApplication.
static void ApplyOhosLocaleEnv(const std::string &lang) {
  const char *posix = nullptr;
  if (lang.rfind("zh-Hant", 0) == 0 || lang.find("-TW") != std::string::npos ||
      lang.find("-HK") != std::string::npos || lang.find("-MO") != std::string::npos)
    posix = "zh_TW.UTF-8";
  else if (lang.rfind("zh", 0) == 0)
    posix = "zh_CN.UTF-8";
  if (posix) {
    setenv("LANG", posix, 1);
    setenv("LC_ALL", posix, 1);
  }
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "system language=%{public}s -> LANG=%{public}s",
               lang.c_str(), posix ? posix : "(unset)");
}

// ── NAPI entry: preloadLibs(bundleCodeDir, cacheDir, qmlDir[, language]) ────
// Sets Qt environment variables from the ArkTS thread so they are in effect
// before the QPA plugin initializes, dlopen, and QApplication construction.
// Called early in onWindowStageCreate, before initQtBridge / XComponent.
// The language parameter (optional, 4th arg) is mapped to LANG/LC_ALL for
// QTranslator .qm loading (OHOS does not populate these for native processes).
static napi_value PreloadLibs(napi_env env, napi_callback_info info) {
  uint32_t cid = NextCid();
  size_t argc = 4;
  napi_value argv[4] = { nullptr, nullptr, nullptr, nullptr };
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

  CHAIN_LOG(cid, "trigger", "preloadLibs argc=%{public}zu", argc);

  if (argc < 3) {
    CHAIN_ERR(cid, "failure", "preloadLibs requires 3 string args (got %{public}zu)", argc);
    napi_throw_type_error(env, nullptr, "preloadLibs requires 3 string args");
    return nullptr;
  }

  char buf[1024];
  size_t len = 0;
  std::string bundleCodeDir, cacheDir, qmlDir;

  napi_get_value_string_utf8(env, argv[0], buf, sizeof(buf), &len);
  bundleCodeDir = std::string(buf, len);
  napi_get_value_string_utf8(env, argv[1], buf, sizeof(buf), &len);
  cacheDir = std::string(buf, len);
  napi_get_value_string_utf8(env, argv[2], buf, sizeof(buf), &len);
  qmlDir = std::string(buf, len);

  // Optional 4th arg: OHOS system language tag → LANG/LC_ALL for Qt.
  if (argc >= 4 && argv[3] != nullptr) {
    len = 0;
    if (napi_get_value_string_utf8(env, argv[3], buf, sizeof(buf), &len) == napi_ok)
      ApplyOhosLocaleEnv(std::string(buf, len));
  }

  SetupQtEnv(bundleCodeDir, cacheDir, qmlDir);

  CHAIN_LOG(cid, "result", "preloadLibs ok");
  napi_value undef;
  napi_get_undefined(env, &undef);
  return undef;
}

// ── NAPI entry: startQtNative(bundleCodeDir, cacheDir, qmlDir[, language]) ─
static napi_value StartQtNative(napi_env env, napi_callback_info info) {
  uint32_t cid = NextCid();
  size_t argc = 4;
  napi_value argv[4] = { nullptr, nullptr, nullptr, nullptr };
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

  CHAIN_LOG(cid, "trigger", "startQtNative argc=%{public}zu", argc);

  if (argc < 3) {
    CHAIN_ERR(cid, "failure", "startQtNative requires 3 string args (got %{public}zu)", argc);
    napi_throw_type_error(env, nullptr, "startQtNative requires 3 string args");
    return nullptr;
  }

  char buf[1024];
  size_t len = 0;
  std::string dirs;

  napi_get_value_string_utf8(env, argv[0], buf, sizeof(buf), &len);
  dirs += std::string(buf, len);
  dirs += '\t';
  napi_get_value_string_utf8(env, argv[1], buf, sizeof(buf), &len);
  dirs += std::string(buf, len);
  dirs += '\t';
  napi_get_value_string_utf8(env, argv[2], buf, sizeof(buf), &len);
  dirs += std::string(buf, len);

  // Optional 4th arg: OHOS system language tag → LANG/LC_ALL for Qt.
  if (argc >= 4 && argv[3] != nullptr) {
    len = 0;
    if (napi_get_value_string_utf8(env, argv[3], buf, sizeof(buf), &len) == napi_ok)
      ApplyOhosLocaleEnv(std::string(buf, len));
  }

  QtThreadArg *bundle = new QtThreadArg{ cid, dirs };
  pthread_t tid;
  int prc = pthread_create(&tid, nullptr, qt_thread_func, bundle);
  if (prc != 0) {
    CHAIN_ERR(cid, "failure", "pthread_create failed rc=%{public}d", prc);
    delete bundle;
    napi_value undef;
    napi_get_undefined(env, &undef);
    return undef;
  }
  pthread_detach(tid);

  CHAIN_LOG(cid, "boundary", "launcher thread dispatched (main JS thread free)");
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "Qt C++ launcher thread created");

  napi_value undef;
  napi_get_undefined(env, &undef);
  return undef;
}

// ── Module registration ──────────────────────────────────────────────────
// ── NAPI entry: sendMouse(x, y, button, action)
// Coordinates are physical pixels.  button: 1 = left, 2 = right.
// action: 0 = press, 1 = release, 2 = move.  Forwarded to the
// scidavis_inject_mouse export of libentry.so (thread-safe: it queues onto
// the Qt GUI thread internally).
static napi_value SendMouse(napi_env env, napi_callback_info info) {
  uint32_t cid = NextCid();
  size_t argc = 4;
  napi_value argv[4] = { nullptr, nullptr, nullptr, nullptr };
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

  CHAIN_LOG(cid, "trigger", "sendMouse argc=%{public}zu", argc);

  napi_value result;
  {
    std::lock_guard<std::mutex> lock(g_injectMutex);
    if (argc < 4 || !g_appHandle) {
      CHAIN_ERR(cid, "failure", "not ready g_appHandle=%{public}p argc=%{public}zu",
                g_appHandle, argc);
      OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                   "sendMouse: FAIL g_appHandle=%{public}p argc=%{public}zu", g_appHandle, argc);
      napi_get_boolean(env, false, &result);
      return result;
    }

    if (!g_injectMouse) {
      g_injectMouse = reinterpret_cast<inject_mouse_fn_t>(
          dlsym(g_appHandle, "scidavis_inject_mouse"));
      if (!g_injectMouse) {
        CHAIN_ERR(cid, "failure", "dlsym scidavis_inject_mouse failed: %{public}s", dlerror());
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                     "sendMouse: dlsym scidavis_inject_mouse failed: %{public}s", dlerror());
        napi_get_boolean(env, false, &result);
        return result;
      }
    }

    double x = 0, y = 0, button = 0, action = 0;
    napi_get_value_double(env, argv[0], &x);
    napi_get_value_double(env, argv[1], &y);
    napi_get_value_double(env, argv[2], &button);
    napi_get_value_double(env, argv[3], &action);

    CHAIN_LOG(cid, "boundary", "inject x=%{public}.1f y=%{public}.1f btn=%{public}d act=%{public}d",
              x, y, static_cast<int>(button), static_cast<int>(action));
    g_injectMouse(static_cast<float>(x), static_cast<float>(y),
                  static_cast<int>(button), static_cast<int>(action));
  }
  CHAIN_LOG(cid, "result", "sendMouse ok");
  napi_get_boolean(env, true, &result);
  return result;
}

EXTERN_C_START
static napi_value CallQtCommand(napi_env env, napi_callback_info info) {
  uint32_t cid = NextCid();
  size_t argc = 2;
  napi_value argv[2] = { nullptr, nullptr };
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

  if (argc < 2 || !g_appHandle) {
    CHAIN_ERR(cid, "failure", "not ready argc=%{public}zu handle=%{public}p", argc, g_appHandle);
    napi_value result;
    napi_create_string_utf8(env, R"({"success":false,"error":"not ready"})", NAPI_AUTO_LENGTH, &result);
    return result;
  }

  typedef const char *(*call_fn_t)(const char *, const char *);
  static call_fn_t s_call = nullptr;
  if (!s_call) {
    s_call = reinterpret_cast<call_fn_t>(dlsym(g_appHandle, "scidavis_call"));
    if (!s_call) {
      CHAIN_ERR(cid, "failure", "dlsym scidavis_call failed: %{public}s", dlerror());
      OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                   "callQtCommand: dlsym scidavis_call failed: %{public}s", dlerror());
      napi_value result;
      napi_create_string_utf8(env, R"({"success":false,"error":"dlsym failed"})", NAPI_AUTO_LENGTH, &result);
      return result;
    }
  }

  char cmd[256] = {0};
  char args[8192] = {0};
  size_t cmdLen = 0, argsLen = 0;
  napi_get_value_string_utf8(env, argv[0], cmd, sizeof(cmd), &cmdLen);
  napi_get_value_string_utf8(env, argv[1], args, sizeof(args), &argsLen);

  CHAIN_LOG(cid, "trigger", "callQtCommand cmd=%{public}s", cmd);
  CHAIN_LOG(cid, "boundary", "scidavis_call(cmd=%{public}s) args=%{public}.120s", cmd, args);
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "callQtCommand: cmd=%{public}s args=%{public}s", cmd, args);

  const char *resultStr = s_call(cmd, args);

  CHAIN_LOG(cid, "result", "cmd=%{public}s -> %{public}.200s",
            cmd, resultStr ? resultStr : "(null)");
  napi_value result;
  napi_create_string_utf8(env, resultStr ? resultStr : R"({"success":false,"error":"null"})",
                          NAPI_AUTO_LENGTH, &result);
  return result;
}

// ── NAPI entry: onQtEvent(callback) ──────────────────────────────────────
// Subscribes an ArkTS callback to the Qt event channel.  Returns true on
// success.  Events emitted by Qt before subscription are buffered inside
// libentry.so and flushed upon registration.
static napi_value OnQtEvent(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value argv[1] = { nullptr };
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

  napi_value result;
  napi_valuetype type = napi_undefined;
  if (argc < 1 || napi_typeof(env, argv[0], &type) != napi_ok || type != napi_function) {
    napi_throw_type_error(env, nullptr, "onQtEvent requires a callback function");
    napi_get_boolean(env, false, &result);
    return result;
  }

  {
    std::lock_guard<std::mutex> lock(g_eventMutex);
    if (g_eventTsfn) {
      // Replace previous subscription (e.g. page reload).
      napi_release_threadsafe_function(g_eventTsfn, napi_tsfn_abort);
      g_eventTsfn = nullptr;
      g_sinkRegistered = false;
    }
    napi_value resourceName;
    napi_create_string_utf8(env, "scidavisQtEvent", NAPI_AUTO_LENGTH, &resourceName);
    napi_status st = napi_create_threadsafe_function(
        env, argv[0], nullptr, resourceName, 0 /*unbounded queue*/, 1,
        nullptr, nullptr, nullptr, CallJsEventCallback, &g_eventTsfn);
    if (st != napi_ok) {
      OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                   "onQtEvent: napi_create_threadsafe_function failed %{public}d", st);
      napi_get_boolean(env, false, &result);
      return result;
    }
    // Keep the event loop free to exit; events are best-effort UI updates.
    napi_unref_threadsafe_function(env, g_eventTsfn);
    g_sinkWanted = true;
  }
  TryRegisterEventSink();
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "onQtEvent: subscribed (sink %{public}s)", g_sinkRegistered ? "live" : "pending");
  napi_get_boolean(env, true, &result);
  return result;
}

static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
    { "preloadLibs", nullptr, PreloadLibs, nullptr, nullptr, nullptr, napi_default, nullptr },
    { "startQtNative", nullptr, StartQtNative, nullptr, nullptr, nullptr, napi_default, nullptr },
    { "sendMouse", nullptr, SendMouse, nullptr, nullptr, nullptr, napi_default, nullptr },
    { "callQtCommand", nullptr, CallQtCommand, nullptr, nullptr, nullptr, napi_default, nullptr },
    { "onQtEvent", nullptr, OnQtEvent, nullptr, nullptr, nullptr, napi_default, nullptr },
  };
  napi_define_properties(env, exports, 5, desc);
  return exports;
}
EXTERN_C_END

static napi_module demoModule = {
  .nm_version = 1,
  .nm_flags = 0,
  .nm_filename = nullptr,
  .nm_register_func = Init,
  .nm_modname = "qohos",
  .nm_priv = ((void*)0),
  .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
  napi_module_register(&demoModule);
}
