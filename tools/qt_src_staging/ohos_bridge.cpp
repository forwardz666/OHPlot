/***************************************************************************
    File                 : ohos_bridge.cpp
    Project              : SciDAVis
    Description          : Qt → ArkTS event channel + dialog symbol
                           interposition for the OpenHarmony single-window
                           QPA (see ohos_bridge.h for rationale).

    HOW THE INTERPOSITION WORKS
    ---------------------------
    libscidavis.a is statically linked into libentry.so.  At static link
    time the linker prefers symbols *defined inside the link unit* over
    dynamic symbols exported by libQt5Widgets.so, so every call site in
    SciDAVis code binds to the definitions below instead of the real Qt
    implementations.  Vtable slots emitted in libentry.so (all SciDAVis
    dialog subclasses) bind the same way, and vtable slots inside
    libQt5Widgets.so are data relocations resolved through the dlopen
    lookup order (libentry.so first), so virtual dispatch is covered too.

    Every blocked popup is reported to ArkTS via scidavis_emit so the
    shell can render a native ArkUI replacement instead of failing
    silently.
 ***************************************************************************/
#include "ohos_bridge.h"

#ifdef SCIDAVIS_OHOS

#include <QApplication>
#include <QColorDialog>
#include <QComboBox>
#include <QDialog>
#include <QFileDialog>
#include <QFontDialog>
#include <QInputDialog>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMenu>
#include <QMessageBox>
#include <QPointer>

#include <atomic>
#include <cstdio>
#include <deque>
#include <map>
#include <mutex>
#include <string>

#include <hilog/log.h>

