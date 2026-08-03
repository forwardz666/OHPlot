/***************************************************************************
    File                 : main.cpp
    Project              : SciDAVis
    --------------------------------------------------------------------
    Copyright            : (C) 2006 by Ion Vasilief, Tilman Benkert
    Email (use @ for *)  : ion_vasilief*yahoo.fr, thzs*gmx.net
    Description          : SciDAVis main function

 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *  This program is free software; you can redistribute it and/or modify   *
 *  it under the terms of the GNU General Public License as published by   *
 *  the Free Software Foundation; either version 2 of the License, or      *
 *  (at your option) any later version.                                    *
 *                                                                         *
 *  This program is distributed in the hope that it will be useful,        *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of         *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          *
 *  GNU General Public License for more details.                           *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the Free Software           *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor,                    *
 *   Boston, MA  02110-1301  USA                                           *
 *                                                                         *
 ***************************************************************************/
#include <QMenuBar>
#include "ApplicationWindow.h"
#include "globals.h"
#include "Note.h"
#include "ohos_bridge.h"
#include "TableStatistics.h"
#include "Table.h"
#include "Matrix.h"
#include "future/matrix/MatrixView.h"
#include "future/table/TableView.h"
#include "future/core/column/Column.h"
#include "Correlation.h"
#include "Differentiation.h"
#include "FFT.h"
#include "FFTFilter.h"
#include "Integration.h"
#include "Interpolation.h"
#include "PolynomialFit.h"
#include "SmoothFilter.h"
#include "Convolution.h"
#include "ArrowMarker.h"

#include <QAction>
#include <QApplication>
#include <QClipboard>
#include <QElapsedTimer>
#include <QMouseEvent>
#include <QMdiSubWindow>
#include <QSplashScreen>
#include <QTimer>
#include <QToolBar>
#include <QDockWidget>
#include <QWindow>
#include <QPointer>
#include <QSemaphore>
#include <QSet>
#include <atomic>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <algorithm>
#include <functional>
#include <map>
#include <memory>
#include <set>
#include "Folder.h"
#include "MultiLayer.h"
#include "Graph.h"
#include "Legend.h"
#include "PlotCurve.h"
#include "ImageMarker.h"
#include "Grid.h"
#include <qwt_data.h>
#include <qwt_scale_div.h>
#include <qwt_scale_draw.h>
#include <qwt_scale_engine.h>
#include <qwt_scale_map.h>

#include <typeinfo>
#include <cmath>
#include <cstdio>
#include <string>
#include <chrono>
#define OHOS_LOG(fmt, ...) do { fprintf(stderr, "[SciDAVis:%d] " fmt "\n", __LINE__, ##__VA_ARGS__); fflush(stderr); } while(0)

// Earliest probe — runs during dlopen, before main()
__attribute__((constructor)) static void _ohos_early_probe() {
    fprintf(stderr, "[SciDAVis:CTOR] early-probe\n"); fflush(stderr);
}

struct Application : public QApplication
{
    Application(int &argc, char **argv) : QApplication(argc, argv) { }

    // catch exception, and display their contents as modal dialogue
    bool notify(QObject *receiver, QEvent *event)
    {
        try {
            return QApplication::notify(receiver, event);
        } catch (const std::exception &e) {
            QMessageBox::critical(0, tr("Error!"),
                                  tr("Error ") + e.what() + tr(" sending event ")
                                          + typeid(*event).name() + tr(" to object ")
                                          + qPrintable(receiver->objectName()) + " \""
                                          + typeid(*receiver).name() + "\"");
        } catch (...) // shouldn't happen...
        {
            QMessageBox::critical(0, tr("Error!"),
                                  tr("Error <unknown> sending event") + typeid(*event).name()
                                          + tr(" to object ") + qPrintable(receiver->objectName())
                                          + " \"" + typeid(*receiver).name() + "\"");
        }
        return false;
    }
};

// The OpenHarmony QPA delivers physical-keyboard key events with an empty
// text() (verified via InputProbe: digit '1' arrives as key=0x31 text='').
// Editors insert nothing without text, so synthesize it for printable keys.
static QString printableTextFor(int key, Qt::KeyboardModifiers mods)
{
    if (mods & (Qt::ControlModifier | Qt::AltModifier | Qt::MetaModifier))
        return QString(); // shortcuts don't need text
    if (key < 0x20 || key > 0x7e)
        return QString(); // non-printable / special keys untouched
    QChar c = QChar(key);
    if (mods & Qt::ShiftModifier) {
        static const char digitShift[] = ")!@#$%^&*("; // US layout
        if (key >= Qt::Key_0 && key <= Qt::Key_9)
            c = QLatin1Char(digitShift[key - Qt::Key_0]);
        static const struct { int key; char shifted; } symbolShift[] = {
            { Qt::Key_Minus, '_' },
            { Qt::Key_Equal, '+' },
            { Qt::Key_BracketLeft, '{' },
            { Qt::Key_BracketRight, '}' },
            { Qt::Key_Backslash, '|' },
            { Qt::Key_Semicolon, ':' },
            { Qt::Key_Apostrophe, '"' },
            { Qt::Key_Comma, '<' },
            { Qt::Key_Period, '>' },
            { Qt::Key_Slash, '?' },
            { Qt::Key_AsciiTilde, '~' },
        };
        for (const auto &s : symbolShift) {
            if (key == s.key) {
                c = QLatin1Char(s.shifted);
                break;
            }
        }
    }
    if (c.isLetter()) {
        bool shift = mods & Qt::ShiftModifier;
#ifdef Q_OS_OHOS
        bool caps = false; // CapsLockModifier not available on OHOS Qt
#else
        bool caps = mods & Qt::CapsLockModifier;
#endif
        c = (shift ^ caps) ? c.toUpper() : c.toLower();
    }
    return QString(c);
}

// Input diagnostics for the OpenHarmony port: logs mouse press / release,
// key presses and focus changes via qWarning (Qt5Core routes messages to
// hilog on OpenHarmony).  Also fixes text-less printable key events (see
// printableTextFor above).
class InputProbe : public QObject
{
protected:
    bool eventFilter(QObject *obj, QEvent *ev) override
    {
        switch (ev->type()) {
        case QEvent::MouseButtonPress:
        case QEvent::MouseButtonRelease:
        case QEvent::MouseButtonDblClick: {
            auto *me = static_cast<QMouseEvent *>(ev);
            // The single-window QPA cannot create popup windows: a press on
            // the native QMenuBar would run QMenu::popup() -> new top-level
            // window -> SIGSEGV inside the plugin.  The ArkTS overlay is the
            // only menu UI, so block menu-bar presses outright.
            if (ev->type() != QEvent::MouseButtonRelease && obj->isWidgetType()
                && (obj->inherits("QMenuBar") || obj->inherits("QMenu"))) {
                qWarning("[InputProbe] blocked menu-bar mouse %d on %s (popup unsupported)",
                         int(ev->type()), obj->metaObject()->className());
                return true;
            }
            // Cross-source dedup at the QWindow delivery level: a finger tap
            // reaches Qt twice -- natively via the QPA touch pipeline
            // (MouseEventSynthesizedByQt) and again via the ETS overlay
            // (MouseEventSynthesizedByApplication), because ArkTS cannot
            // distinguish finger touches from mouse-converted ones (both
            // report TouchScreen/Finger).  An identical type+button+pos
            // event from a DIFFERENT source within 60ms is that duplicate:
            // swallow it before the widget dispatch runs.
            if (obj->isWindowType()) {
                // Match by down/up KIND, not exact type: the injected path
                // synthesizes DblClick REPLACING the second press, while the
                // native path delivers Press AND DblClick, so exact-type
                // matching would let the native pair of a double-tap leak.
                const int kind = (ev->type() == QEvent::MouseButtonRelease) ? 1 : 0;
                static int sDupKind = -1;
                static QPoint sDupPos;
                static Qt::MouseButton sDupBtn = Qt::NoButton;
                static int sDupSrc = -1;
                static QElapsedTimer sDupTimer;
                const bool dup = sDupTimer.isValid() && !sDupTimer.hasExpired(60)
                        && kind == sDupKind && me->button() == sDupBtn
                        && int(me->source()) != sDupSrc
                        && (me->globalPos() - sDupPos).manhattanLength() < 5;
                if (dup) {
                    qWarning("[InputProbe] dropped cross-source duplicate type=%d src=%d",
                             int(ev->type()), int(me->source()));
                    return true;
                }
                sDupKind = kind;
                sDupPos = me->globalPos();
                sDupBtn = me->button();
                sDupSrc = int(me->source());
                sDupTimer.restart();
            }
            qWarning("[InputProbe] mouse %s recv=%s pos=(%d,%d) global=(%d,%d) btn=0x%x src=%d",
                     ev->type() == QEvent::MouseButtonPress         ? "press"
                             : ev->type() == QEvent::MouseButtonRelease ? "release"
                                                                        : "dblclick",
                     obj->metaObject()->className(), me->pos().x(), me->pos().y(), me->globalX(),
                     me->globalY(), int(me->button()), int(me->source()));
            break;
        }
        case QEvent::MouseMove: {
            auto *me = static_cast<QMouseEvent *>(ev);
            // Finger drags reach Qt twice -- natively via the QPA touch
            // pipeline (MouseEventSynthesizedByQt) and again via the ETS
            // overlay (MouseEventSynthesizedByApplication) -- so every move
            // would otherwise be processed twice by the widgets (drag lag).
            // Coalesce the cross-source duplicate at the QWindow delivery
            // level: a near-identical move from the OTHER source within 60ms
            // is the same finger position re-delivered, so swallow it before
            // the widget dispatch runs.  Moves from the SAME source always
            // pass (the QPA native stream is singular, and the injected
            // stream is a single source too).  Separate state from the
            // press/release dedup above so the two never interfere.
            if (obj->isWindowType()) {
                static int sMoveSrc = -1;
                static QPoint sMovePos;
                static QElapsedTimer sMoveTimer;
                const bool dup = sMoveTimer.isValid() && !sMoveTimer.hasExpired(60)
                        && int(me->source()) != sMoveSrc
                        && (me->globalPos() - sMovePos).manhattanLength() < 5;
                if (dup) {
                    qWarning("[InputProbe] dropped cross-source duplicate move src=%d pos=(%d,%d)",
                             int(me->source()), me->globalPos().x(), me->globalPos().y());
                    return true;
                }
                sMovePos = me->globalPos();
                sMoveSrc = int(me->source());
                sMoveTimer.restart();
            }
            break;
        }
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
        case QEvent::FocusIn:
            if (obj->isWidgetType())
                qWarning("[InputProbe] focus-in recv=%s", obj->metaObject()->className());
            break;
        case QEvent::KeyPress: {
            auto *ke = static_cast<QKeyEvent *>(ev);
            qWarning("[InputProbe] key press recv=%s key=0x%x nativeVk=%u text='%s'",
                     obj->metaObject()->className(), ke->key(), unsigned(ke->nativeVirtualKey()), qPrintable(ke->text()));
            // Diagnostic markers for the Bluetooth-keyboard Del problem: flag
            // Del/Backspace explicitly so the device log shows whether the key
            // reaches Qt and which Qt key code it carries.
            if (ke->key() == Qt::Key_Delete)
                qWarning("[InputProbe] DEL key reached Qt key=0x%x text='%s'", ke->key(), qPrintable(ke->text()));
            else if (ke->key() == Qt::Key_Backspace)
                qWarning("[InputProbe] BACKSPACE key reached Qt key=0x%x text='%s'", ke->key(), qPrintable(ke->text()));
            // Del-key fix (2026-08-04): the deployed QPA plugin (alpha_v6) fails to
            // map OHOS KEYCODE_DEL(67)/KEYCODE_FORWARD_DEL(112) to Qt::Key_Delete,
            // so a Bluetooth keyboard Del arrives as Qt::Key_unknown.  Remap via the
            // nativeVirtualKey the plugin forwards (device-verified: uinput DEL → key=0x1ffffff).
            // Safety: map ONLY when nativeVk exactly equals a known Del-family code,
            // never for other unknown keys (system Back(2) must keep its own semantics).
            const quint32 nativeVk = ke->nativeVirtualKey();
            const bool isDeleteKey = (ke->key() == Qt::Key_unknown || ke->key() == 0x1000061)
                    && (nativeVk == 67 || nativeVk == 112 || nativeVk == 2055);
            if (isDeleteKey) {
                qWarning("[InputProbe] Del remap nativeVk=%u key=0x%x -> Qt::Key_Delete", nativeVk, ke->key());
                QKeyEvent delEv(ev->type(), Qt::Key_Delete, ke->modifiers(),
                                QString(), ke->isAutoRepeat(), ke->count());
                QCoreApplication::sendEvent(obj, &delEv);
                return true; // consume original
            }
            // QPA delivers spontaneous key events with empty text: swallow the
            // original and re-send a copy carrying the synthesized character.
            if (ev->spontaneous() && ke->text().isEmpty()) {
                const QString fixed = printableTextFor(ke->key(), ke->modifiers());
                if (!fixed.isEmpty()) {
                    QKeyEvent fixedEv(QEvent::KeyPress, ke->key(), ke->modifiers(),
                                      fixed, ke->isAutoRepeat(), ke->count());
                    QCoreApplication::sendEvent(obj, &fixedEv);
                    return true;
                }
            }
            break;
        }
        case QEvent::KeyRelease: {
            auto *ke = static_cast<QKeyEvent *>(ev);
            qWarning("[InputProbe] key release recv=%s key=0x%x nativeVk=%u text='%s'",
                     obj->metaObject()->className(), ke->key(), unsigned(ke->nativeVirtualKey()), qPrintable(ke->text()));
            // Diagnostic markers for the Bluetooth-keyboard Del problem (same
            // tags as KeyPress, so the press→release pair is greppable in the
            // device log).
            if (ke->key() == Qt::Key_Delete)
                qWarning("[InputProbe] DEL key reached Qt key=0x%x text='%s'", ke->key(), qPrintable(ke->text()));
            else if (ke->key() == Qt::Key_Backspace)
                qWarning("[InputProbe] BACKSPACE key reached Qt key=0x%x text='%s'", ke->key(), qPrintable(ke->text()));
            // Del-key fix (2026-08-04): mirror of the KeyPress remap -- the QPA
            // plugin (alpha_v6) fails to map KEYCODE_DEL(67)/KEYCODE_FORWARD_DEL(112)
            // on release too, so remap identically so press/release stay paired for
            // widgets that consume release events.
            const quint32 nativeVk = ke->nativeVirtualKey();
            const bool isDeleteKey = (ke->key() == Qt::Key_unknown || ke->key() == 0x1000061)
                    && (nativeVk == 67 || nativeVk == 112 || nativeVk == 2055);
            if (isDeleteKey) {
                qWarning("[InputProbe] Del remap nativeVk=%u key=0x%x -> Qt::Key_Delete", nativeVk, ke->key());
                QKeyEvent delEv(ev->type(), Qt::Key_Delete, ke->modifiers(),
                                QString(), ke->isAutoRepeat(), ke->count());
                QCoreApplication::sendEvent(obj, &delEv);
                return true; // consume original
            }
            // Same text-less fix as KeyPress: on a Bluetooth keyboard a
            // Shift combo (Shift+digit/symbol/letter) arrives with empty text
            // on release too.  Re-send a copy carrying the synthesized
            // character so editors that consume release events also see it.
            if (ev->spontaneous() && ke->text().isEmpty()) {
                const QString fixed = printableTextFor(ke->key(), ke->modifiers());
                if (!fixed.isEmpty()) {
                    QKeyEvent fixedEv(QEvent::KeyRelease, ke->key(), ke->modifiers(),
                                      fixed, ke->isAutoRepeat(), ke->count());
                    QCoreApplication::sendEvent(obj, &fixedEv);
                    return true;
                }
            }
            break;
        }
        default:
            break;
        }
        return false; // observe only, never consume
    }
};

