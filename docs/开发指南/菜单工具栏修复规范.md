# 菜单/工具栏缺陷修复 Spec（2026-07-28）

> 本文档是三层委派（L1 Qoder / L2 GLM-5.1 / L3 deepseek-v4-flash）的任务输入与验收依据。
> 背景与硬约束见 `docs/FEATURE_IMPLEMENTATION_PLAN.md` §1.3（C1 单窗口 QPA、C2 死锁防护等）。

## 一、根因结论（真机排查确认）

| 现象 | 根因 |
|---|---|
| File/Edit 下方及底部两行小图标、点击无反应 | Qt 原生 QToolBar 透过 XComponent 渲染（DPR=1 下桌面 16~24px 图标过小）；底部 24vp 被 ETS chrome band 吞掉点击；部分按钮触发 ToolTip/QMenu 弹出 SIGSEGV（crash1.txt：QToolButton→QToolTip::showText→QWidgetPrivate::create） |
| New Project 点击后延迟崩溃 | ETS 无 new_project 分支→menuAction 回退→`ApplicationWindow::newProject()`（ApplicationWindow.cpp L7447）new 第二个 ApplicationWindow 顶层窗口→单窗口 QPA SIGSEGV；fire-and-forget 队列导致"过一会儿才崩" |
| close_window 崩溃风险 | `MyWidget::closeEvent`（MyWidget.cpp L75）在 askOnClose=true（构造默认值）时弹 QMessageBox 三键确认框→C1 崩溃 |
| quit 假动作 | ETS 分支只打日志不退出 |
| 菜单项静默无响应 | menuAction 不支持项返回 jsonError，ETS default 分支只记日志，违反 F-01"未实现必须 Toast"规范 |

## 二、任务卡

### T1 隐藏 Qt 原生工具栏 — L1（已直接执行）
- `scidavis/scidavis/src/main.cpp` main() 中 `mw->applyUserSettings()` 后：遍历 `mw->findChildren<QToolBar*>()` 全部 hide()
- 验收：真机截图无任何小图标行；staging 副本同步

### T2 New Project 安全化 — L2（脚本 l2_fix1 / l2_fix2）
- C++（main.cpp menuAction 的 new_project 分支）：
  - 不再调用 newProject()；就地清空：`for (MyWidget *w : g_mainWindow->windowsList()) { w->askOnCloseEvent(false); w->close(); }`
  - 然后 `g_mainWindow->projectname = "untitled";`、`g_mainWindow->newTable();`（回到与冷启动一致的单空表状态）、`g_mainWindow->savedProject();`
  - 经 `scidavisEmitEvent("message", {title:"New Project", text:"Project cleared", icon:"information"})` 通知完成
- ETS（MainLayout.ets dispatchMenuItem）：新增 `new_project` 分支：`AlertDialog.show` 确认框（primaryButton Cancel / secondaryButton OK，文案 "Discard unsaved changes and start a new project?"），确认后 `callQtCommand('menuAction', {itemId:'new_project'})` 并 `this.projectPath = ''`、`refreshUiState()`
- 验收：录入数据→New Project→确认→单张空表、faultlog 零新增；取消则无动作

### T3 close_window / quit 弹窗防护 — L2（同 l2_fix1 / l2_fix2）
- C++（main() applyUserSettings 后）：`confirmCloseTable/Matrix/Plot2D/Plot3D/Folder/Notes` 全置 false（新窗口创建时会以这些值刷新 askOnClose）
- C++（menuAction close_window 分支）：close 前对活动窗口 `askOnCloseEvent(false)` 兜底（防项目文件载入的旧窗口）
- ETS（quit 分支）：`(getContext(this) as common.UIAbilityContext).terminateSelf()`
- 验收：close_window 直接关窗无弹框；quit 应用退出

### T4 未实现项 Toast — L2（l2_fix2）；审计表 — L3（l3_fix1，L1 预拟内容逐字写入）
- ETS default 分支：解析 menuAction 返回 JSON，`success === false` 时 `promptAction.showToast({ message: '功能开发中', duration: 2000 })`
- 审计表见本文档附录 A（回归清单）

### T5 ArkTS 工具栏 — 组件 L2（l2_fix3）/ 接线 L1
- 新建 `entry/src/main/ets/components/ToolBar.ets`：
  - `@Component export struct ToolBar`，高 32vp、背景 #F0F0F0、底边框 #CCCCCC，横向 Row 排列
  - 按钮组（SymbolGlyph systemResource 图标 + 分组分隔线）：new_table、open、save ｜ import、export ｜ cut、copy、paste ｜ undo、redo ｜ plot_line、plot_scatter
  - 接口：`onItemClick?: (itemId: string) => void`；`@Prop undoEnabled/redoEnabled/hasWin/isTable: boolean`（灰显控制：cut/copy/paste 随 hasWin，undo/redo 随各自 enabled，plot_* 随 isTable）
  - 禁用态图标 #A8A8A8 且吞点击；itemId 与菜单完全一致（复用同一分发）
