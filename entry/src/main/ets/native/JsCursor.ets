/**
 * JsCursor – bridge for mouse pointer style management.
 * Mirrors the official Qt SDK template's JsCursor.ets.
 * The QPA plugin requests this object via createJsObject("JsCursor")
 * and calls setPointerStyle / setPointerVisible to change the cursor.
 */
import pointer from '@ohos.multimodalInput.pointer';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'JsCursor';

/** Minimal window lookup interface (avoids circular dependency). */
interface WindowLookup {
  getWindowId(): number | undefined;
}

export class JsCursor {
  private windowGetter: ((name: string) => WindowLookup | undefined) | undefined = undefined;

  constructor(windowGetter?: (name: string) => WindowLookup | undefined) {
    this.windowGetter = windowGetter;
  }

  setPointerStyle(pointerStyle: pointer.PointerStyle, windowName: string): void {
    let windowId: number | undefined = this.getWindowId(windowName);
    if (windowId == undefined || windowId < 0) {
      hilog.warn(DOMAIN, TAG, 'setPointerStyle: invalid windowId for %{public}s', windowName);
      return;
    }
    try {
      pointer.setPointerStyle(windowId, pointerStyle).then(() => {
        hilog.info(DOMAIN, TAG, 'setPointerStyle OK: %{public}d', pointerStyle as number);
      }).catch((e: Object) => {
        hilog.error(DOMAIN, TAG, 'setPointerStyle async failed: %{public}s', JSON.stringify(e));
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setPointerStyle failed: %{public}s', JSON.stringify(e));
    }
  }

  private getWindowId(windowName: string): number | undefined {
    if (this.windowGetter == undefined) { return undefined; }
    let win: WindowLookup | undefined = this.windowGetter(windowName);
    if (win == undefined) { return undefined; }
    return win.getWindowId();
  }

  setPointerVisible(isVisible: boolean): void {
    try {
      pointer.setPointerVisible(isVisible, (error: Error) => {
        if (error) {
          hilog.error(DOMAIN, TAG, 'setPointerVisible failed: %{public}s', JSON.stringify(error));
        }
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setPointerVisible failed: %{public}s', JSON.stringify(e));
    }
  }
}
