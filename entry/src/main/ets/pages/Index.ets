// Qt Widgets surface. The XComponent with libraryname 'plugins_platforms_qopenharmony'
// is owned by the official QPA plugin: it provides the native surface that Qt
// renders into.
//
// Phase 1 - ArkTS Frontend Migration:
// XComponent remains as backup (Qt rendering underneath). ArkTS UI overlays on
// top: MenuBar at top, StatusBar at bottom, transparent content area in the
// middle that passes events through to the XComponent (Qt).
//
// Once the ArkTS frontend fully replaces all Qt UI panels, XComponent will be
// removed and Qt switched to QT_QPA_PLATFORM=offscreen (pure backend).
import hilog from '@ohos.hilog';
import qohos from 'libqohos.so';
import { MainLayout } from './MainLayout';

interface QohosInjector {
  sendMouse(x: number, y: number, button: number, action: number): boolean;
}

const qtInjector = qohos as QohosInjector;

let storage = LocalStorage.getShared();

const DOMAIN: number = 0x0000;
const TAG: string = 'QtInput';

let dbgCount: number = 0;
let leftDown: boolean = false;

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
        .onFocus(() => {
          hilog.info(DOMAIN, TAG, 'XComponent %{public}s gained focus', this.windowId);
        })
        .onBlur(() => {
          hilog.info(DOMAIN, TAG, 'XComponent %{public}s lost focus', this.windowId);
        })
        .width('100%')
        .height('100%')

      // Transparent hit-test layer: captures touch events converted from
      // left-button clicks by ArkUI. QPA touchDown is empty, so these
      // are forwarded via NAPI as mouse press/release events.
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .hitTestBehavior(HitTestMode.Transparent)
        .focusable(false)
        .onMouse((event: MouseEvent) => {
          // Only left-button drag (Move when leftDown) arrives via onMouse
          if (event.button === MouseButton.Left && event.action === MouseAction.Move && leftDown) {
            qtInjector.sendMouse(event.x, event.y, 1, 2);
          }
        })
        .onTouch((event: TouchEvent) => {
          // Forward ArkUI touch events (converted from left-button) as mouse events
          const changed: TouchObject[] = event.changedTouches;
          for (let i = 0; i < changed.length; i++) {
            const t: TouchObject = changed[i];
            let action: number = -1;
            if (t.type === TouchType.Down) {
              action = 0; leftDown = true;
            } else if (t.type === TouchType.Up) {
              action = 1; leftDown = false;
            } else if (t.type === TouchType.Move && leftDown) {
              action = 2;
            }
            if (action >= 0 && action !== 2) {
              qtInjector.sendMouse(t.x, t.y, 1, action);
            }
          }
        })

      // Layer 2 (top): ArkTS UI overlay
      // MenuBar and StatusBar block events in their areas.
      // Content area (middle) is transparent, passes through to XComponent.
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