- MainLayout 接线（L1）：MenuBar 下插入 ToolBar；`TOP_CHROME_VP = 60`（28 菜单 + 32 工具栏）替换 onTouch/onMouse 守卫中的 MENUBAR_HEIGHT_VP；scrim/dropdown y 偏移同步改；工具栏点击后 refreshUiState
- 本地化：en_US string.json 工具栏 tooltip 条目（L3）；zh_CN 由 L1 复核写入（教训：L3 不碰中文 JSON）
- 验收：uitest dumpLayout 可见 12 个按钮 bounds；逐个点击 hilog 出现与菜单一致的分发日志

### T6 构建、验证、提交 — L1
- ninja libentry.so → hvigorw assembleHap → hdc install（192.168.0.116:5555）
- 回归：T2 端到端、工具栏逐按钮、close_window/quit、faultlog 基线对比零新增
- 原子提交：fix(toolbar-hide) / fix(new-project) / fix(close-quit) / feat(ets-toolbar) / chore(l10n)；推送前征求确认

## 三、委派纪律

- 脚本落盘 `tools/delegate/l2_fix1.ps1`（C++）、`l2_fix2.ps1`（MainLayout.ets）、`l2_fix3.ps1`（ToolBar.ets）、`l3_fix1.ps1`（审计表+en_US），`-File` 执行
- L2/L3 不做设计决策；产出必经 L1 diff 审查后才构建；L3 失败→L2 重派，L2 失败→L1 接管并记录

## 附录 A：菜单项审计表（回归清单）

| 菜单 | itemId | 处理路径 | 真机状态（修复前→后） |
|---|---|---|---|
| File | new_project | menuAction→newProject() | 崩溃 → T2 就地清空 |
| File | new_table | 专用命令 newTable | 正常 |
| File | new_matrix / new_notes / new_graph | menuAction | 正常（MDI 子窗口，安全） |
| File | open / save / save_as | ETS picker + openProject/saveProject | 正常 |
| File | import / export | ETS 对话框 | 正常 |
| File | print | 灰显 | 安全 |
| File | quit | ETS 仅日志 | 假动作 → T3 terminateSelf |
| Edit | undo / redo / cut / copy / delete | menuAction | 正常 |
| Edit | paste | ETS 剪贴板桥 + menuAction | 正常 |
| Edit | preferences | ETS PreferencesDialog 桩 | 正常（逻辑未接线，下阶段） |
| View | project_browser / plots / tables / notes / log / script_console | ETS 本地 | 正常 |
| Table | add_columns / set_values / sort / statistics_* | ETS 对话框 + 专用命令 | 正常 |
| Matrix | set_dimensions / set_values / transpose / invert | ETS + 专用命令 | 正常 |
| Graph | graph_props / export_image | ETS + 专用命令 | 正常 |
| Graph | add_curve / add_error_bars / add_function / rescale | 灰显 | 安全 |
| Plot | plot_*（13 项） | ETS Plot2DDialog | 正常 |
| Plot | plot_3d | 灰显（timebox 桩） | 安全 |
| Analysis | an_*（11 项）/ correlate | ETS AnalysisDialog | 正常 |
| Windows | cascade / maximize / minimize / close_window | menuAction | close_window 有弹框风险 → T3 |
| Windows | win:* | activateWindow | 正常 |
| Help | help | 灰显 | 安全 |
| Help | about | menuAction→事件通道 | 正常 |
| （其余未列 id 落入 default） | — | menuAction 返回 unsupported | 静默 → T4 Toast（2026-07-28 起升级为附录 B 统一对话框） |

## 附录 B：工具栏按钮审计表（原始图标复刻，2026-07-28）

> ToolBar.ets 重写为 Windows 版 `initToolBars()` 1:1 布局（File/Edit/Graph/Plot 四组，
> 图标来自 `Desktop\scidavis\scidavis\icons` 原始 xpm→PNG + breeze svg，22vp）。
> 未适配提示**全局统一**为 AlertDialog「此功能还未适配完毕」（`$r('app.string.not_adapted')`，
> 三语 string.json），替代原 T4 Toast「功能开发中」。工具栏 id 与菜单同分发（onMenuItemClick）。