// ── ETS → Qt mouse injection channel ────────────────────────────────────
// The QPA plugin drops LEFT-button mouse events entirely (ArkUI re-routes
// them into the touch pipeline which the plugin filters out; only RIGHT
// button reaches dispatchMouseEvent — verified via InputProbe).  The ETS
// layer forwards left-button events through libqohos.so, which dlsym's this
// export.  Coordinates are physical pixels (HighDpi scaling disabled).
// action: 0 = press, 1 = release, 2 = move (left button held)
extern "C" __attribute__((visibility("default")))
void scidavis_inject_mouse(float x, float y, int button, int action)
{
    QCoreApplication *core = QCoreApplication::instance();
    if (!core)
        return;
    // Hop onto the Qt GUI thread; NAPI calls arrive on the ArkTS thread.
    QMetaObject::invokeMethod(core, [x, y, button, action]() {
        // NOTE: the previous 30ms global debounce was removed.  It did not
        // distinguish button/action, so a fast tap lost its release event
        // (<30ms after press -> stuck button) and drag moves arriving every
        // 8-16ms were mostly dropped.  Duplicate delivery is prevented at
        // the source instead: the ETS overlay skips LEFT clicks in onMouse
        // (left arrives via onTouch only), so no event reaches here twice.

        QPointer<QWindow> win = QGuiApplication::focusWindow();
        if (!win) {
            const auto tls = QGuiApplication::topLevelWindows();
            for (QWindow *w : tls)
                if (w->isVisible()) { win = w; break; }
        }
        if (!win || !win->isExposed())
            return;
        // Double-click tracking: static locals are safe here -- this lambda
        // always runs on the Qt GUI thread (QueuedConnection), never
        // concurrently.  (The previous make_shared-per-event version reset
        // the timer on every call, so DblClick was never synthesized.)
        static QElapsedTimer sPressTimer;
        static QPoint sLastPress;
        const QPoint localP{ static_cast<int>(x), static_cast<int>(y) };
        const QPoint globalP = win->mapToGlobal(localP);
        const Qt::MouseButton srcBtn = (button == 2) ? Qt::RightButton
                                     : (button == 3) ? Qt::MiddleButton
                                                     : Qt::LeftButton;
        Qt::MouseButton btn = srcBtn;
        Qt::MouseButtons buttons = srcBtn;
        QEvent::Type type = QEvent::MouseButtonPress;
        switch (action) {
        case 0: { // press — synthesize double click like QGuiApplication would
            const bool dbl = sPressTimer.isValid() && !sPressTimer.hasExpired(400)
                    && (localP - sLastPress).manhattanLength() < 10;
            type = dbl ? QEvent::MouseButtonDblClick : QEvent::MouseButtonPress;
            sPressTimer.restart();
            sLastPress = localP;
            break;
        }
        case 1:
            type = QEvent::MouseButtonRelease;
            buttons = Qt::NoButton;
            break;
        case 2: // move with the source button held (left drag / right drag)
            type = QEvent::MouseMove;
            btn = Qt::NoButton;
            buttons = srcBtn;
            break;
        default:
            return;
        }
        // Bounds sanity check: reject coordinates far outside the window
        // to prevent Qt widget code from asserting on bogus positions.
        if (localP.x() < -100 || localP.y() < -100 ||
            localP.x() > win->width() + 100 || localP.y() > win->height() + 100)
            return;

        QMouseEvent ev(type, localP, localP, globalP, btn, buttons, Qt::NoModifier,
                       Qt::MouseEventSynthesizedByApplication);
        // Deliver to the QWidgetWindow: its event() runs the full widget-level
        // dispatch (popup handling, implicit grab, child lookup).
        // Wrap in try-catch as defensive measure against widget-tree transitions.
        try {
            QCoreApplication::sendEvent(win, &ev);
        } catch (...) {
            qWarning("[SciDAVis] scidavis_inject_mouse: sendEvent crashed, caught");
        }
    }, Qt::QueuedConnection);
}


static ApplicationWindow *g_mainWindow = nullptr;

// --- Plot helper functions ------------------------------------------------
static std::string plotListJson()
{
    if (!g_mainWindow) return "[]";
    QJsonArray plots;
    QList<MyWidget *> windows = g_mainWindow->windowsList();
    for (MyWidget *w : windows) {
        if (!w->inherits("MultiLayer")) continue;
        MultiLayer *ml = static_cast<MultiLayer *>(w);
        QJsonObject plotObj;
        plotObj["name"] = ml->name();
        plotObj["label"] = ml->windowLabel();
        plotObj["layers"] = ml->layers();
        QJsonArray graphs;
        QWidgetList gList = ml->graphPtrs();
        for (QWidget *gw : gList) {
            Graph *g = qobject_cast<Graph *>(gw);
            if (!g) continue;
            QJsonObject gObj;
            gObj["curves"] = g->curves();
            QJsonArray curveNames;
            for (int i = 0; i < g->curves(); i++) {
                QwtPlotCurve *pc = g->curve(i);
                if (pc) curveNames.append(pc->title().text());
            }
            gObj["curveNames"] = curveNames;
            graphs.append(gObj);
        }
        plotObj["graphs"] = graphs;
        plots.append(plotObj);
    }
    return QJsonDocument(plots).toJson(QJsonDocument::Compact).toStdString();
}

static std::string plotDataJson(const QString &plotName, int graphIdx, int curveIdx)
{
    if (!g_mainWindow) return "[]";
    QList<MyWidget *> windows = g_mainWindow->windowsList();
    for (MyWidget *w : windows) {
        if (!w->inherits("MultiLayer")) continue;
        MultiLayer *ml = static_cast<MultiLayer *>(w);
        if (ml->name() != plotName) continue;
        QWidgetList gList = ml->graphPtrs();
        if (graphIdx < 0 || graphIdx >= gList.size()) return "[]";
        Graph *g = qobject_cast<Graph *>(gList[graphIdx]);
        if (!g || curveIdx < 0 || curveIdx >= g->curves()) return "[]";
        QwtPlotCurve *pc = g->curve(curveIdx);
        if (!pc) return "[]";
        const QwtData &d = pc->data();
        size_t n = d.size();
        QJsonObject root;
        root["title"] = pc->title().text();
        root["points"] = static_cast<int>(n);
        QJsonArray xArr, yArr;
        for (size_t i = 0; i < n; i++) {
            xArr.append(d.x(i));
            yArr.append(d.y(i));
        }
        root["x"] = xArr;
        root["y"] = yArr;
        DataCurve *dc = dynamic_cast<DataCurve *>(pc);
        if (dc) {
            root["xColumn"] = dc->xColumnName();
            root["yColumn"] = dc->yColumnName();
        }
        return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
    }
    return "[]";
}

// --- NAPI -> Qt command dispatch ------------------------------------------

static std::string tableListJson()
{
    if (!g_mainWindow) return "[]";
    QList<MyWidget *> *tables = g_mainWindow->tableList();
    if (!tables) return "[]";
    QJsonArray arr;
    for (MyWidget *w : *tables) {
        Table *t = qobject_cast<Table *>(w);
        if (!t) continue;
        QJsonObject obj;
        obj["name"] = t->name();
        obj["label"] = t->windowLabel();
        obj["rows"] = t->rowCount();
        obj["cols"] = t->columnCount();
        arr.append(obj);
    }
    return QJsonDocument(arr).toJson(QJsonDocument::Compact).toStdString();
}

static std::string tableDataJson(const QString &tableName)
{
    if (!g_mainWindow) return "[]";
    Table *t = g_mainWindow->table(tableName);
    if (!t) return "[]";
    int rows = t->rowCount();
    int cols = t->columnCount();
    QJsonObject root;
    root["name"] = t->name();
    root["rows"] = rows;
    root["cols"] = cols;
    QJsonArray colNames;
    for (int c = 0; c < cols; c++)
        colNames.append(t->colName(c));
    root["colNames"] = colNames;
    QJsonArray data;
    for (int r = 0; r < rows; r++) {
        QJsonArray row;
        for (int c = 0; c < cols; c++)
            row.append(t->text(r, c));
        data.append(row);
    }
    root["data"] = data;
    return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
}

// Resolve the table a command targets: explicit tableId, else the active
// MDI subwindow if it is a Table.
static Table *resolveTable(const QJsonObject &args)
{
    if (!g_mainWindow) return nullptr;
    QString id = args["tableId"].toString();
    if (!id.isEmpty())
        return g_mainWindow->table(id);
    return qobject_cast<Table *>(g_mainWindow->d_workspace.activeSubWindow());
}

// Resolve the matrix a command targets (same pattern as resolveTable).
static Matrix *resolveMatrix(const QJsonObject &args)
{
    if (!g_mainWindow) return nullptr;
    QString id = args["matrixId"].toString();
    if (!id.isEmpty())
        return g_mainWindow->matrix(id);
    return qobject_cast<Matrix *>(g_mainWindow->d_workspace.activeSubWindow());
}

// Resolve the MultiLayer a command targets (explicit plotId, else the
// active MDI subwindow if it is a plot).
static MultiLayer *resolvePlot(const QJsonObject &args)
{
    if (!g_mainWindow) return nullptr;
    QString id = args["plotId"].toString();
    if (!id.isEmpty()) {
        for (QMdiSubWindow *w : g_mainWindow->d_workspace.subWindowList()) {
            auto *ml = qobject_cast<MultiLayer *>(w);
            if (ml && ml->name() == id) return ml;
        }
        return nullptr;
    }
    return qobject_cast<MultiLayer *>(g_mainWindow->d_workspace.activeSubWindow());
}

// UI state for the ArkTS shell: active window, window list, undo/redo
// availability.  Drives menu enabling/greying and context-menu switching.
static std::string uiStateJson()
{
    if (!g_mainWindow) return "{}";
    QJsonObject root;
    QMdiSubWindow *sub = g_mainWindow->d_workspace.activeSubWindow();
    MyWidget *aw = qobject_cast<MyWidget *>(sub);
    root["activeType"] = aw ? QString::fromLatin1(aw->metaObject()->className()) : QString();
    root["activeName"] = aw ? aw->name() : QString();
    QJsonArray wins;
    // windowsList() concatenates the folder-tree windows with the
    // hiddenWindows/outWindows lists; analysis result tables created via
    // newHiddenTable() sit in BOTH (initTable adds them to the folder,
    // hideWindow appends to hiddenWindows), so dedupe by pointer here or
    // the Windows menu shows Smoothed1/Derivative1/... twice.
    QSet<MyWidget *> seen;
    for (MyWidget *w : g_mainWindow->windowsList()) {
        if (seen.contains(w)) continue;
        seen.insert(w);
        QJsonObject o;
        o["name"] = w->name();
        o["type"] = QString::fromLatin1(w->metaObject()->className());
        o["label"] = w->windowLabel();
        o["status"] = int(w->status());
        o["active"] = (w == aw);
        wins.append(o);
    }
    // Additional dedup by name (pointer dedup above may miss duplicates
    // from windowsList() concatenating folder + hiddenWindows + outWindows
    // where the same window appears as different pointer entries)
    QSet<QString> seenNames;
    QJsonArray dedupedWins;
    for (int i = 0; i < wins.size(); i++) {
        const QJsonObject &o = wins[i].toObject();
        const QString name = o["name"].toString();
        if (seenNames.contains(name)) continue;
        seenNames.insert(name);
        dedupedWins.append(o);
    }
    root["windows"] = dedupedWins;
    QAction *undo = g_mainWindow->ohosActionUndo();
    QAction *redo = g_mainWindow->ohosActionRedo();
    root["undoEnabled"] = undo && undo->isEnabled();
    root["redoEnabled"] = redo && redo->isEnabled();
    return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
}

// Qt → ArkTS push for MDI subwindow activation: the ArkTS menu bar rebuilds
// on windowActivated, mirroring the activeType/activeName getUiState reports
// (className() of the active MyWidget, e.g. "Table"/"Matrix"/"MultiLayer").
// Connected to QMdiArea::subWindowActivated in main() so BOTH activation by
// clicking a window in the workspace AND activation via the Windows→win:*
// menu (activateSubWindow → setActiveSubWindow) fire the event.
static void emitWindowActivated(QMdiSubWindow *sub)
{
    MyWidget *aw = qobject_cast<MyWidget *>(sub);
    if (!aw)
        return;
    QJsonObject p;
    p[QStringLiteral("activeType")] = QString::fromLatin1(aw->metaObject()->className());
    p[QStringLiteral("activeName")] = aw->name();
    scidavisEmitEvent(QStringLiteral("windowActivated"), p);
}

static QJsonObject projectTreeJson(Folder *f)
{
    QJsonObject node;
    node["name"] = f->name();
    node["type"] = QStringLiteral("Folder");
    QJsonArray children;
    for (MyWidget *w : f->windowsList()) {
        QJsonObject wn;
        wn["name"] = w->name();
        wn["type"] = QString::fromLatin1(w->metaObject()->className());
        wn["children"] = QJsonArray();
        children.append(wn);
    }
    for (Folder *sub : f->folders())
        children.append(projectTreeJson(sub));
    node["children"] = children;
    return node;
}

// --- Command registry -------------------------------------------------------
// Every scidavis_call command is one entry here; handlers always run on the
// Qt GUI thread (queued from scidavis_call).  Adding a command = adding an
// entry (and, for read-only commands, listing it in queryCommands()).

