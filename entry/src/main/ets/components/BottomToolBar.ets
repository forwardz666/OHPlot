// OHPlot bottom toolbar — the 2D plot (plot_tools) and 3D surface
// (plot3d) groups moved out of the top ToolBar into a dedicated bar docked
// below the MDI content area (problem 1: matrix/3D plotting placed in the
// lower page region).  Only shown while a Table is active.  Button ids and
// dispatch (plot_*/plot3d_*/tbdrop_*) are IDENTICAL to the previous top
// placement so command routing and verify scripts are unchanged.
//
// Builder/reactivity conventions mirror ToolBar.ets: @Builder parameters
// are passed as one object literal (by-reference) so @Prop-driven greying
// stays live (ArkTS by-value @Builder params are frozen at first render).
import * as Theme from './Theme';

interface TbButtonOpts {
  id: string;
  icon: Resource;
  enabled: boolean;
  tip: string;   // resource name of the hover tooltip (Windows-style hint)
}

interface TbDropOpts {
  id: string;
  icon: Resource;
  enabled: boolean;
  menu: MenuElement[];
  tip: string;
}

@Component
export struct BottomToolBar {
  @Prop isTable: boolean = false;     // active window is a Table
  onItemClick?: (itemId: string) => void;
  // Callback to show/hide a custom tooltip overlay in MainLayout (rendered
  // at Stack level so it is NOT occluded by the XComponent).  tipKey is the
  // string resource name (e.g. 'tip_plot_area'); x/y is the global position
  // for the overlay; show=true → display, show=false → hide.
  onHoverTip?: (tipKey: string, x: number, y: number, show: boolean) => void;
  // Id of the button currently hovered by the mouse; used internally.
  @State hoverTipId: string = '';
  // Per-button global position [x, y], captured via onAreaChange.
  @State btnPos: Record<string, [number, number]> = {};

  private fire(itemId: string): void {
    if (this.onItemClick) {
      this.onItemClick(itemId);
    }
  }

  // ── Dropdown menus (Windows QToolButton InstantPopup equivalents) ──

