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

#include <QAction>
#include <QApplication>
#include <QElapsedTimer>
#include <QMouseEvent>
#include <QSplashScreen>
#include <QTimer>
#include <QWindow>

#include <typeinfo>
#include <cstdio>
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
            qWarning("[InputProbe] mouse %s recv=%s pos=(%d,%d) global=(%d,%d) btn=0x%x",
                     ev->type() == QEvent::MouseButtonPress         ? "press"
                             : ev->type() == QEvent::MouseButtonRelease ? "release"
                                                                        : "dblclick",
                     obj->metaObject()->className(), me->pos().x(), me->pos().y(), me->globalX(),
                     me->globalY(), int(me->button()));
            break;
        }
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
        QWindow *win = QGuiApplication::focusWindow();
        if (!win) {
            const auto tls = QGuiApplication::topLevelWindows();
            for (QWindow *w : tls)
                if (w->isVisible()) { win = w; break; }
        }
        if (!win)
            return;
        static QElapsedTimer sPressTimer;
        static QPoint sLastPress;
        const QPoint globalP{ int(x), int(y) };
        const QPoint localP = win->mapFromGlobal(globalP);
        Qt::MouseButton btn = (button == 2) ? Qt::RightButton : Qt::LeftButton;
        Qt::MouseButtons buttons = btn;
        QEvent::Type type = QEvent::MouseButtonPress;
        switch (action) {
        case 0: { // press — synthesize double click like QGuiApplication would
            const bool dbl = sPressTimer.isValid() && !sPressTimer.hasExpired(400)
                    && (globalP - sLastPress).manhattanLength() < 10;
            type = dbl ? QEvent::MouseButtonDblClick : QEvent::MouseButtonPress;
            sPressTimer.restart();
            sLastPress = globalP;
            break;
        }
        case 1:
            type = QEvent::MouseButtonRelease;
            buttons = Qt::NoButton;
            break;
        case 2:
            type = QEvent::MouseMove;
            btn = Qt::NoButton;
            buttons = Qt::LeftButton;
            break;
        default:
            return;
        }
        QMouseEvent ev(type, localP, localP, globalP, btn, buttons, Qt::NoModifier,
                       Qt::MouseEventSynthesizedByApplication);
        // Deliver to the QWidgetWindow: its event() runs the full widget-level
        // dispatch (popup handling, implicit grab, child lookup).
        QCoreApplication::sendEvent(win, &ev);
    }, Qt::QueuedConnection);
}

int main(int argc, char **argv)
{

    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling, true);
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
