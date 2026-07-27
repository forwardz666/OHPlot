// ArkSciDAVis Main Layout - overlays on top of XComponent (Qt render)
// Phase 1: XComponent remains visible as backup underneath
//
// CRITICAL EVENT FLOW:
// - MenuBar area: ArkTS handles menu clicks. No event passes to Qt.
// - Content area: HitTestMode.Transparent - touch events pass through to
//   the XComponent underneath, where QPA's native callbacks handle them.
//   Left-button events are also forwarded via NAPI sendMouse().
// - StatusBar area: ArkTS handles status display.
// - When a sub-menu is open, a transparent overlay catches external
//   clicks to close the menu, then passes the event through to Qt.
import { MenuBar } from '../components/MenuBar';
import { StatusBar } from '../components/StatusBar';
import { QtEventHost } from '../components/QtEventHost';
import { NoteEditor } from './NoteEditor';
import hilog from '@ohos.hilog';
import qohos from 'libqohos.so';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

interface QohosInjector {
  sendMouse(x: number, y: number, button: number, action: number): boolean;
}

const qtInjector = qohos as QohosInjector;

const DOMAIN: number = 0x0000;
const TAG: string = 'QtInput';

let leftDown: boolean = false;

interface SubMenuItemData {
  id: string;
  label: string;
  shortcut?: string;
  enabled?: boolean;
  checked?: boolean;
}

interface MenuItemData {
  id: string;
  label: string;
  items?: SubMenuItemData[];
}

// Payload for the generic 'menuAction' fallback command.
interface MenuActionArgs {
  itemId: string;
}

interface ActivateWindowArgs {
  name: string;
}

// openProject / saveProject command payload (both queued; completion is
// signalled by the projectSaved event handled in QtEventHost).
interface ProjectPathArgs {
  path: string;
}

// getUiState payload (see uiStateJson in scidavis/src/main.cpp)
interface UiWindow {
  name: string;
  type: string;
  label: string;
  status: number;
  active: boolean;
}

interface UiState {
  activeType: string;
  activeName: string;
  windows: UiWindow[];
  undoEnabled: boolean;
  redoEnabled: boolean;
}

interface UiStateResponse {
  success: boolean;
  data?: UiState;
}

@Component
export struct MainLayout {
  @State openMenu: string | null = null;
  @State showNotes: boolean = false;
  @State statusText: string = '';
  @State currentView: string = 'default';
  @State showImportDialog: boolean = false;
  @State showExportDialog: boolean = false;
  // Sandbox path of the current project file ('' = untitled).  The picker
  // flows copy external files in/out of the sandbox because Qt can only
  // reach sandbox paths, not content URIs.
  @State projectPath: string = '';
  // x offset (vp) of the floating dropdown, looked up from the anchor map
  // whenever a menu opens so it appears under its title.
  @State dropdownX: number = 0;
  private menuAnchorMap: Map<string, number> = new Map<string, number>();

  onMenuChanged(): void {
    if (this.openMenu !== null) {
      this.statusText = '[' + this.openMenu + ' menu open]';
      const x: number | undefined = this.menuAnchorMap.get(this.openMenu);
      this.dropdownX = (x !== undefined) ? x : 0;
      // Refresh backend UI state on every menu-open so greying/checkmarks
      // and the Windows list are current.  getUiState is a query command:
      // Qt answers via QueuedConnection with a 3s semaphore fallback, so
      // worst-case stall is bounded (normally single-digit ms when idle).
      this.refreshUiState();
    } else {
      this.statusText = '';
    }
  }

  aboutToAppear(): void {
    this.rebuildMenus(); // initial static skeleton before Qt is queried
  }