  // Plot ▸ Lines and/or symbols (lpPlot.xpm button)
  private linesMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: $r('app.string.tbmenu_line'), icon: $r('app.media.tb_lplot'), action: (): void => this.fire('plot_line') },
      { value: $r('app.string.tbmenu_scatter'), icon: $r('app.media.tb_pplot'), action: (): void => this.fire('plot_scatter') },
      { value: $r('app.string.tbmenu_line_symbol'), icon: $r('app.media.tb_lpplot'), action: (): void => this.fire('plot_line_symbol') },
      { value: $r('app.string.tbmenu_spline'), action: (): void => this.fire('plot_spline') },
      { value: $r('app.string.tbmenu_vertical_drop_lines'), action: (): void => this.fire('plot_drop_lines') },
      { value: $r('app.string.tbmenu_horizontal_steps'), action: (): void => this.fire('plot_horizontal_steps') },
      { value: $r('app.string.tbmenu_vertical_steps'), action: (): void => this.fire('plot_vertical_steps') }
    ];
    return items;
  }

  // Plot ▸ Bars (vertBars.xpm button)
  private barsMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: $r('app.string.tbmenu_vertical_bars'), action: (): void => this.fire('plot_vertical_bars') },
      { value: $r('app.string.tbmenu_horizontal_bars'), action: (): void => this.fire('plot_horizontal_bars') }
    ];
    return items;
  }

  // Plot ▸ Vectors (vectXYXY.xpm button)
  private vectorsMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: $r('app.string.tbmenu_vectors_xyxy'), action: (): void => this.fire('plot_vect_xyxy') },
      { value: $r('app.string.tbmenu_vectors_xyam'), action: (): void => this.fire('plot_vect_xyam') }
    ];
    return items;
  }

  // ── Builders ──

  @Builder
  ToolButton($$: TbButtonOpts) {
    Column() {
      Image($$.icon)
        .width(22)
        .height(22)
        .objectFit(ImageFit.Contain)
        .draggable(false)
    }
    .width(30)
    .height(28)
    .justifyContent(FlexAlign.Center)
    .borderRadius(4)
    .opacity($$.enabled ? 1.0 : Theme.OPACITY_DISABLED)
    .id('tb_' + $$.id)
    .onAreaChange((_o: Area, n: Area) => {
      if (n.globalPosition) {
        this.btnPos[$$.id] = [n.globalPosition.x as number, n.globalPosition.y as number];
      }
    })
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.hoverTipId = $$.id;
        const p = this.btnPos[$$.id];
        if (this.onHoverTip && p) { this.onHoverTip($$.tip, p[0], p[1] - 34, true); }
      } else if (this.hoverTipId === $$.id) {
        this.hoverTipId = '';
        if (this.onHoverTip) { this.onHoverTip('', 0, 0, false); }
      }
    })
    .onClick(() => {
      if (!$$.enabled) {
        return;
      }
      this.fire($$.id);
    })
  }

  @Builder
  DropButton($$: TbDropOpts) {
    Column() {
      Image($$.icon)
        .width(22)
        .height(22)
        .objectFit(ImageFit.Contain)
        .draggable(false)
    }
    .width(30)
    .height(28)
    .justifyContent(FlexAlign.Center)
    .borderRadius(4)
    .opacity($$.enabled ? 1.0 : Theme.OPACITY_DISABLED)
    .enabled($$.enabled)
    .id($$.id)
    .onAreaChange((_o: Area, n: Area) => {
      if (n.globalPosition) {
        this.btnPos[$$.id] = [n.globalPosition.x as number, n.globalPosition.y as number];
      }
    })
    .onHover((isHover: boolean) => {
      if (isHover) {
        this.hoverTipId = $$.id;
        const p = this.btnPos[$$.id];
        if (this.onHoverTip && p) { this.onHoverTip($$.tip, p[0], p[1] - 34, true); }
      } else if (this.hoverTipId === $$.id) {
        this.hoverTipId = '';
        if (this.onHoverTip) { this.onHoverTip('', 0, 0, false); }
      }
    })
    .bindMenu($$.menu)
  }

  @Builder
  Separator() {
    Row()
      .width(1)
      .height(20)
      .backgroundColor(Theme.LINE)
      .margin({ left: 4, right: 4 })
  }

  // QToolBar-style grip drawn at the left edge of every group.
  @Builder
  Grip() {
    Row() {
      Row().width(1).height(16).backgroundColor(Theme.GRIP)
      Row().width(1).height(16).backgroundColor(Theme.GRIP).margin({ left: 2 })
    }
    .margin({ left: 3, right: 5 })
  }

  // table_tools — Windows fillProjectToolBar (resize / add column /
  // column statistics / row statistics), icons ported from the desktop
  // SciDAVis toolbar.  NOTE: named TblGroup (not TableGroup) because
  // 'TableGroup' clashes with the ArkUI built-in Table component and is
  // silently skipped by the runtime.
  @Builder
  TblGroup() {
    Row() {
      this.Grip()
      this.ToolButton({ id: 'table_size', icon: $r('app.media.tb_table_size'), enabled: true, tip: 'tip_table_size' })
      this.ToolButton({ id: 'add_column', icon: $r('app.media.tb_add_column'), enabled: true, tip: 'tip_add_column' })
      this.ToolButton({ id: 'stats_columns', icon: $r('app.media.tb_stats_columns'), enabled: true, tip: 'tip_stats_columns' })
      this.ToolButton({ id: 'stats_rows', icon: $r('app.media.tb_stats_rows'), enabled: true, tip: 'tip_stats_rows' })
    }
    .height(30)
    .padding({ right: 3 })
    .margin(2)
    .borderRadius(4)
    .border({ width: 1, color: Theme.GROUP_BORDER })
    .backgroundColor(Theme.GROUP_BG)
  }

  // ── Toolbar groups (one per desktop QToolBar) ──

  // plot_tools 2D part (rendered only with an active Table)
  @Builder
  PlotGroup() {
    Row() {
      this.Grip()
      this.DropButton({ id: 'tbdrop_lines', icon: $r('app.media.tb_lpplot'), enabled: true, menu: this.linesMenu(), tip: 'tip_plot_lines' })
      this.DropButton({ id: 'tbdrop_bars', icon: $r('app.media.tb_vertbars'), enabled: true, menu: this.barsMenu(), tip: 'tip_plot_bars' })
      this.ToolButton({ id: 'plot_area', icon: $r('app.media.tb_area'), enabled: true, tip: 'tip_plot_area' })
      this.ToolButton({ id: 'plot_pie', icon: $r('app.media.tb_pie'), enabled: true, tip: 'tip_plot_pie' })
      this.ToolButton({ id: 'plot_histogram', icon: $r('app.media.tb_histogram'), enabled: true, tip: 'tip_plot_histogram' })
      this.ToolButton({ id: 'plot_box', icon: $r('app.media.tb_boxplot'), enabled: true, tip: 'tip_plot_box' })
      this.DropButton({ id: 'tbdrop_vectors', icon: $r('app.media.tb_vectxyxy'), enabled: true, menu: this.vectorsMenu(), tip: 'tip_plot_vectors' })
    }
    .height(30)
    .padding({ right: 3 })
    .margin(2)
    .borderRadius(4)
    .border({ width: 1, color: Theme.GROUP_BORDER })
    .backgroundColor(Theme.GROUP_BG)
  }

  // plot_tools 3D tail as its own category (desktop appends these four to
  // plot_tools; split out to match the "3D surface" category).
  @Builder
  Plot3DGroup() {
    Row() {
      this.Grip()
      this.ToolButton({ id: 'plot3d_ribbon', icon: $r('app.media.tb_ribbon'), enabled: true, tip: 'tip_plot3d_ribbon' })
      this.ToolButton({ id: 'plot3d_bars', icon: $r('app.media.tb_bars'), enabled: true, tip: 'tip_plot3d_bars' })
      this.ToolButton({ id: 'plot3d_scatter', icon: $r('app.media.tb_scatter'), enabled: true, tip: 'tip_plot3d_scatter' })
      this.ToolButton({ id: 'plot3d_trajectory', icon: $r('app.media.tb_trajectory'), enabled: true, tip: 'tip_plot3d_trajectory' })
    }
    .height(30)
    .padding({ right: 3 })
    .margin(2)
    .borderRadius(4)
    .border({ width: 1, color: Theme.GROUP_BORDER })
    .backgroundColor(Theme.GROUP_BG)
  }

  build() {
    // Docked below the content area; groups wrap onto extra rows if the
    // tablet width is exceeded.  MainLayout measures the height via
    // onAreaChange and folds it into the Qt bottom chrome inset so the MDI
    // area clears this bar.
    Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
      this.PlotGroup()
      this.Plot3DGroup()
      this.TblGroup()
    }
    .width('100%')
    .padding({ left: 2, top: 1, bottom: 1 })
    .backgroundColor(Theme.CHROME_BG)
    .border({ width: { top: 1 }, color: Theme.LINE })
  }
}
