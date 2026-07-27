# Fixes the two faults captured in device faultlogs (2026-07-27 15:35/15:59):
#
# 1. cppcrash x2: hovering a toolbar button fires QEvent::ToolTip ->
#    QToolTip::showText creates a top-level tooltip window -> single-window
#    QPA SIGSEGVs in QWidgetPrivate::create (same family as QMenu popups).
#    Fix: InputProbe swallows QEvent::ToolTip.
#
# 2. appfreeze THREAD_BLOCK_6S: classic cross-thread deadlock.
#    JS thread: scidavis_call -> BlockingQueuedConnection -> QSemaphore::acquire
#    Qt thread: newTable -> Table::insertColumns -> setOverrideCursor ->
#               QOpenHarmonyJsFunction::call waits for the JS thread.
#    Fix: mutation commands become queued fire-and-forget; query commands
#    wait with a 3s timeout fallback.  Idempotent.
$ErrorActionPreference = 'Stop'
$path = 'C:\Users\Forwardz\scidavis-ohos\scidavis\scidavis\src\main.cpp'
$text = [System.IO.File]::ReadAllText($path)
$textLf = $text -replace "`r`n", "`n"

function Apply-Patch([string]$label, [string]$old, [string]$new) {
    $oldLf = $old -replace "`r`n", "`n"
    $newLf = $new -replace "`r`n", "`n"
    if ($script:textLf.Contains($newLf)) {
        Write-Host "SKIP: $label already applied"
        return
    }
    if (-not $script:textLf.Contains($oldLf)) {
        Write-Error "FAIL: $label anchor not found"
        exit 1
    }
    $script:textLf = $script:textLf.Replace($oldLf, $newLf)
    Write-Host "OK: $label"
}

# --- includes ---
Apply-Patch 'includes' @'
#include <QPointer>
'@ @'
#include <QPointer>
#include <QSemaphore>
#include <atomic>
'@

# --- 1. swallow ToolTip events ---
Apply-Patch 'tooltip block' @'
        case QEvent::ContextMenu:
            // Context menus are QMenu popups too -- unsupported by the
            // single-window QPA (same SIGSEGV as the menu bar).  Swallow.
            qWarning("[InputProbe] blocked context-menu event on %s (popup unsupported)",
                     obj->metaObject()->className());
            return true;
'@ @'
        case QEvent::ContextMenu:
            // Context menus are QMenu popups too -- unsupported by the
            // single-window QPA (same SIGSEGV as the menu bar).  Swallow.
            qWarning("[InputProbe] blocked context-menu event on %s (popup unsupported)",
                     obj->metaObject()->className());
            return true;
        case QEvent::ToolTip:
            // QToolTip::showText creates a top-level tooltip window -- the
            // single-window QPA SIGSEGVs in QWidgetPrivate::create (device
            // faultlog 20260727155912, same family as QMenu popups).
            return true;
'@

# --- 2a. scidavis_call head: copy args, classify cmd, shared call state ---
Apply-Patch 'dispatch head' @'
    static std::string s_result;

    QCoreApplication *core = QCoreApplication::instance();
    if (!core) {
        s_result = "{\"success\":false,\"error\":\"Qt not running\"}";
        return s_result.c_str();
    }

    QMetaObject::invokeMethod(core, [cmd, jsonArgs]() {
        std::string cmdStr(cmd);
        QJsonDocument doc = QJsonDocument::fromJson(QByteArray(jsonArgs));
'@ @'
    static std::string s_ret;

    QCoreApplication *core = QCoreApplication::instance();
    if (!core) {
        s_ret = "{\"success\":false,\"error\":\"Qt not running\"}";
        return s_ret.c_str();
    }

    // Deadlock guard (device appfreeze THREAD_BLOCK_6S 20260727155932): the
    // Qt thread can synchronously call back into the ArkTS JS thread through
    // the QPA plugin (e.g. Table::insertColumns -> setOverrideCursor ->
    // QOpenHarmonyJsFunction::call).  If this JS thread blocks on the Qt
    // thread at the same time, both deadlock and the watchdog kills the app.
    // Mutation commands are therefore queued fire-and-forget; query commands
    // (read-only, no QPA callbacks) wait with a 3s timeout fallback.
    const std::string cmdName(cmd ? cmd : "");
    const std::string argsCopy(jsonArgs ? jsonArgs : "{}");
    const bool isQuery = cmdName == "ping" || cmdName == "getTableList"
            || cmdName == "getTableData" || cmdName == "getPlotList"
            || cmdName == "getPlotData";

    struct CallState {
        QSemaphore done;
        std::string result;
        std::atomic<bool> abandoned { false };
    };
    auto state = std::make_shared<CallState>();

    QMetaObject::invokeMethod(core, [cmdName, argsCopy, state]() {
        std::string s_result;
        const std::string &cmdStr = cmdName;
        QJsonDocument doc = QJsonDocument::fromJson(
                QByteArray(argsCopy.c_str(), int(argsCopy.size())));
'@

# --- 2b. scidavis_call tail: queued dispatch + timeout wait ---
Apply-Patch 'dispatch tail' @'
        } else {
            s_result = "{\"success\":false,\"error\":\"unknown cmd: ";
            s_result += cmdStr;
            s_result += "\"}";
        }
    }, Qt::BlockingQueuedConnection);

    return s_result.c_str();
}
'@ @'
        } else {
            s_result = "{\"success\":false,\"error\":\"unknown cmd: ";
            s_result += cmdStr;
            s_result += "\"}";
        }
        if (state->abandoned.load())
            OHOS_LOG("scidavis_call[%s] finished after timeout: %s",
                     cmdStr.c_str(), s_result.c_str());
        else
            state->result = std::move(s_result);
        state->done.release();
    }, Qt::QueuedConnection);

    if (!isQuery) {
        // Fire-and-forget: the action runs as soon as the Qt event loop is
        // idle.  Returning now keeps the JS thread free to service any QPA
        // callback the action triggers (cursor, window title, ...).
        s_ret = "{\"success\":true,\"queued\":true}";
        return s_ret.c_str();
    }

    if (state->done.tryAcquire(1, 3000)) {
        s_ret = state->result;
    } else {
        // Qt thread busy or blocked on a QPA callback: give up so the JS
        // thread can drain it; the queued lambda will still run later.
        state->abandoned.store(true);
        s_ret = "{\"success\":false,\"error\":\"timeout\"}";
    }
    return s_ret.c_str();
}
'@

# --- 2c. stale comment in menuAction branch ---
Apply-Patch 'menuAction comment' @'
            // Fallback route for ArkTS menu items without a dedicated
            // command.  Runs on the Qt thread (BlockingQueuedConnection),
            // so ApplicationWindow methods are called directly.  Only
'@ @'
            // Fallback route for ArkTS menu items without a dedicated
            // command.  Runs queued on the Qt thread, so ApplicationWindow
            // methods are called directly on the right thread.  Only
'@

[System.IO.File]::WriteAllText($path, $textLf)
Write-Host 'DONE'