  private refreshUiState(): void {
    try {
      const raw: string = qtInjector.callQtCommand('getUiState', '{}');
      const resp: UiStateResponse = JSON.parse(raw) as UiStateResponse;
      if (resp.success && resp.data !== undefined) {
        this.uiState = resp.data;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getUiState failed: %{public}s', (e as Error).message);
    }
    this.rebuildMenus();
  }

  // Menu model is rebuilt from getUiState on every menu-open (desktop
  // parity: greyed = not yet wired on tablet / not applicable; the fourth
  // menu switches Table/Matrix/Graph with the active MDI window type).
  @State menuDefs: MenuItemData[] = [];
  @State uiState: UiState = {
    activeType: '', activeName: '', windows: [],
    undoEnabled: false, redoEnabled: false
  };

  private rebuildMenus(): void {
    const st: UiState = this.uiState;
    const hasWin: boolean = st.activeName !== '';
    const defs: MenuItemData[] = [];

    defs.push({ id: 'file', label: 'File', items: [
      { id: 'new_project', label: 'New Project' },
      { id: 'new_table', label: 'New Table' },
      { id: 'new_matrix', label: 'New Matrix' },
      { id: 'new_notes', label: 'New Note' },
      { id: 'new_graph', label: 'New Graph' },
      { id: 'sep1', label: '─' },
      { id: 'open', label: 'Open Project...', shortcut: 'Ctrl+O' },
      { id: 'save', label: 'Save Project', shortcut: 'Ctrl+S' },
      { id: 'save_as', label: 'Save Project As...' },
      { id: 'sep2', label: '─' },
      { id: 'import', label: 'Import ASCII...' },
      { id: 'export', label: 'Export ASCII...' },
      { id: 'sep3', label: '─' },
      { id: 'print', label: 'Print...', shortcut: 'Ctrl+P', enabled: false },
      { id: 'sep4', label: '─' },
      { id: 'quit', label: 'Quit', shortcut: 'Ctrl+Q' }
    ]});

    defs.push({ id: 'edit', label: 'Edit', items: [
      { id: 'undo', label: 'Undo', shortcut: 'Ctrl+Z', enabled: st.undoEnabled },
      { id: 'redo', label: 'Redo', shortcut: 'Ctrl+Y', enabled: st.redoEnabled },
      { id: 'sep1', label: '─' },
      { id: 'cut', label: 'Cut Selection', shortcut: 'Ctrl+X', enabled: hasWin },
      { id: 'copy', label: 'Copy Selection', shortcut: 'Ctrl+C', enabled: hasWin },
      { id: 'paste', label: 'Paste Selection', shortcut: 'Ctrl+V', enabled: hasWin },
      { id: 'delete', label: 'Delete Selection', enabled: hasWin },
      { id: 'sep2', label: '─' },
      { id: 'preferences', label: 'Preferences...', enabled: false }
    ]});

    defs.push({ id: 'view', label: 'View', items: [
      { id: 'plots', label: 'Plot List', checked: this.currentView === 'plots' },
      { id: 'tables', label: 'Table List', checked: this.currentView === 'tables' },
      { id: 'notes', label: 'Note Pad', checked: this.showNotes },
      { id: 'sep1', label: '─' },
      { id: 'log', label: 'Results Log', enabled: false },
      { id: 'script_console', label: 'Script Console', enabled: false }
    ]});

    // Context menu follows the active MDI window type (desktop behaviour).
    // Entries are greyed until their Phase 2/3 commands land.
    if (st.activeType === 'Matrix') {
      defs.push({ id: 'matrix', label: 'Matrix', items: [
        { id: 'set_dimensions', label: 'Set Dimensions...', enabled: false },
        { id: 'set_values', label: 'Set Values...', enabled: false },
        { id: 'sep1', label: '─' },
        { id: 'transpose', label: 'Transpose', enabled: false },
        { id: 'invert', label: 'Invert', enabled: false }
      ]});
    } else if (st.activeType === 'MultiLayer' || st.activeType === 'Graph3D') {
      defs.push({ id: 'graph', label: 'Graph', items: [
        { id: 'add_curve', label: 'Add/Remove Curve...', enabled: false },
        { id: 'add_error_bars', label: 'Add Error Bars...', enabled: false },
        { id: 'add_function', label: 'Add Function...', enabled: false },
        { id: 'sep1', label: '─' },
        { id: 'rescale', label: 'Rescale To Show All', enabled: false }
      ]});
    } else {
      defs.push({ id: 'table', label: 'Table', items: [
        { id: 'add_columns', label: 'Add Column', enabled: false },
        { id: 'set_values', label: 'Set Column Values...', enabled: false },
        { id: 'sort', label: 'Sort Table...', enabled: false },
        { id: 'sep1', label: '─' },
        { id: 'statistics_columns', label: 'Statistics on Columns', enabled: false },
        { id: 'statistics_rows', label: 'Statistics on Rows', enabled: false }
      ]});
    }

    defs.push({ id: 'plot', label: 'Plot', items: [
      { id: 'plot_line', label: 'Line', enabled: false },
      { id: 'plot_scatter', label: 'Scatter', enabled: false },
      { id: 'plot_line_symbol', label: 'Line + Symbol', enabled: false },
      { id: 'plot_bar', label: 'Vertical Bars', enabled: false },
      { id: 'plot_histogram', label: 'Histogram', enabled: false },
      { id: 'plot_pie', label: 'Pie', enabled: false },
      { id: 'sep1', label: '─' },
      { id: 'plot_2d', label: 'Plot Explorer (2D)' },
      { id: 'plot_3d', label: '3D Plot', enabled: false }
    ]});

    defs.push({ id: 'analysis', label: 'Analysis', items: [
      { id: 'fit_linear', label: 'Fit Linear', enabled: false },
      { id: 'fit_poly', label: 'Fit Polynomial...', enabled: false },
      { id: 'fit_wizard', label: 'Fit Wizard...', enabled: false },
      { id: 'sep1', label: '─' },
      { id: 'fft', label: 'FFT...', enabled: false },
      { id: 'smooth', label: 'Smooth', enabled: false },
      { id: 'interpolate', label: 'Interpolate...', enabled: false },
      { id: 'differentiate', label: 'Differentiate', enabled: false },
      { id: 'integrate', label: 'Integrate...', enabled: false }
    ]});

    // Windows menu: management commands + live MDI window list from Qt.
    const winItems: SubMenuItemData[] = [
      { id: 'cascade', label: 'Cascade' },
      { id: 'maximize_window', label: 'Maximize Window', enabled: hasWin },
      { id: 'minimize_window', label: 'Minimize Window', enabled: hasWin },
      { id: 'close_window', label: 'Close Window', shortcut: 'Ctrl+W', enabled: hasWin }
    ];
    if (st.windows.length > 0) {
      winItems.push({ id: 'sep1', label: '─' });
      for (let i = 0; i < st.windows.length; i++) {
        const w: UiWindow = st.windows[i];
        winItems.push({ id: 'win:' + w.name, label: w.name + ' (' + w.type + ')', checked: w.active });
      }
    }
    defs.push({ id: 'windows', label: 'Windows', items: winItems });

    defs.push({ id: 'help', label: 'Help', items: [
      { id: 'help', label: 'Help Browser', enabled: false },
      { id: 'sep1', label: '─' },
      { id: 'about', label: 'About SciDAVis' }
    ]});

    this.menuDefs = defs;
  }
  
  // NAPI defensive-programming spec (HARNESS guide §3.3): every callQtCommand
  // must be wrapped in try-catch — a failed dlsym/route otherwise throws an
  // uncaught exception that kills the ArkTS UI thread.
  onMenuItemClick(itemId: string): void {
    hilog.info(DOMAIN, TAG, 'MainLayout menu click: %{public}s', itemId);
    try {
      this.dispatchMenuItem(itemId);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'menuAction failed for %{public}s: %{public}s',
        itemId, (e as Error).message);
    }
  }

