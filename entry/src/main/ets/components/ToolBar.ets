// OHPlot toolbar — original SciDAVis desktop icons (converted from
// scidavis/icons *.xpm and icons/light/24 *.svg), replicating the Windows
// File / Edit / Graph / Plot toolbars 1:1; ids reuse the menu dispatch.
// Buttons are emitted directly (no ForEach) so @Prop changes always
// refresh the greyed state (past ForEach-key defect on device).

// @Builder by-reference parameter shapes: passing one object literal keeps
// the enabled flags reactive (see the Builders note inside ToolBar).
interface TbButtonOpts {
  id: string;
  icon: Resource;
  enabled: boolean;
}

interface TbDropOpts {
  icon: Resource;
  enabled: boolean;
  menu: MenuElement[];
}

@Component
export struct ToolBar {
  @Prop undoEnabled: boolean = false;
  @Prop redoEnabled: boolean = false;
  @Prop hasWin: boolean = false;      // an MDI window is active
  @Prop isTable: boolean = false;     // active window is a Table
  @Prop isGraph: boolean = false;     // active window is a 2D plot (MultiLayer)
  onItemClick?: (itemId: string) => void;

  private fire(itemId: string): void {
    if (this.onItemClick) {
      this.onItemClick(itemId);
    }
  }

  // ── Dropdown menus (Windows QToolButton InstantPopup equivalents) ──

