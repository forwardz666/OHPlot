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
#include "ApplicationWindow.h"
#include "globals.h"
#include "ohos_bridge.h"

#include <QAction>
#include <QApplication>
#include <QElapsedTimer>
#include <QMouseEvent>
#include <QMdiSubWindow>
#include <QSplashScreen>
#include <QTimer>
#include <QWindow>
#include <QPointer>
#include <QSemaphore>
#include <atomic>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <functional>
#include <map>
#include <memory>
#include <set>
#include "MultiLayer.h"
#include "Graph.h"
#include "PlotCurve.h"
#include <qwt_data.h>

#include <typeinfo>
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
    } else if (c.isLetter()) {
        c = c.toLower();
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
            qWarning("[InputProbe] key press recv=%s key=0x%x text='%s'",
                     obj->metaObject()->className(), ke->key(), qPrintable(ke->text()));
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
    for (MyWidget *w : g_mainWindow->windowsList()) {
        QJsonObject o;
        o["name"] = w->name();
        o["type"] = QString::fromLatin1(w->metaObject()->className());
        o["label"] = w->windowLabel();
        o["status"] = int(w->status());
        o["active"] = (w == aw);
        wins.append(o);
    }
    root["windows"] = wins;
    QAction *undo = g_mainWindow->ohosActionUndo();
    QAction *redo = g_mainWindow->ohosActionRedo();
    root["undoEnabled"] = undo && undo->isEnabled();
    root["redoEnabled"] = redo && redo->isEnabled();
    return QJsonDocument(root).toJson(QJsonDocument::Compact).toStdString();
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
                                             "getPlotList", "getPlotData",  "getUiState" };
    return q;
}

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
              return "{\"success\":true,\"data\":" + tableDataJson(args["tableId"].toString())
                      + "}";
          } },

        { "getUiState",
          [](const QJsonObject &) -> std::string {
              return "{\"success\":true,\"data\":" + uiStateJson() + "}";
          } },

        { "newTable",
          [](const QJsonObject &) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              Table *t = g_mainWindow->newTable();
              if (!t) return jsonError("failed");
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
              return "{\"success\":true}";
          } },

        { "importASCII",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              QString sep = args["separator"].toString("\t");
              QStringList files;
              files << args["filePath"].toString();
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
              return "{\"success\":true,\"data\":" + tableListJson() + "}";
          } },

        { "exportASCII",
          [](const QJsonObject &args) -> std::string {
              if (!g_mainWindow) return jsonError("no mw");
              g_mainWindow->exportASCII(args["tableId"].toString(),
                                        args["separator"].toString("\t"),
                                        args["colNames"].toBool(true), false);
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
              if (itemId == "new_notes")
                  g_mainWindow->newNote();
              else if (itemId == "new_matrix")
                  g_mainWindow->newMatrix();
              else if (itemId == "new_project")
                  g_mainWindow->newProject();
              else if (itemId == "new_graph")
                  g_mainWindow->newGraph();
              else if (itemId == "cascade")
                  g_mainWindow->cascade();
              else if (itemId == "maximize_window")
                  g_mainWindow->maximizeWindow();
              else if (itemId == "minimize_window")
                  g_mainWindow->minimizeWindow();
              else if (itemId == "close_window")
                  g_mainWindow->closeActiveWindow();
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
              else
                  ok = false;
              if (!ok)
                  return jsonError("unsupported on device: " + itemId.toStdString());
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
        mw->applyUserSettings();
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
