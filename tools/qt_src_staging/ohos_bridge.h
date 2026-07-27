/***************************************************************************
    File                 : ohos_bridge.h
    Project              : SciDAVis
    Description          : Qt → ArkTS event channel + dialog interposition
                           for the OpenHarmony (OHOS) single-window QPA.

    The alpha QPA plugin supports exactly one top-level window; creating a
    second one (QDialog/QMenu/QMessageBox/QToolTip/...) segfaults inside
    QOpenHarmonyJsObject::getJsFunction.  This bridge

      1. exports a C event channel so Qt code can push JSON events up to
         the ArkTS shell (scidavis_set_event_sink / scidavis_emit), and
      2. interposes the dialog entry points at the symbol level (see
         ohos_bridge.cpp) so *every* legacy call site is neutralized and
         reported to ArkTS instead of crashing.
 ***************************************************************************/
#ifndef OHOS_BRIDGE_H
#define OHOS_BRIDGE_H

#ifdef SCIDAVIS_OHOS

extern "C" {
typedef void (*scidavis_event_sink_t)(const char *json);

// Registered by the NAPI layer (qohos.cpp) via dlsym; may be called from
// any thread.  Passing nullptr unregisters the sink.
__attribute__((visibility("default"))) void scidavis_set_event_sink(scidavis_event_sink_t sink);

// Thread-safe: forwards a UTF-8 JSON document to the ArkTS sink.  Events
// emitted before a sink is registered are buffered (bounded) and flushed
// on registration.
__attribute__((visibility("default"))) void scidavis_emit(const char *json);
}

#include <QJsonObject>
#include <QString>

// Convenience helper: wraps payload as {"kind":<kind>, ...payload} and emits.
void scidavisEmitEvent(const QString &kind, QJsonObject payload = QJsonObject());

// Applies an ArkTS picker selection to the QComboBox whose popup request
// was emitted with the given id (see QComboBox::showPopup interposition).
// Must be called on the Qt GUI thread.  Returns false if the combo died.
bool ohosBridgeSelectCombo(int comboId, int index);

// Triggers the action at the '/'-separated index path of a blocked QMenu
// (see the contextMenu event).  Qt GUI thread only; false if the menu died.
bool ohosBridgeTriggerMenu(int menuId, const QString &path);

#endif // SCIDAVIS_OHOS

#endif // OHOS_BRIDGE_H
