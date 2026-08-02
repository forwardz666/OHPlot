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
//   these and forwards via sendMouse 鈫?scidavis_inject_mouse 鈫?Qt.
// - MenuBar area: ArkTS handles all menu UI natively.
// - Content area: HitTestMode.Transparent lets events pass through to
//   the XComponent underneath for native QPA processing.
// - StatusBar area: ArkTS handles status display.
// - WARNING: Do NOT forward touch events via sendMouse 鈥?the QPA plugin
//   already handles them natively.  Forwarding duplicates causes crashes.
import { MenuBar, DropdownMenu } from '../components/MenuBar';
import { ContextMenu } from '../components/ContextMenu';
import { ToolBar } from '../components/ToolBar';
import { BottomToolBar } from '../components/BottomToolBar';
import * as Theme from '../components/Theme';
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
import { AddCurveDialog } from './dialogs/AddCurveDialog';
import { ErrorBarsDialog } from './dialogs/ErrorBarsDialog';
import { AddFunctionDialog } from './dialogs/AddFunctionDialog';
import { ProjectTree } from '../components/ProjectTree';
import { getAppString } from '../components/LocaleHelper';
import hilog from '@ohos.hilog';
import qohos from 'libqohos.so';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import pasteboard from '@ohos.pasteboard';
import common from '@ohos.app.ability.common';
import display from '@ohos.display';

interface QohosInjector {
  sendMouse(x: number, y: number, button: number, action: number): boolean;
  callQtCommand(cmd: string, argsJson: string): string;
}

const qtInjector = qohos as QohosInjector;

const DOMAIN: number = 0x0000;
const TAG: string = 'QtInput';

// ArkTS chrome bands that must NOT be forwarded to Qt (vp).  A forwarded
// tap on the Qt menu bar (hidden underneath the ArkTS one) makes Qt call
// QMenu::popup() 鈫?QPA window creation 鈫?SIGSEGV: the alpha_v6 plugin
// supports only the single main XComponent window (device crash log
// cppcrash-...-20260727151314, QOpenHarmonyJsObject::getJsFunction).
const MENUBAR_HEIGHT_VP: number = 28;
// The toolbar height is DYNAMIC (grouped toolbars wrap onto 1..n rows and
// context groups show/hide with the active window type), so the full top
// chrome band is MENUBAR_HEIGHT_VP + the measured toolbar height 鈥?see
// topChromeVp().  That band must never be forwarded to Qt (the hidden Qt
// menu bar sits underneath).
const STATUSBAR_HEIGHT_VP: number = 24;
// Results Log auto-scroll: distance (vp) from bottom at which the user
// is considered "at the bottom" vs "scrolled up".  Smaller = stricter.
const SCROLL_BOTTOM_THRESHOLD: number = 50;