// stderr is a black hole on OHOS — route bridge diagnostics to hilog so
// interposer hits show up next to the ArkTS logs (tag SciDAVisBridge).
#define BRIDGE_LOG(fmt, ...)                                                                       \
    do {                                                                                           \
        OH_LOG_Print(LOG_APP, LOG_INFO, 0x0000, "SciDAVisBridge", fmt, ##__VA_ARGS__);             \
    } while (0)

// ── Event channel ────────────────────────────────────────────────────────

namespace {
std::mutex g_sinkMutex;
scidavis_event_sink_t g_sink = nullptr;
// Events emitted before the ArkTS sink registers (e.g. during Qt startup)
// are buffered here and flushed on registration.
std::deque<std::string> g_pending;
constexpr size_t kMaxPending = 64;
}

extern "C" void scidavis_set_event_sink(scidavis_event_sink_t sink)
{
    std::deque<std::string> flush;
    {
        std::lock_guard<std::mutex> lock(g_sinkMutex);
        g_sink = sink;
        if (sink)
            std::swap(flush, g_pending);
    }
    BRIDGE_LOG("event sink %s (%zu buffered flushed)", sink ? "registered" : "cleared",
               flush.size());
    if (sink)
        for (const std::string &e : flush)
            sink(e.c_str());
}

extern "C" void scidavis_emit(const char *json)
{
    if (!json)
        return;
    scidavis_event_sink_t sink;
    {
        std::lock_guard<std::mutex> lock(g_sinkMutex);
        if (!g_sink) {
            if (g_pending.size() >= kMaxPending)
                g_pending.pop_front();
            g_pending.emplace_back(json);
            return;
        }
        sink = g_sink;
    }
    sink(json);
}

void scidavisEmitEvent(const QString &kind, QJsonObject payload)
{
    payload.insert(QStringLiteral("kind"), kind);
    const QByteArray doc = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    scidavis_emit(doc.constData());
}

// ── Shared helpers for the interposed entry points ───────────────────────

namespace {

QJsonObject widgetInfo(const QWidget *w)
{
    QJsonObject o;
    if (w) {
        o[QStringLiteral("className")] = QString::fromLatin1(w->metaObject()->className());
        o[QStringLiteral("objectName")] = w->objectName();
        o[QStringLiteral("title")] = w->windowTitle();
    }
    return o;
}

// Safe default answer for a blocked QMessageBox: prefer the non-destructive
// choice (Ok to acknowledge, No to decline) over a potentially destructive
// Yes, then the caller-supplied default, then Cancel.
QMessageBox::StandardButton pickSafeButton(QMessageBox::StandardButtons buttons,
                                           QMessageBox::StandardButton defaultButton)
{
    if (buttons & QMessageBox::Ok)
        return QMessageBox::Ok;
    if (buttons & QMessageBox::No)
        return QMessageBox::No;
    if (defaultButton != QMessageBox::NoButton)
        return defaultButton;
    if (buttons & QMessageBox::Cancel)
        return QMessageBox::Cancel;
    if (buttons & QMessageBox::Close)
        return QMessageBox::Close;
    return QMessageBox::Cancel;
}

QMessageBox::StandardButton emitMessage(const char *severity, QWidget *parent,
                                        const QString &title, const QString &text,
                                        QMessageBox::StandardButtons buttons,
                                        QMessageBox::StandardButton defaultButton)
{
    const QMessageBox::StandardButton chosen = pickSafeButton(buttons, defaultButton);
    QJsonObject p = widgetInfo(parent);
    p[QStringLiteral("severity")] = QString::fromLatin1(severity);
    p[QStringLiteral("title")] = title;
    p[QStringLiteral("text")] = text;
    p[QStringLiteral("buttons")] = int(buttons);
    p[QStringLiteral("defaultButton")] = int(defaultButton);
    p[QStringLiteral("chosen")] = int(chosen);
    scidavisEmitEvent(QStringLiteral("message"), p);
    BRIDGE_LOG("QMessageBox::%s blocked: %s", severity, title.toUtf8().constData());
    return chosen;
}

void emitFileDialog(const char *mode, QWidget *parent, const QString &caption, const QString &dir,
                    const QString &filter)
{
    QJsonObject p = widgetInfo(parent);
    p[QStringLiteral("mode")] = QString::fromLatin1(mode);
    p[QStringLiteral("caption")] = caption;
    p[QStringLiteral("dir")] = dir;
    p[QStringLiteral("filter")] = filter;
    scidavisEmitEvent(QStringLiteral("fileDialog"), p);
    BRIDGE_LOG("QFileDialog::%s blocked: %s", mode, caption.toUtf8().constData());
}

void emitInputDialog(const char *mode, const QString &title, const QString &label)
{
    QJsonObject p;
    p[QStringLiteral("mode")] = QString::fromLatin1(mode);
    p[QStringLiteral("title")] = title;
    p[QStringLiteral("label")] = label;
    scidavisEmitEvent(QStringLiteral("inputDialog"), p);
    BRIDGE_LOG("QInputDialog::%s blocked: %s", mode, title.toUtf8().constData());
}

// ── Menu registry (context menus) ────────────────────────────────────────
// Blocked QMenus are registered so ArkTS can render the entries and, for
// heap-allocated menus that stay alive (e.g. windowsMenu), trigger the
// chosen action via ohosBridgeTriggerMenu.  Stack-allocated menus die as
// soon as the caller returns; triggering those fails gracefully.
std::mutex g_menuMutex;
std::map<int, QPointer<QMenu>> g_menus;
int g_menuSeq = 0;

QJsonArray describeActions(const QList<QAction *> &actions, int depth)
{
    QJsonArray arr;
    for (QAction *a : actions) {
        QJsonObject item;
        if (a->isSeparator()) {
            item[QStringLiteral("separator")] = true;
        } else {
            item[QStringLiteral("text")] = a->text();
            item[QStringLiteral("enabled")] = a->isEnabled();
            item[QStringLiteral("checkable")] = a->isCheckable();
            item[QStringLiteral("checked")] = a->isChecked();
            if (a->menu() && depth < 3)
                item[QStringLiteral("children")] = describeActions(a->menu()->actions(), depth + 1);
        }
        arr.append(item);
    }
    return arr;
}

void emitBlockedMenu(QMenu *menu)
{
    if (!menu)
        return;
    int id;
    {
        std::lock_guard<std::mutex> lock(g_menuMutex);
        // prune dead entries
        for (auto it = g_menus.begin(); it != g_menus.end();)
            it = it->second.isNull() ? g_menus.erase(it) : std::next(it);
        id = ++g_menuSeq;
        g_menus[id] = menu;
    }
    QJsonObject p = widgetInfo(menu);
    p[QStringLiteral("menuId")] = id;
    p[QStringLiteral("items")] = describeActions(menu->actions(), 0);
    scidavisEmitEvent(QStringLiteral("contextMenu"), p);
    BRIDGE_LOG("QMenu blocked: id=%d '%s' (%d actions)", id,
               menu->objectName().toUtf8().constData(), menu->actions().size());
}

// ── Combo popup registry ─────────────────────────────────────────────────
std::mutex g_comboMutex;
std::map<int, QPointer<QComboBox>> g_combos;
int g_comboSeq = 0;

} // namespace

bool ohosBridgeTriggerMenu(int menuId, const QString &path)
{
    QPointer<QMenu> menu;
    {
        std::lock_guard<std::mutex> lock(g_menuMutex);
        auto it = g_menus.find(menuId);
        if (it == g_menus.end())
            return false;
        menu = it->second;
        g_menus.erase(it);
    }
    if (menu.isNull())
        return false;
    // path is a '/'-separated index chain, e.g. "2/0" = 3rd action's
    // submenu, 1st action.
    QList<QAction *> actions = menu->actions();
    QAction *target = nullptr;
    for (const QString &seg : path.split(QLatin1Char('/'), Qt::SkipEmptyParts)) {
        bool ok = false;
        const int idx = seg.toInt(&ok);
        if (!ok || idx < 0 || idx >= actions.size())
            return false;
        target = actions.at(idx);
        actions = target->menu() ? target->menu()->actions() : QList<QAction *>();
    }
    if (!target || target->isSeparator() || target->menu() || !target->isEnabled())
        return false;
    target->trigger();
    return true;
}

bool ohosBridgeSelectCombo(int comboId, int index)
{
    QPointer<QComboBox> box;
    {
        std::lock_guard<std::mutex> lock(g_comboMutex);
        auto it = g_combos.find(comboId);
        if (it == g_combos.end())
            return false;
        box = it->second;
        g_combos.erase(it);
    }
    if (box.isNull())
        return false;
    if (index >= 0 && index < box->count())
        box->setCurrentIndex(index);
    return true;
}

// ═════════════════════════════════════════════════════════════════════════
//  Symbol interposition — these definitions preempt the libQt5Widgets.so
//  implementations at static link time (signatures must match the Qt 5.15
//  OHOS headers exactly; default arguments live in the declarations).
// ═════════════════════════════════════════════════════════════════════════

// ── QDialog ──────────────────────────────────────────────────────────────

int QDialog::exec()
{
    scidavisEmitEvent(QStringLiteral("dialogBlocked"), widgetInfo(this));
    BRIDGE_LOG("blocked %s::exec()", metaObject()->className());
    return QDialog::Rejected;
}

void QDialog::setVisible(bool visible)
{
    if (visible) {
        scidavisEmitEvent(QStringLiteral("dialogBlocked"), widgetInfo(this));
        BRIDGE_LOG("blocked %s show()", metaObject()->className());
        return;
    }
    // Hiding is safe; bypass QDialog's own logic (never shown anyway).
    this->QWidget::setVisible(visible);
}

// QFileDialog / QColorDialog / QFontDialog override setVisible, so their
// vtable slots would otherwise still point at the real (crashing) code.

void QFileDialog::setVisible(bool visible)
{
    if (visible) {
        scidavisEmitEvent(QStringLiteral("dialogBlocked"), widgetInfo(this));
        BRIDGE_LOG("blocked QFileDialog show()");
        return;
    }
    this->QWidget::setVisible(visible);
}

void QColorDialog::setVisible(bool visible)
{
    if (visible) {
        scidavisEmitEvent(QStringLiteral("dialogBlocked"), widgetInfo(this));
        return;
    }
    this->QWidget::setVisible(visible);
}

void QFontDialog::setVisible(bool visible)
{
    if (visible) {
        scidavisEmitEvent(QStringLiteral("dialogBlocked"), widgetInfo(this));
        return;
    }
    this->QWidget::setVisible(visible);
}

// ── QMenu ────────────────────────────────────────────────────────────────

QAction *QMenu::exec()
{
    emitBlockedMenu(this);
    return nullptr;
}

QAction *QMenu::exec(const QPoint &pos, QAction *at)
{
    Q_UNUSED(pos);
    Q_UNUSED(at);
    emitBlockedMenu(this);
    return nullptr;
}

void QMenu::popup(const QPoint &pos, QAction *at)
{
    Q_UNUSED(pos);
    Q_UNUSED(at);
    emitBlockedMenu(this);
}

QAction *QMenu::exec(QList<QAction *> actions, const QPoint &pos, QAction *at, QWidget *parent)
{
    Q_UNUSED(pos);
    Q_UNUSED(at);
    QJsonObject p = widgetInfo(parent);
    p[QStringLiteral("items")] = describeActions(actions, 0);
    scidavisEmitEvent(QStringLiteral("contextMenu"), p);
    BRIDGE_LOG("static QMenu::exec blocked (%d actions)", actions.size());
    return nullptr;
}

// ── QMessageBox ──────────────────────────────────────────────────────────

QMessageBox::StandardButton QMessageBox::information(QWidget *parent, const QString &title,
                                                     const QString &text, StandardButtons buttons,
                                                     StandardButton defaultButton)
{
    return emitMessage("information", parent, title, text, buttons, defaultButton);
}

QMessageBox::StandardButton QMessageBox::question(QWidget *parent, const QString &title,
                                                  const QString &text, StandardButtons buttons,
                                                  StandardButton defaultButton)
{
    return emitMessage("question", parent, title, text, buttons, defaultButton);
}

QMessageBox::StandardButton QMessageBox::warning(QWidget *parent, const QString &title,
                                                 const QString &text, StandardButtons buttons,
                                                 StandardButton defaultButton)
{
    return emitMessage("warning", parent, title, text, buttons, defaultButton);
}

QMessageBox::StandardButton QMessageBox::critical(QWidget *parent, const QString &title,
                                                  const QString &text, StandardButtons buttons,
                                                  StandardButton defaultButton)
{
    return emitMessage("critical", parent, title, text, buttons, defaultButton);
}

void QMessageBox::about(QWidget *parent, const QString &title, const QString &text)
{
    emitMessage("about", parent, title, text, QMessageBox::Ok, QMessageBox::Ok);
}

void QMessageBox::aboutQt(QWidget *parent, const QString &title)
{
    emitMessage("about", parent, title.isEmpty() ? QStringLiteral("About Qt") : title,
                QStringLiteral("Qt %1").arg(QLatin1String(qVersion())), QMessageBox::Ok,
                QMessageBox::Ok);
}

// ── QFileDialog statics ──────────────────────────────────────────────────
// Empty return = "user cancelled"; the ArkTS shell opens its own picker in
// response to the fileDialog event (Phase 2 wires the result back through
// dedicated commands like openProject(path)).

QString QFileDialog::getOpenFileName(QWidget *parent, const QString &caption, const QString &dir,
                                     const QString &filter, QString *selectedFilter,
                                     Options options)
{
    Q_UNUSED(selectedFilter);
    Q_UNUSED(options);
    emitFileDialog("open", parent, caption, dir, filter);
    return QString();
}

QStringList QFileDialog::getOpenFileNames(QWidget *parent, const QString &caption,
                                          const QString &dir, const QString &filter,
                                          QString *selectedFilter, Options options)
{
    Q_UNUSED(selectedFilter);
    Q_UNUSED(options);
    emitFileDialog("openMulti", parent, caption, dir, filter);
    return QStringList();
}

QString QFileDialog::getSaveFileName(QWidget *parent, const QString &caption, const QString &dir,
                                     const QString &filter, QString *selectedFilter,
                                     Options options)
{
    Q_UNUSED(selectedFilter);
    Q_UNUSED(options);
    emitFileDialog("save", parent, caption, dir, filter);
    return QString();
}

QString QFileDialog::getExistingDirectory(QWidget *parent, const QString &caption,
                                          const QString &dir, Options options)
{
    Q_UNUSED(options);
    emitFileDialog("directory", parent, caption, dir, QString());
    return QString();
}

// ── QInputDialog statics ─────────────────────────────────────────────────
// *ok = false and the default value = "user cancelled".

QString QInputDialog::getText(QWidget *parent, const QString &title, const QString &label,
                              QLineEdit::EchoMode echo, const QString &text, bool *ok,
                              Qt::WindowFlags flags, Qt::InputMethodHints inputMethodHints)
{
    Q_UNUSED(parent);
    Q_UNUSED(echo);
    Q_UNUSED(flags);
    Q_UNUSED(inputMethodHints);
    emitInputDialog("text", title, label);
    if (ok)
        *ok = false;
    return text;
}

QString QInputDialog::getMultiLineText(QWidget *parent, const QString &title, const QString &label,
                                       const QString &text, bool *ok, Qt::WindowFlags flags,
                                       Qt::InputMethodHints inputMethodHints)
{
    Q_UNUSED(parent);
    Q_UNUSED(flags);
    Q_UNUSED(inputMethodHints);
    emitInputDialog("multiLineText", title, label);
    if (ok)
        *ok = false;
    return text;
}

QString QInputDialog::getItem(QWidget *parent, const QString &title, const QString &label,
                              const QStringList &items, int current, bool editable, bool *ok,
                              Qt::WindowFlags flags, Qt::InputMethodHints inputMethodHints)
{
    Q_UNUSED(parent);
    Q_UNUSED(editable);
    Q_UNUSED(flags);
    Q_UNUSED(inputMethodHints);
    emitInputDialog("item", title, label);
    if (ok)
        *ok = false;
    return (current >= 0 && current < items.size()) ? items.at(current) : QString();
}

int QInputDialog::getInt(QWidget *parent, const QString &title, const QString &label, int value,
                         int minValue, int maxValue, int step, bool *ok, Qt::WindowFlags flags)
{
    Q_UNUSED(parent);
    Q_UNUSED(minValue);
    Q_UNUSED(maxValue);
    Q_UNUSED(step);
    Q_UNUSED(flags);
    emitInputDialog("int", title, label);
    if (ok)
        *ok = false;
    return value;
}

double QInputDialog::getDouble(QWidget *parent, const QString &title, const QString &label,
                               double value, double minValue, double maxValue, int decimals,
                               bool *ok, Qt::WindowFlags flags)
{
    Q_UNUSED(parent);
    Q_UNUSED(minValue);
    Q_UNUSED(maxValue);
    Q_UNUSED(decimals);
    Q_UNUSED(flags);
    emitInputDialog("double", title, label);
    if (ok)
        *ok = false;
    return value;
}

double QInputDialog::getDouble(QWidget *parent, const QString &title, const QString &label,
                               double value, double minValue, double maxValue, int decimals,
                               bool *ok, Qt::WindowFlags flags, double step)
{
    Q_UNUSED(step);
    return getDouble(parent, title, label, value, minValue, maxValue, decimals, ok, flags);
}

// ── QColorDialog / QFontDialog statics ───────────────────────────────────

QColor QColorDialog::getColor(const QColor &initial, QWidget *parent, const QString &title,
                              ColorDialogOptions options)
{
    Q_UNUSED(parent);
    Q_UNUSED(options);
    QJsonObject p;
    p[QStringLiteral("title")] = title;
    p[QStringLiteral("initial")] = initial.name();
    scidavisEmitEvent(QStringLiteral("colorDialog"), p);
    BRIDGE_LOG("QColorDialog::getColor blocked");
    return QColor(); // invalid = cancelled
}

QFont QFontDialog::getFont(bool *ok, QWidget *parent)
{
    Q_UNUSED(parent);
    scidavisEmitEvent(QStringLiteral("fontDialog"), QJsonObject());
    if (ok)
        *ok = false;
    return QFont();
}

QFont QFontDialog::getFont(bool *ok, const QFont &initial, QWidget *parent, const QString &title,
                           FontDialogOptions options)
{
    Q_UNUSED(parent);
    Q_UNUSED(options);
    QJsonObject p;
    p[QStringLiteral("title")] = title;
    p[QStringLiteral("initial")] = initial.toString();
    scidavisEmitEvent(QStringLiteral("fontDialog"), p);
    BRIDGE_LOG("QFontDialog::getFont blocked");
    if (ok)
        *ok = false;
    return initial;
}

// ── QComboBox popup ──────────────────────────────────────────────────────
// The dropdown is a Qt::Popup top-level window → crash.  Emit the items so
// ArkTS can render a picker; the selection comes back through the
// selectCombo command (ohosBridgeSelectCombo).

void QComboBox::showPopup()
{
    int id;
    {
        std::lock_guard<std::mutex> lock(g_comboMutex);
        for (auto it = g_combos.begin(); it != g_combos.end();)
            it = it->second.isNull() ? g_combos.erase(it) : std::next(it);
        id = ++g_comboSeq;
        g_combos[id] = this;
    }
    QJsonArray items;
    for (int i = 0; i < count(); ++i)
        items.append(itemText(i));
    QJsonObject p = widgetInfo(this);
    p[QStringLiteral("comboId")] = id;
    p[QStringLiteral("items")] = items;
    p[QStringLiteral("current")] = currentIndex();
    scidavisEmitEvent(QStringLiteral("comboRequest"), p);
    BRIDGE_LOG("QComboBox popup blocked: id=%d (%d items)", id, count());
}

#endif // SCIDAVIS_OHOS