using CommandHandler = std::function<std::string(const QJsonObject &)>;

static std::string jsonError(const std::string &msg)
{
    return "{\"success\":false,\"error\":\"" + msg + "\"}";
}

// Read-only commands: scidavis_call waits (3s timeout) and returns the
// payload; everything else is queued fire-and-forget (deadlock guard).
static const std::set<std::string> &queryCommands()
{
    static const std::set<std::string> q = { "ping",        "getTableList", "getTableData",
                                             "getColumnInfo", "getPlotList", "getPlotData",
                                              "getUiState", "getClipboardText", "getGraphCurves",
                                              "getProjectTree", "getPreference", "getNoteData",
                                              "getMatrixData", "tableSize", "getAxisConfig",
                                              "getPlotAssociations", "getCurveInfo",
                                              "getActiveWindowInfo", "getStartPath" };
    return q;
}

// setViewportMargins() is protected in QAbstractScrollArea. Expose it via a
// minimal accessor (standard idiom) so setChromeInsets can deterministically
// shift the QMdiArea viewport to clear the ArkTS chrome overlay.
class ViewportMarginAccessor : public QAbstractScrollArea
{
public:
    using QAbstractScrollArea::setViewportMargins;
};

static const std::map<std::string, CommandHandler> &commandRegistry()
{
    static const std::map<std::string, CommandHandler> reg = {
        { "ping",
          [](const QJsonObject &) -> std::string { return "{\"success\":true,\"pong\":true}"; } },

        { "getTableList",
          [](const QJsonObject &) -> std::string {
              return "{\"success\":true,\"data\":" + tableListJson() + "}";
          } },

        { "getTableData",
          [](const QJsonObject &args) -> std::string {
              // Empty tableId falls back to the active table (the ArkTS
              // @Prop may not have propagated yet when a dialog opens).
              QString id = args["tableId"].toString();
              if (id.isEmpty()) {
                  Table *t = resolveTable(args);
                  if (t) id = t->name();
              }
              return "{\"success\":true,\"data\":" + tableDataJson(id) + "}";
          } },

        { "getColumnInfo",
          [](const QJsonObject &args) -> std::string {
              Table *t = resolveTable(args);
              if (!t) return jsonError("table not found");
              int cols = t->columnCount();
              QJsonArray arr;
              for (int c = 0; c < cols; c++) {
                  Column *col = t->column(c);
                  if (!col) continue;
                  QJsonObject obj;
                  obj["col"] = c;
                  obj["name"] = col->name();
                  // Column mode / type
                  QString type;
                  switch (col->columnMode()) {
                  case SciDAVis::ColumnMode::Numeric:  type = QStringLiteral("Numeric");  break;
                  case SciDAVis::ColumnMode::Text:     type = QStringLiteral("Text");     break;
                  case SciDAVis::ColumnMode::DateTime: type = QStringLiteral("DateTime"); break;
                  case SciDAVis::ColumnMode::Month:    type = QStringLiteral("Month");    break;
                  case SciDAVis::ColumnMode::Day:      type = QStringLiteral("Day");      break;
                  default: type = QStringLiteral("Numeric"); break;
                  }
                  obj["type"] = type;
                  // Description — use comment(), or fall back to name
                  QString desc = col->comment();
                  if (desc.isEmpty()) desc = col->name();
                  obj["description"] = desc;
                  // Formula for row 0
                  obj["formula"] = col->formula(0);
                  // Plot designation
                  QString pd;
                  switch (col->plotDesignation()) {
                  case SciDAVis::X:             pd = QStringLiteral("X");      break;
                  case SciDAVis::Y:             pd = QStringLiteral("Y");      break;
                  case SciDAVis::Z:             pd = QStringLiteral("Z");      break;
                  case SciDAVis::xErr:          pd = QStringLiteral("XError"); break;
                  case SciDAVis::yErr:          pd = QStringLiteral("YError"); break;
                  case SciDAVis::noDesignation: pd = QStringLiteral("None");   break;
                  default:                      pd = QStringLiteral("None");   break;
                  }
                  obj["plotDesignation"] = pd;
                  arr.append(obj);
              }
              QJsonObject root;
              root["success"] = true;
              root["data"] = arr;
              return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "getUiState",
          [](const QJsonObject &) -> std::string {
              return "{\"success\":true,\"data\":" + uiStateJson() + "}";
          } },

        { "getProjectTree",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              QJsonObject root;
              root["success"] = true;
              root["data"] = projectTreeJson(g_mainWindow->projectFolder());
              return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "newTable",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              Table *t = g_mainWindow->newTable();
              if (!t) return jsonError("failed");
              // Notify ArkTS that the table list changed
              scidavisEmitEvent(QStringLiteral("tableListChanged"));
              return "{\"success\":true,\"data\":" + tableListJson() + "}";
          } },

        { "getPlotList",
          [](const QJsonObject &) -> std::string {
              return "{\"success\":true,\"data\":" + plotListJson() + "}";
          } },

        { "getPlotData",
          [](const QJsonObject &args) -> std::string {
              std::string data = plotDataJson(args["plotId"].toString(),
                                              args["graphIdx"].toInt(), args["curveIdx"].toInt());
              return "{\"success\":true,\"data\":" + data + "}";
          } },

        { "setCellValue",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              Table *t = g_mainWindow->table(args["tableId"].toString());
              int row = args["row"].toInt();
              int col = args["col"].toInt();
              if (!t || row < 0 || row >= t->rowCount() || col < 0 || col >= t->columnCount())
                  return jsonError("invalid cell");
              t->setText(row, col, args["value"].toString());
              // Notify ArkTS to refresh table data
              {
                  QJsonObject ep;
                  ep["tableId"] = args["tableId"].toString();
                  scidavisEmitEvent(QStringLiteral("tableDataChanged"), ep);
              }
              return "{\"success\":true}";
          } },

        { "importASCII",
          [](const QJsonObject &args) -> std::string {
              // Queued command; ArkTS copies the picked file into the sandbox
              // first.  Completion is announced through the message event.
              if (!g_mainWindow) return jsonError("no mw");
              QString fn = args["filePath"].toString();
              if (fn.isEmpty() || !QFile::exists(fn)) return jsonError("file not found");
              QString sep = args["separator"].toString("\t");
              QStringList files;
              files << fn;
              // Only set locale if explicitly provided
              QLocale locale = QLocale::c();
              if (args.contains("locale"))
                  locale = QLocale(args["locale"].toString());
              g_mainWindow->importASCII(files, args["importMode"].toInt(0), sep,
                                        args["ignoredLines"].toInt(0),
                                        args["renameColumns"].toBool(true),
                                        args["stripSpaces"].toBool(true),
                                        args["simplifySpaces"].toBool(false),
                                        args["convertToNumeric"].toBool(true), locale);
              QJsonObject p;
              p["title"] = QObject::tr("Import ASCII");
              p["text"] = QObject::tr("Imported: ") + QFileInfo(fn).fileName();
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              // Notify ArkTS that table list changed after import
              scidavisEmitEvent(QStringLiteral("tableListChanged"));
              return "{\"success\":true,\"data\":" + tableListJson() + "}";
          } },

        { "exportASCII",
          [](const QJsonObject &args) -> std::string {
              // Direct-to-path export (Table::exportASCII); the desktop
              // ApplicationWindow::exportASCII pops a QFileDialog which the
              // single-window QPA cannot show.  Queued; the asciiExported
              // event triggers the ArkTS picker copy-out.
              if (!g_mainWindow) return jsonError("no mw");
              Table *t = g_mainWindow->table(args["tableId"].toString());
              if (!t) return jsonError("table not found");
              QString fn = args["path"].toString();
              if (fn.isEmpty()) return jsonError("no path");
              bool ok = t->exportASCII(fn, args["separator"].toString("\t"),
                                       args["colNames"].toBool(true), false);
              QJsonObject done; done["ok"] = ok; done["path"] = fn;
              scidavisEmitEvent(QStringLiteral("asciiExported"), done);
              if (!ok) {
                  QJsonObject p;
                  p["title"] = QObject::tr("Export ASCII");
                  p["text"] = QObject::tr("Failed to export: ") + QFileInfo(fn).fileName();
                  p["icon"] = QStringLiteral("critical");
                  scidavisEmitEvent(QStringLiteral("message"), p);
              }
              return ok ? std::string("{\"success\":true}") : jsonError("export failed");
          } },

        // ── Table operations (Phase 2) ─────────────────────────────────
        // All queued (mutations); results are announced via the message
        // event so the ArkTS shell can toast them.  The desktop dialogs
        // (SetColValuesDialog/SortDialog/...) cannot be shown on the
        // single-window QPA, so ArkTS dialogs supply the parameters.
        { "addTableColumns",
          [](const QJsonObject &args) -> std::string {
              Table *t = resolveTable(args);
              if (!t) return jsonError("table not found");
              int count = qBound(1, args["count"].toInt(1), 100);
              for (int i = 0; i < count; i++)
                  t->addCol();
              // Notify ArkTS to refresh table data + list
              {
                  QJsonObject ep;
                  ep["tableId"] = args["tableId"].toString();
                  scidavisEmitEvent(QStringLiteral("tableDataChanged"), ep);
              }
              scidavisEmitEvent(QStringLiteral("tableListChanged"));
              QJsonObject p;
              p["title"] = QObject::tr("Add Columns");
              p["text"] = QObject::tr("Added %1 column(s) to %2").arg(count).arg(t->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              return "{\"success\":true}";
          } },

        { "setColumnValues",
          [](const QJsonObject &args) -> std::string {
              // muParser formula, whole column (desktop SetColValuesDialog).
              Table *t = resolveTable(args);
              if (!t) return jsonError("table not found");
              int col = args["col"].toInt(-1);
              if (col < 0 || col >= t->numCols()) return jsonError("invalid column");
              QString formula = args["formula"].toString();
              if (formula.isEmpty()) return jsonError("empty formula");
              t->setCommand(col, formula);
              bool ok = t->recalculate(col, false);
              QJsonObject p;
              p["title"] = QObject::tr("Set Column Values");
              p["text"] = ok ? t->colName(col) + " = " + formula
                             : QObject::tr("Formula error: ") + formula;
              p["icon"] = ok ? QStringLiteral("information") : QStringLiteral("critical");
              scidavisEmitEvent(QStringLiteral("message"), p);
              // Notify ArkTS to refresh table data after column recalculation
              {
                  QJsonObject ep;
                  ep["tableId"] = args["tableId"].toString();
                  scidavisEmitEvent(QStringLiteral("tableDataChanged"), ep);
              }
              return ok ? std::string("{\"success\":true}") : jsonError("recalculate failed");
          } },

        { "sortTable",
          [](const QJsonObject &args) -> std::string {
              // future::Table::sortColumns — no-dialog core of SortDialog.
              // leading < 0 sorts every column separately.
              Table *t = resolveTable(args);
              if (!t || !t->d_future_table) return jsonError("table not found");
              bool asc = args["ascending"].toBool(true);
              int leadIdx = args["leading"].toInt(-1);
              QList<Column *> cols;
              for (int i = 0; i < t->numCols(); i++)
                  cols << t->column(i);
              Column *leading =
                      (leadIdx >= 0 && leadIdx < t->numCols()) ? t->column(leadIdx) : nullptr;
              t->d_future_table->sortColumns(leading, cols, asc);
              QJsonObject p;
              p["title"] = QObject::tr("Sort Table");
              p["text"] = QObject::tr("Sorted %1 (%2)").arg(t->name())
                      .arg(asc ? QObject::tr("ascending") : QObject::tr("descending"));
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              // Notify ArkTS to refresh table data after sort
              {
                  QJsonObject ep;
                  ep["tableId"] = args["tableId"].toString();
                  scidavisEmitEvent(QStringLiteral("tableDataChanged"), ep);
              }
              return "{\"success\":true}";
          } },

        { "tableStatistics",
          [](const QJsonObject &args) -> std::string {
              // Column/row statistics table (desktop acts on the selection;
              // ArkTS has no selection info, so default to all).
              Table *t = resolveTable(args);
              if (!t) return jsonError("table not found");
              bool onRows = args["type"].toString() == "rows";
              QList<int> targets;
              if (args["targets"].isArray()) {
                  for (const QJsonValue &v : args["targets"].toArray())
                      targets << v.toInt();
              } else {
                  int n = onRows ? t->numRows() : t->numCols();
                  for (int i = 0; i < n; i++)
                      targets << i;
              }
              if (targets.isEmpty()) return jsonError("no targets");
              TableStatistics *s = g_mainWindow->newTableStatistics(
                      t, onRows ? TableStatistics::StatRow : TableStatistics::StatColumn,
                      targets);
              if (!s) return jsonError("failed");
              s->showNormal();
              // Notify ArkTS that the table list changed (new statistics table created)
              scidavisEmitEvent(QStringLiteral("tableListChanged"));
              QJsonObject p;
              p["title"] = QObject::tr("Statistics");
              p["text"] = QObject::tr("Created %1").arg(s->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              return "{\"success\":true}";
          } },

        // ── 2D plotting (Phase 2) ──────────────────────────────────────
        // No-dialog core of the desktop Plot menu: multilayerPlot(table,
        // colList, style, ...) never pops a dialog.  Validation that the
        // desktop does via QMessageBox is re-done here with message events.
        { "plot2D",
          [](const QJsonObject &args) -> std::string {
              static const std::map<std::string, int> styles = {
                  { "line", Graph::Line },
                  { "scatter", Graph::Scatter },
                  { "line_symbol", Graph::LineSymbols },
                  { "vertical_bars", Graph::VerticalBars },
                  { "horizontal_bars", Graph::HorizontalBars },
                  { "area", Graph::Area },
                  { "pie", Graph::Pie },
                  { "drop_lines", Graph::VerticalDropLines },
                  { "spline", Graph::Spline },
                  { "vertical_steps", Graph::VerticalSteps },
                  { "horizontal_steps", Graph::HorizontalSteps },
                  { "histogram", Graph::Histogram },
                  { "box", Graph::Box },
              };
              auto emitPlotError = [](const QString &text) {
                  QJsonObject p;
                  p["title"] = QObject::tr("Plot error");
                  p["text"] = text;
                  p["icon"] = QStringLiteral("critical");
                  scidavisEmitEvent(QStringLiteral("message"), p);
              };
              Table *t = resolveTable(args);
              if (!t) {
                  emitPlotError(QObject::tr("No table to plot from"));
                  return jsonError("table not found");
              }
              auto it = styles.find(args["type"].toString().toStdString());
              if (it == styles.end()) return jsonError("unknown plot type");
              const int style = it->second;

              // Column list: explicit indices from the ArkTS dialog, else
              // the current Qt selection, else every Y column.
              QStringList colList;
              if (args["cols"].isArray()) {
                  for (const QJsonValue &v : args["cols"].toArray()) {
                      int idx = v.toInt(-1);
                      if (idx >= 0 && idx < t->numCols())
                          colList << t->colName(idx);
                  }
              }
              if (colList.isEmpty())
                  colList = t->selectedColumns();
              if (colList.isEmpty()) {
                  for (int i = 0; i < t->numCols(); i++)
                      if (t->colPlotDesignation(i) == SciDAVis::Y)
                          colList << t->colName(i);
              }

              // Desktop validFor2DPlot()/plotPie() minus the QMessageBox popups.
              if (style == Graph::Pie) {
                  if (colList.count() != 1) {
                      emitPlotError(QObject::tr("Select exactly one column for a pie plot"));
                      return jsonError("pie needs 1 column");
                  }
                  if (t->noXColumn()) {
                      emitPlotError(QObject::tr("Please set a default X column for this table, first!"));
                      return jsonError("no X column");
                  }
              } else if (style != Graph::Histogram && style != Graph::Box) {
                  if (t->numCols() < 2) {
                      emitPlotError(QObject::tr("You need at least two columns for this operation!"));
                      return jsonError("need 2 columns");
                  }
                  if (t->noXColumn()) {
                      emitPlotError(QObject::tr("Please set a default X column for this table, first!"));
                      return jsonError("no X column");
                  }
              }
              if (colList.isEmpty()) {
                  emitPlotError(QObject::tr("Please select a column to plot!"));
                  return jsonError("no columns");
              }

              int startRow = args["startRow"].toInt(0);
              int endRow = args["endRow"].toInt(t->numRows() - 1);
              auto *ml = g_mainWindow->multilayerPlot(t, colList, style, startRow, endRow);
              if (!ml) return jsonError("plot failed");
              QJsonObject p;
              p["title"] = QObject::tr("Plot");
              p["text"] = QObject::tr("Created plot from %1").arg(colList.join(", "));
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              // Notify ArkTS to refresh plot list
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        // ── Clipboard bridge (Phase 2) ──────────────────────────────
        // OHOS pasteboard ↔ QClipboard.  ArkTS pushes the system pasteboard
        // text in before dispatching a paste; Qt-side changes are emitted
        // through the clipboardChanged event (connected in main()).
        { "setClipboardText",
          [](const QJsonObject &args) -> std::string {
              QClipboard *cb = QApplication::clipboard();
              if (!cb) return jsonError("no clipboard");
              cb->setText(args["text"].toString());
              return "{\"success\":true}";
          } },

        { "getClipboardText",
          [](const QJsonObject &) -> std::string {
              QClipboard *cb = QApplication::clipboard();
              QJsonObject r;
              r["success"] = cb != nullptr;
              r["text"] = cb ? cb->text() : QString();
              return QJsonDocument(r).toJson(QJsonDocument::Compact).toStdString();
          } },

        // ── Matrix operations (Phase 3) ────────────────────────────
        // All Matrix slots are dialog-free; invert()'s not-square warning
        // goes through the QMessageBox interposer (ohos_bridge).
        { "matrixSetDimensions",
          [](const QJsonObject &args) -> std::string {
              Matrix *m = resolveMatrix(args);
              if (!m) return jsonError("matrix not found");
              int rows = qBound(1, args["rows"].toInt(m->numRows()), 100000);
              int cols = qBound(1, args["cols"].toInt(m->numCols()), 10000);
              m->setDimensions(rows, cols);
              QJsonObject p;
              p["title"] = QObject::tr("Matrix");
              p["text"] = QObject::tr("%1 resized to %2 x %3").arg(m->name()).arg(rows).arg(cols);
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              return "{\"success\":true}";
          } },

        { "matrixSetFormula",
          [](const QJsonObject &args) -> std::string {
              // Matrix::recalculate only fills selected cells, so select
              // everything first (ArkTS has no cell selection to offer).
              Matrix *m = resolveMatrix(args);
              if (!m) return jsonError("matrix not found");
              QString formula = args["formula"].toString();
              if (formula.isEmpty()) return jsonError("empty formula");
              m->setFormula(formula);
              if (auto *view = qobject_cast<MatrixView *>(m->view()))
                  view->selectAll();
              bool ok = m->recalculate();
              QJsonObject p;
              p["title"] = QObject::tr("Set Matrix Values");
              p["text"] = ok ? m->name() + " = " + formula
                             : QObject::tr("Formula error: ") + formula;
              p["icon"] = ok ? QStringLiteral("information") : QStringLiteral("critical");
              scidavisEmitEvent(QStringLiteral("message"), p);
              return ok ? std::string("{\"success\":true}") : jsonError("recalculate failed");
          } },

        { "matrixTranspose",
          [](const QJsonObject &args) -> std::string {
              Matrix *m = resolveMatrix(args);
              if (!m) return jsonError("matrix not found");
              m->transpose();
              QJsonObject p;
              p["title"] = QObject::tr("Matrix");
              p["text"] = QObject::tr("Transposed %1").arg(m->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              return "{\"success\":true}";
          } },

        { "matrixInvert",
          [](const QJsonObject &args) -> std::string {
              Matrix *m = resolveMatrix(args);
              if (!m) return jsonError("matrix not found");
              if (m->numRows() != m->numCols()) {
                  QJsonObject p;
                  p["title"] = QObject::tr("Error");
                  p["text"] = QObject::tr("Inversion failed, the matrix is not square!");
                  p["icon"] = QStringLiteral("critical");
                  scidavisEmitEvent(QStringLiteral("message"), p);
                  return jsonError("not square");
              }
              m->invert();
              QJsonObject p;
              p["title"] = QObject::tr("Matrix");
              p["text"] = QObject::tr("Inverted %1").arg(m->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              return "{\"success\":true}";
          } },

        // ── Graph image export (Phase 3) ──────────────────────────
        // Renders the MultiLayer to a sandbox PNG; the imageExported event
        // triggers the ArkTS picker copy-out (same flow as exportASCII).
        { "exportGraphImage",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              QString id = args["plotId"].toString();
              MultiLayer *ml = nullptr;
              if (!id.isEmpty()) {
                  for (QMdiSubWindow *w : g_mainWindow->d_workspace.subWindowList()) {
                      auto *cand = qobject_cast<MultiLayer *>(w);
                      if (cand && cand->name() == id) { ml = cand; break; }
                  }
              } else {
                  ml = qobject_cast<MultiLayer *>(g_mainWindow->d_workspace.activeSubWindow());
              }
              if (!ml) return jsonError("plot not found");
              QString fn = args["path"].toString();
              if (fn.isEmpty()) return jsonError("no path");
              ml->exportImage(fn, args["quality"].toInt(-1));
              bool ok = QFile::exists(fn);
              QJsonObject done; done["ok"] = ok; done["path"] = fn;
              scidavisEmitEvent(QStringLiteral("imageExported"), done);
              if (!ok) {
                  QJsonObject p;
                  p["title"] = QObject::tr("Export Image");
                  p["text"] = QObject::tr("Failed to export: ") + QFileInfo(fn).fileName();
                  p["icon"] = QStringLiteral("critical");
                  scidavisEmitEvent(QStringLiteral("message"), p);
              }
              return ok ? std::string("{\"success\":true}") : jsonError("export failed");
          } },

        // ── Analysis suite (Phase 3) ───────────────────────────────
        // One command drives every curve analysis of the desktop Analysis
        // menu; parameters come from ArkTS dialogs.  Whatever the filter
        // appends to the results log is re-emitted as a resultsLog event.
        { "getGraphCurves",
          [](const QJsonObject &args) -> std::string {
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              QJsonArray arr;
              for (const QString &c : g->analysableCurvesList())
                  arr.append(c);
              QJsonObject r;
              r["success"] = true;
              r["curves"] = arr;
              return QJsonDocument(r).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "analyzeCurve",
          [](const QJsonObject &args) -> std::string {
              auto emitErr = [](const QString &text) {
                  QJsonObject p;
                  p["title"] = QObject::tr("Analysis");
                  p["text"] = text;
                  p["icon"] = QStringLiteral("critical");
                  scidavisEmitEvent(QStringLiteral("message"), p);
              };
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g || !g->validCurvesDataSize()) {
                  emitErr(QObject::tr("No plot with analysable curves is active"));
                  return jsonError("no graph");
              }
              QStringList curves = g->analysableCurvesList();
              if (curves.isEmpty()) {
                  emitErr(QObject::tr("The active plot has no analysable curves"));
                  return jsonError("no curves");
              }
              // Default to the most recently added curve (the desktop pops
              // a DataSetDialog instead, which the QPA cannot show).
              QString curve = args["curve"].toString();
              if (curve.isEmpty())
                  curve = curves.last();
              else if (!curves.contains(curve)) {
                  emitErr(QObject::tr("Unknown curve: ") + curve);
                  return jsonError("curve not found");
              }

              const QString op = args["op"].toString();
              const int logBefore = g_mainWindow->logInfo.length();
              bool ok = true;
              if (op == "fit_linear" || op == "fit_sigmoidal" || op == "fit_gauss"
                  || op == "fit_lorentz") {
                  static const std::map<std::string, QString> whichFit = {
                      { "fit_linear", QStringLiteral("fitLinear") },
                      { "fit_sigmoidal", QStringLiteral("fitSigmoidal") },
                      { "fit_gauss", QStringLiteral("fitGauss") },
                      { "fit_lorentz", QStringLiteral("fitLorentz") },
                  };
                  g_mainWindow->analyzeCurve(g, whichFit.at(op.toStdString()), curve);
              } else if (op == "fit_poly") {
                  int order = qBound(2, args["order"].toInt(2), 9);
                  auto *fit = new PolynomialFit(g_mainWindow, g, order, true);
                  if ((ok = fit->setDataFromCurve(curve))) {
                      fit->scaleErrors(g_mainWindow->fit_scale_errors);
                      fit->setOutputPrecision(g_mainWindow->fit_output_precision);
                      fit->generateFunction(g_mainWindow->generateUniformFitPoints,
                                            g_mainWindow->fitPoints);
                      fit->fit();
                  }
                  delete fit;
              } else if (op == "differentiate") {
                  auto *d = new Differentiation(g_mainWindow, g, curve);
                  d->run();
                  delete d;
              } else if (op == "integrate") {
                  auto *i = new Integration(g_mainWindow, g, curve);
                  i->run();
                  delete i;
              } else if (op == "fft") {
                  auto *f = new FFT(g_mainWindow, g, curve);
                  f->run();
                  delete f;
              } else if (op == "smooth") {
                  // method: 1 = Savitzky-Golay, 2 = FFT, 3 = moving average
                  int method = qBound(1, args["method"].toInt(3), 3);
                  auto *s = new SmoothFilter(g_mainWindow, g, curve, method);
                  s->setSmoothPoints(qBound(2, args["points"].toInt(5), 1000));
                  if (method == SmoothFilter::SavitzkyGolay)
                      s->setPolynomOrder(qBound(0, args["order"].toInt(2), 9));
                  ok = s->run();
                  delete s;
              } else if (op == "interpolate") {
                  // method: 0 = linear, 1 = cubic, 2 = Akima
                  int method = qBound(0, args["method"].toInt(0), 2);
                  auto *i = new Interpolation(g_mainWindow, g, curve, method);
                  i->setOutputPoints(qBound(3, args["points"].toInt(1000), 100000));
                  ok = i->run();
                  delete i;
              } else if (op == "fft_filter") {
                  // filterType: 1 low pass, 2 high pass, 3 band pass, 4 band block
                  int type = qBound(1, args["filterType"].toInt(1), 4);
                  auto *f = new FFTFilter(g_mainWindow, g, curve, type);
                  if (type <= FFTFilter::HighPass)
                      f->setCutoff(args["freq"].toDouble(0.0));
                  else
                      f->setBand(args["freq"].toDouble(0.0), args["freq2"].toDouble(0.0));
                  ok = f->run();
                  delete f;
              } else {
                  return jsonError("unknown op");
              }

              QString logDelta = g_mainWindow->logInfo.mid(logBefore).trimmed();
              QJsonObject p;
              p["title"] = QObject::tr("Analysis");
              p["text"] = ok ? op + QObject::tr(" done on ") + curve
                             : QObject::tr("%1 failed on %2").arg(op, curve);
              p["icon"] = ok ? QStringLiteral("information") : QStringLiteral("critical");
              scidavisEmitEvent(QStringLiteral("message"), p);
              if (!logDelta.isEmpty()) {
                  QJsonObject l;
                  l["text"] = logDelta;
                  scidavisEmitEvent(QStringLiteral("resultsLog"), l);
              }
              return ok ? std::string("{\"success\":true}") : jsonError("analysis failed");
          } },

        { "correlate",
          [](const QJsonObject &args) -> std::string {
              // (Auto)correlation of two table columns; the desktop takes
              // the two selected columns, ArkTS passes indices instead.
              Table *t = resolveTable(args);
              if (!t) return jsonError("table not found");
              int c1 = args["col1"].toInt(-1);
              int c2 = args["col2"].toInt(c1);
              if (c1 < 0 || c1 >= t->numCols() || c2 < 0 || c2 >= t->numCols())
                  return jsonError("invalid columns");
              const int logBefore = g_mainWindow->logInfo.length();
              auto *cor = new Correlation(g_mainWindow, t, t->colName(c1), t->colName(c2));
              cor->run();
              delete cor;
              QString logDelta = g_mainWindow->logInfo.mid(logBefore).trimmed();
              QJsonObject p;
              p["title"] = QObject::tr("Correlation");
              p["text"] = QObject::tr("Correlated %1 and %2").arg(t->colName(c1), t->colName(c2));
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              if (!logDelta.isEmpty()) {
                  QJsonObject l;
                  l["text"] = logDelta;
                  scidavisEmitEvent(QStringLiteral("resultsLog"), l);
              }
              return "{\"success\":true}";
          } },

        // ArkTS picker result for a blocked QComboBox popup (ohos_bridge).
        { "selectCombo",
          [](const QJsonObject &args) -> std::string {
              if (!ohosBridgeSelectCombo(args["comboId"].toInt(-1), args["index"].toInt(-1)))
                  return jsonError("combo gone");
              return "{\"success\":true}";
          } },

        // ArkTS selection for a blocked context QMenu (ohos_bridge).
        { "triggerMenu",
          [](const QJsonObject &args) -> std::string {
              if (!ohosBridgeTriggerMenu(args["menuId"].toInt(-1), args["path"].toString()))
                  return jsonError("menu gone");
              return "{\"success\":true}";
          } },

        { "activateWindow",
          [](const QJsonObject &args) -> std::string {
              // Windows menu: raise the MDI subwindow with this name.
              if (!g_mainWindow) return jsonError("no mw");
              QString name = args["name"].toString();
              for (MyWidget *w : g_mainWindow->windowsList()) {
                  if (w && w->name() == name) {
                      g_mainWindow->activateSubWindow(w);
                      return "{\"success\":true}";
                  }
              }
              return jsonError("window not found");
          } },

        { "setGraphTitle",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              g->setTitle(args["title"].toString());
              g->replot();
              return "{\"success\":true}";
          } },

        { "setAxisTitle",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              int axis = args["axis"].toInt(0);
              if (axis < 0 || axis > 3) return jsonError("bad axis");
              g->setAxisTitle(axis, args["text"].toString());
              g->replot();
              return "{\"success\":true}";
          } },

        { "setAxisScale",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              int axis = args["axis"].toInt(0);
              if (axis < 0 || axis > 3) return jsonError("bad axis");
              const QwtScaleDiv *scDiv = g->plotWidget()->axisScaleDiv(axis);
              double start = std::min(scDiv->lowerBound(), scDiv->upperBound());
              double end = std::max(scDiv->lowerBound(), scDiv->upperBound());
              // Honor explicit from/to bounds (AxesDialog sends {axis, scale,
              // from, to}); fall back to the current axis bounds when omitted
              // (GraphPropsDialog toggles the scale type only).
              if (args.contains("from"))
                  start = args["from"].toDouble(start);
              if (args.contains("to"))
                  end = args["to"].toDouble(end);
              if (start > end)
                  std::swap(start, end);
              int type = (args["scale"].toString() == "log") ? 1 : 0;
              if (type == 1 && start <= 0)
                  start = 1e-3;
              g->setScale(axis, start, end, 0.0, 5, 5, type, false);
              g->replot();
              return "{\"success\":true}";
          } },

        { "setAxisGrid",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              int axis = args["axis"].toInt(0);
              if (axis < 0 || axis > 3) return jsonError("bad axis");
              Grid *grid = g->grid();
              if (!grid) return jsonError("no grid");
              // Same axis->grid mapping as getAxisConfig: yLeft/yRight drive
              // the Y grid lines, xBottom/xTop the X lines.
              const bool major = args.contains("majorGrid")
                      ? args["majorGrid"].toBool()
                      : (axis == QwtPlot::yLeft || axis == QwtPlot::yRight)
                              ? grid->yEnabled()
                              : grid->xEnabled();
              const bool minor = args.contains("minorGrid")
                      ? args["minorGrid"].toBool()
                      : (axis == QwtPlot::yLeft || axis == QwtPlot::yRight)
                              ? grid->yMinEnabled()
                              : grid->xMinEnabled();
              if (axis == QwtPlot::yLeft || axis == QwtPlot::yRight) {
                  grid->enableY(major);
                  grid->enableYMin(minor);
              } else {
                  grid->enableX(major);
                  grid->enableXMin(minor);
              }
              g->replot();
              QJsonObject p;
              p["title"] = QObject::tr("Axes");
              p["text"] = QObject::tr("Grid updated for axis %1").arg(axis);
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "setAxisFrame",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              const bool showAxis = args.contains("showAxis") ? args["showAxis"].toBool() : true;
              const bool backbones = args.contains("backbones") ? args["backbones"].toBool() : true;
              const int lineWidth = args["lineWidth"].toInt(1);
              g->drawAxesBackbones(backbones);
              g->setAxesLinewidth(lineWidth);
              // AxesDialog's frame tab sends no per-axis key; apply the axis
              // on/off state to every axis in that case, otherwise only to the
              // requested one.
              if (args.contains("axis")) {
                  int axis = qBound(0, args["axis"].toInt(0), 3);
                  g->enableAxis(axis, showAxis);
              } else {
                  for (int a = QwtPlot::yLeft; a <= QwtPlot::xTop; a++)
                      g->enableAxis(a, showAxis);
              }
              g->replot();
              QJsonObject p;
              p["title"] = QObject::tr("Axes");
              p["text"] = QObject::tr("Frame updated");
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "toggleLegend",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              if (g->hasLegend())
                  g->removeLegend();
              else
                  (void)g->newLegend();
              g->replot();
              return "{\"success\":true}";
          } },

        { "toggleColumnEditor",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              auto *tableView = g_mainWindow->findChild<TableView *>();
              if (!tableView) return jsonError("not a table");
              if (tableView->isControlTabBarVisible())
                  tableView->toggleControlTabBar();
              return "{\"success\":true}";
          } },

        { "openProject",
          [](const QJsonObject &args) -> std::string {
              // ArkTS DocumentViewPicker copies the picked .sciprj into the
              // app sandbox and hands the path over (queued; result toast
              // arrives through the event channel).
              if (!g_mainWindow) return jsonError("no mw");
              QString fn = args["path"].toString();
              if (fn.isEmpty() || !QFile::exists(fn)) return jsonError("file not found");
              bool ok = g_mainWindow->loadProject(fn);
              QJsonObject p;
              p["title"] = QObject::tr("Open Project");
              p["text"] = ok ? QObject::tr("Opened: ") + QFileInfo(fn).fileName()
                             : QObject::tr("Failed to open: ") + QFileInfo(fn).fileName();
              p["icon"] = ok ? QStringLiteral("information") : QStringLiteral("critical");
              scidavisEmitEvent(QStringLiteral("message"), p);
              QJsonObject r;
              r["success"] = ok;
              r["path"] = fn;
              return QJsonDocument(r).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "saveProject",
          [](const QJsonObject &args) -> std::string {
              // No-dialog replacement for saveProjectAs(): fix projectname
              // to a sandbox path first so saveProject() never falls back to
              // the QFileDialog branch (single-window QPA would SIGSEGV).
              // Queued command (saving calls back into the JS thread via the
              // QPA — a blocking query would deadlock); completion is
              // signalled by the projectSaved event, which also triggers the
              // ArkTS save-as copy-out to the picker target.
              if (!g_mainWindow) return jsonError("no mw");
              QString fn = args["path"].toString();
              if (fn.isEmpty()) return jsonError("no path");
              if (!fn.endsWith(".sciprj") && !fn.endsWith(".sciprj.gz"))
                  fn += ".sciprj";
              g_mainWindow->projectname = fn;
              g_mainWindow->saveProject();
              bool ok = QFile::exists(fn);
              QJsonObject done;
              done["ok"] = ok;
              done["path"] = fn;
              scidavisEmitEvent(QStringLiteral("projectSaved"), done);
              QJsonObject p;
              p["title"] = QObject::tr("Save Project");
              p["text"] = ok ? QObject::tr("Saved: ") + QFileInfo(fn).fileName()
                             : QObject::tr("Failed to save: ") + QFileInfo(fn).fileName();
              p["icon"] = ok ? QStringLiteral("information") : QStringLiteral("critical");
              scidavisEmitEvent(QStringLiteral("message"), p);
              QJsonObject r;
              r["success"] = ok;
              r["path"] = fn;
              return QJsonDocument(r).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "menuAction",
          [](const QJsonObject &args) -> std::string {
              // Fallback route for ArkTS menu items without a dedicated
              // command.  Runs queued on the Qt thread, so ApplicationWindow
              // methods are called directly on the right thread.  Only
              // non-dialog actions: the single-window QPA cannot create the
              // top-level window a QDialog/QMessageBox needs (SIGSEGV).
              if (!g_mainWindow) return jsonError("no mw");
              QString itemId = args["itemId"].toString();
              bool ok = true;
               if (itemId == "new_notes") {
                   Note *note = g_mainWindow->newNote();
                   if (note) {
                       // Defer the display to the next event-loop tick: a
                       // synchronous showNormal()+setFocus() blocks the Qt GUI
                       // thread (QMdiArea activation chain + first-frame
                       // render) until the whole menuAction command finishes,
                       // which the UI perceives as a freeze before the window
                       // appears.  QTimer::singleShot(0,...) lets the loop
                       // flush other events first.  Note* is owned by
                       // ApplicationWindow, so the bare pointer stays valid
                       // across one event-loop turn (null-checked anyway).
                       QTimer::singleShot(0, [note]() {
                           if (note) {
                               note->showNormal();
                               note->setFocus();
                           }
                       });
                   }
               }
              else if (itemId == "new_matrix") {
                  // newMatrix() only registers the matrix in the project tree
                  // (d_project->addChild) — it never adds the widget to the MDI
                  // workspace nor shows it, so the matrix is created but stays
                  // invisible.  Mirror the display steps of initMatrix() here.
                  Matrix *m = g_mainWindow->newMatrix(32, 32);
                  if (m) {
                      // Registration steps stay synchronous (must complete in
                      // this command)…
                      g_mainWindow->d_workspace.addSubWindow(m);
                      // newMatrix() already generates and sets a unique name.
                      g_mainWindow->currentFolder()->addWindow(m);
                      g_mainWindow->addListViewItem(m);
                      g_mainWindow->modifiedProject(m);
                      // …but the display is deferred to the next event-loop
                      // tick: synchronous showNormal()/setFocus() blocks the
                      // GUI thread (MDI activation + first-frame render) until
                      // the command finishes.  Deferring lets the loop flush
                      // first, so the window appears without the perceived
                      // freeze.  Matrix* is owned by ApplicationWindow, so the
                      // bare pointer stays valid (null-checked anyway).
                      QTimer::singleShot(0, [m]() {
                          if (m) {
                              m->showNormal();
                              m->setFocus();
                          }
                      });
                  }
              }
              else if (itemId == "new_project") {
                  // Cannot call newProject() — it creates a second
                  // ApplicationWindow which SIGSEGVs on the single-window QPA.
                  // Instead, clear the existing project in-place.
                  for (MyWidget *w : g_mainWindow->windowsList()) {
                      w->askOnCloseEvent(false);
                      w->close();
                  }
                  g_mainWindow->projectname = "untitled";
                  g_mainWindow->newTable();
                  g_mainWindow->savedProject();
                  QJsonObject p;
                  p["title"] = QObject::tr("New Project");
                  p["text"] = QObject::tr("Project cleared");
                  p["icon"] = QStringLiteral("information");
                  scidavisEmitEvent(QStringLiteral("message"), p);
              }
               else if (itemId == "new_graph") {
                   // newGraph() → multilayerPlot() → initMultilayerPlot() now
                   // shows the subwindow in Normal state (initMultilayerPlot
                   // uses showNormal(), not show()) so a new graph opens
                   // already small — no "fullscreen then shrink" flash.  The
                   // showNormal()/setFocus() below keep the final state Normal.
                   MultiLayer *ml = g_mainWindow->newGraph();
                   if (ml) {
                       // Defer the display to the next event-loop tick like the
                       // other new-window commands (see new_notes above).
                       // MultiLayer* is owned by ApplicationWindow, so the bare
                       // pointer stays valid across one event-loop turn
                       // (null-checked anyway).
                       QTimer::singleShot(0, [ml]() {
                           if (ml) {
                               ml->showNormal();
                               ml->setFocus();
                           }
                       });
                   }
               }
              else if (itemId == "cascade")
                  g_mainWindow->cascade();
              else if (itemId == "maximize_window")
                  g_mainWindow->maximizeWindow();
              else if (itemId == "minimize_window")
                  g_mainWindow->minimizeWindow();
              else if (itemId == "restore_window")
                  g_mainWindow->restoreWindow();
              else if (itemId == "close_window") {
                  // Suppress confirmation dialogs — the single-window QPA
                  // cannot show a QMessageBox (never let the close path
                  // pop a QMessageBox).
                  for (MyWidget *w : g_mainWindow->windowsList())
                      w->askOnCloseEvent(false);
                  g_mainWindow->closeActiveWindow();
              }
              else if (itemId == "about") {
                  // SciDAVis::about() spins up a bare QDialog whose vtable
                  // lives in libQt5Widgets.so, so the exec() interposer can't
                  // catch it (virtual dispatch) -> would SIGSEGV on the QPA.
                  // Emit the about text straight to ArkTS instead.
                  QJsonObject p;
                  p["title"] = QObject::tr("About SciDAVis");
                  p["text"] = SciDAVis::versionString() + SciDAVis::extraVersion()
                          + "\nReleased: " + SciDAVis::releaseDateString()
                          + "\nQt " + QT_VERSION_STR;
                  p["icon"] = QStringLiteral("information");
                  scidavisEmitEvent(QStringLiteral("message"), p);
              }
              else if (itemId == "undo")
                  g_mainWindow->undo();
              else if (itemId == "redo")
                  g_mainWindow->redo();
              else if (itemId == "cut")
                  g_mainWindow->cutSelection();
              else if (itemId == "copy")
                  g_mainWindow->copySelection();
              else if (itemId == "paste")
                  g_mainWindow->pasteSelection();
else if (itemId == "delete")
                   g_mainWindow->clearSelection();
               else if (itemId == "clear_selection")
                   g_mainWindow->clearSelection();
else if (itemId == "insert_row") {
                     ok = false;
                 }
                 else if (itemId == "insert_col") {
                     ok = false;
                 }
               else
                   ok = false;
              if (!ok)
                  return jsonError("unsupported on device: " + itemId.toStdString());
              return "{\"success\":true}";
          } },

        // ── Graph interaction (Phase 4) ──────────────────────────────
        // Direct ApplicationWindow method calls for zoom, rescale, and
        // pointer tools.  QMessageBox warnings inside these methods are
        // caught by the ohos_bridge interposer.
        { "rescale",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              g_mainWindow->setAutoScale();
              return "{\"success\":true}";
          } },

        { "graph_pointer",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              g_mainWindow->pickPointerCursor();
              return "{\"success\":true}";
          } },

        { "zoom_in",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              g_mainWindow->zoomIn();
              return "{\"success\":true}";
          } },

        { "zoom_out",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              g_mainWindow->zoomOut();
              return "{\"success\":true}";
          } },

        { "screen_reader",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              g_mainWindow->showScreenReader();
              return "{\"success\":true}";
          } },

        { "data_reader",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              g_mainWindow->showCursor();
              return "{\"success\":true}";
          } },

        // ── Function / curve / error-bar commands (Phase 4) ───────────
        // add_curve / add_error_bars / add_function receive JSON
        // parameters from the ArkTS dialogs and call the Qt engine API
        // directly.  They never open QDialogs (the OHOS single-window
        // QPA blocks them), so all errors are reported via jsonError.
        { "new_function",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              // newFunctionPlot requires formula parameters normally
              // obtained from a FunctionDialog.  Without a dialog,
              // create a default y=x function plot (type=0 normal).
              int type = 0;
              QStringList formulas{ QStringLiteral("x") };
              QString var = QStringLiteral("x");
              QList<double> ranges{ 0.0, 1.0 };
              int points = 1000;
              bool ok = g_mainWindow->newFunctionPlot(type, formulas, var, ranges, points);
              if (!ok)
                  return jsonError("newFunctionPlot failed");
              return "{\"success\":true}";
          } },

        { "add_curve",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              static const std::map<std::string, int> styles = {
                  { "line", Graph::Line },
                  { "scatter", Graph::Scatter },
                  { "line_symbol", Graph::LineSymbols },
                  { "vertical_bars", Graph::VerticalBars },
                  { "horizontal_bars", Graph::HorizontalBars },
                  { "area", Graph::Area },
                  { "pie", Graph::Pie },
                  { "drop_lines", Graph::VerticalDropLines },
                  { "spline", Graph::Spline },
                  { "vertical_steps", Graph::VerticalSteps },
                  { "horizontal_steps", Graph::HorizontalSteps },
                  { "histogram", Graph::Histogram },
                  { "box", Graph::Box },
              };
              // No QDialog: minimal replica of CurvesDialog::addCurve --
              // insert each requested column as a curve on the active
              // graph with the requested style, then replot.  Column
              // colours/symbols are left at Graph defaults.
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              const QString tableId = args["tableId"].toString();
              if (tableId.isEmpty()) return jsonError("missing tableId");
              Table *t = g_mainWindow->table(tableId);
              if (!t) return jsonError("table not found");
              auto it = styles.find(args["style"].toString(QStringLiteral("line")).toStdString());
              if (it == styles.end()) return jsonError("unknown style");
              const int style = it->second;
              if (!args["cols"].isArray()) return jsonError("missing cols");
              int added = 0;
              for (const QJsonValue &v : args["cols"].toArray()) {
                  int idx = v.toInt(-1);
                  if (idx >= 0 && idx < t->numCols()) {
                      if (g->insertCurve(t, t->colName(idx), style))
                          added++;
                  }
              }
              if (added == 0) return jsonError("no valid columns");
              g->updatePlot();
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              QJsonObject r;
              r["success"] = true;
              r["added"] = added;
              return QJsonDocument(r).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "add_error_bars",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              // No QDialog: replicate both
              // ApplicationWindow::defineErrorBars() overloads with the
              // graph resolved from plotId instead of the active MDI
              // subwindow.
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              const QString curveName = args["curveName"].toString();
              if (curveName.isEmpty()) return jsonError("missing curveName");
              DataCurve *master = static_cast<DataCurve *>(g->curve(curveName));
              if (!master) return jsonError("curve not found");
              const QString xColName = master->xColumnName();
              if (xColName.isEmpty()) return jsonError("no x column");
              // QwtErrorPlotCurve::Horizontal == 0, Vertical == 1
              const int direction =
                  args["direction"].toString(QStringLiteral("y")) == QStringLiteral("x") ? 0 : 1;
              const QString mode = args["mode"].toString();
              if (mode == QStringLiteral("compute")) {
                  // Curve source table = curveName with the "_<col>"
                  // suffix stripped (ApplicationWindow::table() does the
                  // same truncation).
                  const int pos = curveName.indexOf(QStringLiteral("_"));
                  const QString tableName = pos >= 0 ? curveName.left(pos) : curveName;
                  Table *w = g_mainWindow->table(tableName);
                  if (!w) return jsonError("table not found");
                  Column *errors = new Column(QStringLiteral("1"), SciDAVis::ColumnMode::Numeric);
                  errors->setPlotDesignation(direction == 0 ? SciDAVis::xErr : SciDAVis::yErr);
                  Column *data = w->d_future_table->column(direction == 0 ? xColName : curveName);
                  if (!data) {
                      delete errors;
                      return jsonError("data column not found");
                  }
                  const int rows = data->rowCount();
                  if (args["type"].toInt(0) == 0) {
                      // percent of the data values
                      const double fraction = args["percent"].toDouble(5.0) / 100.0;
                      for (int i = 0; i < rows; i++)
                          errors->setValueAt(i, data->valueAt(i) * fraction);
                  } else {
                      // standard deviation of the data column
                      double average = 0.0;
                      for (int i = 0; i < rows; i++)
                          average += data->valueAt(i);
                      average /= rows;
                      double dev = 0.0;
                      for (int i = 0; i < rows; i++)
                          dev += (data->valueAt(i) - average) * (data->valueAt(i) - average);
                      dev = std::sqrt(dev / rows);
                      for (int i = 0; i < rows; i++)
                          errors->setValueAt(i, dev);
                  }
                  w->d_future_table->addChild(errors);
                  if (!g->addErrorBars(xColName, curveName, w, errors->name(), direction))
                      return jsonError("addErrorBars failed");
              } else if (mode == QStringLiteral("column")) {
                  const QString errTableId = args["errTableId"].toString();
                  const QString errColumnName = args["errColumnName"].toString();
                  if (errTableId.isEmpty()) return jsonError("missing errTableId");
                  if (errColumnName.isEmpty()) return jsonError("missing errColumnName");
                  Table *errTable = g_mainWindow->table(errTableId);
                  if (!errTable) return jsonError("err table not found");
                  if (!g->addErrorBars(curveName, errTable, errColumnName, direction))
                      return jsonError("addErrorBars failed");
              } else {
                  return jsonError("unknown mode");
              }
              emit g_mainWindow->modified();
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "add_function",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              // No QDialog: replicate the dialog-free path of
              // addFunctionCurve(); without an active graph fall back to
              // newFunctionPlot(), which creates a new plot window.
              const int type = args["type"].toInt(0);
              QStringList formulas;
              if (args["formulas"].isArray()) {
                  for (const QJsonValue &v : args["formulas"].toArray())
                      formulas << v.toString();
              }
              if (formulas.isEmpty()) return jsonError("missing formulas");
              // normal needs 1 formula, parametric / polar need 2
              if (formulas.count() != (type == 0 ? 1 : 2)) return jsonError("wrong formula count");
              const QString var = args["var"].toString(QStringLiteral("x"));
              const QJsonArray rangeArr = args["ranges"].toArray();
              if (rangeArr.count() != 2) return jsonError("missing ranges");
              QList<double> ranges;
              for (const QJsonValue &v : rangeArr)
                  ranges << v.toDouble();
              if (!(ranges[0] < ranges[1])) return jsonError("invalid range");
              const int points = args["points"].toInt(1000);
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) {
                  if (!g_mainWindow->newFunctionPlot(type, formulas, var, ranges, points))
                      return jsonError("newFunctionPlot failed");
                  scidavisEmitEvent(QStringLiteral("plotListChanged"));
                  QJsonObject r;
                  r["success"] = true;
                  r["newPlot"] = true;
                  return QJsonDocument(r).toJson(QJsonDocument::Compact).toStdString();
              }
              if (!g->addFunctionCurve(g_mainWindow, type, formulas, var, ranges, points))
                  return jsonError("function parse failed");
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "getPreference",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              QSettings &s = ApplicationWindow::getSettings();
              QString key = args["key"].toString();
              if (key.isEmpty()) return jsonError("missing key");
              QVariant v = s.value(key);
              QJsonObject r;
              r["success"] = true;
              r["value"] = v.toString();
              return QJsonDocument(r).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "setPreference",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              QSettings &s = ApplicationWindow::getSettings();
              QString key = args["key"].toString();
              if (key.isEmpty()) return jsonError("missing key");
              s.setValue(key, args["value"].toString());
              return "{\"success\":true}";
          } },

        { "setChromeInsets",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              int top = args["top"].toInt(0);
              int bottom = args["bottom"].toInt(0);
              if (auto *sa = qobject_cast<QAbstractScrollArea *>(g_mainWindow->centralWidget()))
                  static_cast<ViewportMarginAccessor *>(sa)->setViewportMargins(0, top, 0, bottom);
              if (auto *cw = g_mainWindow->centralWidget())
                  cw->update();
              return "{\"success\":true}";
          } },

        { "getNoteData",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              QString name = args["noteId"].toString();
              Note *note = nullptr;
              if (name.isEmpty()) {
                  note = qobject_cast<Note *>(g_mainWindow->d_workspace.activeSubWindow());
              } else {
                  for (MyWidget *w : g_mainWindow->windowsList()) {
                      if (w->inherits("Note") && w->name() == name) {
                          note = static_cast<Note *>(w);
                          break;
                      }
                  }
              }
              if (!note) return jsonError("note not found");
              QJsonObject r;
              r["success"] = true;
              r["text"] = note->text();
              r["name"] = note->name();
              r["label"] = note->windowLabel();
              return QJsonDocument(r).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "setNoteData",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              QString name = args["noteId"].toString();
              Note *note = nullptr;
              if (name.isEmpty()) {
                  note = qobject_cast<Note *>(g_mainWindow->d_workspace.activeSubWindow());
              } else {
                  for (MyWidget *w : g_mainWindow->windowsList()) {
                      if (w->inherits("Note") && w->name() == name) {
                          note = static_cast<Note *>(w);
                          break;
                      }
                  }
              }
              if (!note) return jsonError("note not found");
              note->setText(args["text"].toString());
return "{\"success\":true}";
           } },

        { "insert_row",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              QMdiSubWindow *sub = g_mainWindow->d_workspace.activeSubWindow();
              MyWidget *w = qobject_cast<MyWidget *>(sub);
              if (!w || !w->inherits("Table"))
                  return jsonError("no active table");
              static_cast<Table *>(w)->insertRow();
              {
                  QJsonObject ep;
                  ep["tableId"] = w->name();
                  scidavisEmitEvent(QStringLiteral("tableDataChanged"), ep);
              }
              scidavisEmitEvent(QStringLiteral("tableListChanged"));
              return "{\"success\":true}";
          } },

        { "insert_col",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              QMdiSubWindow *sub = g_mainWindow->d_workspace.activeSubWindow();
              MyWidget *w = qobject_cast<MyWidget *>(sub);
              if (!w || !w->inherits("Table"))
                  return jsonError("no active table");
              static_cast<Table *>(w)->insertCol();
              {
                  QJsonObject ep;
                  ep["tableId"] = w->name();
                  scidavisEmitEvent(QStringLiteral("tableDataChanged"), ep);
              }
              scidavisEmitEvent(QStringLiteral("tableListChanged"));
              return "{\"success\":true}";
          } },

        { "normalize",
          [](const QJsonObject &args) -> std::string {
              // future::Table::normalizeColumns — no-dialog core of
              // NormalizeDialog.  columns (optional) filters which columns
              // are normalised; default = every column in the table.
              Table *t = resolveTable(args);
              if (!t || !t->d_future_table) return jsonError("table not found");
              QList<Column *> cols;
              if (args["columns"].isArray()) {
                  QSet<QString> wanted;
                  for (const QJsonValue &v : args["columns"].toArray())
                      wanted.insert(v.toString());
                  for (int i = 0; i < t->numCols(); i++) {
                      Column *c = t->column(i);
                      if (c && wanted.contains(c->name()))
                          cols << c;
                  }
              } else {
                  for (int i = 0; i < t->numCols(); i++)
                      cols << t->column(i);
              }
              if (cols.isEmpty()) return jsonError("no matching columns");
              t->d_future_table->normalizeColumns(cols);
              QJsonObject p;
              p["title"] = QObject::tr("Normalize");
              p["text"] = QObject::tr("Normalized %1").arg(t->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              // Notify ArkTS to refresh table data after normalize
              {
                  QJsonObject ep;
                  ep["tableId"] = args["tableId"].toString();
                  scidavisEmitEvent(QStringLiteral("tableDataChanged"), ep);
              }
              return "{\"success\":true}";
          } },

        { "convolve",
          [](const QJsonObject &args) -> std::string {
              // Convolution filter (libscidavis Convolution.h) — convolves
              // signalCol with responseCol and appends a result curve.
              Table *t = resolveTable(args);
              if (!t) return jsonError("table not found");
              QString signalCol = args["signalCol"].toString();
              QString responseCol = args["responseCol"].toString();
              if (signalCol.isEmpty() || responseCol.isEmpty())
                  return jsonError("missing signalCol/responseCol");
              bool ok = false;
              try {
                  Convolution *conv =
                          new Convolution(g_mainWindow, t, signalCol, responseCol);
                  ok = conv->run();
                  delete conv;
              } catch (...) {
                  ok = false;
              }
              QJsonObject p;
              p["title"] = QObject::tr("Convolution");
              p["text"] = ok ? QObject::tr("Convolved %1").arg(t->name())
                             : QObject::tr("Convolution failed on %1").arg(t->name());
              p["icon"] = ok ? QStringLiteral("information") : QStringLiteral("critical");
              scidavisEmitEvent(QStringLiteral("message"), p);
              if (ok) scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return ok ? std::string("{\"success\":true}") : jsonError("convolution failed");
          } },

        { "getMatrixData",
          [](const QJsonObject &args) -> std::string {
              // Read-only: return the full matrix cell contents as a 2-D
              // JSON array (rows of cols).  Mirrors getTableData.
              Matrix *m = resolveMatrix(args);
              if (!m) return jsonError("matrix not found");
              QJsonArray rows;
              for (int r = 0; r < m->numRows(); r++) {
                  QJsonArray rowArr;
                  for (int c = 0; c < m->numCols(); c++)
                      rowArr.append(m->text(r, c));
                  rows.append(rowArr);
              }
              QJsonObject data;
              data["rows"] = m->numRows();
              data["cols"] = m->numCols();
              data["cells"] = rows;
              QJsonObject root;
              root["success"] = true;
              root["data"] = data;
              return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "addText",
          [](const QJsonObject &args) -> std::string {
              // Add a legend/text marker to the active graph layer and
              // consume the 11 styling keys sent by TextDialog
              // (text/fontFamily/fontSize/bold/italic/textColor/bgFrame/
              // bgOpacity/bgColor/alignment/angle).
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              const QString text = args["text"].toString();
              Legend *l;
              if (text.isEmpty())
                  l = g->newLegend();
              else
                  l = g->newLegend(text);
              if (!l) return jsonError("failed to create text marker");
              QFont f = l->font();
              const QString family = args["fontFamily"].toString();
              if (!family.isEmpty())
                  f.setFamily(family);
              if (args.contains("fontSize"))
                  f.setPointSizeF(args["fontSize"].toDouble(f.pointSizeF()));
              f.setBold(args["bold"].toBool(false));
              f.setItalic(args["italic"].toBool(false));
              l->setFont(f);
              const QString textColor = args["textColor"].toString();
              if (!textColor.isEmpty())
                  l->setTextColor(QColor(textColor));
              const QString bgColor = args["bgColor"].toString();
              if (!bgColor.isEmpty()) {
                  QColor bg(bgColor);
                  // bgOpacity is sent as an alpha in the 0-255 range.
                  if (args.contains("bgOpacity"))
                      bg.setAlpha(qBound(0, args["bgOpacity"].toInt(255), 255));
                  l->setBackgroundColor(bg);
              }
              // TextDialog's bgFrameIdx maps directly onto the Legend frame
              // styles (None=0/Line=1/Shadow=2).
              if (args.contains("bgFrame"))
                  l->setFrameStyle(args["bgFrame"].toInt(int(Legend::None)));
              if (args.contains("angle"))
                  l->setAngle(args["angle"].toInt(0));
              // "alignment" has no Qt Legend equivalent: the desktop build
              // only uses it for axis titles, so it is intentionally
              // ignored here.
              g->updatePlot();
              QJsonObject p;
              p["title"] = QObject::tr("Add Text");
              p["text"] = QObject::tr("Added text to %1").arg(ml->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "drawArrow",
          [](const QJsonObject &args) -> std::string {
              // Draw an arrow marker (axes-value coordinates) on the graph.
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              // LineDialog sends xStart/yStart/xEnd/yEnd; keep x1/y1/x2/y2
              // as a legacy fallback.
              double x1 = args["xStart"].toDouble(args["x1"].toDouble(0.0));
              double y1 = args["yStart"].toDouble(args["y1"].toDouble(0.0));
              double x2 = args["xEnd"].toDouble(args["x2"].toDouble(0.0));
              double y2 = args["yEnd"].toDouble(args["y2"].toDouble(0.0));
              auto *mrk = new ArrowMarker();
              mrk->setStartPoint(x1, y1);
              mrk->setEndPoint(x2, y2);
              mrk->setWidth(args["width"].toInt(1));
              mrk->setColor(QColor(args["color"].toString(QStringLiteral("black"))));
              // drawArrow defaults to arrow heads at both ends when the
              // flags are absent.
              const bool startArrow = args.contains("arrowStart")
                      ? args["arrowStart"].toBool() : true;
              const bool endArrow = args.contains("arrowEnd")
                      ? args["arrowEnd"].toBool() : true;
              mrk->drawStartArrow(startArrow);
              mrk->drawEndArrow(endArrow);
              if (args.contains("headLength"))
                  mrk->setHeadLength(args["headLength"].toInt(mrk->headLength()));
              if (args.contains("headAngle"))
                  mrk->setHeadAngle(args["headAngle"].toInt(mrk->headAngle()));
              if (args.contains("headFilled"))
                  mrk->fillArrowHead(args["headFilled"].toBool(true));
              g->addArrow(mrk);
              QJsonObject p;
              p["title"] = QObject::tr("Draw Arrow");
              p["text"] = QObject::tr("Arrow added to %1").arg(ml->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "drawLine",
          [](const QJsonObject &args) -> std::string {
              // Draw a plain line marker (no arrow heads) on the graph.
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              // LineDialog sends xStart/yStart/xEnd/yEnd; keep x1/y1/x2/y2
              // as a legacy fallback.
              double x1 = args["xStart"].toDouble(args["x1"].toDouble(0.0));
              double y1 = args["yStart"].toDouble(args["y1"].toDouble(0.0));
              double x2 = args["xEnd"].toDouble(args["x2"].toDouble(0.0));
              double y2 = args["yEnd"].toDouble(args["y2"].toDouble(0.0));
              auto *mrk = new ArrowMarker();
              mrk->setStartPoint(x1, y1);
              mrk->setEndPoint(x2, y2);
              mrk->setWidth(args["width"].toInt(1));
              mrk->setColor(QColor(args["color"].toString(QStringLiteral("black"))));
              // drawLine defaults to no arrow heads when the flags are
              // absent.
              const bool startArrow = args.contains("arrowStart")
                      ? args["arrowStart"].toBool() : false;
              const bool endArrow = args.contains("arrowEnd")
                      ? args["arrowEnd"].toBool() : false;
              mrk->drawStartArrow(startArrow);
              mrk->drawEndArrow(endArrow);
              if (args.contains("headLength"))
                  mrk->setHeadLength(args["headLength"].toInt(mrk->headLength()));
              if (args.contains("headAngle"))
                  mrk->setHeadAngle(args["headAngle"].toInt(mrk->headAngle()));
              if (args.contains("headFilled"))
                  mrk->fillArrowHead(args["headFilled"].toBool(true));
              g->addArrow(mrk);
              QJsonObject p;
              p["title"] = QObject::tr("Draw Line");
              p["text"] = QObject::tr("Line added to %1").arg(ml->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "timeStamp",
          [](const QJsonObject &args) -> std::string {
              // One-liner: add a timestamp text marker to the graph.
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              g->addTimeStamp();
              QJsonObject p;
              p["title"] = QObject::tr("Time Stamp");
              p["text"] = QObject::tr("Timestamp added to %1").arg(ml->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "addImage",
          [](const QJsonObject &args) -> std::string {
              // Insert an image file as an image marker on the graph and
              // consume the 5 keys sent by ImageDialog (originX/originY/
              // width/height/keepAspect), all in paint/pixel coordinates.
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              const QString filePath = args["filePath"].toString();
              if (filePath.isEmpty()) return jsonError("missing filePath");
              if (!QFile::exists(filePath)) return jsonError("file not found");
              ImageMarker *m = g->addImage(filePath);
              if (!m) return jsonError("failed to add image");
              int x = args["originX"].toInt(0);
              int y = args["originY"].toInt(0);
              int w = args["width"].toInt(0);
              int h = args["height"].toInt(0);
              const bool keepAspect = args["keepAspect"].toBool(false);
              if (w <= 0 && h <= 0) {
                  // No explicit size: keep the canvas-clamped default sizing
                  // that addImage() already applied.
              } else {
                  const QSize src = m->pixmap().size();
                  if (w <= 0) w = src.width();
                  if (h <= 0) h = src.height();
                  // Preserve the source pixmap aspect ratio when requested
                  // (same ratio source as Graph::addImage).
                  if (keepAspect && src.width() > 0 && src.height() > 0) {
                      const double ratio = double(src.width()) / double(src.height());
                      if (w / double(h) > ratio)
                          w = qRound(h * ratio);
                      else
                          h = qRound(w / ratio);
                  }
                  m->setRect(x, y, w, h);
              }
              g->updatePlot();
              QJsonObject p;
              p["title"] = QObject::tr("Add Image");
              p["text"] = QObject::tr("Image added to %1").arg(ml->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "newLegend",
          [](const QJsonObject &args) -> std::string {
              // Add a legend to the graph; auto-generated from curve titles
              // when no explicit text is supplied.
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              QString text = args["text"].toString();
              if (text.isEmpty())
                  g->newLegend();
              else
                  g->newLegend(text);
              QJsonObject p;
              p["title"] = QObject::tr("New Legend");
              p["text"] = QObject::tr("Legend added to %1").arg(ml->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "tableSize",
          [](const QJsonObject &args) -> std::string {
              // Read-only: return the row/column count of a table.
              Table *t = resolveTable(args);
              if (!t) return jsonError("table not found");
              QJsonObject root;
              root["success"] = true;
              root["rows"] = t->rowCount();
              root["cols"] = t->columnCount();
              return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "resizeTable",
          [](const QJsonObject &args) -> std::string {
              // Mutation: resize a table to the given dimensions
              // (TableSizeDialog "Table Size").  Existing cell data is kept;
              // rows/cols below 1 are rejected.
              Table *t = resolveTable(args);
              if (!t) return jsonError("table not found");
              int rows = args["rows"].toInt(0);
              int cols = args["cols"].toInt(0);
              if (rows < 1 || cols < 1) return jsonError("bad dimensions");
              t->setNumRows(rows);
              t->setNumCols(cols);
              QJsonObject p;
              p["title"] = QObject::tr("Table Size");
              p["text"] = QObject::tr("Resized %1 to %2 × %3")
                      .arg(t->name()).arg(rows).arg(cols);
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              QJsonObject ep;
              ep["tableId"] = t->name();
              scidavisEmitEvent(QStringLiteral("tableDataChanged"), ep);
              return "{\"success\":true}";
          } },

        // ── Dialog suite (batch 4) ─────────────────────────────────────
        // One command per ArkTS dialog: PlotWizard, Axes, Associations,
        // Curve Range, Arrange Layers, Rename Window, Find.  Each dialog
        // was read to match its exact arg keys and response shape.
        { "plotWizard",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              if (!args["curves"].isArray()) return jsonError("missing curves");
              // Reuse the desktop PlotWizard path: build the same
              // "Table: XCol(X), YCol(Y)" spec strings that
              // ApplicationWindow::multilayerPlot(const QStringList&)
              // parses (it handles the X/Y curves and xErr/yErr error
              // bars).  Master curves first, error bars appended last,
              // mirroring PlotWizard::accept().
              QStringList colList, errList;
              int plotted = 0;
              bool zSkipped = false;
              for (const QJsonValue &v : args["curves"].toArray()) {
                  const QJsonObject cv = v.toObject();
                  const QString tableId = cv["tableId"].toString();
                  const QString xCol = cv["xCol"].toString();
                  const QString yCol = cv["yCol"].toString();
                  if (tableId.isEmpty() || xCol.isEmpty() || yCol.isEmpty())
                      continue;
                  if (!cv["zCol"].toString().isEmpty()) {
                      zSkipped = true; // 3-D curves have no 2-D wizard path
                      continue;
                  }
                  const QString master = tableId + ": " + xCol + "(X), " + yCol + "(Y)";
                  colList << master;
                  if (!cv["xErrCol"].toString().isEmpty())
                      errList << master + ", " + cv["xErrCol"].toString() + "(xErr)";
                  if (!cv["yErrCol"].toString().isEmpty())
                      errList << master + ", " + cv["yErrCol"].toString() + "(yErr)";
                  plotted++;
              }
              if (colList.isEmpty() && errList.isEmpty())
                  return jsonError("no valid curves");
              colList += errList;
              MultiLayer *ml = g_mainWindow->multilayerPlot(colList);
              if (!ml) return jsonError("plot failed");
              QJsonObject p;
              p["title"] = QObject::tr("Plot Wizard");
              p["text"] = QObject::tr("Plotted %1 curve(s)").arg(plotted);
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              if (zSkipped) {
                  QJsonObject pz;
                  pz["title"] = QObject::tr("Plot Wizard");
                  pz["text"] = QObject::tr("3-D (Z) curves are not supported and were skipped");
                  pz["icon"] = QStringLiteral("warning");
                  scidavisEmitEvent(QStringLiteral("message"), pz);
              }
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "getAxisConfig",
          [](const QJsonObject &args) -> std::string {
              // Read-only: one axis at a time (Qwt axis id: Bottom=2,
              // Left=0, Top=3, Right=1).  Shape matches AxesDialog's
              // AxisConfigData.  Fields with no clean getter fall back to
              // safe defaults rather than failing.
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              int axis = qBound(0, args["axis"].toInt(0), 3);
              const QwtScaleDiv *scDiv = g->plotWidget()->axisScaleDiv(axis);
              const QwtScaleEngine *se = g->plotWidget()->axisScaleEngine(axis);
              QJsonObject data;
              data["from"] = std::min(scDiv->lowerBound(), scDiv->upperBound());
              data["to"] = std::max(scDiv->lowerBound(), scDiv->upperBound());
              data["scaleType"] =
                      (se && se->transformation()
                       && se->transformation()->type() == QwtScaleTransformation::Log10)
                              ? QStringLiteral("log")
                              : QStringLiteral("linear");
              data["inverted"] = se ? se->testAttribute(QwtScaleEngine::Inverted) : false;
              data["title"] = g->axisTitle(axis);
              data["visible"] = g->plotWidget()->axisEnabled(axis);
              // Grid: the axis id is a QwtPlot axis (yLeft=0, yRight=1,
              // xBottom=2, xTop=3).  Y axes drive the grid's Y lines,
              // X axes its X lines (same mapping as setAxisGrid).
              Grid *grid = g->grid();
              if (axis == QwtPlot::yLeft || axis == QwtPlot::yRight) {
                  data["majorGrid"] = grid && grid->yEnabled();
                  data["minorGrid"] = grid && grid->yMinEnabled();
              } else {
                  data["majorGrid"] = grid && grid->xEnabled();
                  data["minorGrid"] = grid && grid->xMinEnabled();
              }
              data["backbones"] = g->axesBackbones();
              data["lineWidth"] = 1; // no per-axis line-width getter exposed
              QJsonObject root;
              root["success"] = true;
              root["data"] = data;
              return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "getPlotAssociations",
          [](const QJsonObject &args) -> std::string {
              // Read-only: per-curve X/Y/xErr/yErr column associations for
              // the active graph.  Shape matches AssociationsDialog's
              // PlotAssociationEntry (curveName, tableName, xCol, yCol,
              // xErrCol, yErrCol).
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              const QStringList names = g->analysableCurvesList();
              QJsonArray arr;
              for (int i = 0; i < names.count(); i++) {
                  QJsonObject o;
                  o["curveName"] = names[i];
                  // analysableCurvesList() skips error-bar curves, so look
                  // the curve up by name (not by index) to stay aligned.
                  if (auto *dc = dynamic_cast<DataCurve *>(g->curve(names[i]))) {
                      Table *t = dc->table();
                      const QString tname = t ? t->name() : QString();
                      // Strip the "Table_" prefix so the dialog shows the
                      // bare column names (as the desktop AssociationsDialog
                      // does).
                      auto strip = [&tname](const QString &full) {
                          if (!tname.isEmpty() && full.startsWith(tname + "_"))
                              return full.mid(tname.length() + 1);
                          return full;
                      };
                      o["tableName"] = tname;
                      o["xCol"] = strip(dc->xColumnName());
                      o["yCol"] = strip(dc->yColumnName());
                      // Error-bar associations live in separate curves and
                      // are not exposed by DataCurve::plotAssociation().
                      o["xErrCol"] = QString();
                      o["yErrCol"] = QString();
                  } else {
                      o["tableName"] = QString();
                      o["xCol"] = QString();
                      o["yCol"] = QString();
                      o["xErrCol"] = QString();
                      o["yErrCol"] = QString();
                  }
                  arr.append(o);
              }
              QJsonObject root;
              root["success"] = true;
              root["data"] = arr;
              return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "updatePlotAssociation",
          [](const QJsonObject &args) -> std::string {
              // Re-associate a curve's X/Y data columns.  Consumes the
              // structured contract sent by AssociationsDialog:
              // {curveIdx, tableName, xCol, yCol, xErrCol, yErrCol}.
              // Mirrors AssociationsDialog::changePlotAssociation() for the
              // plain 2-column case: column ids are of the form
              // "<tableName>_<colName>".  Error-bar reassignment
              // (xErrCol/yErrCol) would require re-targeting a separate
              // QwtErrorPlotCurve and is downgraded to a warning log (no UI
              // dialog) until supported.
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              const int idx = args["curveIdx"].toInt(-1);
              const QStringList names = g->analysableCurvesList();
              if (idx < 0 || idx >= names.count())
                  return jsonError("curve index out of range");
              auto *dc = dynamic_cast<DataCurve *>(g->curve(names[idx]));
              if (!dc) return jsonError("curve not a data curve");
              const QString tableName = args["tableName"].toString();
              const QString xCol = args["xCol"].toString();
              const QString yCol = args["yCol"].toString();
              if (tableName.isEmpty() || xCol.isEmpty() || yCol.isEmpty())
                  return jsonError("missing table/column association");
              const QString fullX = tableName + "_" + xCol;
              const QString fullY = tableName + "_" + yCol;
              if (dc->xColumnName() != fullX || dc->yColumnName() != fullY) {
                  dc->setXColumnName(fullX);
                  dc->setYColumnName(fullY);
                  dc->loadData();
              }
              const QString xErrCol = args["xErrCol"].toString();
              const QString yErrCol = args["yErrCol"].toString();
              if (!xErrCol.isEmpty() || !yErrCol.isEmpty())
                  qWarning("[SciDAVis] updatePlotAssociation: error-bar reassociation "
                           "(xErr=%s, yErr=%s) not supported yet; X/Y reassigned only",
                           qPrintable(xErrCol), qPrintable(yErrCol));
              g->updatePlot();
              g->notifyChanges();
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "getCurveInfo",
          [](const QJsonObject &args) -> std::string {
              // Read-only: row range + max rows for one curve.  Shape
              // matches CurveRangeDialog's CurveInfoData (curveIdx,
              // curveName, startRow, endRow, maxRows; the dialog displays
              // the 0-based rows as 1-based).
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              int idx = args["curveIdx"].toInt(-1);
              const QStringList names = g->analysableCurvesList();
              if (idx < 0 || idx >= names.count())
                  return jsonError("curve index out of range");
              QJsonObject data;
              data["curveIdx"] = idx;
              data["curveName"] = names[idx];
              if (auto *dc = dynamic_cast<DataCurve *>(g->curve(names[idx]))) {
                  data["startRow"] = dc->startRow();
                  data["endRow"] = dc->endRow();
                  data["maxRows"] = dc->table() ? dc->table()->numRows() : 0;
              } else {
                  data["startRow"] = 0;
                  data["endRow"] = 0;
                  data["maxRows"] = 0;
              }
              QJsonObject root;
              root["success"] = true;
              root["data"] = data;
              return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "setCurveRange",
          [](const QJsonObject &args) -> std::string {
              // Apply a 0-based row range to a curve (mirrors
              // CurveRangeDialog::accept -> DataCurve::setRowRange).
              MultiLayer *ml = resolvePlot(args);
              Graph *g = ml ? ml->activeGraph() : nullptr;
              if (!g) return jsonError("no active graph");
              int idx = args["curveIdx"].toInt(-1);
              const QStringList names = g->analysableCurvesList();
              if (idx < 0 || idx >= names.count())
                  return jsonError("curve index out of range");
              auto *dc = dynamic_cast<DataCurve *>(g->curve(names[idx]));
              if (!dc) return jsonError("curve not a data curve");
              const int maxRows = dc->table() ? dc->table()->numRows() : 0;
              const int start = qBound(0, args["startRow"].toInt(0), qMax(0, maxRows - 1));
              int end = args["endRow"].toInt(-1);
              if (end < 0)
                  end = qMax(0, maxRows - 1);
              else
                  end = qBound(0, end, qMax(0, maxRows - 1));
              dc->setRowRange(qMin(start, end), qMax(start, end));
              g->updatePlot();
              QJsonObject p;
              p["title"] = QObject::tr("Curve Range");
              p["text"] = QObject::tr("Set range of %1 to rows %2..%3")
                                  .arg(dc->yColumnName())
                                  .arg(qMin(start, end) + 1)
                                  .arg(qMax(start, end) + 1);
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "arrangeLayers",
          [](const QJsonObject &args) -> std::string {
              // No-dialog core of LayerDialog::update() minus the
              // QMessageBox popups: set layer count, grid, canvas,
              // alignment, margins and spacing, then lay them out.
              MultiLayer *ml = resolvePlot(args);
              if (!ml) return jsonError("no active plot");
              const int graphs = qBound(0, args["layers"].toInt(ml->layers()), 100);
              ml->setLayersNumber(graphs);
              if (!graphs) {
                  QJsonObject p;
                  p["title"] = QObject::tr("Arrange Layers");
                  p["text"] = QObject::tr("Removed all layers from %1").arg(ml->name());
                  p["icon"] = QStringLiteral("information");
                  scidavisEmitEvent(QStringLiteral("message"), p);
                  scidavisEmitEvent(QStringLiteral("plotListChanged"));
                  return "{\"success\":true}";
              }
              const bool fit = args["autoLayout"].toBool(false);
              if (!fit) {
                  ml->setCols(qMax(1, args["gridCols"].toInt(1)));
                  ml->setRows(qMax(1, args["gridRows"].toInt(1)));
              }
              if (args["customCanvas"].toBool(false))
                  ml->setLayerCanvasSize(args["canvasWidth"].toInt(600),
                                         args["canvasHeight"].toInt(400));
              ml->setAlignement(args["alignH"].toInt(0), args["alignV"].toInt(0));
              ml->setMargins(args["marginLeft"].toInt(0), args["marginRight"].toInt(0),
                             args["marginTop"].toInt(0), args["marginBottom"].toInt(0));
              // setSpacing(rowGap, colGap) — row gap first, then column gap.
              ml->setSpacing(args["rowsGap"].toInt(5), args["colsGap"].toInt(5));
              ml->arrangeLayers(fit, args["customCanvas"].toBool(false));
              QJsonObject p;
              p["title"] = QObject::tr("Arrange Layers");
              p["text"] = QObject::tr("Arranged %1 layer(s) of %2").arg(graphs).arg(ml->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "getActiveWindowInfo",
          [](const QJsonObject &) -> std::string {
              // Read-only: name/label/caption-policy of the active MDI
              // subwindow (RenameWindowDialog's ActiveWindowInfo).
              if (!g_mainWindow) return jsonError("no mw");
              QMdiSubWindow *sub = g_mainWindow->d_workspace.activeSubWindow();
              MyWidget *w = qobject_cast<MyWidget *>(sub);
              if (!w) return jsonError("no active window");
              QJsonObject data;
              data["name"] = w->name();
              data["label"] = w->windowLabel();
              data["type"] = QString::fromLatin1(w->metaObject()->className());
              data["captionPolicy"] = int(w->captionPolicy());
              QJsonObject root;
              root["success"] = true;
              root["data"] = data;
              return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "renameWindow",
          [](const QJsonObject &args) -> std::string {
              // No-dialog replica of RenameWindowDialog::accept():
              // rename (via ApplicationWindow::renameWindow), then update
              // label + caption policy and sync the project tree.
              if (!g_mainWindow) return jsonError("no mw");
              const QString windowName = args["windowName"].toString();
              MyWidget *w = nullptr;
              if (!windowName.isEmpty()) {
                  for (MyWidget *cand : g_mainWindow->windowsList())
                      if (cand->name() == windowName) { w = cand; break; }
              }
              if (!w)
                  w = qobject_cast<MyWidget *>(g_mainWindow->d_workspace.activeSubWindow());
              if (!w) return jsonError("window not found");
              const QString text = args["newName"].toString();
              const QString label = args["newLabel"].toString();
              const int policy = args["captionPolicy"].toInt(int(w->captionPolicy()));
              if (!text.isEmpty() && text != w->name()) {
                  if (!g_mainWindow->renameWindow(w, text))
                      return jsonError("rename failed");
              }
              w->setWindowLabel(label);
              w->setCaptionPolicy(static_cast<MyWidget::CaptionPolicy>(qBound(0, policy, 2)));
              g_mainWindow->setListViewLabel(w->name(), label);
              g_mainWindow->modifiedProject(w);
              QJsonObject p;
              p["title"] = QObject::tr("Rename Window");
              p["text"] = QObject::tr("Renamed %1").arg(w->name());
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              // No dedicated window-list event on the ArkTS side; refresh
              // the list the renamed window belongs to so the new name
              // propagates to the UI.
              if (w->inherits("Table"))
                  scidavisEmitEvent(QStringLiteral("tableListChanged"));
              else if (w->inherits("MultiLayer"))
                  scidavisEmitEvent(QStringLiteral("plotListChanged"));
              return "{\"success\":true}";
          } },

        { "getStartPath",
          [](const QJsonObject &) -> std::string {
              // FindDialog shows this as the search start folder; the
              // project folder is not exposed, so default to the root.
              QJsonObject root;
              root["success"] = true;
              root["path"] = QStringLiteral("/");
              return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
          } },

        { "find",
          [](const QJsonObject &args) -> std::string {
              // Minimal search over window names/labels/folder names; the
              // found subwindow is activated (same as the desktop Find).
              if (!g_mainWindow) return jsonError("no mw");
              const QString text = args["text"].toString();
              if (text.isEmpty()) return jsonError("empty search text");
              g_mainWindow->find(text, args["searchWindowNames"].toBool(true),
                                 args["searchWindowLabels"].toBool(false),
                                 args["searchFolderNames"].toBool(false),
                                 args["caseSensitive"].toBool(false),
                                 args["partialMatch"].toBool(true),
                                 args["includeSubfolders"].toBool(true));
              QJsonObject p;
              p["title"] = QObject::tr("Find");
              p["text"] = QObject::tr("Searched for \"%1\"").arg(text);
              p["icon"] = QStringLiteral("information");
              scidavisEmitEvent(QStringLiteral("message"), p);
              return "{\"success\":true}";
          } },

    };
    return reg;
}

extern "C" __attribute__((visibility("default")))
const char *scidavis_call(const char *cmd, const char *jsonArgs)
{
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
    const bool isQuery = queryCommands().count(cmdName) > 0;

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
        QJsonObject argsObj = doc.object();

        const auto &registry = commandRegistry();
        auto it = registry.find(cmdStr);
        if (it != registry.end()) {
            try {
                s_result = it->second(argsObj);
            } catch (const std::exception &e) {
                s_result = jsonError(std::string("exception: ") + e.what());
            } catch (...) {
                s_result = jsonError("unknown exception");
            }
        } else {
            s_result = jsonError("unknown cmd: " + cmdStr);
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

int main(int argc, char **argv)
{

    QCoreApplication::setOrganizationName("SciDAVis");
    QCoreApplication::setApplicationName("SciDAVis");

    Application app(argc, argv);

    app.installEventFilter(new InputProbe);

#ifdef __APPLE__
    // set python home to bundle specific directory
    setenv("PYTHONHOME",(QCoreApplication::applicationDirPath()+"/../Resources").toStdString().c_str(),true);
#endif
    
    ApplicationWindow::getSettings();
    
    QStringList args = app.arguments();
    args.removeFirst(); // remove application name

    if ((args.count() == 1) && (args[0] == "-a" || args[0] == "--about")) {
        ApplicationWindow::about();
        exit(0);
    } else {
        ApplicationWindow *mw = new ApplicationWindow;
        g_mainWindow = mw;
        // MDI activation → ArkTS menu refresh.  QMdiArea::subWindowActivated
        // fires for every real active-window change: clicking a subwindow in
        // the workspace, the Windows→win:* menu entries (activateSubWindow →
        // setActiveSubWindow), and the F5/F6 next/prev-window actions.  This
        // single hook keeps the ArkTS menu in sync for all of them without
        // redundant emissions (the signal only fires when the active window
        // actually changes).
        QObject::connect(&mw->d_workspace, &QMdiArea::subWindowActivated, mw,
                         [](QMdiSubWindow *sub) { emitWindowActivated(sub); });
        // Clipboard bridge (Phase 2): mirror Qt-side clipboard changes to
        // ArkTS, which writes them into the OHOS system pasteboard.  Large
        // payloads are truncated — the NAPI event channel is not meant for
        // multi-megabyte transfers.
        QObject::connect(QApplication::clipboard(), &QClipboard::dataChanged, mw, []() {
            QClipboard *cb = QApplication::clipboard();
            if (!cb)
                return;
            QString text = cb->text();
            if (text.isEmpty())
                return;
            if (text.size() > 512 * 1024)
                text.truncate(512 * 1024);
            QJsonObject p;
            p["text"] = text;
            scidavisEmitEvent(QStringLiteral("clipboardChanged"), p);
        });
        mw->applyUserSettings();
        // OHOS: hide all native Qt toolbars — they render at desktop pixel
        // sizes through the XComponent (unusably small at DPR=1) and their
        // QToolButton tooltips/popups would create a second top-level window
        // (single-window QPA -> SIGSEGV).  The toolbar is rebuilt in ArkTS.
        for (QToolBar *tb : mw->findChildren<QToolBar *>())
            tb->hide();
        // OHOS: hide the native QMenuBar — the ArkTS MenuBar replaces it
        if (auto *mb = mw->menuBar())
            mb->hide();
#ifdef SCIDAVIS_OHOS
        // OHOS: hide all QDockWidgets — restoreState() may have made them visible.
        // The ArkTS shell provides its own panels (ProjectTree, ResultsLog).
        for (QDockWidget *dw : mw->findChildren<QDockWidget *>())
            dw->hide();
#endif
        // Disable all "Save changes?" confirmation switches — the
        // single-window QPA cannot show the Save changes QMessageBox.
        mw->confirmCloseTable = false;
        mw->confirmCloseMatrix = false;
        mw->confirmClosePlot2D = false;
        mw->confirmClosePlot3D = false;
        mw->confirmCloseFolder = false;
        mw->confirmCloseNotes = false;
        mw->newTable();
        mw->activateSubWindow();
        mw->savedProject();
#ifdef SEARCH_FOR_UPDATES
        if (mw->autoSearchUpdates) {
            mw->autoSearchUpdatesRequest = true;
            mw->searchForUpdates();
        }
#endif
        mw->parseCommandLineArguments(args);
    }
    app.connect(&app, SIGNAL(lastWindowClosed()), &app, SLOT(quit()));
    return app.exec();
}