// Mirror of the Qt-side menuAction whitelist (main.cpp command registry).
// menuAction is a *mutation* command: scidavis_call queues it and returns
// {"success":true,"queued":true} immediately, so the Qt-side "unsupported"
// error can never reach ETS through the return value.  Unadapted items must
// therefore be gated here, before calling Qt.  Keep in sync with main.cpp.
const MENU_ACTION_SUPPORTED: string[] = [
  'new_notes', 'new_matrix', 'new_project', 'new_graph',
  'cascade', 'maximize_window', 'minimize_window', 'restore_window', 'close_window',
  'about', 'undo', 'redo', 'cut', 'copy', 'paste', 'delete',
  'clear_selection'
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

// setClipboardText payload (Phase 2 clipboard bridge, OHOS 鈫?Qt).
interface SetClipboardArgs {
  text: string;
}

// setChromeInsets payload: physical-pixel top/bottom margins Qt applies
// to the QMainWindow so the MDI area clears the ArkTS chrome
// (top/bottom bands).  The Qt-native table column panel is rendered by
// Qt itself (TableView d_control_tabs), so no right inset is needed.
interface ChromeInsetsArgs {
  top: number;
  bottom: number;
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
  // User's explicit View-menu selection (View→Tables/Plots/...).  This
  // distinguishes a manual choice from the system's auto-switch inside
  // refreshUiState: auto-switch only fires while this flag is false and
  // never overrides a locked view.  It is set on every manual switch and
  // never reset by refreshUiState (active name/type changes keep it), so
  // the user's explicit choice always wins over the auto logic.
  @State userViewLocked: boolean = false;
  // 问题5: whether the active MDI window is maximized.  Drives the
  // window-control middle button glyph (maximize '□' vs restore '❐');
  // refreshed from uiState.windows (status===2 == MyWidget::Maximized).
  @State activeWinMaximized: boolean = false;
  @State showImportDialog: boolean = false;
  @State showExportDialog: boolean = false;
  // Right-click context menu state
  @State showContextMenu: boolean = false;
  @State contextMenuX: number = 0;
  @State contextMenuY: number = 0;
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
  // Graph-edit dialogs (Phase 3b): add_curve / add_error_bars / add_function.
  @State showAddCurveDialog: boolean = false;
  @State showErrorBarsDialog: boolean = false;
  @State showAddFunctionDialog: boolean = false;
  // Results Log panel (View menu): text accumulated from resultsLog
  // events by QtEventHost via AppStorage.
  @State showResultsLog: boolean = false;
  @StorageProp('resultsLog') @Watch('onResultsLogChanged') resultsLogText: string = '';
  private scroller: Scroller = new Scroller();
  // true = auto-scroll to bottom on next layout; set false when user
  // manually scrolls up, re-enabled by onResultsLogChanged on new text.
  private shouldAutoScroll: boolean = true;
  // Measured dimensions (vp) from onAreaChange callbacks.
  private scrollViewportHeight: number = 0;
  // Long-press-to-right-click state (touch -> context menu)
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;
  private touchStartTime: number = 0;
  private LONG_PRESS_DURATION_MS: number = 500;
  private LONG_PRESS_MAX_MOVE_VP: number = 20;
  private scrollContentHeight: number = 0;
  // Project browser sidebar (Phase 3): tree from getProjectTree; the tick
  // bumps on every uiState refresh so the tree stays current.
  @State showProjectTree: boolean = false;
  @State projectTreeTick: number = 0;
  // Dynamic toolbar height (vp), measured via onAreaChange on the ToolBar:
  // the grouped toolbar wraps onto 1..n rows and its context groups
  // show/hide with the active window type, so the chrome band cannot be a
  // constant any more.
  @State toolbarHeightVp: number = 32;
  // Height (vp) of the bottom toolbar (2D-plot + 3D-surface groups), only
  // present while a Table is active; 0 otherwise.  Folded into the Qt
  // bottom chrome inset so the MDI area clears the docked bar.
  @State bottomToolbarHeightVp: number = 0;
  // Custom tooltip overlay for BottomToolBar buttons (bindPopup is occluded
  // by the XComponent native rendering layer; this overlay sits at Stack
  // level with zIndex 300 to appear above XComponent).
  @State tooltipText: string = '';
  @State tooltipX: number = 0;
  @State tooltipY: number = 0;
  @State tooltipShow: boolean = false;
  // Global y of the BottomToolBar top edge, used to position the tooltip
  // above the hovered button.
  @State bottomBarTopY: number = 0;
  // setChromeInsets startup retry: the first push can race the Qt event
  // loop ("Qt not running"), so retry until the queued ack arrives.
  private insetsRetry: number = 0;
  private uiRefreshRetry: number = 0;
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
  // Language switch pipeline: OHPlotAbility.onConfigurationUpdate bumps
  // langTick on every language change; menu labels are data-model strings
  // (not $r bindings), so they must be rebuilt explicitly.
  @StorageProp('langTick') @Watch('onLangChanged') langTick: number = 0;
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

  onLangChanged(): void {
    this.rebuildMenus();
  }

  onResultsLogChanged(): void {
    // New content appended 鈥?re-enable auto-scroll so the next Text
    // layout (onAreaChange) will scroll to the bottom automatically.
    this.shouldAutoScroll = true;
  }

  aboutToAppear(): void {
    this.rebuildMenus(); // initial static skeleton before Qt is queried
    this.schedulePushChromeInsets(); // tell Qt to clear the ArkTS chrome
  }

  // Full ArkTS top chrome height (vp): menu bar + measured toolbar rows.
  private topChromeVp(): number {
    return MENUBAR_HEIGHT_VP + this.toolbarHeightVp;
  }

  // Push the chrome insets to Qt (setChromeInsets 鈫?QMainWindow content
  // Unified hover-tip handler for both ToolBar (top) and BottomToolBar
  // (bottom).  Renders a yellow tooltip overlay at Stack level (zIndex 300)
  // above the XComponent native layer.  The caller supplies x/y so the
  // overlay can appear below (top toolbar) or above (bottom toolbar) the
  // hovered button.
  private handleHoverTip(tipKey: string, x: number, y: number, show: boolean): void {
    if (show) {
      this.tooltipText = getAppString(tipKey);
      this.tooltipX = x;
      this.tooltipY = y;
      this.tooltipShow = true;
    } else {
      this.tooltipShow = false;
    }
  }

  // margins in physical px).  Queued fire-and-forget on the Qt side;
  // returns false while Qt is not running yet so the retry loop keeps
  // going.
  private pushChromeInsets(): boolean {
    try {
      // Use the UIContext-bound vp2px, NOT the deprecated global vp2px():
      // the global one falls back to the DEFAULT screen's virtual pixel
      // ratio when the UI instance is ambiguous, which can disagree with
      // the real UI density (device DPR=2.2).  A wrong conversion makes
      // the Qt MDI top inset mismatch the ArkTS overlay bottom edge and
      // the overlay covers the first rows of tables/matrices (问题3).
      const density: number = display.getDefaultDisplaySync().densityPixels;
      const topVp: number = this.topChromeVp();
      const bottomVp: number = STATUSBAR_HEIGHT_VP + this.bottomToolbarHeightVp;
      const top: number = Math.round(this.getUIContext().vp2px(topVp));
      const bottom: number = Math.round(this.getUIContext().vp2px(bottomVp));
      const raw: string = qtInjector.callQtCommand('setChromeInsets',
        JSON.stringify({ top: top, bottom: bottom } as ChromeInsetsArgs));
      const resp: CmdResult = JSON.parse(raw) as CmdResult;
      hilog.info(DOMAIN, TAG,
        'setChromeInsets density=%{public}s topVp=%{public}s topPx=%{public}d bottomVp=%{public}s bottomPx=%{public}d -> %{public}s',
        String(density), String(topVp), top, String(bottomVp), bottom, raw);
      return resp.success;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'setChromeInsets failed: %{public}s', (e as Error).message);
      return false;
    }
  }

  // Startup path: Qt's event loop may not be running when the overlay
  // first appears, so retry with a short backoff until the push succeeds
  // (later height changes go through onAreaChange directly).  A queued
  // ack only proves the QApplication exists, so the follow-up uiState
  // fetch below still needs its own retry loop.
  private schedulePushChromeInsets(): void {
    if (this.pushChromeInsets()) {
      this.scheduleStartupUiRefresh();
      return;
    }
    if (this.insetsRetry < 20) {
      this.insetsRetry++;
      setTimeout(() => this.schedulePushChromeInsets(), 500);
    }
  }

  // Startup uiState fetch: getUiState can time out (3s fallback) while
  // the Qt event loop is still starting, leaving the toolbar context
  // groups hidden although the default Table exists.  Poll until an
  // active window shows up (device-verified: first fetch after install
  // returned an empty state).
  private scheduleStartupUiRefresh(): void {
    this.refreshUiState();
    if (this.uiState.activeName === '' && this.uiRefreshRetry < 10) {
      this.uiRefreshRetry++;
      setTimeout(() => this.scheduleStartupUiRefresh(), 1000);
    }
  }

  private refreshUiState(): void {
    try {
      const raw: string = qtInjector.callQtCommand('getUiState', '{}');
      const resp: UiStateResponse = JSON.parse(raw) as UiStateResponse;
      if (resp.success && resp.data !== undefined) {
        this.uiState = resp.data;
        // Default view passes through to Qt native rendering; the ArkTS
        // table overlay (TablePage) is only surfaced via the explicit
        // View menu choice.
        // 问题①: a non-Table window (graph/matrix) becoming active must not
        // leave the ArkTS table overlay mounted over the Qt window.  Only
        // revert a view that the system placed automatically; a user-locked
        // 'tables' choice stays, and 'plots' is never touched here.
        if (resp.data.activeType !== 'Table' && this.currentView === 'tables' && !this.userViewLocked) {
          this.currentView = 'default';
        }
        // 问题5: derive the maximize/restore state of the active window
        // from the serialized status (MyWidget::Status: Maximized = 2).
        let maximized: boolean = false;
        for (let i = 0; i < resp.data.windows.length; i++) {
          const w: UiWindow = resp.data.windows[i];
          if (w.active && w.status === 2) {
            maximized = true;
            break;
          }
        }
        this.activeWinMaximized = maximized;
        // The bottom toolbar only exists for Tables; when it is gone its
        // onAreaChange can no longer zero the height, so clear the bottom
        // inset here or the MDI area keeps an empty band reserved.
        if (resp.data.activeType !== 'Table' && this.bottomToolbarHeightVp !== 0) {
          this.bottomToolbarHeightVp = 0;
          this.pushChromeInsets();
        }
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

    defs.push({ id: 'file', label: getAppString('menu_file'), items: [
      { id: 'new_project', label: getAppString('file_new_project') },
      { id: 'new_table', label: getAppString('file_new_table') },
      { id: 'new_matrix', label: getAppString('file_new_matrix') },
      { id: 'new_notes', label: getAppString('file_new_note') },
      { id: 'new_graph', label: getAppString('file_new_graph') },
      { id: 'sep1', label: '鈹€' },
      { id: 'open', label: getAppString('file_open_project'), shortcut: 'Ctrl+O' },
      { id: 'save', label: getAppString('file_save_project'), shortcut: 'Ctrl+S' },
      { id: 'save_as', label: getAppString('file_save_as') },
      { id: 'sep2', label: '鈹€' },
      { id: 'import', label: getAppString('file_import_ascii') },
      { id: 'export', label: getAppString('file_export_ascii') },
      { id: 'sep3', label: '鈹€' },
      { id: 'print', label: getAppString('file_print'), shortcut: 'Ctrl+P', enabled: false },
      { id: 'sep4', label: '鈹€' },
      { id: 'quit', label: getAppString('file_quit'), shortcut: 'Ctrl+Q' }
    ]});

    defs.push({ id: 'edit', label: getAppString('menu_edit'), items: [
      { id: 'undo', label: getAppString('edit_undo'), shortcut: 'Ctrl+Z', enabled: st.undoEnabled },
      { id: 'redo', label: getAppString('edit_redo'), shortcut: 'Ctrl+Y', enabled: st.redoEnabled },
      { id: 'sep1', label: '鈹€' },
      { id: 'cut', label: getAppString('edit_cut_selection'), shortcut: 'Ctrl+X', enabled: hasWin },
      { id: 'copy', label: getAppString('edit_copy_selection'), shortcut: 'Ctrl+C', enabled: hasWin },
      { id: 'paste', label: getAppString('edit_paste_selection'), shortcut: 'Ctrl+V', enabled: hasWin },
      { id: 'delete', label: getAppString('edit_delete_selection'), enabled: hasWin },
      { id: 'sep2', label: '鈹€' },
      { id: 'preferences', label: getAppString('edit_preferences') }
    ]});

    defs.push({ id: 'view', label: getAppString('menu_view'), items: [
      { id: 'project_browser', label: getAppString('view_project_browser'), checked: this.showProjectTree },
      { id: 'plots', label: getAppString('view_plot_list'), checked: this.currentView === 'plots' },
      { id: 'tables', label: getAppString('view_table_list'), checked: this.currentView === 'tables' },
      { id: 'notes', label: getAppString('view_note_pad'), checked: this.showNotes },
      { id: 'sep1', label: '鈹€' },
      { id: 'log', label: getAppString('view_results_log'), checked: this.showResultsLog },
      { id: 'script_console', label: getAppString('view_script_console') }
    ]});

    // Context menu follows the active MDI window type (desktop behaviour).
    // Entries are greyed until their Phase 2/3 commands land.
    if (st.activeType === 'Matrix') {
      defs.push({ id: 'matrix', label: getAppString('menu_matrix'), items: [
        { id: 'set_dimensions', label: getAppString('matrix_set_dimensions') },
        { id: 'set_values', label: getAppString('matrix_set_values') },
        { id: 'sep1', label: '鈹€' },
        { id: 'transpose', label: getAppString('matrix_transpose') },
        { id: 'invert', label: getAppString('matrix_invert') }
      ]});
    } else if (st.activeType === 'MultiLayer' || st.activeType === 'Graph3D') {
      defs.push({ id: 'graph', label: getAppString('menu_graph'), items: [
        { id: 'graph_props', label: getAppString('graph_properties'), enabled: st.activeType === 'MultiLayer' },
        { id: 'export_image', label: getAppString('graph_export_image'), enabled: st.activeType === 'MultiLayer' },
        { id: 'sep0', label: '鈹€' },
        { id: 'add_curve', label: getAppString('graph_add_remove_curve'), enabled: st.activeType === 'MultiLayer' },
        { id: 'add_error_bars', label: getAppString('graph_add_error_bars'), enabled: st.activeType === 'MultiLayer' },
        { id: 'add_function', label: getAppString('graph_add_function'), enabled: st.activeType === 'MultiLayer' },
        { id: 'sep1', label: '鈹€' },
        { id: 'rescale', label: getAppString('graph_rescale'), enabled: st.activeType === 'MultiLayer' }
      ]});
    } else {
      const isTable: boolean = st.activeType === 'Table';
      defs.push({ id: 'table', label: getAppString('menu_table'), items: [
        { id: 'add_columns', label: getAppString('table_add_columns'), enabled: isTable },
        { id: 'set_values', label: getAppString('table_set_values'), enabled: isTable },
        { id: 'sort', label: getAppString('table_sort_table'), enabled: isTable },
        { id: 'sep1', label: '鈹€' },
        { id: 'statistics_columns', label: getAppString('table_stats_columns'), enabled: isTable },
        { id: 'statistics_rows', label: getAppString('table_stats_rows'), enabled: isTable }
      ]});
    }

    // Plot menu mirrors the desktop 2D types; every entry funnels into the
    // Plot2DDialog (column picker) 鈫?queued plot2D backend command.
    const isTablePlot: boolean = st.activeType === 'Table';
    defs.push({ id: 'plot', label: getAppString('menu_plot'), items: [
      { id: 'plot_line', label: getAppString('plot_line'), enabled: isTablePlot },
      { id: 'plot_scatter', label: getAppString('plot_scatter'), enabled: isTablePlot },
      { id: 'plot_line_symbol', label: getAppString('plot_line_symbol'), enabled: isTablePlot },
      { id: 'plot_vertical_bars', label: getAppString('plot_vertical_bars'), enabled: isTablePlot },
      { id: 'plot_horizontal_bars', label: getAppString('plot_horizontal_bars'), enabled: isTablePlot },
      { id: 'plot_area', label: getAppString('plot_area'), enabled: isTablePlot },
      { id: 'plot_pie', label: getAppString('plot_pie'), enabled: isTablePlot },
      { id: 'sep0', label: '鈹€' },
      { id: 'plot_drop_lines', label: getAppString('plot_vertical_drop_lines'), enabled: isTablePlot },
      { id: 'plot_spline', label: getAppString('plot_spline'), enabled: isTablePlot },
      { id: 'plot_vertical_steps', label: getAppString('plot_vertical_steps'), enabled: isTablePlot },
      { id: 'plot_horizontal_steps', label: getAppString('plot_horizontal_steps'), enabled: isTablePlot },
      { id: 'sep0b', label: '鈹€' },
      { id: 'plot_histogram', label: getAppString('plot_histogram'), enabled: isTablePlot },
      { id: 'plot_box', label: getAppString('plot_box'), enabled: isTablePlot },
      { id: 'sep1', label: '鈹€' },
      { id: 'plot_2d', label: getAppString('plot_explorer_2d') },
      { id: 'plot_3d', label: getAppString('plot_3d'), enabled: false }
    ]});

    // Analysis menu mirrors the desktop: curve analyses need an active
    // 2D plot, correlation runs on a table's columns.
    const isPlotWin: boolean = st.activeType === 'MultiLayer';
    defs.push({ id: 'analysis', label: getAppString('menu_analysis'), items: [
      { id: 'an_fit_linear', label: getAppString('analysis_fit_linear'), enabled: isPlotWin },
      { id: 'an_fit_poly', label: getAppString('analysis_fit_polynomial'), enabled: isPlotWin },
      { id: 'an_fit_gauss', label: getAppString('analysis_fit_gaussian'), enabled: isPlotWin },
      { id: 'an_fit_lorentz', label: getAppString('analysis_fit_lorentzian'), enabled: isPlotWin },
      { id: 'an_fit_sigmoidal', label: getAppString('analysis_fit_boltzmann'), enabled: isPlotWin },
      { id: 'sep1', label: '鈹€' },
      { id: 'an_fft', label: getAppString('analysis_fft_dlg'), enabled: isPlotWin },
      { id: 'an_fft_filter', label: getAppString('analysis_fft_filter'), enabled: isPlotWin },
      { id: 'an_smooth', label: getAppString('analysis_smooth_dlg'), enabled: isPlotWin },
      { id: 'an_interpolate', label: getAppString('analysis_interpolate'), enabled: isPlotWin },
      { id: 'an_differentiate', label: getAppString('analysis_differentiate'), enabled: isPlotWin },
      { id: 'an_integrate', label: getAppString('analysis_integrate'), enabled: isPlotWin },
      { id: 'sep2', label: '鈹€' },
      { id: 'correlate', label: getAppString('analysis_correlate'), enabled: st.activeType === 'Table' }
    ]});

    // Windows menu: management commands + live MDI window list from Qt.
    const winItems: SubMenuItemData[] = [
      { id: 'cascade', label: getAppString('win_cascade') },
      { id: 'maximize_window', label: getAppString('win_maximize'), enabled: hasWin },
      { id: 'minimize_window', label: getAppString('win_minimize'), enabled: hasWin },
      { id: 'close_window', label: getAppString('win_close'), shortcut: 'Ctrl+W', enabled: hasWin }
    ];
    if (st.windows.length > 0) {
      winItems.push({ id: 'sep1', label: '鈹€' });
      // Defensive dedup by name (device-verified: C++ dedup may miss edge cases)
      const seenWinNames: string[] = [];
      for (let i = 0; i < st.windows.length; i++) {
        const w: UiWindow = st.windows[i];
        if (seenWinNames.indexOf(w.name) >= 0) {
          continue;
        }
        seenWinNames.push(w.name);
        winItems.push({ id: 'win:' + w.name, label: w.name + ' (' + w.type + ')', checked: w.active });
      }
    }
    defs.push({ id: 'windows', label: getAppString('menu_windows'), items: winItems });

    defs.push({ id: 'help', label: getAppString('menu_help'), items: [
      { id: 'help', label: getAppString('help_browser'), enabled: false },
      { id: 'sep1', label: '鈹€' },
      { id: 'about', label: getAppString('help_about_ohplot') }
    ]});

    this.menuDefs = defs;
  }
  
  // Unified "not adapted yet" notice (menu + toolbar): an AlertDialog per
  // spec 鈥?silent no-ops and toasts are both forbidden for unadapted items.
  private showNotAdapted(): void {
    this.getUIContext().showAlertDialog({
      message: $r('app.string.not_adapted'),
      confirm: {
        value: $r('app.string.common_ok'),
        action: () => {}
      }
    });
  }

  // NAPI defensive-programming spec (HARNESS guide 搂3.3): every callQtCommand
  // must be wrapped in try-catch 鈥?a failed dlsym/route otherwise throws an
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
          title: $r('app.string.file_new_project'),
          message: $r('app.string.msg_new_project_confirm'),
          primaryButton: {
            value: $r('app.string.common_cancel'),
            action: () => {}
          },
          secondaryButton: {
            value: $r('app.string.common_ok'),
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
      case 'add_column':
        this.tableOpsTarget = this.uiState.activeName;
        AppStorage.setOrCreate<string>('tableOpsTarget', this.tableOpsTarget);
        this.showAddColsDialog = true;
        break;
      case 'table_dimensions':
      case 'table_size':
        // Stub: the backend dimensions command is not implemented yet —
        // surface the unified "not adapted yet" notice (same handling as
        // unwhitelisted menu items) instead of a silent no-op.
        this.showNotAdapted();
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
      case 'rescale': {
        const result: string = qtInjector.callQtCommand('rescale', '{}');
        hilog.info(DOMAIN, TAG, 'rescale result: %{public}s', result);
        break;
      }
      case 'add_curve':
        this.showAddCurveDialog = true;
        break;
      case 'add_error_bars':
        this.showErrorBarsDialog = true;
        break;
      case 'add_function':
        this.showAddFunctionDialog = true;
        break;
      case 'sort':
        this.tableOpsTarget = this.uiState.activeName;
        AppStorage.setOrCreate<string>('tableOpsTarget', this.tableOpsTarget);
        this.showSortDialog = true;
        break;
      case 'statistics_columns':
      case 'statistics_rows':
      case 'stats_columns':
      case 'stats_rows': {
        // No parameters needed; queued command, result toast via events.
        const result: string = qtInjector.callQtCommand('tableStatistics',
          JSON.stringify({
            tableId: this.uiState.activeName,
            type: (itemId === 'statistics_rows' || itemId === 'stats_rows') ? 'rows' : 'columns'
          } as TableStatisticsArgs));
        hilog.info(DOMAIN, TAG, '%{public}s queued: %{public}s', itemId, result);
        break;
      }
      case 'tables':
        // Explicit user choice: lock the view so refreshUiState's auto
        // logic never overrides it (toggling off to 'default' also locks —
        // the user explicitly closed the tables overlay).
        this.userViewLocked = true;
        this.currentView = (this.currentView === 'tables') ? 'default' : 'tables';
        // Re-push chrome insets so a side-bar-mounted right inset is
        // cleared immediately when the view leaves 'default'.
        this.pushChromeInsets();
        break;
      case 'plots':
        this.userViewLocked = true;
        this.currentView = (this.currentView === 'plots') ? 'default' : 'plots';
        this.pushChromeInsets();
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
      case 'insert_row': {
         const result: string = qtInjector.callQtCommand('insert_row', '{}');
         hilog.info(DOMAIN, TAG, 'insert_row: %{public}s', result);
         setTimeout(() => { this.refreshUiState(); }, 300);
         break;
      }
      case 'insert_col': {
         const result: string = qtInjector.callQtCommand('insert_col', '{}');
         hilog.info(DOMAIN, TAG, 'insert_col: %{public}s', result);
         setTimeout(() => { this.refreshUiState(); }, 300);
         break;
      }
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
        // (HARNESS guide P1 鈥?users expect a real response, not just a log).
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

  // 鈹€鈹€ Project open/save (Phase 2) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  // Qt only reaches sandbox paths, so the pickers copy files in/out.

  // 鈹€鈹€ Clipboard bridge (Phase 2) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  // Qt 鈫?OHOS runs through the clipboardChanged event (QtEventHost).
  // The PasteButton temp READ_PASTEBOARD authorization is one-shot and is
  // granted on click — the read MUST complete synchronously inside this
  // onClick chain (spec §2.2), so only getDataSync() is used here (same
  // constraint as the JsPasteBoard bridge, spec §1.3).  An async getData()
  // would resume after the onClick callback returns and may lose the auth.
  private pasteWithSystemClipboard(): void {
    try {
      const data: pasteboard.PasteData = pasteboard.getSystemPasteboard().getDataSync();
      const text: string = data.getPrimaryText();
      if (text !== null && text !== undefined && text !== '') {
        qtInjector.callQtCommand('setClipboardText',
          JSON.stringify({ text: text } as SetClipboardArgs));
      }
    } catch (e) {
      // Empty/non-text pasteboard or auth window missed — fall through to
      // Qt's own clipboard (the in-app copy already lives in Qt's cache).
      hilog.info(DOMAIN, TAG, 'pasteboard read skipped: %{public}s', (e as Error).message);
    }
    const result: string = qtInjector.callQtCommand('menuAction',
      JSON.stringify({ itemId: 'paste' } as MenuActionArgs));
    hilog.info(DOMAIN, TAG, 'paste dispatched: %{public}s', result);
  }

  // 鈹€鈹€ Graph image export (Phase 3) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
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

  // 问题5: one MDI window-control button (min/max/close).  Windows SciDAVis
  // shows these at the right end of the main menu bar while a sub-window is
  // maximized; the commands are already in the MENU_ACTION_SUPPORTED
  // whitelist and routed through the existing dispatchMenuItem fallback.
  // Styled with the shared Theme tokens so they blend into the chrome.
  @Builder
  WindowCtlButton(label: string, action: string) {
    Text(label)
      .width(30)
      .height(24)
      .fontSize(12)
      .textAlign(TextAlign.Center)
      .fontColor(Theme.TEXT)
      .borderRadius(3)
      .backgroundColor(Theme.GROUP_BG)
      .border({ width: 1, color: Theme.GROUP_BORDER })
      .margin({ left: 2 })
      .onClick(() => {
        this.onMenuItemClick(action);
        // Menu-open refresh already covers greying; mirror the toolbar
        // behaviour and keep uiState current after the queued mutation.
        this.refreshUiState();
        // The window command is QUEUED on the Qt thread, so the immediate
        // refresh reads the pre-mutation status and would leave the
        // maximize/restore glyph stale.  Refresh again once the queue has
        // drained (aligned with the ToolBar 700ms pattern).
        setTimeout(() => this.refreshUiState(), 700);
      })
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

        // ArkTS toolbar: original SciDAVis desktop icons grouped into the
        // Windows toolbar categories (File/Edit/Graph/Plot/3D); groups wrap
        // onto extra rows on narrow screens and the context groups follow
        // the active window type.  Ids reuse the menu dispatch so behaviour
        // matches the menu items 1:1.
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
            // Mutations are QUEUED (new_*, activateWindow...), so the
            // immediate refresh can read the pre-mutation state and leave
            // stale context groups (device-verified: Graph group lingered
            // after New Matrix).  Refresh again once the queue drained.
            setTimeout(() => this.refreshUiState(), 700);
          },
          // 问题4b: toolbar right-click 鈫?reuse the existing ContextMenu.
          // ToolBar forwards window coordinates; both live in the same
          // full-window space as the Stack-relative contextMenuX/Y.
          onContextMenu: (x: number, y: number) => {
            this.contextMenuX = x;
            this.contextMenuY = y;
            this.showContextMenu = true;
          },
          onHoverTip: (tipKey: string, x: number, y: number, show: boolean) => {
            this.handleHoverTip(tipKey, x, y, show);
          }
        })
          // The toolbar height changes when rows wrap or context groups
          // toggle; track it so the touch guards, floating panels and the
          // Qt-side insets all follow the real chrome height.
          .onAreaChange((_old: Area, now: Area) => {
            const h: number = now.height as number;
            if (h > 0 && h !== this.toolbarHeightVp) {
              this.toolbarHeightVp = h;
              this.pushChromeInsets();
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
          // touch via sendMouse here 鈥?QPA handles it natively.
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

        // Bottom toolbar: 2D-plot and 3D-surface groups docked below the
        // content area (Windows plot_tools/plot3d moved to the lower page
        // region).  Always visible regardless of active window type.
        BottomToolBar({
          isTable: true,
          onItemClick: (itemId: string) => {
            this.onMenuItemClick(itemId);
            this.refreshUiState();
            setTimeout(() => this.refreshUiState(), 700);
          },
          onHoverTip: (tipKey: string, x: number, y: number, show: boolean) => {
            this.handleHoverTip(tipKey, x, y, show);
          }
        })
          .onAreaChange((_old: Area, now: Area) => {
            const h: number = now.height as number;
            if (h >= 0 && h !== this.bottomToolbarHeightVp) {
              this.bottomToolbarHeightVp = h;
              this.pushChromeInsets();
            }
            if (now.globalPosition) {
              this.bottomBarTopY = now.globalPosition.y as number;
            }
          })

        // Status bar
        StatusBar({ statusText: this.statusText })
      }
      .width('100%')
      .height('100%')

      // Scrim while a menu is open: covers everything below the menu bar,
      // closes the menu when tapped, and (being hit-test opaque) blocks
      // both ETS forwarding and native QPA delivery of that tap 鈥?desktop
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

      // Right-click context menu: floating popup positioned at the click
      // coordinates.  Always rendered (like DropdownMenu) so the @Link
      // isVisible drives its internal show/hide.  zIndex above the sidebar
      // and regular dropdown so menu items stay clickable.
      ContextMenu({
        isVisible: $showContextMenu,
        positionX: this.contextMenuX,
        positionY: this.contextMenuY,
        activeType: this.uiState.activeType,
        onItemClick: (itemId: string) => this.onMenuItemClick(itemId)
      })
        .zIndex(200)

      // 问题5: MDI window controls (min/max/close) at the right end of the
      // SAME row as the "files"/menu titles (Windows SciDAVis puts them
      // there when a sub-window is maximized).  A full-width transparent
      // Row keeps the MenuBar titles clickable below it; only the buttons
      // (its children) grab clicks.  Shown whenever an MDI window is
      // active (activeName !== ''); the middle button toggles between
      // maximize '□' and restore '❐' following activeWinMaximized.
      if (this.uiState.activeName !== '') {
        Row() {
          this.WindowCtlButton('—', 'minimize_window')
          if (this.activeWinMaximized) {
            this.WindowCtlButton('❐', 'restore_window')
          } else {
            this.WindowCtlButton('□', 'maximize_window')
          }
          this.WindowCtlButton('✕', 'close_window')
        }
        .width('100%')
        .height(MENUBAR_HEIGHT_VP)
        .justifyContent(FlexAlign.End)
        .padding({ right: 4 })
        .position({ x: 0, y: 0 })
        .zIndex(300)
        // Do not swallow menu-title taps: self+children hit-test but the
        // siblings below (MenuBar) stay reachable; clicks on the buttons
        // themselves are still delivered.
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // Custom tooltip overlay for ToolBar and BottomToolBar buttons.
      // bindPopup is occluded by the XComponent (native rendering layer);
      // this Text sits at Stack level with zIndex 300 so it renders above
      // XComponent.  Position (x/y) is supplied by the caller via
      // handleHoverTip: top toolbar → below button (btnY+30), bottom
      // toolbar → above button (btnY-34).
      if (this.tooltipShow && this.tooltipText) {
        Text(this.tooltipText)
          .fontSize(12)
          .fontColor('#333333')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#FFFFE1')
          .borderRadius(4)
          .border({ width: 1, color: '#C0C0C0' })
          .position({ x: this.tooltipX, y: this.tooltipY })
          .zIndex(300)
          .hitTestBehavior(HitTestMode.Transparent)
      }

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
        // Below the full top chrome (menubar + toolbar rows): at
        // MENUBAR_HEIGHT the panel used to overlap the toolbar band and
        // swallow its clicks (device-verified via uitest hit-test).
        .position({ x: 8, y: this.topChromeVp() + 8 })
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .border({ width: 1, color: '#C0C0C0' })
        .shadow({ radius: 10, color: '#50000000', offsetX: 2, offsetY: 2 })
        .clip(true)
      }

      // Column-properties sidebar is intentionally NOT mounted: the user
      // wants the Qt-native table column control panel (TableView
      // d_control_tabs) rendered by Qt itself, like the matrix one.

      // Results Log panel (View menu): analysis output from resultsLog events.
      if (this.showResultsLog) {
        Column() {
          Row() {
            Text($r('app.string.panel_results_log'))
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
              .layoutWeight(1)
            Button($r('app.string.common_clear'))
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

          Scroll(this.scroller) {
            Text(this.resultsLogText === '' ? getAppString('common_empty') : this.resultsLogText)
              .fontSize(11)
              .fontColor('#444444')
              .fontFamily('monospace')
              .textAlign(TextAlign.Start)
              .width('100%')
              .padding({ left: 12, right: 12, bottom: 12 })
              .onAreaChange((oldValue: Area, newValue: Area) => {
                // Text content has been laid out 鈥?the Scroll is also
                // fully laid out by this point, so scrollEdge is safe.
                this.scrollContentHeight = newValue.height as number;
                if (this.shouldAutoScroll) {
                  this.scroller.scrollEdge(Edge.Bottom);
                  this.shouldAutoScroll = false;
                }
              })
          }
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
          .onAreaChange((oldValue: Area, newValue: Area) => {
            // Capture the Scroll viewport height (vp) so onScroll can
            // compute the real distance from the bottom edge.
            this.scrollViewportHeight = newValue.height as number;
          })
          .onScroll((xOffset: number, yOffset: number) => {
            // Use measured dimensions 鈥?no hardcoded magic numbers.
            if (this.scrollContentHeight > 0 && this.scrollViewportHeight > 0) {
              const maxScrollOffset: number = Math.max(0,
                this.scrollContentHeight - this.scrollViewportHeight);
              const distanceFromBottom: number = maxScrollOffset - yOffset;
              if (distanceFromBottom > SCROLL_BOTTOM_THRESHOLD) {
                this.shouldAutoScroll = false;
              }
            }
          })
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
        }
        .width('46%')
        .height('60%')
        // Same toolbar-occlusion fix as the project browser panel above.
        .position({ x: '52%', y: this.topChromeVp() + 8 })
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
      AddCurveDialog({ isVisible: $showAddCurveDialog })
      ErrorBarsDialog({ isVisible: $showErrorBarsDialog })
      AddFunctionDialog({ isVisible: $showAddFunctionDialog })

      // Qt backend event host: renders ArkUI replacements for QMessageBox /
      // context menus / combo popups pushed via scidavis_emit 鈫?onQtEvent.
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
    // the dismissing tap stays inside ArkTS 鈥?the scrim alone cannot stop
    // the native pipeline because an opaque child does not override the
    // outer Stack's Transparent mode (device-verified: src=2 press reached
    // Qt at the dismiss tap position).
    .hitTestBehavior(this.openMenu !== null ? HitTestMode.Default : HitTestMode.Transparent)
    // Forward touch events (finger + Bluetooth-left-converted-to-touch)
    // via sendMouse.  ETS CANNOT tell them apart: both report
    // source=TouchScreen, sourceTool=Finger (device-verified).  Finger
    // touches are also delivered natively by the QPA plugin, so Qt would
    // see them twice 鈥?the Qt side (InputProbe) drops the duplicate by
    // matching type+pos+button across different event sources within 60ms.
    // Right/middle Bluetooth clicks stay as MouseEvent and go via onMouse.
    // COORDINATES: ETS delivers vp; Qt runs with HighDpi scaling disabled
    // (DPR=1) and therefore expects PHYSICAL pixels 鈥?convert with vp2px()
    // before forwarding (DEVELOPMENT_GUIDE 搂1.3, device 2456x1600, ~1.5x).
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
          if (t.y < this.topChromeVp() || t.y > stackHeight - STATUSBAR_HEIGHT_VP) {
            continue; // ArkTS chrome band - handled natively, not Qt's
          }
          // Record long-press start position and time
          this.lastTouchX = t.x;
          this.lastTouchY = t.y;
          this.touchStartTime = Date.now();
          hilog.info(DOMAIN, TAG,
            'touch start recorded for long-press at (%{public}d,%{public}d)',
            Math.round(t.x), Math.round(t.y));
          action = 0; leftDown = true;
        } else if (t.type === TouchType.Up) {
          if (!leftDown) { continue; }
          // Long-press detection: check if held long enough with minimal movement
          const elapsed = Date.now() - this.touchStartTime;
          const dx = t.x - this.lastTouchX;
          const dy = t.y - this.lastTouchY;
          if (elapsed >= this.LONG_PRESS_DURATION_MS &&
              (dx * dx + dy * dy) <= this.LONG_PRESS_MAX_MOVE_VP * this.LONG_PRESS_MAX_MOVE_VP) {
            hilog.info(DOMAIN, TAG,
              'long-press detected at (%{public}d,%{public}d) after %{public}dms',
              Math.round(this.lastTouchX), Math.round(this.lastTouchY), elapsed);
            this.contextMenuX = this.lastTouchX;
            this.contextMenuY = this.lastTouchY;
            this.showContextMenu = true;
          }
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
              'touch鈫抦ouse action=%{public}d vp=(%{public}d,%{public}d) px=(%{public}d,%{public}d)',
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
      // Show ArkTS context menu on right-click press in the content area.
      // Runs BEFORE the openMenu guard so the context menu appears even when
      // a dropdown menu is open (desktop parity: right-click always shows
      // the context menu regardless of the menu bar state).
      if (event.button === MouseButton.Right && event.action === MouseAction.Press) {
        const sh: number = event.target.area.height as number;
        if (event.y >= this.topChromeVp() && event.y <= sh - STATUSBAR_HEIGHT_VP) {
          this.contextMenuX = event.x;
          this.contextMenuY = event.y;
          this.showContextMenu = true;
        }
      }
      // Same chrome-band guard as onTouch: keep forwarded clicks out of
      // the Qt menu bar underneath the ArkTS one (popup crash).
      if (this.openMenu !== null) return;
      const stackHeight: number = event.target.area.height as number;
      if (event.y < this.topChromeVp() || event.y > stackHeight - STATUSBAR_HEIGHT_VP) {
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
          'mouse鈫抦ouse action=%{public}d btn=%{public}d vp=(%{public}d,%{public}d) px=(%{public}d,%{public}d)',
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
