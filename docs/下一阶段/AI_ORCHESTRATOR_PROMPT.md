# OHPlot (SciDAVis OHOS) 一日修复任务 — AI 编排器指令

> 生成时间：2026-07-30 | 基于完整代码审查产出

---

## 0. 核心工作流约束（MANDATORY，违反即失败）

### 0.1 需求澄清义务
- 在开始任何工作之前，AI 编排器必须**逐条检查**每项任务的需求是否明确。
- **如果任何需求不明确**，必须立即向我提问，不得自行假设。
- 持续提问直到所有需求都明确为止。在得到我确认之前，不得开始实施。

### 0.2 禁止直接修改代码
- **AI 编排器自身不得修改任何代码文件。** 零例外。
- 所有代码修改必须通过委派子代理执行。
- 职责仅限于：需求分析 → 创建 Todo → 委派子代理 → 收集结果 → Code Review → 汇总报告。

### 0.3 Todo 文档强制
- 在开始实施前，必须使用 todowrite 创建详细待办清单。
- 每个 Todo 标题包含：文件名、做什么、为什么、预期结果。
- 每完成一项立即更新状态，不得跳过或合并。

### 0.4 委派与审查分离
- 每个原子任务必须委派给子代理。
- 子代理的 prompt 必须包含：目标、涉及文件、实现思路、验收标准、约束条件。
- 每项任务完成后，派出另一个子代理进行 Code Review。
- Review 不通过 → 标记 failed，回退修改，向我报告。

### 0.5 完成确认与汇报
- 逐一确认 Todos 全部 completed 或 failed
- 运行 lsp_diagnostics 检查修改过的文件
- 运行 python tools/verify_smoke.py 执行静态检查
- 提交总结报告
## 1. 项目背景

### 1.1 项目结构
项目根目录: C:\Users\Forwardz\scidavis-ohos\ohos

ohos/entry/src/main/ets/:
  pages/ - 主页面
    Index.ets - 入口: XComponent + MainLayout
    MainLayout.ets - 主布局(1250行)
    TablePage.ets - 表格页面
    PlotPage.ets - 绘图页面
    NoteEditor.ets - 笔记编辑器
    dialogs/ - 10个对话框
  components/ - UI组件
    DataTable.ets - 数据表格(275行)
    MenuBar.ets - 菜单栏+下拉菜单
    ToolBar.ets - 顶部工具栏
    PlotCanvas.ets - Canvas 2D绘图
    QtEventHost.ets - Qt事件宿主(426行)
  entryability/
    OHPlotAbility.ets - 主Ability(381行)
  native/ - JS桥接对象(6个)
ohos/entry/src/main/cpp/:
  qohos.cpp - NAPI原生模块(450行)

### 1.2 架构
ArkTS前端(ArkUI) -NAPI-> qohos.cpp桥接层 -dlsym-> Qt/C++后端(libentry.so)
通信方式: callQtCommand + sendMouse + onQtEvent(TSFN)

### 1.3 关键约束
C1: 单窗口QPA - Qt创建QDialog会SIGSEGV, 所有对话框必须用ArkTS实现
C2: 死锁防护 - 变更命令fire-and-forget, 查询命令3s超时
C3: QPA handleKeyEvent的text()恒空, 文本输入必须走IME或JSON直传
C4: 所有callQtCommand必须try-catch包裹
C5: 禁止any类型, 禁止require()
C6: 涉及scidavis/目录修改, 必须先问我是否允许

---

## 2. 今日修复任务

### 执行顺序说明
第一批(先诊断后执行, 可并行):
  任务G: 修复DataTable缺第一行和标题行(先诊断根因, 汇报后再修复)
  任务T0: 修复Qt内容被工具栏遮挡(需确认Qt侧修改权限)
  任务B: KeyTextFixer扩展(字母键+符号键, 需确认Qt侧权限)

第二批(可并行, 依赖第一批):
  任务A: DataTable单元格编辑完整实现(依赖G的修复)
  任务C: scidavis_call分发器扩展(需确认Qt侧权限)
  任务T1: Windows菜单窗口列表去重(ArkTS侧)

第三批(依赖第二批):
  任务D: 偏好设置持久化接线(需确认Qt侧权限)
  任务E: 实时数据刷新机制(ArkTS侧)
  任务T3: PlotCanvas多层图支持(ArkTS侧)

第四批(依赖第三批):
  任务F: 数据变更事件推送(Qt侧, 依赖E就绪)

