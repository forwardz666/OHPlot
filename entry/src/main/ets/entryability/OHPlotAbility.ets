import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { Want, AbilityConstant, Configuration } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import display from '@ohos.display';
import font from '@ohos.font';
import deviceInfo from '@ohos.deviceInfo';
// Official Qt-for-OpenHarmony QPA plugin (alpha_v6).
import qpaRaw from 'libplugins_platforms_qopenharmony.so';
// Native helper: launches Qt on a C++ thread so the main JS thread stays
// free for NAPI TSFN callbacks (createJsObject / deleteJsObject).
import qohosNative from 'libqohos.so';
import { JsLocale } from '../native/JsLocale';
import { JsStandardPaths, ApplicationDirs } from '../native/JsStandardPaths';
import { SimpleJsWindowManager, SimpleJsWindow } from '../native/JsWindowManager';
import { JsInputMethod, QpaInput } from '../native/JsInputMethod';
import { JsCursor } from '../native/JsCursor';
import { JsPasteBoard } from '../native/JsPasteBoard';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';
const WINDOW_NAME: string = 'openharmony_qt_mainwindow';

interface QpaModule extends QpaInput {
  setDeviceType(deviceType: string): void;
  setDisplayMetrics(width: number, height: number, densityDPI: number, scaledDensity: number,
    xDPI: number, yDPI: number, x: number, y: number, physicalWidth: number, physicalHeight: number): void;
  setDefaultShowIsMaximized(maximized: boolean): void;
  setResourceManager(resourceManager: object): void;
  setDisplayVersion(version: string): void;
  setFontInfos(fonts: Array<string>): void;
  setTouchPad(isTouchPad: boolean): void;
  setJsQuitFunction(quit: () => void): void;
  startQtApplication(dirs: ApplicationDirs, appBinary: string): boolean;
  quitQtApplication(): void;
  qtMajorVersion(): number;
  handleGeometryChange(name: string, rect: window.Rect): void;
  handleWindowEvent(name: string, type: number): void;
}

interface QtCoreModule {
  default: Object;
}

interface QtCoreNapi {
  initJsObjectLoader(createFn: (type: string, name: string, ...args: Object[]) => Object,
    deleteFn: (name: string) => boolean): void;
}

interface QohosNativeModule {
  startQtNative(bundleCodeDir: string, cacheDir: string, qmlDir: string): void;
}

const qpa = qpaRaw as QpaModule;
const qohos = qohosNative as QohosNativeModule;

// Cache of live JS bridge objects handed to Qt Core, keyed by instance name.
const jsObjectCache = new Map<string, Object>();

// Pre-created JsWindowManager (created in onWindowStageCreate before Qt starts).
let windowManager: SimpleJsWindowManager | null = null;

/**
 * Callback registered with Qt Core via initJsObjectLoader.
 * Qt calls this when it needs a JS bridge object (e.g. "JsLocale").
 * Returning null for an unknown type is safe — Qt logs a warning.
 */
function createJsObject(type: string, name: string, ...args: Object[]): Object {
  hilog.info(DOMAIN, TAG, '>>> createJsObject ENTER type=%{public}s name=%{public}s args=%{public}d', type, name, args.length);
  if (jsObjectCache.has(name)) {
    return jsObjectCache.get(name) as Object;
  }
  let obj: Object | null = null;
  if (type == 'JsLocale') {
    obj = new JsLocale();
  } else if (type == 'JsStandardPaths') {
    let appCtx = (jsObjectCache.get('__dirs__') as ApplicationDirs);
    obj = new JsStandardPaths(appCtx);
  } else if (type == 'JsInputMethod') {
    obj = new JsInputMethod(qpa);
  } else if (type == 'JsCursor') {
    // Provide a window-name → window-id lookup backed by the window manager.
    obj = new JsCursor((name: string) => {
      if (windowManager != null) {
        return windowManager.getWindow(name);
      }
      return undefined;
    });
  } else if (type == 'JsPasteBoard') {
    // Clipboard bridge: QOpenHarmonyPlatformClipboard proxies QClipboard
    // entirely through this object (see specifications/08).
    obj = new JsPasteBoard();
  } else if (type == 'JsWindowManager') {
    // Return the pre-created window manager (already has main window registered).
    obj = windowManager;
  } else if (type == 'JsWindow') {
    // QPA requests a specific window by name (e.g. "openharmony_window_1").
    // Look it up in the window manager.
    if (windowManager != null) {
      let w = windowManager.getWindow(name);
      if (w != undefined) {
        obj = w;
      }
    }
  }
  // Other types (JsDialog, JsCursor, …) return null — Qt handles gracefully.
  if (obj != null) {
    jsObjectCache.set(name, obj);
  }
  hilog.info(DOMAIN, TAG, 'createJsObject type=%{public}s name=%{public}s → %{public}s',
    type, name, obj != null ? 'ok' : 'null');
  return obj as Object;
}