| 组 | 按钮（图标） | itemId | 处理路径 | 灰显条件 |
|---|---|---|---|---|
| File | new.xpm | new_project | ETS 确认框→就地清空（T2） | 恒可用 |
| File | new_aspect.xpm ▾ | new_table/new_matrix/new_notes/new_graph/new_function/new_surface | 前 4 项适配；后 2 项 default→对话框 | 恒可用 |
| File | fileopen.xpm | open | ETS picker | 恒可用 |
| File | open_template.xpm | open_template | default→未适配对话框 | 恒可用 |
| File | import.xpm | import | ETS ImportDialog | 恒可用 |
| File | filesave.xpm | save | ETS picker+saveProject | 恒可用 |
| File | save_template.xpm | save_template | default→未适配对话框 | 恒可用 |
| File | fileprint.xpm / pdf.xpm | print / export_pdf | default→未适配对话框 | 恒可用 |
| File | folder.xpm / log.xpm | project_browser / log | ETS 本地视图切换（View 菜单同款，已适配） | 恒可用 |
| Edit | edit-undo/redo.svg | undo / redo | menuAction | undoEnabled/redoEnabled |
| Edit | edit-cut/copy/paste.svg | cut / copy / paste | menuAction（paste 走剪贴板桥） | hasWin |
| Edit | erase.xpm | delete | menuAction | hasWin |
| Graph | pointer.xpm | graph_pointer | default→未适配对话框 | isGraph(MultiLayer) |
| Graph | arrangeLayers.xpm ▾ | auto_layout/add_layer/delete_layer/arrange_layers | default→未适配对话框 | isGraph |
| Graph | curves.xpm ▾ | add_curve/add_error_bars/add_function | default→未适配对话框 | isGraph |
| Graph | text.xpm ▾ | add_text/draw_arrow/draw_line/time_stamp/add_image/new_legend | default→未适配对话框 | isGraph |
| Graph | zoom/zoomOut/unzoom.xpm | zoom_in / zoom_out / rescale | default→未适配对话框 | isGraph |
| Graph | cursor_16/select/cursors.xpm | screen_reader / data_reader / select_range | default→未适配对话框 | isGraph |
| Plot | lpPlot.xpm ▾ | plot_line/plot_scatter/plot_line_symbol/plot_spline/plot_drop_lines/plot_horizontal_steps/plot_vertical_steps | ETS Plot2DDialog（已适配） | isTable |
| Plot | vertBars.xpm ▾ | plot_vertical_bars/plot_horizontal_bars | ETS Plot2DDialog（已适配） | isTable |
| Plot | area/pie/histogram/boxPlot.xpm | plot_area/plot_pie/plot_histogram/plot_box | ETS Plot2DDialog（已适配） | isTable |
| Plot | vectXYXY.xpm ▾ | plot_vect_xyxy/plot_vect_xyam | default→未适配对话框 | isTable |
| Plot | ribbon/bars/scatter/trajectory.xpm | plot3d_ribbon/plot3d_bars/plot3d_scatter/plot3d_trajectory | default→未适配对话框 | isTable |

- 旧版 12 按钮 SymbolGlyph 工具栏（T5）已被本表布局取代；`export`（Export ASCII）按钮移除——Windows 工具栏无此按钮，功能保留在 File 菜单。
- `lock.xpm`（锁定工具栏）与 `newFunction.xpm`（icons 根目录缺失）按"图片搁置"原则未摆放。

## 附录 C：真机验证结论与缺陷修复记录（2026-07-28，设备 192.168.0.116）

自动化脚本 `tools/verify_toolbar.py`（uitest uiInput + dumpLayout + hilog 断言）逐按钮回归：
**最终 run6 = 39 项检查全部 PASS、0 FAIL**（日志 `tools/_vt_run6.log`）；
`hilog -T FaultLogger` 过滤 cppcrash/appfreeze **零新增**；截图 `tools/shots/tb_final.jpeg`。

验证过程中发现并修复三个真缺陷：

| # | 缺陷 | 根因 | 修复 |
|---|---|---|---|
| C-1 | 未适配按钮不弹对话框 | menuAction 是 mutation 命令，scidavis_call 队列化后立即返回 `{"success":true,"queued":true}`，Qt 侧 unsupported 错误永远到不了 ETS，`resp.success===false` 分支形同虚设 | MainLayout.ets 新增 `MENU_ACTION_SUPPORTED` 白名单（15 项，与 main.cpp L1296-1357 镜像），default 分支先查白名单、不在则直接 showNotAdapted()，不发 Qt |
| C-2 | 建表后 Edit/Plot 组仍灰显（uiState 已正确返回 Table） | ArkTS `@Builder` 按值传参在首次渲染时冻结，@Prop 后续变化不触发 Builder 重渲染 | ToolBar.ets 两个 Builder 改为按引用传参（`ToolButton($$: TbButtonOpts)` 单对象字面量形式），38 处调用点同步重写 |
| C-3 | Plot 组按钮点击被吞（脚本 10 项 FAIL、手测偶发） | Results Log / ProjectTree 浮动面板 `position.y = MENUBAR_HEIGHT_VP+8`（36vp）盖住工具栏带（65..127px）；uitest hit-test 证实遮挡节点 `Column [1277,79][2407,1039]` 拦截点击 | 两面板 y 改 `TOP_CHROME_VP+8`（68vp，工具栏之下）；脚本侧加 `ensure_log_panel_closed()` 防 toggle 奇偶错位 |

其他验证结论：
- 建表后 `undoEnabled` 变 true（aspect 添加入 Qt undo 栈）——undo/redo 灰显断言必须在建表前执行。
- bindMenu 下拉偶发首击无响应，脚本以重试 3 次防御（面板遮挡修复后大幅减少）。
- Graph 组 10 项在 Table 激活时灰显正确（enabled=false / opacity 0.40，dumpLayout 证实）。