独立(可随时并行):
  任务T4: DataTable列宽自适应(ArkTS侧)
  任务T5: NoteEditor连接Qt后端(需确认Qt侧权限)
  任务T6: 分析结果日志自动滚到底部(ArkTS侧)
---

### 任务G: 修复DataTable/矩阵显示缺第一行和标题行 - P0

现象: 表格第一行数据不显示, 内容从第二行开始; 列标题行不可见
涉及文件: entry/src/main/ets/components/DataTable.ets, pages/TablePage.ets, 可能涉及Qt侧getTableData
诊断思路(必须先诊断后修复):
1. 在loadCurrentTable()中增加日志, 打印getTableData的原始JSON响应
2. 检查colNames数组是否为空, data数组长度是否比rows少1
3. 检查ForEach渲染逻辑和Stack布局
验收标准: 第一行完整显示, 标题行可见, 行号从1开始, 矩阵也同样修复
约束: 先诊断后修复, 根因在Qt侧需问我是否允许修改

---

### 任务T0: 修复Qt内容被ArkTS工具栏遮挡 - P0

现象: Qt渲染内容被菜单栏/工具栏/状态栏遮挡
根因: setChromeInsets命令在C++端可能缺失, QMainWindow.setContentsMargins从未被调用
涉及文件: scidavis/src/main.cpp(C++端注册), MainLayout.ets(ArkTS端验证)
验收标准: Qt内容上下边距对齐ArkTS chrome, 工具栏高度变化时同步更新
约束: 需确认是否允许修改scidavis/src/main.cpp

---

### 任务B: KeyTextFixer扩展(字母键+符号键) - P0

现象: 蓝牙键盘只能输入数字键, 字母键和符号键无法输入
根因: KeyTextFixer事件过滤器只处理了数字键的text合成
涉及文件: scidavis/src/下的KeyTextFixer实现(需先找到位置)
实现思路: 增加字母键(A-Z, 检测Shift/CapsLock), 增加符号键(Shift+数字键)
验收标准: a-z字母输入, Shift+字母大写, Shift+数字符号, 无崩溃
约束: 需确认是否允许修改scidavis/目录

---

### 任务A: DataTable单元格编辑完整实现 - P0

现象: 双击编辑的代码已存在, 但setCellValue命令在Qt侧可能未注册
涉及文件: DataTable.ets, TablePage.ets, 可能需Qt侧新增setCellValue命令
实现思路: 确认setCellValue是否注册, 未注册则在scidavis_call中新增
验收标准: 双击编辑, Enter提交, Esc取消, Ctrl+Z撤销生效
约束: 所有callQtCommand必须try-catch, 涉C++需问我
---

### 任务C: scidavis_call分发器扩展 - P0

现象: 点击new_function, rescale, zoom_in等显示未适配弹窗
根因: 命令未在scidavis_call中注册handler
涉及文件: scidavis/src/main.cpp - scidavis_call函数
需要注册的命令:
  new_function -> g_mainWindow->newFunctionPlot()
  add_curve/add_error_bars/add_function -> 对应ApplicationWindow方法
  rescale -> activeWindow()->graph()->rescaleAxes()
  graph_pointer/zoom_in/zoom_out/screen_reader/data_reader -> setActiveTool()
验收标准: 各命令在Qt中执行对应操作, 真机无崩溃
约束: 返回JSON, 禁止创建QDialog, 需确认Qt侧修改权限

---

### 任务T1: Windows菜单窗口列表去重 - P0

现象: 分析操作后Windows菜单中窗口出现两次
涉及文件: MainLayout.ets(498-510行), 可能涉及Qt侧uiStateJson
验收标准: 每窗口仅出现一次
约束: 先查ArkTS侧去重逻辑, 根因在C++侧再问我

---

### 任务D: 偏好设置持久化接线 - P1

描述: PreferencesDialog UI已完整, 但getPreference/setPreference命令未注册
涉及文件: scidavis/src/main.cpp(C++侧), PreferencesDialog.ets(ArkTS侧)
验收标准: 修改设置后重启应用保持
约束: QSettings路径必须在沙箱内, 需确认Qt侧修改权限

---

### 任务E: 实时数据刷新机制(ArkTS侧) - P1

描述: Qt后端数据变更后自动推送到ArkTS前端
涉及文件: QtEventHost.ets, TablePage.ets, PlotPage.ets
实现思路: handleEvent新增tableDataChanged/plotListChanged, 通过AppStorage驱动刷新
验收标准: 编辑后自动刷新, 500ms防抖, 无循环刷新
约束: 仅ArkTS侧
---

### 任务F: 数据变更事件推送(Qt侧) - P1