function deleteJsObject(name: string): boolean {
  hilog.info(DOMAIN, TAG, 'deleteJsObject: %{public}s', name);
  // Also clean up the window from the manager (safety net in case QPA
  // didn't call destroyWindow on the manager before deleting the JS object).
  if (windowManager != null) {
    let w = windowManager.getWindow(name);
    if (w != undefined) {
      windowManager.destroyWindow(name);
    }
  }
  return jsObjectCache.delete(name);
}

export default class OHPlotAbility extends UIAbility {
  private heartbeatId: number = -1;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    hilog.info(DOMAIN, TAG, 'OHPlotAbility::onCreate');
  }

  // Language change (system or setAppPreferredLanguage) → bump langTick so
  // MainLayout rebuilds data-model strings (menu labels); $r() bindings
  // refresh automatically via the ArkUI configuration update.
  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, TAG, 'onConfigurationUpdate language=%{public}s', newConfig.language ?? '');
    let tick = AppStorage.get<number>('langTick') ?? 0;
    AppStorage.setOrCreate('langTick', tick + 1);
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    hilog.info(DOMAIN, TAG, 'OHPlotAbility::onWindowStageCreate');
    let mainWindow = windowStage.getMainWindowSync();
    mainWindow.setWindowLayoutFullScreen(true);
    mainWindow.setWindowSystemBarEnable([]);

    // ApplicationDirs consumed by QPA.startQtApplication. Shape must match the
    // QPA plugin's expectation (mirrors JsDataStore.getApplicationDirs).
    let appCtx = this.context.getApplicationContext();
    let dirs: ApplicationDirs = {
      tempDir: appCtx.tempDir,
      filesDir: appCtx.filesDir,
      cacheDir: appCtx.cacheDir,
      databaseDir: appCtx.databaseDir,
      bundleCodeDir: appCtx.bundleCodeDir,
      preferencesDir: appCtx.preferencesDir,
      distributedFilesDir: appCtx.distributedFilesDir,
      qmlDir: appCtx.cacheDir + '/Qt/qml'
    };
    // Stash dirs so createJsObject can build JsStandardPaths later.
    jsObjectCache.set('__dirs__', dirs);

    // ── Create JsWindowManager and pre-register the main window.
    // The QPA plugin will request this object via createJsObject("JsWindowManager").
    // The main window name MUST match the XComponent id in pages/Index.ets.
    windowManager = new SimpleJsWindowManager(windowStage);
    // Set geometry-change callback so windows notify the QPA plugin (triggers rendering).
    windowManager.onGeometryChange = (name: string, rect: window.Rect): void => {
      hilog.info(DOMAIN, TAG, 'onGeometryChange: %{public}s rect=%{public}s', name, JSON.stringify(rect));
      try {
        qpa.handleGeometryChange(name, rect);
        hilog.info(DOMAIN, TAG, 'handleGeometryChange OK');
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'handleGeometryChange failed: %{public}s', JSON.stringify(e));
      }
    };
    windowManager.onWindowEvent = (name: string, type: number): void => {
      try {
        qpa.handleWindowEvent(name, type);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'handleWindowEvent failed: %{public}s', JSON.stringify(e));
      }
    };
    let mainJsWindow = new SimpleJsWindow(WINDOW_NAME, mainWindow, true);
    mainJsWindow.setHasFrame(false);  // full-screen, no frame
    mainJsWindow.onGeometryChange = windowManager.onGeometryChange;
    mainJsWindow.onWindowEvent = windowManager.onWindowEvent;
    windowManager.setMainWindow(mainJsWindow);
    windowManager.addWindow(WINDOW_NAME, mainJsWindow);
    mainJsWindow.startListener();
    jsObjectCache.set('JsWindowManager', windowManager);
    hilog.info(DOMAIN, TAG, 'JsWindowManager created, main window "%{public}s" registered', WINDOW_NAME);

    // ── CRITICAL: initialise the Qt Core JS-object bridge BEFORE the
    // XComponent is created.  Match the template's JsQtCore.loadQtCore()
    // pattern exactly: dynamic import → .default → initJsObjectLoader.
    this.initQtBridge();

    let storage = new LocalStorage();
    storage.setOrCreate('idName', WINDOW_NAME);

    windowStage.loadContent('pages/Index', storage).then(() => {
      // Delay startQtApplication to allow the XComponent's native callbacks
      // (OH_NativeXComponent_RegisterCallback → OnSurfaceCreated) to fire.
      setTimeout(() => {
        try {
          let d = display.getDefaultDisplaySync();
          qpa.setDeviceType(deviceInfo.deviceType);
          qpa.setDisplayMetrics(d.width, d.height, d.densityDPI, d.scaledDensity,
            d.xDPI, d.yDPI, 0, 0, d.width, d.height);
          qpa.setDefaultShowIsMaximized(true);
          qpa.setResourceManager(this.context.resourceManager);
          qpa.setDisplayVersion(deviceInfo.displayVersion);
          try {
            let f = mainWindow.getUIContext().getFont();
            let fonts: Array<string> = [];
            for (let fname of f.getSystemFontList()) {
              let info = font.getFontByName(fname);
              fonts.push(info.path);
            }
            qpa.setFontInfos(fonts);
          } catch (e) {
            qpa.setFontInfos([]);
          }
          qpa.setTouchPad(false);
          qpa.setJsQuitFunction(() => {
            hilog.error(DOMAIN, TAG, 'Qt quit callback triggered - Qt application exited!');
            setTimeout(() => {
              this.context.getApplicationContext().killAllProcesses();
            }, 2000);
          });

          // ── Start Qt on a C++ thread via our native helper module.
          // The C++ thread sets env vars, dlopen's libentry.so, and calls
          // its main() — completely bypassing the NAPI layer so the main
          // JS thread stays free for TSFN callbacks (createJsObject).
          hilog.info(DOMAIN, TAG, 'starting Qt via C++ thread (startQtNative)...');
          hilog.info(DOMAIN, TAG, 'bundleCodeDir=%{public}s', dirs.bundleCodeDir);
          hilog.info(DOMAIN, TAG, 'cacheDir=%{public}s', dirs.cacheDir);
          qohos.startQtNative(dirs.bundleCodeDir, dirs.cacheDir, dirs.qmlDir);
          hilog.info(DOMAIN, TAG, 'startQtNative dispatched – main thread free');

          // Heartbeat: proves the JS event loop is still running after
          // startQtApplication returns.  If TSFN callbacks (createJsObject)
          // never fire while the heartbeat keeps ticking, the problem is in
          // the TSFN plumbing, not a blocked event loop.
          let beat: number = 0;
          this.heartbeatId = setInterval(() => {
            beat++;
            hilog.info(DOMAIN, TAG, 'heartbeat #%{public}d – event loop alive', beat);
            if (beat >= 10) {
              clearInterval(this.heartbeatId);
              hilog.info(DOMAIN, TAG, 'heartbeat stopped (10 beats done)');
            }
          }, 1000);
        } catch (e) {
          let msg: string = '';
          if (e instanceof Error) {
            msg = e.message + ' | ' + e.stack;
          } else {
            msg = JSON.stringify(e);
          }
          hilog.error(DOMAIN, TAG, 'Qt bootstrap failed: %{public}s', msg);
        }
      }, 300);
    });
  }

  /**
   * Match the template's JsQtCore.loadQtCore() pattern exactly:
   * async dynamic import → .default → initJsObjectLoader.
   * Called without await from onWindowStageCreate (same as template's
   * loadQtModules → loadQtCore fire-and-forget pattern).
   */
  private async initQtBridge(): Promise<void> {
    try {
      let qtMajor: number = qpa.qtMajorVersion();
      hilog.info(DOMAIN, TAG, 'QPA qtMajorVersion = %{public}d', qtMajor);
      let qtCoreMod: QtCoreModule = await import('libQt5Core.so');
      let qtCore = qtCoreMod.default as QtCoreNapi;
      qtCore.initJsObjectLoader(createJsObject, deleteJsObject);
      hilog.info(DOMAIN, TAG, 'initJsObjectLoader registered (Qt%{public}d)', qtMajor);
    } catch (e) {
      let msg: string = '';
      if (e instanceof Error) {
        msg = e.message + ' | ' + e.stack;
      } else {
        msg = JSON.stringify(e);
      }
      hilog.error(DOMAIN, TAG, 'initQtBridge failed: %{public}s', msg);
    }
  }

  onWindowStageDestroy() {
    if (this.heartbeatId >= 0) {
      clearInterval(this.heartbeatId);
      this.heartbeatId = -1;
    }
    try { qpa.quitQtApplication(); } catch (e) {}
  }

  onForeground() { hilog.info(DOMAIN, TAG, 'onForeground'); }
  onBackground() { hilog.info(DOMAIN, TAG, 'onBackground'); }
  onDestroy() { hilog.info(DOMAIN, TAG, 'onDestroy'); }
}
