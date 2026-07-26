// Qt Widgets surface. The XComponent with libraryname 'plugins_platforms_qopenharmony'
// is owned by the official QPA plugin: it provides the native surface that Qt
// renders into. The id is set via LocalStorage ("idName") so each window
// (main or sub-window) gets its own XComponent with a unique id.
//
// Input note: the QPA plugin registers OH_NativeXComponent_RegisterCallback,
// RegisterMouseEventCallback and RegisterKeyEventCallback natively, so touch /
// keyboard / right-button mouse events are delivered directly to the plugin as
// long as the XComponent itself holds focus.  .defaultFocus ensures a Bluetooth
// keyboard works immediately without a prior touch.
//
// LEFT-BUTTON WORKAROUND: ArkUI converts left-button mouse events into the
// touch pipeline (mousetransEnable=1) and the QPA plugin's touch dispatch
// drops them entirely (ground truth: InputProbe saw zero events for left
// clicks while right clicks propagate fully).  The XComponent's own .onMouse
// never fires either (native callbacks consume everything), so a transparent
// overlay (HitTestMode.Transparent) sits on top: it observes mouse events at
// the ETS level and forwards left press/release/drag through libqohos.so
// sendMouse() into the scidavis_inject_mouse export of libentry.so, while
// touch / right-button events still pass through to the XComponent.
import hilog from '@ohos.hilog';
import qohos from 'libqohos.so';

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

      // Transparent hit-test layer: receives mouse events that the native
      // XComponent swallows before ETS dispatch, and lets everything continue
      // through to the XComponent underneath (HitTestMode.Transparent).
      //
      // ArkUI converts left-button Press/Release into touch events
      // (mousetransEnable=1), so .onMouse only receives Move.  We use
      // .onTouch to catch the converted touch events whose sourceType is
      // SourceType.Mouse and forward them as injected mouse Press/Release.
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .hitTestBehavior(HitTestMode.Transparent)
        .focusable(false)
        .onMouse((event: MouseEvent) => {
          // Mouse Move events (right button, middle button, etc.) still
          // arrive via onMouse.  Forward left-button drag here.
          if (event.button === MouseButton.Left && event.action === MouseAction.Move && leftDown) {
            const px: number = vp2px(event.x);
            const py: number = vp2px(event.y);
            const ok: boolean = qtInjector.sendMouse(px, py, 1, 2);
            if (dbgCount < 200) {
              dbgCount++;
              hilog.info(DOMAIN, TAG,
                'forward drag px=(%{public}d,%{public}d) ok=%{public}s',
                Math.round(px), Math.round(py), String(ok));
            }
          } else if (event.button !== MouseButton.Left && dbgCount < 200) {
            dbgCount++;
            hilog.info(DOMAIN, TAG, 'onMouse action=%{public}d btn=%{public}d x=%{public}d y=%{public}d',
              event.action as number, event.button as number, Math.round(event.x), Math.round(event.y));
          }
        })
        .onTouch((event: TouchEvent) => {
          // ArkUI converts left-button Press/Release into touch events
          // (mousetransEnable=1).  The QPA plugin's touchDown is an empty
          // function, so these touch events are silently dropped.  We
          // capture them here and re-inject as mouse events via NAPI.
          //
          // Note: we forward ALL touch Down/Up events as mouse clicks.
          // This is safe because QPA touchDown is empty (no double
          // dispatch), and finger touches will also work as mouse clicks
          // which is acceptable for a desktop-style application.
          const changed: TouchObject[] = event.changedTouches;
          for (let i = 0; i < changed.length; i++) {
            const t: TouchObject = changed[i];
            const px: number = vp2px(t.x);
            const py: number = vp2px(t.y);
            let action: number = -1;
            if (t.type === TouchType.Down) {
              action = 0; // mouse press
              leftDown = true;
            } else if (t.type === TouchType.Up) {
              action = 1; // mouse release
              leftDown = false;
            } else if (t.type === TouchType.Move && leftDown) {
              action = 2; // drag
            }
            if (action >= 0 && action !== 2) {
              const ok: boolean = qtInjector.sendMouse(px, py, 1, action);
              if (dbgCount < 200) {
                dbgCount++;
                hilog.info(DOMAIN, TAG,
                  'forward touch->mouse action=%{public}d px=(%{public}d,%{public}d) ok=%{public}s',
                  action, Math.round(px), Math.round(py), String(ok));
              }
            }
          }
        })
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
