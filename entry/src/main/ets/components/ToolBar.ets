// OHPlot toolbar, replaces the hidden native Qt toolbars; ids reuse the menu dispatch

interface ToolBtnDef {
  id: string;
  symbol: Resource;
  enabled: boolean;
}

@Component
export struct ToolBar {
  @Prop undoEnabled: boolean = false;
  @Prop redoEnabled: boolean = false;
  @Prop hasWin: boolean = false;
  @Prop isTable: boolean = false;
  onItemClick?: (itemId: string) => void;

  private fileGroup(): ToolBtnDef[] {
    const items: ToolBtnDef[] = [
      { id: 'new_table', symbol: $r('sys.symbol.plus'), enabled: true },
      { id: 'open', symbol: $r('sys.symbol.folder'), enabled: true },
      { id: 'save', symbol: $r('sys.symbol.save'), enabled: true },
    ];
    return items;
  }

  private ioGroup(): ToolBtnDef[] {
    const items: ToolBtnDef[] = [
      // arrow_down_and_square / arrow_up_and_square not in SDK; replaced with closest available
      { id: 'import', symbol: $r('sys.symbol.arrow_down_circle'), enabled: true },
      { id: 'export', symbol: $r('sys.symbol.doc_text_badge_arrow_up'), enabled: this.hasWin },
    ];
    return items;
  }

  private editGroup(): ToolBtnDef[] {
    const items: ToolBtnDef[] = [
      // scissor not in SDK; replaced with square_and_pencil (edit/cut)
      { id: 'cut', symbol: $r('sys.symbol.square_and_pencil'), enabled: this.hasWin },
      { id: 'copy', symbol: $r('sys.symbol.plus_square_on_square'), enabled: this.hasWin },
      // doc_on_clipboard not in SDK; replaced with doc_text_on_doc_text (closest paste/clipboard icon)
      { id: 'paste', symbol: $r('sys.symbol.doc_text_on_doc_text'), enabled: true },
    ];
    return items;
  }

  private undoRedoGroup(): ToolBtnDef[] {
    const items: ToolBtnDef[] = [
      { id: 'undo', symbol: $r('sys.symbol.arrow_counterclockwise'), enabled: this.undoEnabled },
      { id: 'redo', symbol: $r('sys.symbol.arrow_clockwise'), enabled: this.redoEnabled },
    ];
    return items;
  }

  private plotGroup(): ToolBtnDef[] {
    const items: ToolBtnDef[] = [
      // chart_line_uptrend_xyaxis / chart_scatter_dot not in SDK; replaced with closest available
      { id: 'plot_line', symbol: $r('sys.symbol.arrow_up_circle'), enabled: this.isTable },
      { id: 'plot_scatter', symbol: $r('sys.symbol.square_grid_2x2'), enabled: this.isTable },
    ];
    return items;
  }

  private iconColor(enabled: boolean): ResourceColor[] {
    if (enabled) {
      const c: ResourceColor[] = [Color.Black];
      return c;
    }
    const c: ResourceColor[] = ['#A8A8A8'];
    return c;
  }

  @Builder
  ToolButton(id: string, symbol: Resource, enabled: boolean) {
    Column() {
      SymbolGlyph(symbol)
        .fontSize(20)
        .fontColor(this.iconColor(enabled))
    }
    .width(30)
    .height(28)
    .justifyContent(FlexAlign.Center)
    .borderRadius(4)
    .onClick(() => {
      if (!enabled) {
        return;
      }
      if (this.onItemClick) {
        this.onItemClick(id);
      }
    })
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
    Row() {
      ForEach(this.fileGroup(), (btn: ToolBtnDef) => {
        this.ToolButton(btn.id, btn.symbol, btn.enabled)
      }, (btn: ToolBtnDef) => btn.id + (btn.enabled ? '_1' : '_0'))
      this.Separator()
      ForEach(this.ioGroup(), (btn: ToolBtnDef) => {
        this.ToolButton(btn.id, btn.symbol, btn.enabled)
      }, (btn: ToolBtnDef) => btn.id + (btn.enabled ? '_1' : '_0'))
      this.Separator()
      ForEach(this.editGroup(), (btn: ToolBtnDef) => {
        this.ToolButton(btn.id, btn.symbol, btn.enabled)
      }, (btn: ToolBtnDef) => btn.id + (btn.enabled ? '_1' : '_0'))
      this.Separator()
      ForEach(this.undoRedoGroup(), (btn: ToolBtnDef) => {
        this.ToolButton(btn.id, btn.symbol, btn.enabled)
      }, (btn: ToolBtnDef) => btn.id + (btn.enabled ? '_1' : '_0'))
      this.Separator()
      ForEach(this.plotGroup(), (btn: ToolBtnDef) => {
        this.ToolButton(btn.id, btn.symbol, btn.enabled)
      }, (btn: ToolBtnDef) => btn.id + (btn.enabled ? '_1' : '_0'))
    }
    .width('100%')
    .height(32)
    .backgroundColor('#F0F0F0')
    .border({ width: { bottom: 1 }, color: '#CCCCCC' })
    .padding({ left: 4 })
  }
}
