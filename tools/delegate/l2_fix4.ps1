# L2 fix4: rebuild ToolBar.ets with original SciDAVis icons, full 4-toolbar Windows layout (GLM-5.1).
# cwd = repo root so the agent can read the ohos/ tree.
$root = 'c:\Users\Forwardz\scidavis-ohos'

$task = @'
任务：完全重写 ohos/entry/src/main/ets/components/ToolBar.ets（HarmonyOS NEXT，ArkTS 严格模式），用 SciDAVis 桌面版原始图标复刻 Windows 版 4 条工具栏（File/Edit/Graph/Plot）。图标 PNG/SVG 资源已放入 ohos/entry/src/main/resources/base/media/（tb_*.png / tb_edit_*.svg），直接 $r('app.media.tb_xxx') 引用。只改这一个文件，不要改仓库其他文件。风格参考现有 ToolBar.ets（先读旧版再整体替换）。

组件契约（父组件按此接线，必须完全一致）：
@Component
export struct ToolBar {
  @Prop undoEnabled: boolean = false;
  @Prop redoEnabled: boolean = false;
  @Prop hasWin: boolean = false;      // 有活动 MDI 窗口
  @Prop isTable: boolean = false;     // 活动窗口是 Table
  @Prop isGraph: boolean = false;     // 活动窗口是 2D 图 (MultiLayer)
  onItemClick?: (itemId: string) => void;
}

普通按钮：点击调 this.onItemClick?.(id)。灰显（enabled=false）时 .opacity(0.4) 且 onClick 直接 return。
下拉按钮：Image 右下角不用加角标；用 .bindMenu(this.XxxMenu()) 弹 ArkUI Menu，Menu 内每个 MenuItem 点击调 this.onItemClick?.(子id)；下拉按钮灰显时用 .enabled(false)（阻断 bindMenu）+ .opacity(0.4)。
所有按钮外观：Column 容器包 Image($r('app.media.tb_xxx')).width(22).height(22).objectFit(ImageFit.Contain).draggable(false)；按钮整体 width(30) height(28) justifyContent(FlexAlign.Center) borderRadius(4)。
最外层 Row：width('100%') height(32) backgroundColor('#F0F0F0') border({ width: { bottom: 1 }, color: '#CCCCCC' }) padding({ left: 4 })。
组间分隔线：Row 1vp 宽 20vp 高 backgroundColor('#CCCCCC') margin({ left: 4, right: 4 })。
ForEach 的 key 必须含 enabled 位（如 btn.id + (btn.enabled ? '_1' : '_0')），否则灰显状态不刷新（既往真机缺陷）。

按钮总表（顺序即排布顺序；┃=组间分隔线；▾=下拉按钮）：

【File 组（全部恒可用 enabled=true）】
1. new_project — tb_new
2. ▾New Aspect — tb_new_aspect，菜单项：
   new_table「New Table」图标 tb_table
   new_matrix「New Matrix」图标 tb_new_matrix
   new_notes「New Note」图标 tb_new_note
   new_graph「New Graph」图标 tb_new_graph
   new_function「New Function Plot」无图标
   new_surface「New 3D Surface Plot」无图标
3. open — tb_fileopen
4. open_template — tb_open_template
5. import — tb_import
6. save — tb_filesave
7. save_template — tb_save_template
┃
8. print — tb_fileprint
9. export_pdf — tb_pdf
┃
10. show_explorer — tb_folder
11. show_log — tb_log
┃
【Edit 组】
12. undo — tb_edit_undo（svg）— enabled: this.undoEnabled
13. redo — tb_edit_redo（svg）— enabled: this.redoEnabled
14. cut — tb_edit_cut（svg）— enabled: this.hasWin
15. copy — tb_edit_copy（svg）— enabled: this.hasWin
16. paste — tb_edit_paste（svg）— enabled: this.hasWin
17. delete — tb_erase — enabled: this.hasWin
┃
【Graph 组（全部 enabled: this.isGraph）】
18. graph_pointer — tb_pointer
┃（组内小分隔线，Windows 原样）
19. ▾Manage layers — tb_arrangelayers，菜单项（无图标）：
   auto_layout「Automatic Layout」
   add_layer「Add Layer」
   delete_layer「Remove Layer」
   arrange_layers「Arrange Layers...」
20. ▾Add curves — tb_curves，菜单项（无图标）：
   add_curve「Add/Remove Curve...」
   add_error_bars「Add Error Bars...」
   add_function「Add Function...」
21. ▾Enrichments — tb_text，菜单项（无图标）：
   add_text「Add Text」
   draw_arrow「Draw Arrow」
   draw_line「Draw Line」
   time_stamp「Add Time Stamp」
   add_image「Add Image」
   new_legend「New Legend」
┃（组内小分隔线）
22. zoom_in — tb_zoom
23. zoom_out — tb_zoomout
24. rescale — tb_unzoom
┃（组内小分隔线）
25. screen_reader — tb_cursor_16
26. data_reader — tb_select
27. select_range — tb_cursors
┃
【Plot 组（全部 enabled: this.isTable）】
28. ▾Lines and/or symbols — tb_lpplot，菜单项：
   plot_line「Line」图标 tb_lplot
   plot_scatter「Scatter」图标 tb_pplot
   plot_line_symbol「Line + Symbol」图标 tb_lpplot
   plot_spline「Spline」无图标
   plot_drop_lines「Vertical Drop Lines」无图标
   plot_horizontal_steps「Horizontal Steps」无图标
   plot_vertical_steps「Vertical Steps」无图标
29. ▾Bars — tb_vertbars，菜单项（无图标）：
   plot_vertical_bars「Vertical Bars」
   plot_horizontal_bars「Horizontal Bars」
30. plot_area — tb_area
31. plot_pie — tb_pie
32. plot_histogram — tb_histogram
33. plot_box — tb_boxplot
34. ▾Vectors — tb_vectxyxy，菜单项（无图标）：
   plot_vect_xyxy「Vectors XYXY」
   plot_vect_xyam「Vectors XYAM」
┃（组内小分隔线）
35. plot3d_ribbon — tb_ribbon
36. plot3d_bars — tb_bars
37. plot3d_scatter — tb_scatter
38. plot3d_trajectory — tb_trajectory

实现建议（可微调但不许改契约与按钮表）：
- interface ToolBtnDef { id: string; icon: Resource; enabled: boolean; } 显式类型，禁止 any/unknown
- @Builder ToolButton(id: string, icon: Resource, enabled: boolean) 复用普通按钮
- 下拉菜单用 @Builder XxxMenu() { Menu() { MenuItem({ content: '...' , startIcon: 可选 }).onClick(...) } }；MenuItem 有图标时用 startIcon: $r('app.media.tb_xxx')
- Graph/Plot 组随 @Prop 变化必须即时刷新灰显（ForEach key 带 enabled 位；下拉按钮不在 ForEach 里则直接读 this.isGraph/this.isTable）
- 文件头保留简短英文注释块（OHPlot toolbar, original SciDAVis desktop icons, replicates the Windows File/Edit/Graph/Plot toolbars; ids reuse the menu dispatch）
- 本组件不打日志、不 import hilog

完成后回复 done 并给出文件总行数。
'@

Set-Location $root
deveco run $task --model deveco/GLM-5.1 2>&1