  // File ▸ New Aspect (new_aspect.xpm button)
  private newAspectMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: 'New Table', icon: $r('app.media.tb_table'), action: (): void => this.fire('new_table') },
      { value: 'New Matrix', icon: $r('app.media.tb_new_matrix'), action: (): void => this.fire('new_matrix') },
      { value: 'New Note', icon: $r('app.media.tb_new_note'), action: (): void => this.fire('new_notes') },
      { value: 'New Graph', icon: $r('app.media.tb_new_graph'), action: (): void => this.fire('new_graph') },
      { value: 'New Function Plot', action: (): void => this.fire('new_function') },
      { value: 'New 3D Surface Plot', action: (): void => this.fire('new_surface') }
    ];
    return items;
  }

  // Graph ▸ Manage layers (arrangeLayers.xpm button)
  private layersMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: 'Automatic Layout', action: (): void => this.fire('auto_layout') },
      { value: 'Add Layer', action: (): void => this.fire('add_layer') },
      { value: 'Remove Layer', action: (): void => this.fire('delete_layer') },
      { value: 'Arrange Layers...', action: (): void => this.fire('arrange_layers') }
    ];
    return items;
  }

  // Graph ▸ Add curves / error bars (curves.xpm button)
  private curvesMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: 'Add/Remove Curve...', action: (): void => this.fire('add_curve') },
      { value: 'Add Error Bars...', action: (): void => this.fire('add_error_bars') },
      { value: 'Add Function...', action: (): void => this.fire('add_function') }
    ];
    return items;
  }

  // Graph ▸ Enrichments (text.xpm button)
  private enrichmentsMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: 'Add Text', action: (): void => this.fire('add_text') },
      { value: 'Draw Arrow', action: (): void => this.fire('draw_arrow') },
      { value: 'Draw Line', action: (): void => this.fire('draw_line') },
      { value: 'Add Time Stamp', action: (): void => this.fire('time_stamp') },
      { value: 'Add Image', action: (): void => this.fire('add_image') },
      { value: 'New Legend', action: (): void => this.fire('new_legend') }
    ];
    return items;
  }

  // Plot ▸ Lines and/or symbols (lpPlot.xpm button)
  private linesMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: 'Line', icon: $r('app.media.tb_lplot'), action: (): void => this.fire('plot_line') },
      { value: 'Scatter', icon: $r('app.media.tb_pplot'), action: (): void => this.fire('plot_scatter') },
      { value: 'Line + Symbol', icon: $r('app.media.tb_lpplot'), action: (): void => this.fire('plot_line_symbol') },
      { value: 'Spline', action: (): void => this.fire('plot_spline') },
      { value: 'Vertical Drop Lines', action: (): void => this.fire('plot_drop_lines') },
      { value: 'Horizontal Steps', action: (): void => this.fire('plot_horizontal_steps') },
      { value: 'Vertical Steps', action: (): void => this.fire('plot_vertical_steps') }
    ];
    return items;
  }

  // Plot ▸ Bars (vertBars.xpm button)
  private barsMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: 'Vertical Bars', action: (): void => this.fire('plot_vertical_bars') },
      { value: 'Horizontal Bars', action: (): void => this.fire('plot_horizontal_bars') }
    ];
    return items;
  }

  // Plot ▸ Vectors (vectXYXY.xpm button)
  private vectorsMenu(): MenuElement[] {
    const items: MenuElement[] = [
      { value: 'Vectors XYXY', action: (): void => this.fire('plot_vect_xyxy') },
      { value: 'Vectors XYAM', action: (): void => this.fire('plot_vect_xyam') }
    ];
    return items;
  }

  // ── Builders ──
  // Device-verified defect: @Builder value-parameters are frozen at first
  // render (ArkTS by-value passing is not reactive), which left Edit/Plot
  // buttons permanently greyed after uiState refreshes.  Parameters are
  // therefore passed as a single object literal — the documented
  // by-reference form that keeps @Prop-driven greying live.

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
    .opacity($$.enabled ? 1.0 : 0.4)
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
    .opacity($$.enabled ? 1.0 : 0.4)
    .enabled($$.enabled)
    .bindMenu($$.menu)
  }

  @Builder
  Separator() {
    Row()
      .width(1)
      .height(20)
      .backgroundColor('#CCCCCC')
      .margin({ left: 4, right: 4 })
  }

  build() {
    // Horizontal Scroll = OHOS stand-in for QToolBar's overflow extension:
    // 38 buttons x 30vp exceed narrow screens (tablet is ~1116vp @ DPR 2.2),
    // so the tail Plot3D group must stay reachable without shrinking icons.
    Scroll() {
      Row() {
      // ── File toolbar (ApplicationWindow::initToolBars file_tools) ──
      this.ToolButton({ id: 'new_project', icon: $r('app.media.tb_new'), enabled: true })
      this.DropButton({ icon: $r('app.media.tb_new_aspect'), enabled: true, menu: this.newAspectMenu() })
      this.ToolButton({ id: 'open', icon: $r('app.media.tb_fileopen'), enabled: true })
      this.ToolButton({ id: 'open_template', icon: $r('app.media.tb_open_template'), enabled: true })
      this.ToolButton({ id: 'import', icon: $r('app.media.tb_import'), enabled: true })
      this.ToolButton({ id: 'save', icon: $r('app.media.tb_filesave'), enabled: true })
      this.ToolButton({ id: 'save_template', icon: $r('app.media.tb_save_template'), enabled: true })
      this.Separator()
      this.ToolButton({ id: 'print', icon: $r('app.media.tb_fileprint'), enabled: true })
      this.ToolButton({ id: 'export_pdf', icon: $r('app.media.tb_pdf'), enabled: true })
      this.Separator()
      this.ToolButton({ id: 'project_browser', icon: $r('app.media.tb_folder'), enabled: true })
      this.ToolButton({ id: 'log', icon: $r('app.media.tb_log'), enabled: true })
      this.Separator()

      // ── Edit toolbar (edit_tools) ──
      this.ToolButton({ id: 'undo', icon: $r('app.media.tb_edit_undo'), enabled: this.undoEnabled })
      this.ToolButton({ id: 'redo', icon: $r('app.media.tb_edit_redo'), enabled: this.redoEnabled })
      this.ToolButton({ id: 'cut', icon: $r('app.media.tb_edit_cut'), enabled: this.hasWin })
      this.ToolButton({ id: 'copy', icon: $r('app.media.tb_edit_copy'), enabled: this.hasWin })
      this.ToolButton({ id: 'paste', icon: $r('app.media.tb_edit_paste'), enabled: this.hasWin })
      this.ToolButton({ id: 'delete', icon: $r('app.media.tb_erase'), enabled: this.hasWin })
      this.Separator()

      // ── Graph toolbar (graph_tools; greyed unless a 2D plot is active) ──
      this.ToolButton({ id: 'graph_pointer', icon: $r('app.media.tb_pointer'), enabled: this.isGraph })
      this.Separator()
      this.DropButton({ icon: $r('app.media.tb_arrangelayers'), enabled: this.isGraph, menu: this.layersMenu() })
      this.DropButton({ icon: $r('app.media.tb_curves'), enabled: this.isGraph, menu: this.curvesMenu() })
      this.DropButton({ icon: $r('app.media.tb_text'), enabled: this.isGraph, menu: this.enrichmentsMenu() })
      this.Separator()
      this.ToolButton({ id: 'zoom_in', icon: $r('app.media.tb_zoom'), enabled: this.isGraph })
      this.ToolButton({ id: 'zoom_out', icon: $r('app.media.tb_zoomout'), enabled: this.isGraph })
      this.ToolButton({ id: 'rescale', icon: $r('app.media.tb_unzoom'), enabled: this.isGraph })
      this.Separator()
      this.ToolButton({ id: 'screen_reader', icon: $r('app.media.tb_cursor_16'), enabled: this.isGraph })
      this.ToolButton({ id: 'data_reader', icon: $r('app.media.tb_select'), enabled: this.isGraph })
      this.ToolButton({ id: 'select_range', icon: $r('app.media.tb_cursors'), enabled: this.isGraph })
      this.Separator()

      // ── Plot toolbar (plot_tools; greyed unless a Table is active) ──
      this.DropButton({ icon: $r('app.media.tb_lpplot'), enabled: this.isTable, menu: this.linesMenu() })
      this.DropButton({ icon: $r('app.media.tb_vertbars'), enabled: this.isTable, menu: this.barsMenu() })
      this.ToolButton({ id: 'plot_area', icon: $r('app.media.tb_area'), enabled: this.isTable })
      this.ToolButton({ id: 'plot_pie', icon: $r('app.media.tb_pie'), enabled: this.isTable })
      this.ToolButton({ id: 'plot_histogram', icon: $r('app.media.tb_histogram'), enabled: this.isTable })
      this.ToolButton({ id: 'plot_box', icon: $r('app.media.tb_boxplot'), enabled: this.isTable })
      this.DropButton({ icon: $r('app.media.tb_vectxyxy'), enabled: this.isTable, menu: this.vectorsMenu() })
      this.Separator()
      this.ToolButton({ id: 'plot3d_ribbon', icon: $r('app.media.tb_ribbon'), enabled: this.isTable })
      this.ToolButton({ id: 'plot3d_bars', icon: $r('app.media.tb_bars'), enabled: this.isTable })
      this.ToolButton({ id: 'plot3d_scatter', icon: $r('app.media.tb_scatter'), enabled: this.isTable })
      this.ToolButton({ id: 'plot3d_trajectory', icon: $r('app.media.tb_trajectory'), enabled: this.isTable })
      }
      .padding({ left: 4 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
    .width('100%')
    .height(32)
    .backgroundColor('#F0F0F0')
    .border({ width: { bottom: 1 }, color: '#CCCCCC' })
  }
}