  private dispatchMenuItem(itemId: string): void {
    // Windows menu dynamic entries: 'win:<name>' activates that subwindow.
    if (itemId.startsWith('win:')) {
      const result: string = qtInjector.callQtCommand('activateWindow',
        JSON.stringify({ name: itemId.substring(4) } as ActivateWindowArgs));
      hilog.info(DOMAIN, TAG, 'activateWindow result: %{public}s', result);
      return;
    }
    switch (itemId) {
      case 'new_table': {
        const result: string = qtInjector.callQtCommand('newTable', '{}');
        hilog.info(DOMAIN, TAG, 'newTable result: %{public}s', result);
        break;
      }
      case 'import':
        this.showImportDialog = true;
        break;
      case 'open':
        this.openProjectViaPicker();
        break;
      case 'save':
        this.saveProjectToSandbox();
        break;
      case 'save_as':
        this.saveProjectAsViaPicker();
        break;
      case 'export':
        this.showExportDialog = true;
        break;
      case 'tables':
        this.currentView = (this.currentView === 'tables') ? 'default' : 'tables';
        break;
      case 'plots':
        this.currentView = (this.currentView === 'plots') ? 'default' : 'plots';
        break;
      case 'notes':
        this.showNotes = !this.showNotes;
        break;
      case 'plot_2d':
        this.currentView = 'plots';
        break;
      case 'quit':
        // In offscreen mode, just log
        hilog.info(DOMAIN, TAG, 'Quit requested - would shut down Qt');
        break;
      default: {
        // Fallback: route unhandled items to Qt so the backend can decide
        // (HARNESS guide P1 — users expect a real response, not just a log).
        const result: string = qtInjector.callQtCommand('menuAction',
          JSON.stringify({ itemId: itemId } as MenuActionArgs));
        hilog.info(DOMAIN, TAG, 'fallback menuAction(%{public}s): %{public}s', itemId, result);
        break;
      }
    }
  }

  // ── Project open/save (Phase 2) ──────────────────────────────────────
  // Qt only reaches sandbox paths, so the pickers copy files in/out.

  private sandboxProjectDir(): string {
    const ctx = getContext(this) as common.UIAbilityContext;
    return ctx.filesDir;
  }

