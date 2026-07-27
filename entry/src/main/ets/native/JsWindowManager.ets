/**
 * Simplified JsWindowManager + JsWindow for the QPA plugin.
 * Provides the window-management bridge that the QPA plugin expects
 * (getWindow / createWindow / getGeometry / setVisible / …) without
 * depending on adapter_ts or JsDataStore from the full Qt SDK template.
 */
import window from '@ohos.window';
import display from '@ohos.display';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'JsWinMgr';

export interface Margins {
  bottom: number;
  left: number;
  right: number;
  top: number;
}

// ── Simplified JsWindow ──────────────────────────────────────────────────
export class SimpleJsWindow {
  name: string;
  id: number = 0;
  private jsWindow: window.Window | undefined = undefined;
  private fullScreen: boolean = false;
  private maximized: boolean = false;
  private hasFrame: boolean = true;
  // Whether this is the main (stage) window – main window cannot be moved off-screen.
  private isMainWindow: boolean = false;
  // Callback to notify QPA plugin of geometry changes (triggers rendering).
  onGeometryChange: ((name: string, rect: window.Rect) => void) | undefined = undefined;
  // Callback to notify QPA plugin of window events (show/hide/activate/destroy).
  onWindowEvent: ((name: string, type: number) => void) | undefined = undefined;

  constructor(name: string, jsWindow: window.Window, isMain: boolean = false) {
    this.name = name;
    this.jsWindow = jsWindow;
    this.isMainWindow = isMain;
  }

