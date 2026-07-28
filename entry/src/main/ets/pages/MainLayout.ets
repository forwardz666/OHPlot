// OHPlot Main Layout - overlays on top of XComponent (Qt render)
// Phase 1: XComponent remains visible as backup underneath
//
// CRITICAL EVENT FLOW (device-verified 2026-07-27 via InputProbe src= field):
// - Finger touches: the QPA touch pipeline delivers them natively and Qt
//   synthesizes mouse events itself (src=2).  The overlay ALSO forwards
//   them (src=3) because TouchEvent.source/sourceTool cannot distinguish
//   finger from mouse-converted touches (both report TouchScreen/Finger).
//   The resulting double delivery is deduplicated in Qt (InputProbe).
// - Bluetooth LEFT clicks: ArkUI re-routes them into the touch pipeline;
//   the QPA plugin drops them, so only the forwarded copy reaches Qt.
// - Bluetooth RIGHT/MIDDLE clicks: ArkUI onMouse on the outer Stack catches
//   these and forwards via sendMouse → scidavis_inject_mouse → Qt.
// - MenuBar area: ArkTS handles all menu UI natively.
// - Content area: HitTestMode.Transparent lets events pass through to
//   the XComponent underneath for native QPA processing.
// - StatusBar area: ArkTS handles status display.
// - WARNING: Do NOT forward touch events via sendMouse — the QPA plugin
//   already handles them natively.  Forwarding duplicates causes crashes.
import { MenuBar, DropdownMenu } from '../components/MenuBar';
import { ToolBar } from '../components/ToolBar';
import { StatusBar } from '../components/StatusBar';
import { QtEventHost } from '../components/QtEventHost';
import { NoteEditor } from './NoteEditor';
import { TablePage } from './TablePage';
import { PlotPage } from './PlotPage';
import { ImportDialog } from './dialogs/ImportDialog';
import { ExportDialog } from './dialogs/ExportDialog';
import { AddColumnsDialog, SetColumnValuesDialog, SortTableDialog } from './dialogs/TableOpsDialog';
import { Plot2DDialog } from './dialogs/Plot2DDialog';
import { MatrixDimensionsDialog, MatrixValuesDialog } from './dialogs/MatrixOpsDialog';
import { AnalysisDialog, CorrelateDialog } from './dialogs/AnalysisDialog';
import { PreferencesDialog } from './dialogs/PreferencesDialog';
import { ScriptConsoleDialog } from './dialogs/ScriptConsoleDialog';
import { GraphPropsDialog } from './dialogs/GraphPropsDialog';
import { ProjectTree } from '../components/ProjectTree';
import hilog from '@ohos.hilog';
import qohos from 'libqohos.so';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import pasteboard from '@ohos.pasteboard';
import common from '@ohos.app.ability.common';

interface QohosInjector {
  sendMouse(x: number, y: number, button: number, action: number): boolean;
  callQtCommand(cmd: string, argsJson: string): string;
}

const qtInjector = qohos as QohosInjector;

const DOMAIN: number = 0x0000;
const TAG: string = 'QtInput';

// ArkTS chrome bands that must NOT be forwarded to Qt (vp).  A forwarded
// tap on the Qt menu bar (hidden underneath the ArkTS one) makes Qt call
// QMenu::popup() → QPA window creation → SIGSEGV: the alpha_v6 plugin
// supports only the single main XComponent window (device crash log
// cppcrash-...-20260727151314, QOpenHarmonyJsObject::getJsFunction).
const MENUBAR_HEIGHT_VP: number = 28;
// Menu bar (28) + ArkTS toolbar (32): the whole top chrome band that must
// never be forwarded to Qt (the hidden Qt menu bar/toolbars sit underneath).
const TOP_CHROME_VP: number = 60;
const STATUSBAR_HEIGHT_VP: number = 24;

// Mirror of the Qt-side menuAction whitelist (main.cpp command registry).
// menuAction is a *mutation* command: scidavis_call queues it and returns
// {"success":true,"queued":true} immediately, so the Qt-side "unsupported"
// error can never reach ETS through the return value.  Unadapted items must
// therefore be gated here, before calling Qt.  Keep in sync with main.cpp.
const MENU_ACTION_SUPPORTED: string[] = [
  'new_notes', 'new_matrix', 'new_project', 'new_graph',
  'cascade', 'maximize_window', 'minimize_window', 'close_window',
  'about', 'undo', 'redo', 'cut', 'copy', 'paste', 'delete'
];