  private async openProjectViaPicker(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      opts.fileSuffixFilters = ['.sciprj', '.gz'];
      const uris: string[] = await docPicker.select(opts);
      if (uris.length === 0) {
        return; // user cancelled
      }
      const uri: string = uris[0];
      let name: string = decodeURIComponent(uri.substring(uri.lastIndexOf('/') + 1));
      if (name === '') {
        name = 'project.sciprj';
      }
      const dest: string = this.sandboxProjectDir() + '/' + name;
      const src = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      fs.copyFileSync(src.fd, dest);
      fs.closeSync(src);
      this.projectPath = dest;
      const result: string = qtInjector.callQtCommand('openProject',
        JSON.stringify({ path: dest } as ProjectPathArgs));
      hilog.info(DOMAIN, TAG, 'openProject(%{public}s): %{public}s', dest, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'openProjectViaPicker failed: %{public}s', (e as Error).message);
    }
  }

  // Save to the current sandbox project file (untitled.sciprj when new).
  // saveProject is a QUEUED command: saving calls back into the JS thread
  // via the QPA, so a blocking query would deadlock (device-verified 3s
  // timeout).  Completion arrives as the 'projectSaved' event, handled in
  // QtEventHost (which also performs the pending save-as copy-out).
  private saveProjectToSandbox(): string {
    const dest: string = this.projectPath !== ''
      ? this.projectPath
      : this.sandboxProjectDir() + '/untitled.sciprj';
    this.projectPath = dest;
    const result: string = qtInjector.callQtCommand('saveProject',
      JSON.stringify({ path: dest } as ProjectPathArgs));
    hilog.info(DOMAIN, TAG, 'saveProject(%{public}s) queued: %{public}s', dest, result);
    return dest;
  }

  private async saveProjectAsViaPicker(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker();
      const opts = new picker.DocumentSaveOptions();
      const current: string = this.projectPath !== ''
        ? this.projectPath.substring(this.projectPath.lastIndexOf('/') + 1)
        : 'untitled.sciprj';
      opts.newFileNames = [current];
      const uris: string[] = await docPicker.save(opts);
      if (uris.length === 0) {
        return; // user cancelled
      }
      // Stash the picker target; QtEventHost copies the sandbox file out
      // when the queued save completes (projectSaved event with ok=true).
      AppStorage.setOrCreate<string>('pendingSaveAsUri', uris[0]);
      const dest: string = this.saveProjectToSandbox();
      hilog.info(DOMAIN, TAG, 'save_as pending: %{public}s -> %{public}s', dest, uris[0]);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'saveProjectAsViaPicker failed: %{public}s', (e as Error).message);
    }
  }
  
  build() {
    Stack() {
      // Layer 1 (bottom): XComponent lives BELOW this Stack.
      // This is the Qt rendering surface - events must pass through to it.

      // Layer 2: Main layout with menu bar, content area, status bar
      Column() {
        // Menu bar
        MenuBar({
          openMenu: this.openMenu,
          menus: this.menuDefs
        })

        // Content area: transparent - events pass through to XComponent
        Column()
          .layoutWeight(1)
          .hitTestBehavior(HitTestMode.Transparent)
          .onTouch((event: TouchEvent) => {
            // Forward touch events (left-button clicks converted by ArkUI)
            // as mouse events to Qt via NAPI
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
          .onMouse((event: MouseEvent) => {
            // Forward left-button drag
            if (event.button === MouseButton.Left && event.action === MouseAction.Move && leftDown) {
              qtInjector.sendMouse(event.x, event.y, 1, 2);
            }
          })

        // Status bar
        StatusBar({ statusText: this.statusText })
      }

      // Layer 3 (top): External-click overlay to close sub-menus.
      // Only shown when a sub-menu is open.
      // HitTestMode.Transparent: we catch the touch to close the menu,
      // then let the event pass through to the XComponent (Qt).
      if (this.openMenu !== null) {
        Column()
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.Transparent)
          .onTouch(() => {
            this.openMenu = null;
          })
      }

      // Floating dropdown menu: rendered at Stack level (NOT inside the
      // Column) so opening it does not reflow/push the content area down.
      // .position() is applied HERE (Stack child) so x/y are relative to
      // the Stack's top-left, anchoring the panel under its menu title.
      DropdownMenu({
        openMenu: this.openMenu,
        menus: this.menuDefs,
        onItemClick: (itemId: string) => this.onMenuItemClick(itemId)
      })
        .position({ x: this.dropdownX, y: MENUBAR_HEIGHT_VP })

      // Note editor overlay
      if (this.showNotes) {
        NoteEditor()
      }

      // Dialogs
      ImportDialog({ isVisible: $showImportDialog })
      ExportDialog({ isVisible: $showExportDialog })

      // Qt backend event host: renders ArkUI replacements for QMessageBox /
      // context menus / combo popups pushed via scidavis_emit → onQtEvent.
      // Fully hit-test transparent while no overlay is visible.
      QtEventHost()

      // No external overlay: touching the content area closes the menu
      // and forwards events to Qt. The dropdown menu area is handled
      // directly by the MenuBar component.
    }
    .width('100%')
    .height('100%')
  }
}
