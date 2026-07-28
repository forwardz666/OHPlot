# L2 fix3: T5 — new ArkTS ToolBar component (GLM-5.1).
# cwd = repo root so the agent can read the ohos/ tree.
$root = 'c:\Users\Forwardz\scidavis-ohos'

$task = @'
任务：新建 ArkTS 文件 ohos/entry/src/main/ets/components/ToolBar.ets（HarmonyOS NEXT，ArkTS 严格模式），实现 OHPlot 主界面工具栏组件。风格参考同目录 ohos/entry/src/main/ets/components/MenuBar.ets（可读它，但不要改它）。只新建这一个文件，不要改仓库其他文件。

组件契约（必须完全一致，父组件按此接线）：
@Component
export struct ToolBar {
  @Prop undoEnabled: boolean = false;
  @Prop redoEnabled: boolean = false;
  @Prop hasWin: boolean = false;      // 有活动 MDI 窗口
  @Prop isTable: boolean = false;     // 活动窗口是 Table
  onItemClick?: (itemId: string) => void;
}

按钮定义（顺序、id、图标、灰显条件；id 与菜单项完全一致，点击即调 this.onItemClick(id)）：
组1: new_table（SymbolGlyph $r('sys.symbol.plus')）、open（$r('sys.symbol.folder')）、save（$r('sys.symbol.save')）——恒可用
组2: import（$r('sys.symbol.arrow_down_and_square')）、export（$r('sys.symbol.arrow_up_and_square')）——export 需 hasWin
组3: cut（$r('sys.symbol.scissor')）、copy（$r('sys.symbol.plus_square_on_square')）、paste（$r('sys.symbol.doc_on_clipboard')）——cut/copy 需 hasWin
组4: undo（$r('sys.symbol.arrow_counterclockwise')）、redo（$r('sys.symbol.arrow_clockwise')）——分别用 undoEnabled/redoEnabled
组5: plot_line（$r('sys.symbol.chart_line_uptrend_xyaxis')）、plot_scatter（$r('sys.symbol.chart_scatter_dot')）——需 isTable
注：若某个 sys.symbol 资源名在 SDK 中不存在导致编译报错，可换用语义最接近的现有 sys.symbol 名并在行尾注释注明替换；禁止使用自定义资源。

布局与样式（与 28vp 菜单栏衔接，桌面工具栏观感）：
- 最外层 Row，width('100%')，height(32)，backgroundColor('#F0F0F0')，border({ width: { bottom: 1 }, color: '#CCCCCC' })，padding({ left: 4 })
- 每个按钮：Column 容器包 SymbolGlyph，fontSize(20)，按钮整体 width(30) height(28)，justifyContent(FlexAlign.Center)，borderRadius(4)
- 图标颜色：可用时 fontColor([Color.Black])，灰显时 fontColor(['#A8A8A8'])（SymbolGlyph 的 fontColor 接收数组）
- 灰显按钮 onClick 直接 return（吞掉点击），与 MenuBar 的 disabled 行为一致；可用按钮 onClick 调 this.onItemClick?.(id)
- 组与组之间放 1vp 宽、20vp 高、backgroundColor('#CCCCCC') 的 Row 作竖分隔线，margin({ left: 4, right: 4 })
- 按下反馈：给按钮加 .stateStyles({ pressed: { .backgroundColor('#D0D0D0') } }) 或等价的简单实现（可选，编译错误就去掉）
- 按钮实现建议用 @Builder 方法（如 @Builder ToolButton(id: string, symbol: Resource, enabled: boolean)）避免重复代码；ForEach 或逐个调用均可
- 文件头加简短英文注释块说明用途（OHPlot toolbar, replaces the hidden native Qt toolbars; ids reuse the menu dispatch）

ArkTS 严格模式硬性要求：禁止 any/unknown；对象字面量必须有显式类型；@Builder 内不能用箭头函数捕获循环变量以外的复杂逻辑；hilog 不需要引入（本组件不打日志）。完成后回复 done 并给出文件行数。
'@

Set-Location $root
deveco run $task --model deveco/GLM-5.1 2>&1
