// Qt Widgets surface. The XComponent with libraryname 'plugins_platforms_qopenharmony'
// is owned by the official QPA plugin: it provides the native surface that Qt
// renders into.
//
// Phase 1 - ArkTS Frontend Migration:
// XComponent remains as backup (Qt rendering underneath). MainLayout overlays
// on top and handles: MenuBar (top), transparent content area (middle),
// StatusBar (bottom). Touch forwarding to Qt is handled inside MainLayout.
//
// Once the ArkTS frontend fully replaces all Qt UI panels, XComponent will be
// removed and Qt switched to QT_QPA_PLATFORM=offscreen (pure backend).
import { MainLayout } from './MainLayout';

let storage = LocalStorage.getShared();

@Component
struct SciDAVisView {
  @LocalStorageProp('idName') windowId: string = 'openharmony_qt_mainwindow';

  build() {
    Stack() {
      // Layer 1 (bottom): Qt rendering surface
      XComponent({
        id: this.windowId,
        type: XComponentType.SURFACE,
        libraryname: 'plugins_platforms_qopenharmony'
      })
        .focusable(true)
        .focusOnTouch(true)
        .defaultFocus(true)
        .width('100%')
        .height('100%')

      // Layer 2 (top): ArkTS UI overlay
      // Touch events in the content area pass through to the XComponent.
      // MainLayout internally handles event forwarding to Qt via NAPI.
      MainLayout()
    }
    .width('100%')
    .height('100%')
  }
}

@Entry(storage)
@Component
struct Index {
  build() {
    Row() {
      SciDAVisView()
    }
    .width('100%')
    .height('100%')
  }
}
