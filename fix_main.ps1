$path = "C:\Users\Forwardz\scidavis-ohos\scidavis\scidavis\src\main.cpp"
$content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

# 1. Add QPointer include
$content = $content -replace '#include <QWindow>', "#include <QWindow>`n#include <QPointer>"

# 2. Replace the whole inject_mouse function
$oldFunc = "extern ""C"" __attribute__((visibility(""default"")))`nvoid scidavis_inject_mouse(float x, float y, int button, int action)`n{`n    QCoreApplication *core = QCoreApplication::instance();`n    if (!core)`n        return;`n    // Hop onto the Qt GUI thread; NAPI calls arrive on the ArkTS thread.`n    QMetaObject::invokeMethod(core, [x, y, button, action]() {`n        QWindow *win = QGuiApplication::focusWindow();`n        if (!win) {`n            const auto tls = QGuiApplication::topLevelWindows();`n            for (QWindow *w : tls)`n                if (w->isVisible()) { win = w; break; }`n        }`n        if (!win)`n            return;`n        static QElapsedTimer sPressTimer;`n        static QPoint sLastPress;`n        const QPoint globalP{ int(x), int(y) };`n        const QPoint localP = win->mapFromGlobal(globalP);`n        Qt::MouseButton btn = (button == 2) ? Qt::RightButton : Qt::LeftButton;`n        Qt::MouseButtons buttons = btn;`n        QEvent::Type type = QEvent::MouseButtonPress;`n        switch (action) {`n        case 0: { // press --- synthesize double click like QGuiApplication would`n            const bool dbl = sPressTimer.isValid() && !sPressTimer.hasExpired(400)`n                    && (globalP - sLastPress).manhattanLength() < 10;`n            type = dbl ? QEvent::MouseButtonDblClick : QEvent::MouseButtonPress;`n            sPressTimer.restart();`n            sLastPress = globalP;`n            break;`n        }`n        case 1:`n            type = QEvent::MouseButtonRelease;`n            buttons = Qt::NoButton;`n            break;`n        case 2:`n            type = QEvent::MouseMove;`n            btn = Qt::NoButton;`n            buttons = Qt::LeftButton;`n            break;`n        default:`n            return;`n        }`n        QMouseEvent ev(type, localP, localP, globalP, btn, buttons, Qt::NoModifier,`n                       Qt::MouseEventSynthesizedByApplication);`n        // Deliver to the QWidgetWindow: its event() runs the full widget-level`n        // dispatch (popup handling, implicit grab, child lookup).`n        QCoreApplication::sendEvent(win, &ev);`n    }, Qt::QueuedConnection);`n}"

$newFunc = "extern ""C"" __attribute__((visibility(""default"")))`nvoid scidavis_inject_mouse(float x, float y, int button, int action)`n{`n    QCoreApplication *core = QCoreApplication::instance();`n    if (!core)`n        return;`n    // Hop onto the Qt GUI thread; NAPI calls arrive on the ArkTS thread.`n    QMetaObject::invokeMethod(core, [x, y, button, action]() {`n        // Find target window (QPointer for crash safety)`n        QPointer<QWindow> win = QGuiApplication::focusWindow();`n        if (!win) {`n            const auto tls = QGuiApplication::topLevelWindows();`n            for (QWindow *w : tls)`n                if (w->isVisible()) { win = w; break; }`n        }`n        if (!win)`n            return;`n`n        // ArkUI onTouch coordinates are window-local virtual pixels (vp).`n        // Treat them as Qt window-local coordinates directly, then derive`n        // the global position from the window's screen position.`n        const QPoint localP{ static_cast<int>(x), static_cast<int>(y) };`n        const QPoint globalP = win->mapToGlobal(localP);`n`n        Qt::MouseButton btn = (button == 2) ? Qt::RightButton : Qt::LeftButton;`n        Qt::MouseButtons buttons = btn;`n        QEvent::Type type = QEvent::MouseButtonPress;`n`n        // Per-connection static timer for double-click detection.`n        // QueuedConnection serialises invocations on the Qt GUI thread,`n        // so this is safe without mutex.`n        static QElapsedTimer sPressTimer;`n        static QPoint sLastPress;`n`n        switch (action) {`n        case 0: { // press`n            const bool dbl = sPressTimer.isValid() && !sPressTimer.hasExpired(400)`n                    && (localP - sLastPress).manhattanLength() < 10;`n            type = dbl ? QEvent::MouseButtonDblClick : QEvent::MouseButtonPress;`n            sPressTimer.restart();`n            sLastPress = localP;`n            break;`n        }`n        case 1:`n            type = QEvent::MouseButtonRelease;`n            buttons = Qt::NoButton;`n            break;`n        case 2:`n            type = QEvent::MouseMove;`n            btn = Qt::NoButton;`n            buttons = Qt::LeftButton;`n            break;`n        default:`n            return;`n        }`n`n        // Bounds sanity check: reject coordinates far outside the window`n        // to prevent Qt widget code from asserting on bogus positions.`n        if (localP.x() < -100 || localP.y() < -100 ||`n            localP.x() > win->width() + 100 || localP.y() > win->height() + 100)`n            return;`n`n        QMouseEvent ev(type, localP, localP, globalP, btn, buttons, Qt::NoModifier,`n                       Qt::MouseEventSynthesizedByApplication);`n        QCoreApplication::sendEvent(win, &ev);`n    }, Qt::QueuedConnection);`n}`

if ($content.Contains($oldFunc)) {
    $content = $content.Replace($oldFunc, $newFunc)
    Write-Output "inject_mouse replaced"
} else {
    Write-Output "ERROR: old function not found!"
    $idx = $content.IndexOf("scidavis_inject_mouse")
    if ($idx -ge 0) {
        Write-Output "Found at index $idx"
        Write-Output $content.Substring($idx, 500)
    }
    exit 1
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
Write-Output "File saved"

# Verify
$v = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$ok = $true
if ($v -match "QPointer") { Write-Output "PASS: QPointer" } else { Write-Output "FAIL: QPointer"; $ok = $false }
if ($v -match "mapToGlobal") { Write-Output "PASS: mapToGlobal" } else { Write-Output "FAIL: mapToGlobal"; $ok = $false }
if ($v -match "localP.x">") { Write-Output "PASS: bounds check" } else { Write-Output "FAIL: bounds check"; $ok = $false }
if ($v -notmatch "mapFromGlobal") { Write-Output "PASS: mapFromGlobal removed" } else { Write-Output "FAIL: mapFromGlobal still present"; $ok = $false }
if ($ok) { exit 0 } else { exit 1 }