描述: 在Qt端关键数据变更点插入scidavis_emit调用
涉及文件: scidavis/src/main.cpp或ohos_bridge.cpp
插入点: Table::setCellValue, Table::addCol, ApplicationWindow::newTable等
验收标准: hilog出现SciDAVisChain事件, ArkTS收到并处理, 无性能退化
约束: 需确认Qt侧修改权限

---

### 任务T3: PlotCanvas多层图支持 - P1

描述: 当前只渲染plot.graphs[0], C++端已返回完整graphs数组
涉及文件: PlotPage.ets, PlotCanvas.ets(仅ArkTS)
验收标准: 每图层正确渲染, 层间坐标轴独立
注意: 先确认getPlotData是否包含graphIdx字段

---

### 任务T4: DataTable列宽自适应 - P1

描述: computeColWidths中charWidth=8未考虑中文字符宽度
涉及文件: DataTable.ets(95-115行, 仅ArkTS)
实现思路: 检测中文字符(Unicode \\u4e00-\\u9fff)赋以2x宽度系数
验收标准: 中文列名完整显示, 列宽在60-200px范围内

---

### 任务T5: NoteEditor连接Qt后端 - P1

描述: NoteEditor只有本地@State, 数据不保存到Qt
涉及文件: NoteEditor.ets(ArkTS), 可能需Qt侧注册getNoteData/setNoteData
验收标准: 编辑后保存项目, 重新打开内容恢复
注意: 先评估SciDAVis Note类是否暴露text()/setText() API

---

### 任务T6: 分析结果日志自动滚到底部 - P2

描述: Results Log面板新内容追加后不自动滚动
涉及文件: MainLayout.ets(1058-1124行, 仅ArkTS)
验收标准: 新内容自动滚动到底部, 手动滚动时不强制跳转
---

## 3. 执行流程

### 步骤1: 需求澄清
逐条检查任务卡, 不明确立即提问。
典型问题: 是否允许修改C++? 真机是否连接? 依赖顺序是否正确?
一个问题对应一个任务卡, 持续提问直到我确认所有需求明确。
在得到我确认之前, 不得开始实施。

### 步骤2: 创建Todo文档
使用todowrite创建详细待办清单。
每个Todo格式: [文件名]: [做什么] - [预期结果]
粒度: 每个原子任务一个Todo(1-3个工具调用可完成)
诊断任务和修复任务分开, 开发和Code Review分开。

### 步骤3: 委派实施
对每个任务派出子代理进行开发/修复。
子代理prompt必须包含: 目标、涉及文件、实现思路、验收标准、约束条件。
使用正确的category: visual-engineering用于UI, unspecified-high用于逻辑, quick用于简单修改。
多个独立任务可以并行委派。

### 步骤4: Code Review
每项任务完成后派出另一个子代理进行Code Review。
检查: 代码风格合规、无类型安全问题、验收标准满足、无新引入问题。
Review通过则标记completed, 不通过则标记failed, 回退修改, 向我报告。

### 步骤5: 最终报告
所有任务完成后提交总结报告, 格式如下:

## 执行总结
### 完成情况
| 任务 | 状态 | 子代理 | Review结果 |
|------|------|--------|-----------|
| 任务G | done/failed | agent-1 | 通过/不通过 |

### 修改文件清单
- [文件路径] - 变更摘要

### 静态检查
- lsp_diagnostics: 零新增错误
- verify_smoke.py: PASS/FAIL

### 未完成/延后
### 风险/备注

---

## 4. 参考资源

| 资源 | 路径 |
|------|------|
| 项目根目录 | C:\Users\Forwardz\scidavis-ohos\ohos |
| 项目架构 | README.md |
| AI约束 | AGENTS.md |
| 开发规范集 | docs/开发规范/ (11篇) |
| 开发指南 | docs/开发指南/开发规范指南.md |
| 功能计划 | docs/功能计划/功能实施计划.md |
| 下一阶段规格 | docs/下一阶段/下一阶段执行规格.md |
| 验证报告 | docs/验证报告/ (2份) |
| 开发日志 | docs/开发日志/ (4篇) |
| 冒烟测试 | tools/verify_smoke.py |

---

## 5. 禁止事项

- 直接修改任何代码文件
- 跳过需求澄清步骤
- 合并多个任务到一次委派
- 跳过Code Review步骤
- 未完成时声称完成
- 添加as any, @ts-ignore, @ts-expect-error
- 修改与当前任务无关的文件
- 未询问就决定C++/ArkTS侧的修改位置