  async startListener(): Promise<boolean> {
    try {
      this.jsWindow?.on('windowSizeChange', (size: window.Size) => {
        hilog.info(DOMAIN, TAG, '%{public}s size changed %{public}s', this.name, JSON.stringify(size));
        // Notify QPA plugin of geometry change so Qt can update rendering.
        this.notifyGeometryChange();
      });
      this.jsWindow?.on('windowEvent', (type: window.WindowEventType) => {
        hilog.info(DOMAIN, TAG, '%{public}s window event %{public}d', this.name, type);
        // Notify QPA plugin of window events (critical for rendering).
        if (this.onWindowEvent != undefined) {
          this.onWindowEvent(this.name, type);
        }
        if (type == window.WindowEventType.WINDOW_DESTROYED) {
          this.jsWindow = undefined;
        }
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'startListener failed: %{public}s', JSON.stringify(e));
    }
    return true;
  }

  isFullScreen(): boolean {
    return this.fullScreen;
  }

  getGeometry(): window.Rect | undefined {
    let p: window.WindowProperties | undefined = this.jsWindow?.getWindowProperties();
    // windowRect is already in physical pixels (matches XComponent surface).
    return p?.windowRect;
  }

  getMargins(): Margins {
    let m: Margins = { left: 0, top: 0, right: 0, bottom: 0 };
    if (!this.hasFrame || this.fullScreen) {
      return m;
    }
    return m;
  }

  async setGeometry(x: number, y: number, w: number, h: number): Promise<boolean> {
    hilog.info(DOMAIN, TAG, '%{public}s setGeometry %{public}d %{public}d %{public}d %{public}d', this.name, x, y, w, h);
    try {
      if (this.jsWindow != undefined) {
        await this.jsWindow.moveWindowTo(x, y);
        await this.jsWindow.resize(w, h);
      }
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setGeometry failed: %{public}s – notifying actual geometry', JSON.stringify(e));
      // Fallback: notify QPA of the actual window geometry so Qt can resize
      // correctly. This is critical for the main window which cannot be resized.
      this.notifyGeometryChange();
      return false;
    }
  }

  async setVisible(visible: boolean): Promise<boolean> {
    hilog.info(DOMAIN, TAG, '%{public}s setVisible %{public}s', this.name, String(visible));
    try {
      if (this.jsWindow != undefined) {
        if (visible) {
          await this.jsWindow.showWindow();
        } else {
          await this.hideWindow();
        }
      }
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setVisible failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  raise(): boolean { return true; }
  lower(): boolean { return true; }

  async hideWindow(): Promise<void> {
    // OpenHarmony has no window hide API.  The official Qt SDK template
    // moves the window off-screen to simulate hiding.  The main window
    // (stage window) must never be moved off-screen.
    if (this.isMainWindow) {
      hilog.info(DOMAIN, TAG, '%{public}s hideWindow skipped (main window)', this.name);
      return;
    }
    try {
      let d: display.Display = display.getDefaultDisplaySync();
      hilog.info(DOMAIN, TAG, '%{public}s hideWindow → move off-screen', this.name);
      await this.jsWindow?.moveWindowTo(d.width + 100, d.height + 100);
    } catch (e) {
      hilog.error(DOMAIN, TAG, '%{public}s hideWindow failed: %{public}s', this.name, JSON.stringify(e));
    }
  }

  async destroyWindow(): Promise<boolean> {
    hilog.info(DOMAIN, TAG, '%{public}s destroyWindow', this.name);
    try {
      await this.jsWindow?.destroyWindow();
      this.jsWindow = undefined;
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, '%{public}s destroyWindow failed: %{public}s', this.name, JSON.stringify(e));
      return false;
    }
  }

  getName(): string { return this.name; }
  getId(): number { return this.id; }
  setId(id: number): void { this.id = id; }

  getWindowId(): number | undefined {
    return this.jsWindow?.getWindowProperties().id;
  }

  isVisible(): boolean {
    if (this.jsWindow == undefined) { return false; }
    try {
      return this.jsWindow.isWindowShowing();
    } catch (e) {
      return false;
    }
  }

  getUIContext(): UIContext | undefined {
    return this.jsWindow?.getUIContext();
  }

  async showMaximized(): Promise<boolean> {
    try {
      hilog.info(DOMAIN, TAG, '%{public}s showMaximized', this.name);
      // For the main window (already fullscreen), just notify QPA of the
      // actual geometry.  Don't try to resize — it fails for stage windows.
      this.notifyGeometryChange();
      this.maximized = true;
      this.fullScreen = false;
      return true;
    } catch (e) {
      return false;
    }
  }

  async showFullScreen(): Promise<boolean> {
    try {
      await this.jsWindow?.setWindowLayoutFullScreen(true);
      await this.jsWindow?.setWindowSystemBarEnable([]);
      this.fullScreen = true;
      this.maximized = false;
      return true;
    } catch (e) {
      return false;
    }
  }

  async showMinimized(): Promise<boolean> {
    try {
      await this.jsWindow?.minimize();
      return true;
    } catch (e) {
      return false;
    }
  }

  async showNormal(): Promise<boolean> {
    try {
      await this.jsWindow?.showWindow();
      // Notify QPA plugin of geometry change (triggers rendering).
      this.notifyGeometryChange();
      this.fullScreen = false;
      this.maximized = false;
      return true;
    } catch (e) {
      return false;
    }
  }

  /** Notify QPA plugin of current window geometry (triggers rendering).
   * windowRect is already in physical pixels (matches XComponent surface). */
  private notifyGeometryChange(): void {
    if (this.onGeometryChange != undefined) {
      let p: window.WindowProperties | undefined = this.jsWindow?.getWindowProperties();
      if (p != undefined) {
        hilog.info(DOMAIN, TAG, '%{public}s notifyGeometryChange rect=%{public}s',
          this.name, JSON.stringify(p.windowRect));
        setTimeout((name: string, rect: window.Rect) => {
          this.onGeometryChange!(name, rect);
        }, 10, this.name, p.windowRect);
      }
    }
  }

  setHasFrame(hasFrame: boolean): void {
    this.hasFrame = hasFrame;
  }

  setWindowLimits(limits: window.WindowLimits): boolean {
    try {
      if (this.jsWindow != undefined) {
        this.jsWindow.setWindowLimits(limits);
      }
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setWindowLimits failed: %{public}s', JSON.stringify(e));
      return true;
    }
  }

  getXComponentController(): Object | undefined {
    // The QPA plugin uses this to get the XComponent surface for rendering.
    // For sub-windows created via createSubWindow, there's no XComponent yet.
    // Return undefined — the QPA plugin should handle this gracefully.
    return undefined;
  }

  async load(): Promise<void> {
    // Load pages/Index into the sub-window with idName = this window's name.
    // This creates an XComponent with id = name and libraryname = QPA plugin,
    // which triggers the QPA plugin's native OnSurfaceCreated callback.
    try {
      let store = new LocalStorage();
      store.setOrCreate('idName', this.name);
      let timeoutPromise = new Promise<void>((_, reject) => {
        setTimeout(() => reject(new Error('loadContent timeout 5s')), 5000);
      });
      await Promise.race([
        this.jsWindow!.loadContent('pages/Index', store),
        timeoutPromise
      ]);
      hilog.info(DOMAIN, TAG, '%{public}s loadContent (Index) done', this.name);
    } catch (e) {
      hilog.error(DOMAIN, TAG, '%{public}s loadContent failed: %{public}s', this.name, JSON.stringify(e));
    }
  }

  createSubWindow(name: string): SimpleJsWindow | undefined {
    return undefined;
  }
}

// ── Simplified JsWindowManager ───────────────────────────────────────────
export class SimpleJsWindowManager {
  private windows: Map<string, SimpleJsWindow> = new Map<string, SimpleJsWindow>();
  private windowStage: window.WindowStage | undefined = undefined;
  private mainWindow: SimpleJsWindow | undefined = undefined;
  // Callback to notify QPA plugin of geometry changes (set by OHPlotAbility).
  onGeometryChange: ((name: string, rect: window.Rect) => void) | undefined = undefined;
  // Callback to notify QPA plugin of window events (set by OHPlotAbility).
  onWindowEvent: ((name: string, type: number) => void) | undefined = undefined;

  constructor(windowStage?: window.WindowStage) {
    this.windowStage = windowStage;
  }

  setMainWindow(w: SimpleJsWindow): void {
    this.mainWindow = w;
  }

  getWindow(name: string): SimpleJsWindow | undefined {
    return this.windows.get(name);
  }

  addWindow(name: string, w: SimpleJsWindow): void {
    if (this.windows.has(name)) { return; }
    this.windows.set(name, w);
    w.setId(this.windows.size);
  }

  removeWindow(name: string): void {
    this.windows.delete(name);
  }

  async createWindow(name: string, title: string, isTopLevel: boolean,
    hasFocus: boolean, hasFrame: boolean, parentWindowName?: string): Promise<boolean> {
    hilog.info(DOMAIN, TAG, 'createWindow %{public}s top=%{public}s focus=%{public}s frame=%{public}s parent=%{public}s',
      name, String(isTopLevel), String(hasFocus), String(hasFrame), parentWindowName ?? 'none');
    try {
      if (this.windows.has(name)) { return false; }
      if (isTopLevel && this.windowStage != undefined) {
        // When a new popup/sub-window appears, hide all other visible popups
        // to enforce standard desktop behavior (one popup at a time).
        this.hideOtherPopups(name);
        // Create a real sub-window for the QPA plugin.
        let windowClass: window.Window = await this.windowStage.createSubWindow(name);
        let w: SimpleJsWindow = new SimpleJsWindow(name, windowClass);
        w.setHasFrame(false);
        w.onGeometryChange = this.onGeometryChange;
        w.onWindowEvent = this.onWindowEvent;
        this.addWindow(name, w);
        // Load pages/Index into the sub-window (creates XComponent for QPA rendering).
        await w.load();
        await windowClass.setWindowFocusable(hasFocus);
        hilog.info(DOMAIN, TAG, 'createWindow: sub-window "%{public}s" created', name);
      }
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'createWindow failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  async destroyWindow(name: string): Promise<boolean> {
    let w = this.windows.get(name);
    if (w == undefined) { return false; }
    hilog.info(DOMAIN, TAG, 'destroyWindow "%{public}s"', name);
    // Actually destroy the underlying OpenHarmony sub-window.
    await w.destroyWindow();
    this.windows.delete(name);
    return true;
  }

  /** Hide all visible sub-windows (popups/menus) except the given one.
   * Called when a new popup is shown to enforce standard desktop behavior:
   * only one popup visible at a time. */
  hideOtherPopups(exceptName: string): void {
    this.windows.forEach((w: SimpleJsWindow, name: string) => {
      if (name != exceptName && name != 'openharmony_qt_mainwindow' && w.isVisible()) {
        hilog.info(DOMAIN, TAG, 'auto-hiding popup "%{public}s" (new popup: "%{public}s")', name, exceptName);
        w.hideWindow();
      }
    });
  }
}