let leftDown: boolean = false;

let dbgCount: number = 0;

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

// Result envelope returned by callQtCommand for menuAction.
interface CmdResult {
  success: boolean;
  error?: string;
}

// tableStatistics command payload (queued; result toast via event channel).
interface TableStatisticsArgs {
  tableId: string;
  type: string;
}

// setClipboardText payload (Phase 2 clipboard bridge, OHOS → Qt).
interface SetClipboardArgs {
  text: string;
}

// matrixTranspose / matrixInvert payload (Phase 3).
interface MatrixIdArgs {
  matrixId: string;
}

// exportGraphImage payload (Phase 3).
interface ExportImageArgs {
  plotId: string;
  path: string;
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
  @State @Watch('onMenuChanged') openMenu: string | null = null;
  @State showNotes: boolean = false;
  @State statusText: string = '';
  @State currentView: string = 'default';
  @State showImportDialog: boolean = false;
  @State showExportDialog: boolean = false;
  // Table-operation dialogs (Phase 2); tableOpsTarget is the active table
  // captured at menu-dispatch time (uiState refreshes on every menu-open).
  @State showAddColsDialog: boolean = false;
  @State showSetValuesDialog: boolean = false;
  @State showSortDialog: boolean = false;
  @State tableOpsTarget: string = '';
  // 2D plot dialog (Phase 2): plotTypeSel is the plot2D type id chosen
  // from the Plot menu, captured at dispatch time like tableOpsTarget.
  @State showPlotDialog: boolean = false;
  @State plotTypeSel: string = 'line';
  // Matrix-operation dialogs (Phase 3), same AppStorage target pattern.
  @State showMatrixDimsDialog: boolean = false;
  @State showMatrixValuesDialog: boolean = false;
  // Analysis dialogs (Phase 3): analysisOpSel is the analyzeCurve op the
  // menu picked (also mirrored to AppStorage for the @Prop-timing gap).
  @State showAnalysisDialog: boolean = false;
  @State analysisOpSel: string = 'fit_linear';
  @State showCorrelateDialog: boolean = false;
  // Results Log panel (View menu): text accumulated from resultsLog
  // events by QtEventHost via AppStorage.
  @State showResultsLog: boolean = false;
  @StorageProp('resultsLog') resultsLogText: string = '';
  // Project browser sidebar (Phase 3): tree from getProjectTree; the tick
  // bumps on every uiState refresh so the tree stays current.
  @State showProjectTree: boolean = false;
  @State projectTreeTick: number = 0;
  // Phase 3 dialogs living outside the isVisible pattern: these are
  // @CustomDialog structs, driven by controllers.
  private prefsDialogCtl: CustomDialogController = new CustomDialogController({
    builder: PreferencesDialog(), autoCancel: true
  });
  private scriptConsoleCtl: CustomDialogController = new CustomDialogController({
    builder: ScriptConsoleDialog(), autoCancel: true
  });
  private graphPropsCtl: CustomDialogController = new CustomDialogController({
    builder: GraphPropsDialog(), autoCancel: true
  });
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
      if (this.showProjectTree) {
        this.projectTreeTick++; // keep the sidebar tree in sync
      }
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
        // Greying debug trail: activeType drives isTable/isGraph on the
        // toolbar; log it so device runs can prove what ETS received.
        hilog.info(DOMAIN, TAG, 'uiState: type=%{public}s name=%{public}s undo=%{public}s',
          resp.data.activeType, resp.data.activeName, String(resp.data.undoEnabled));
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
      { id: 'preferences', label: 'Preferences...' }
    ]});

    defs.push({ id: 'view', label: 'View', items: [
      { id: 'project_browser', label: 'Project Browser', checked: this.showProjectTree },
      { id: 'plots', label: 'Plot List', checked: this.currentView === 'plots' },
      { id: 'tables', label: 'Table List', checked: this.currentView === 'tables' },
      { id: 'notes', label: 'Note Pad', checked: this.showNotes },
      { id: 'sep1', label: '─' },
      { id: 'log', label: 'Results Log', checked: this.showResultsLog },
      { id: 'script_console', label: 'Script Console' }
    ]});

    // Context menu follows the active MDI window type (desktop behaviour).
    // Entries are greyed until their Phase 2/3 commands land.
    if (st.activeType === 'Matrix') {
      defs.push({ id: 'matrix', label: 'Matrix', items: [
        { id: 'set_dimensions', label: 'Set Dimensions...' },
        { id: 'set_values', label: 'Set Values...' },
        { id: 'sep1', label: '─' },
        { id: 'transpose', label: 'Transpose' },
        { id: 'invert', label: 'Invert' }
      ]});
    } else if (st.activeType === 'MultiLayer' || st.activeType === 'Graph3D') {
      defs.push({ id: 'graph', label: 'Graph', items: [
        { id: 'graph_props', label: 'Properties...', enabled: st.activeType === 'MultiLayer' },
        { id: 'export_image', label: 'Export Image...', enabled: st.activeType === 'MultiLayer' },
        { id: 'sep0', label: '─' },
        { id: 'add_curve', label: 'Add/Remove Curve...', enabled: false },
        { id: 'add_error_bars', label: 'Add Error Bars...', enabled: false },
        { id: 'add_function', label: 'Add Function...', enabled: false },
        { id: 'sep1', label: '─' },
        { id: 'rescale', label: 'Rescale To Show All', enabled: false }
      ]});
    } else {
      const isTable: boolean = st.activeType === 'Table';
      defs.push({ id: 'table', label: 'Table', items: [
        { id: 'add_columns', label: 'Add Columns...', enabled: isTable },
        { id: 'set_values', label: 'Set Column Values...', enabled: isTable },
        { id: 'sort', label: 'Sort Table...', enabled: isTable },
        { id: 'sep1', label: '─' },
        { id: 'statistics_columns', label: 'Statistics on Columns', enabled: isTable },
        { id: 'statistics_rows', label: 'Statistics on Rows', enabled: isTable }
      ]});
    }

    // Plot menu mirrors the desktop 2D types; every entry funnels into the
    // Plot2DDialog (column picker) → queued plot2D backend command.
    const isTablePlot: boolean = st.activeType === 'Table';
    defs.push({ id: 'plot', label: 'Plot', items: [
      { id: 'plot_line', label: 'Line', enabled: isTablePlot },
      { id: 'plot_scatter', label: 'Scatter', enabled: isTablePlot },
      { id: 'plot_line_symbol', label: 'Line + Symbol', enabled: isTablePlot },
      { id: 'plot_vertical_bars', label: 'Vertical Bars', enabled: isTablePlot },
      { id: 'plot_horizontal_bars', label: 'Horizontal Bars', enabled: isTablePlot },
      { id: 'plot_area', label: 'Area', enabled: isTablePlot },
      { id: 'plot_pie', label: 'Pie', enabled: isTablePlot },
      { id: 'sep0', label: '─' },
      { id: 'plot_drop_lines', label: 'Vertical Drop Lines', enabled: isTablePlot },
      { id: 'plot_spline', label: 'Spline', enabled: isTablePlot },
      { id: 'plot_vertical_steps', label: 'Vertical Steps', enabled: isTablePlot },
      { id: 'plot_horizontal_steps', label: 'Horizontal Steps', enabled: isTablePlot },
      { id: 'sep0b', label: '─' },
      { id: 'plot_histogram', label: 'Histogram', enabled: isTablePlot },
      { id: 'plot_box', label: 'Box Plot', enabled: isTablePlot },
      { id: 'sep1', label: '─' },
      { id: 'plot_2d', label: 'Plot Explorer (2D)' },
      { id: 'plot_3d', label: '3D Plot', enabled: false }
    ]});

    // Analysis menu mirrors the desktop: curve analyses need an active
    // 2D plot, correlation runs on a table's columns.
    const isPlotWin: boolean = st.activeType === 'MultiLayer';
    defs.push({ id: 'analysis', label: 'Analysis', items: [
      { id: 'an_fit_linear', label: 'Fit Linear', enabled: isPlotWin },
      { id: 'an_fit_poly', label: 'Fit Polynomial...', enabled: isPlotWin },
      { id: 'an_fit_gauss', label: 'Fit Gaussian', enabled: isPlotWin },
      { id: 'an_fit_lorentz', label: 'Fit Lorentzian', enabled: isPlotWin },
      { id: 'an_fit_sigmoidal', label: 'Fit Boltzmann (Sigmoidal)', enabled: isPlotWin },
      { id: 'sep1', label: '─' },
      { id: 'an_fft', label: 'FFT...', enabled: isPlotWin },
      { id: 'an_fft_filter', label: 'FFT Filter...', enabled: isPlotWin },
      { id: 'an_smooth', label: 'Smooth...', enabled: isPlotWin },
      { id: 'an_interpolate', label: 'Interpolate...', enabled: isPlotWin },
      { id: 'an_differentiate', label: 'Differentiate', enabled: isPlotWin },
      { id: 'an_integrate', label: 'Integrate', enabled: isPlotWin },
      { id: 'sep2', label: '─' },
      { id: 'correlate', label: 'Correlate...', enabled: st.activeType === 'Table' }
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
      { id: 'about', label: 'About OHPlot' }
    ]});

    this.menuDefs = defs;
  }
  
  // Unified "not adapted yet" notice (menu + toolbar): an AlertDialog per
  // spec — silent no-ops and toasts are both forbidden for unadapted items.
  private showNotAdapted(): void {
    this.getUIContext().showAlertDialog({
      message: $r('app.string.not_adapted'),
      confirm: {
        value: '确定',
        action: () => {}
      }
    });
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
      case 'new_project': {
        const self = this;
        this.getUIContext().showAlertDialog({
          title: 'New Project',
          message: '当前项目中未保存的内容将丢失。确定新建项目？',
          primaryButton: {
            value: '取消',
            action: () => {}
          },
          secondaryButton: {
            value: '确定',
            fontColor: Color.Red,
            action: () => {
              const result: string = qtInjector.callQtCommand('menuAction',
                JSON.stringify({ itemId: 'new_project' } as MenuActionArgs));
              hilog.info(DOMAIN, TAG, 'new_project result: %{public}s', result);
              self.projectPath = '';
              self.refreshUiState();
            }
          }
        });
        break;
      }
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
      case 'add_columns':
        this.tableOpsTarget = this.uiState.activeName;
        AppStorage.setOrCreate<string>('tableOpsTarget', this.tableOpsTarget);
        this.showAddColsDialog = true;
        break;
      case 'set_values':
        this.tableOpsTarget = this.uiState.activeName;
        AppStorage.setOrCreate<string>('tableOpsTarget', this.tableOpsTarget);
        if (this.uiState.activeType === 'Matrix') {
          this.showMatrixValuesDialog = true;
        } else {
          this.showSetValuesDialog = true;
        }
        break;
      case 'set_dimensions':
        this.tableOpsTarget = this.uiState.activeName;
        AppStorage.setOrCreate<string>('tableOpsTarget', this.tableOpsTarget);
        this.showMatrixDimsDialog = true;
        break;
      case 'transpose':
      case 'invert': {
        const cmd: string = itemId === 'invert' ? 'matrixInvert' : 'matrixTranspose';
        const result: string = qtInjector.callQtCommand(cmd,
          JSON.stringify({ matrixId: this.uiState.activeName } as MatrixIdArgs));
        hilog.info(DOMAIN, TAG, '%{public}s queued: %{public}s', cmd, result);
        break;
      }
      case 'export_image':
        this.exportImageViaPicker();
        break;
      case 'sort':
        this.tableOpsTarget = this.uiState.activeName;
        AppStorage.setOrCreate<string>('tableOpsTarget', this.tableOpsTarget);
        this.showSortDialog = true;
        break;
      case 'statistics_columns':
      case 'statistics_rows': {
        // No parameters needed; queued command, result toast via events.
        const result: string = qtInjector.callQtCommand('tableStatistics',
          JSON.stringify({
            tableId: this.uiState.activeName,
            type: itemId === 'statistics_rows' ? 'rows' : 'columns'
          } as TableStatisticsArgs));
        hilog.info(DOMAIN, TAG, '%{public}s queued: %{public}s', itemId, result);
        break;
      }
      case 'tables':
        this.currentView = (this.currentView === 'tables') ? 'default' : 'tables';
        break;
      case 'plots':
        this.currentView = (this.currentView === 'plots') ? 'default' : 'plots';
        break;
      case 'notes':
        this.showNotes = !this.showNotes;
        break;
      case 'log':
        this.showResultsLog = !this.showResultsLog;
        break;
      case 'project_browser':
        this.showProjectTree = !this.showProjectTree;
        if (this.showProjectTree) {
          this.projectTreeTick++;
        }
        break;
      case 'preferences':
        this.prefsDialogCtl.open();
        break;
      case 'script_console':
        this.scriptConsoleCtl.open();
        break;
      case 'graph_props':
        this.graphPropsCtl.open();
        break;
      case 'plot_2d':
        this.currentView = 'plots';
        break;
      case 'plot_line':
      case 'plot_scatter':
      case 'plot_line_symbol':
      case 'plot_vertical_bars':
      case 'plot_horizontal_bars':
      case 'plot_area':
      case 'plot_pie':
      case 'plot_drop_lines':
      case 'plot_spline':
      case 'plot_vertical_steps':
      case 'plot_horizontal_steps':
      case 'plot_histogram':
      case 'plot_box': {
        // Same @Prop-timing workaround as the table-ops dialogs: store
        // target/type in AppStorage synchronously before opening.
        this.tableOpsTarget = this.uiState.activeName;
        this.plotTypeSel = itemId.substring(5); // strip 'plot_'
        AppStorage.setOrCreate<string>('tableOpsTarget', this.tableOpsTarget);
        AppStorage.setOrCreate<string>('plotType', this.plotTypeSel);
        this.showPlotDialog = true;
        break;
      }
      case 'an_fit_linear':
      case 'an_fit_poly':
      case 'an_fit_gauss':
      case 'an_fit_lorentz':
      case 'an_fit_sigmoidal':
      case 'an_fft':
      case 'an_fft_filter':
      case 'an_smooth':
      case 'an_interpolate':
      case 'an_differentiate':
      case 'an_integrate': {
        // One dialog for the whole Analysis menu: curve picker + the
        // parameters the chosen op needs (analyzeCurve backend command).
        this.analysisOpSel = itemId.substring(3); // strip 'an_'
        AppStorage.setOrCreate<string>('analysisOp', this.analysisOpSel);
        this.showAnalysisDialog = true;
        break;
      }
      case 'correlate':
        this.tableOpsTarget = this.uiState.activeName;
        AppStorage.setOrCreate<string>('tableOpsTarget', this.tableOpsTarget);
        this.showCorrelateDialog = true;
        break;
      case 'paste':
        // Clipboard bridge: pull the OHOS system pasteboard into the Qt
        // clipboard first, then dispatch the paste (both queued → FIFO
        // order on the Qt thread is guaranteed).
        this.pasteWithSystemClipboard();
        break;
      case 'quit':
        hilog.info(DOMAIN, TAG, 'Quit requested - terminating ability');
        (getContext(this) as common.UIAbilityContext).terminateSelf();
        break;
      default: {
        // Unadapted item: the queued menuAction reply cannot tell us (see
        // MENU_ACTION_SUPPORTED above), so gate on the local whitelist.
        if (MENU_ACTION_SUPPORTED.indexOf(itemId) < 0) {
          hilog.info(DOMAIN, TAG, 'not adapted: %{public}s', itemId);
          this.showNotAdapted();
          break;
        }
        // Fallback: route whitelisted items to Qt so the backend can decide
        // (HARNESS guide P1 — users expect a real response, not just a log).
        const result: string = qtInjector.callQtCommand('menuAction',
          JSON.stringify({ itemId: itemId } as MenuActionArgs));
        hilog.info(DOMAIN, TAG, 'fallback menuAction(%{public}s): %{public}s', itemId, result);
        try {
          const resp: CmdResult = JSON.parse(result) as CmdResult;
          if (resp.success === false) {
            // Belt-and-braces: synchronous failures (e.g. Qt not running)
            // still surface the same unified notice.
            this.showNotAdapted();
          }
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'fallback parse failed: %{public}s', (e as Error).message);
        }
        break;
      }
    }
  }

  // ── Project open/save (Phase 2) ──────────────────────────────────────
  // Qt only reaches sandbox paths, so the pickers copy files in/out.

  // ── Clipboard bridge (Phase 2) ─────────────────────────────────
  // Qt → OHOS runs through the clipboardChanged event (QtEventHost).
  private async pasteWithSystemClipboard(): Promise<void> {
    try {
      const data: pasteboard.PasteData = await pasteboard.getSystemPasteboard().getData();
      const text: string = data.getPrimaryText();
      if (text !== null && text !== undefined && text !== '') {
        qtInjector.callQtCommand('setClipboardText',
          JSON.stringify({ text: text } as SetClipboardArgs));
      }
    } catch (e) {
      // Empty/non-text pasteboard throws — fall through to Qt's own clipboard.
      hilog.info(DOMAIN, TAG, 'pasteboard read skipped: %{public}s', (e as Error).message);
    }
    const result: string = qtInjector.callQtCommand('menuAction',
      JSON.stringify({ itemId: 'paste' } as MenuActionArgs));
    hilog.info(DOMAIN, TAG, 'paste dispatched: %{public}s', result);
  }

  // ── Graph image export (Phase 3) ──────────────────────────────
  // Same picker/copy-out pattern as ExportDialog: render into the sandbox,
  // then the imageExported event copies the file to the picked URI.
  private async exportImageViaPicker(): Promise<void> {
    const plotId: string = this.uiState.activeName;
    if (plotId === '') {
      return;
    }
    try {
      const docPicker = new picker.DocumentViewPicker();
      const opts = new picker.DocumentSaveOptions();
      opts.newFileNames = [plotId + '.png'];
      const uris: string[] = await docPicker.save(opts);
      if (uris.length === 0) {
        return; // user cancelled
      }
      AppStorage.setOrCreate<string>('pendingImageUri', uris[0]);
      const dest: string = this.sandboxProjectDir() + '/' + plotId + '.png';
      const result: string = qtInjector.callQtCommand('exportGraphImage',
        JSON.stringify({ plotId: plotId, path: dest } as ExportImageArgs));
      hilog.info(DOMAIN, TAG, 'exportGraphImage(%{public}s) queued: %{public}s', dest, result);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'exportImageViaPicker failed: %{public}s', (e as Error).message);
    }
  }

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
          menus: this.menuDefs,
          onItemClick: (itemId: string) => this.onMenuItemClick(itemId),
          onAnchorChange: (menuId: string, x: number) => {
            this.menuAnchorMap.set(menuId, x);
            if (this.openMenu === menuId) {
              this.dropdownX = x;
            }
          }
        })

        // ArkTS toolbar: original SciDAVis desktop icons, Windows-layout
        // File/Edit/Graph/Plot groups.  Ids reuse the menu dispatch so
        // behaviour matches the menu items 1:1.
        ToolBar({
          undoEnabled: this.uiState.undoEnabled,
          redoEnabled: this.uiState.redoEnabled,
          hasWin: this.uiState.activeName !== '',
          isTable: this.uiState.activeType === 'Table',
          isGraph: this.uiState.activeType === 'MultiLayer',
          onItemClick: (itemId: string) => {
            this.onMenuItemClick(itemId);
            // keep greying current (menus refresh on open; toolbar has no
            // such hook, so refresh right after each dispatch)
            this.refreshUiState();
          }
        })

        // Content area: shows active view (default=transparent pass-through to Qt)
        // When menu is open, touching the content area closes it
        if (this.currentView === 'tables') {
          TablePage()
            .layoutWeight(1)
        } else if (this.currentView === 'plots') {
          PlotPage()
            .layoutWeight(1)
        } else {
          // Default: transparent - touch events pass through to
          // the XComponent for native QPA processing.  We do NOT forward
          // touch via sendMouse here — QPA handles it natively.
          Column()
            .layoutWeight(1)
            .hitTestBehavior(HitTestMode.Transparent)
            .onTouch((_event: TouchEvent) => {
              // Touch ANYWHERE in the content area closes an open menu.
              if (this.openMenu !== null) {
                hilog.info(DOMAIN, TAG, 'content touch - closing menu');
                this.openMenu = null;
              }
            })
        }

        // Status bar
        StatusBar({ statusText: this.statusText })
      }
      .width('100%')
      .height('100%')

      // Scrim while a menu is open: covers everything below the menu bar,
      // closes the menu when tapped, and (being hit-test opaque) blocks
      // both ETS forwarding and native QPA delivery of that tap — desktop
      // menus dismiss on outside-click without acting on the content.
      // It starts at MENUBAR_HEIGHT_VP so the titles keep their toggle and
      // hover-switch behaviour, and is rendered BELOW DropdownMenu so the
      // submenu items stay clickable.  Close happens in onClick (fires on
      // Up, after Stack.onTouch already saw openMenu!==null for both Down
      // and Up) so the dismissing tap is never forwarded to Qt.
      if (this.openMenu !== null) {
        Column()
          .width('100%')
          .height('calc(100% - 28vp)') // 28 = MENUBAR_HEIGHT_VP
          .position({ x: 0, y: MENUBAR_HEIGHT_VP })
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            hilog.info(DOMAIN, TAG, 'scrim tap - closing menu');
            this.openMenu = null;
          })
          .zIndex(100) // above ProjectTree/NoteEditor overlays declared later
      }

      // Floating dropdown menu: rendered at Stack level (NOT inside the
      // Column) so opening it does not reflow/push the content area down.
      // .position() is applied HERE (Stack child) so x/y are relative to
      // the Stack's top-left, anchoring the panel under its menu title.
      // zIndex keeps it above the Project sidebar, which sits later in the
      // Stack and otherwise covers the File/Edit/View dropdowns.
      DropdownMenu({
        openMenu: this.openMenu,
        menus: this.menuDefs,
        onItemClick: (itemId: string) => this.onMenuItemClick(itemId)
      })
        .position({ x: this.dropdownX, y: MENUBAR_HEIGHT_VP })
        .zIndex(101)

      // Note editor overlay
      if (this.showNotes) {
        NoteEditor()
      }

      // Project browser sidebar (View menu): tree from getProjectTree,
      // double-tap activates the MDI window (activateWindow command).
      if (this.showProjectTree) {
        Column() {
          ProjectTree({
            refreshTick: this.projectTreeTick,
            activeName: this.uiState.activeName,
            onActivate: (name: string) => {
              try {
                const result: string = qtInjector.callQtCommand('activateWindow',
                  JSON.stringify({ name: name } as ActivateWindowArgs));
                hilog.info(DOMAIN, TAG, 'tree activateWindow(%{public}s): %{public}s', name, result);
                this.refreshUiState();
                this.projectTreeTick++;
              } catch (e) {
                hilog.error(DOMAIN, TAG, 'tree activate failed: %{public}s', (e as Error).message);
              }
            }
          })
        }
        .width('22%')
        .height('70%')
        // Below the full top chrome (menubar + toolbar): at MENUBAR_HEIGHT
        // the panel used to overlap the toolbar band and swallow its
        // clicks (device-verified via uitest hit-test at y=96px).
        .position({ x: 8, y: TOP_CHROME_VP + 8 })
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .border({ width: 1, color: '#C0C0C0' })
        .shadow({ radius: 10, color: '#50000000', offsetX: 2, offsetY: 2 })
        .clip(true)
      }

      // Results Log panel (View menu): analysis output from resultsLog events.
      if (this.showResultsLog) {
        Column() {
          Row() {
            Text('Results Log')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
              .layoutWeight(1)
            Button('Clear')
              .fontSize(12).height(26)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .margin({ right: 8 })
              .onClick(() => { AppStorage.setOrCreate<string>('resultsLog', ''); })
            Button('✕')
              .fontSize(12).height(26)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.showResultsLog = false; })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })

          Scroll() {
            Text(this.resultsLogText === '' ? '(empty)' : this.resultsLogText)
              .fontSize(11)
              .fontColor('#444444')
              .fontFamily('monospace')
              .textAlign(TextAlign.Start)
              .width('100%')
              .padding({ left: 12, right: 12, bottom: 12 })
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
        }
        .width('46%')
        .height('60%')
        // Same toolbar-occlusion fix as the project browser panel above.
        .position({ x: '52%', y: TOP_CHROME_VP + 8 })
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .border({ width: 1, color: '#C0C0C0' })
        .shadow({ radius: 10, color: '#50000000', offsetX: 2, offsetY: 2 })
      }

      // Dialogs
      ImportDialog({ isVisible: $showImportDialog })
      ExportDialog({ isVisible: $showExportDialog })
      AddColumnsDialog({ isVisible: $showAddColsDialog, tableId: this.tableOpsTarget })
      SetColumnValuesDialog({ isVisible: $showSetValuesDialog, tableId: this.tableOpsTarget })
      SortTableDialog({ isVisible: $showSortDialog, tableId: this.tableOpsTarget })
      Plot2DDialog({ isVisible: $showPlotDialog, tableId: this.tableOpsTarget, plotType: this.plotTypeSel })
      MatrixDimensionsDialog({ isVisible: $showMatrixDimsDialog, matrixId: this.tableOpsTarget })
      MatrixValuesDialog({ isVisible: $showMatrixValuesDialog, matrixId: this.tableOpsTarget })
      AnalysisDialog({ isVisible: $showAnalysisDialog, op: this.analysisOpSel })
      CorrelateDialog({ isVisible: $showCorrelateDialog, tableId: this.tableOpsTarget })

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
    // Transparent normally (touches fall through to the XComponent for
    // native QPA delivery).  While a menu is open, switch to Default so
    // the dismissing tap stays inside ArkTS — the scrim alone cannot stop
    // the native pipeline because an opaque child does not override the
    // outer Stack's Transparent mode (device-verified: src=2 press reached
    // Qt at the dismiss tap position).
    .hitTestBehavior(this.openMenu !== null ? HitTestMode.Default : HitTestMode.Transparent)
    // Forward touch events (finger + Bluetooth-left-converted-to-touch)
    // via sendMouse.  ETS CANNOT tell them apart: both report
    // source=TouchScreen, sourceTool=Finger (device-verified).  Finger
    // touches are also delivered natively by the QPA plugin, so Qt would
    // see them twice — the Qt side (InputProbe) drops the duplicate by
    // matching type+pos+button across different event sources within 60ms.
    // Right/middle Bluetooth clicks stay as MouseEvent and go via onMouse.
    // COORDINATES: ETS delivers vp; Qt runs with HighDpi scaling disabled
    // (DPR=1) and therefore expects PHYSICAL pixels — convert with vp2px()
    // before forwarding (DEVELOPMENT_GUIDE §1.3, device 2456x1600, ~1.5x).
    .onTouch((event: TouchEvent) => {
      // Never forward while an ArkTS menu is open (dropdown interactions),
      // nor within the ArkTS menu-bar / status-bar bands: the Qt menu bar
      // sits underneath and a forwarded tap there opens a QMenu popup,
      // which the single-window QPA cannot create (SIGSEGV).
      if (this.openMenu !== null) { return; }
      const stackHeight: number = event.target.area.height as number;
      const changed: TouchObject[] = event.changedTouches;
      for (let i = 0; i < changed.length; i++) {
        const t: TouchObject = changed[i];
        let action: number = -1;
        if (t.type === TouchType.Down) {
          // Band guard applies to Down only; Move/Up follow leftDown so a
          // drag that ends inside a chrome band still delivers its release
          // (otherwise Qt is left with a stuck pressed button).
          if (t.y < TOP_CHROME_VP || t.y > stackHeight - STATUSBAR_HEIGHT_VP) {
            continue; // ArkTS chrome band — handled natively, not Qt's
          }
          action = 0; leftDown = true;
        } else if (t.type === TouchType.Up) {
          if (!leftDown) { continue; }
          action = 1; leftDown = false;
        } else if (t.type === TouchType.Move && leftDown) {
          action = 2;
        }
        if (action >= 0) {
          const px: number = vp2px(t.x);
          const py: number = vp2px(t.y);
          if (dbgCount < 50) {
            dbgCount++;
            hilog.info(DOMAIN, TAG,
              'touch→mouse action=%{public}d vp=(%{public}d,%{public}d) px=(%{public}d,%{public}d)',
              action, Math.round(t.x), Math.round(t.y), Math.round(px), Math.round(py));
          }
          try {
            const ok = qtInjector.sendMouse(px, py, 1, action);
            if (!ok) {
              hilog.warn(DOMAIN, TAG, 'sendMouse(touch) returned false');
            }
          } catch (e) {
            hilog.error(DOMAIN, TAG, 'sendMouse(touch) failed: %{public}s', (e as Error).message);
          }
        }
      }
    })
    // Forward Bluetooth RIGHT/MIDDLE clicks (these arrive as MouseEvent,
    // not converted to touch by OHOS).  LEFT click arrives as touch event
    // (handled above), so skip it here to avoid duplicates.
    .onMouse((event: MouseEvent) => {
      if (event.button === MouseButton.Left) return;
      // Same chrome-band guard as onTouch: keep forwarded clicks out of
      // the Qt menu bar underneath the ArkTS one (popup crash).
      if (this.openMenu !== null) return;
      const stackHeight: number = event.target.area.height as number;
      if (event.y < TOP_CHROME_VP || event.y > stackHeight - STATUSBAR_HEIGHT_VP) {
        return;
      }
      let btn: number = 0;
      if (event.button === MouseButton.Right) btn = 2;
      else if (event.button === MouseButton.Middle) btn = 3;
      else return;
      let act: number = -1;
      if (event.action === MouseAction.Press) act = 0;
      else if (event.action === MouseAction.Release) act = 1;
      else if (event.action === MouseAction.Move) act = 2;
      else return;
      const px: number = vp2px(event.x);
      const py: number = vp2px(event.y);
      if (dbgCount < 50) {
        dbgCount++;
        hilog.info(DOMAIN, TAG,
          'mouse→mouse action=%{public}d btn=%{public}d vp=(%{public}d,%{public}d) px=(%{public}d,%{public}d)',
          act, btn, Math.round(event.x), Math.round(event.y), Math.round(px), Math.round(py));
      }
      try {
        const ok = qtInjector.sendMouse(px, py, btn, act);
        if (!ok) {
          hilog.warn(DOMAIN, TAG, 'sendMouse(mouse) returned false');
        }
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'sendMouse(mouse) failed: %{public}s', (e as Error).message);
      }
    })
  }
}
