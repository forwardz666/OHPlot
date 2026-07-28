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
| （其余未列 id 落入 default） | — | menuAction 返回 unsupported | 静默 → T4 Toast |
