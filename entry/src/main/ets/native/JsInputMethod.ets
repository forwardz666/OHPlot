/**
 * JsInputMethod – bridge between OpenHarmony IME and the QPA plugin.
 * Mirrors the official Qt SDK template's JsInputMethod.ts.
 * The QPA plugin requests this object via createJsObject("JsInputMethod")
 * and calls attach/detach/showTextInput/etc. to manage the soft keyboard.
 */
import inputMethod from '@ohos.inputMethod';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'JsInputMethod';

/** Minimal QPA interface for input-method forwarding.
 * Exported so QpaModule in SciDAVisAbility can extend it (ArkTS requires
 * nominal typing – structural typing is not supported). */
export interface QpaInput {
  insertText(handler: number, text: string): void;
  sendEnterKey(handler: number): void;
  deleteLeft(handler: number, length: number): void;
  deleteRight(handler: number, length: number): void;
  moveCursor(handler: number, direction: number): void;
}

export class JsInputMethod {
  private handler: number = 0;
  private visable: boolean = false;
  private attached: boolean = false;
  private inputMethodController: inputMethod.InputMethodController = inputMethod.getController();
  private qpa: QpaInput | undefined = undefined;

  constructor(qpa?: QpaInput) {
    this.qpa = qpa;
  }

  private subscribe(): void {
    try {
      this.inputMethodController.on('insertText', (text: string) => {
        hilog.info(DOMAIN, TAG, 'insertText: %{public}s', text);
        this.qpa?.insertText(this.handler, text);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribe insertText failed: %{public}s', JSON.stringify(e));
    }
    try {
      this.inputMethodController.on('sendFunctionKey', (functionKey: inputMethod.FunctionKey) => {
        hilog.info(DOMAIN, TAG, 'sendFunctionKey: %{public}d', functionKey.enterKeyType);
        this.qpa?.sendEnterKey(this.handler);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribe sendFunctionKey failed: %{public}s', JSON.stringify(e));
    }
    try {
      this.inputMethodController.on('sendKeyboardStatus', (keyboardStatus: inputMethod.KeyboardStatus) => {
        hilog.info(DOMAIN, TAG, 'keyboardStatus: %{public}d', keyboardStatus);
        if (keyboardStatus == inputMethod.KeyboardStatus.HIDE) {
          this.visable = false;
          this.detach();
        } else if (keyboardStatus == inputMethod.KeyboardStatus.SHOW) {
          this.visable = true;
        }
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribe sendKeyboardStatus failed: %{public}s', JSON.stringify(e));
    }
    try {
      this.inputMethodController.on('deleteLeft', (length: number) => {
        this.qpa?.deleteLeft(this.handler, length);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribe deleteLeft failed: %{public}s', JSON.stringify(e));
    }
    try {
      this.inputMethodController.on('deleteRight', (length: number) => {
        this.qpa?.deleteRight(this.handler, length);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribe deleteRight failed: %{public}s', JSON.stringify(e));
    }
    try {
      this.inputMethodController.on('moveCursor', (direction: inputMethod.Direction) => {
        this.qpa?.moveCursor(this.handler, direction as number);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'subscribe moveCursor failed: %{public}s', JSON.stringify(e));
    }
    try {
      this.inputMethodController.on('getLeftTextOfCursor', (length: number) => {
        return '';
      });
    } catch (e) { /* optional */ }
    try {
      this.inputMethodController.on('getRightTextOfCursor', (length: number) => {
        return '';
      });
    } catch (e) { /* optional */ }
    try {
      this.inputMethodController.on('getTextIndexAtCursor', () => {
        return 0;
      });
    } catch (e) { /* optional */ }
    try {
      this.inputMethodController.on('selectByRange', (range: inputMethod.Range) => {
        hilog.info(DOMAIN, TAG, 'selectByRange: %{public}d-%{public}d', range.start, range.end);
      });
    } catch (e) { /* optional */ }
    try {
      this.inputMethodController.on('selectByMovement', (movement: inputMethod.Movement) => {
        hilog.info(DOMAIN, TAG, 'selectByMovement: %{public}d', movement.direction);
      });
    } catch (e) { /* optional */ }
    try {
      this.inputMethodController.on('handleExtendAction', (action: inputMethod.ExtendAction) => {
        hilog.info(DOMAIN, TAG, 'handleExtendAction: %{public}d', action);
      });
    } catch (e) { /* optional */ }
  }

  private unsubscribe(): void {
    try { this.inputMethodController.off('insertText'); } catch (e) {}
    try { this.inputMethodController.off('sendFunctionKey'); } catch (e) {}
    try { this.inputMethodController.off('sendKeyboardStatus'); } catch (e) {}
    try { this.inputMethodController.off('deleteLeft'); } catch (e) {}
    try { this.inputMethodController.off('deleteRight'); } catch (e) {}
    try { this.inputMethodController.off('moveCursor'); } catch (e) {}
    try { this.inputMethodController.off('getLeftTextOfCursor'); } catch (e) {}
    try { this.inputMethodController.off('getRightTextOfCursor'); } catch (e) {}
    try { this.inputMethodController.off('getTextIndexAtCursor'); } catch (e) {}
    try { this.inputMethodController.off('selectByRange'); } catch (e) {}
    try { this.inputMethodController.off('selectByMovement'); } catch (e) {}
    try { this.inputMethodController.off('handleExtendAction'); } catch (e) {}
  }

  isInputPanelVisible(): boolean {
    return this.visable;
  }

  isAttached(): boolean {
    return this.attached;
  }

  async attach(handler: number, inputType: number, enterType: number): Promise<boolean> {
    hilog.info(DOMAIN, TAG, 'attach handler=%{public}d inputType=%{public}d enterType=%{public}d',
      handler, inputType, enterType);
    if (this.attached) { return true; }
    if (handler == 0) {
      hilog.error(DOMAIN, TAG, 'attach: handler is 0');
      return false;
    }
    this.handler = handler;
    try {
      let textConfig: inputMethod.TextConfig = {
        inputAttribute: {
          textInputType: inputType,
          enterKeyType: enterType
        }
      };
      await this.inputMethodController.attach(true, textConfig);
      this.subscribe();
      this.attached = true;
      hilog.info(DOMAIN, TAG, 'attach OK');
    } catch (e) {
      this.attached = false;
      hilog.error(DOMAIN, TAG, 'attach failed: %{public}s', JSON.stringify(e));
    }
    return this.attached;
  }

  async detach(): Promise<boolean> {
    hilog.info(DOMAIN, TAG, 'detach');
    this.unsubscribe();
    try {
      await this.inputMethodController.detach();
      this.attached = false;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'detach failed: %{public}s', JSON.stringify(e));
    }
    return !this.attached;
  }

  showTextInput(): void {
    this.inputMethodController.showTextInput().catch((e: Object) => {
      hilog.error(DOMAIN, TAG, 'showTextInput failed: %{public}s', JSON.stringify(e));
    });
  }

  hideTextInput(): void {
    this.inputMethodController.hideTextInput().catch((e: Object) => {
      hilog.error(DOMAIN, TAG, 'hideTextInput failed: %{public}s', JSON.stringify(e));
    });
  }

  setCallingWindow(windowId: number): void {
    this.inputMethodController.setCallingWindow(windowId).catch((e: Object) => {
      hilog.error(DOMAIN, TAG, 'setCallingWindow failed: %{public}s', JSON.stringify(e));
    });
  }

  updateCursor(left: number, top: number, width: number, height: number): void {
    let cursorInfo: inputMethod.CursorInfo = { left: left, top: top, width: width, height: height };
    this.inputMethodController.updateCursor(cursorInfo).catch((e: Object) => {
      hilog.error(DOMAIN, TAG, 'updateCursor failed: %{public}s', JSON.stringify(e));
    });
  }

  changeSelection(text: string, start: number, end: number): void {
    this.inputMethodController.changeSelection(text, start, end).catch((e: Object) => {
      hilog.error(DOMAIN, TAG, 'changeSelection failed: %{public}s', JSON.stringify(e));
    });
  }

  stopInputSession(): void {
    this.inputMethodController.stopInputSession().catch((e: Object) => {
      hilog.error(DOMAIN, TAG, 'stopInputSession failed: %{public}s', JSON.stringify(e));
    });
  }

  showSoftKeyboard(): void {
    this.inputMethodController.showSoftKeyboard().catch((e: Object) => {
      hilog.error(DOMAIN, TAG, 'showSoftKeyboard failed: %{public}s', JSON.stringify(e));
    });
  }

  hideSoftKeyboard(): void {
    this.inputMethodController.hideSoftKeyboard().catch((e: Object) => {
      hilog.error(DOMAIN, TAG, 'hideSoftKeyboard failed: %{public}s', JSON.stringify(e));
    });
  }
}
