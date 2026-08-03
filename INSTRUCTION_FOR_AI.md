# SciDAVis for OpenHarmony 一日修复任务 — AI 执行指令

> 本文档是写给 AI 编码代理（主代理）的**元指令**，规定了主代理的工作模式和今天要完成的任务。
> 主代理必须严格遵守以下工作流程，不得自行修改代码。

---

## 第一部分：工作流程（硬约束）

### 1.0 你的身份

你是主代理（Orchestrator）。你的职责是**分解任务、委派执行、收集结果、审查质量、汇报总结**。
你**不得直接修改任何代码文件**。所有代码修改必须通过子代理完成。

### 1.1 必须先提问，后动手

在开始任何工作之前，如果以下信息不明确，你必须逐一向我提问，直到我确认所有问题都已澄清：

- **任务范围**：哪些功能属于"今天必须完成"、哪些可以延后？
- **优先级冲突**：如果两个任务评估后发现依赖关系与我描述的不同，如何处理？
- **验收标准**：每个任务完成的标准是否足够明确？
- **风险**：是否有你识别出的风险需要我决策？

**在获得所有问题的明确答案之前，不得开始执行。**

格式示例：
```
Q1: [任务 X] 的验收标准中提到的"真机验证"，我目前没有连接真机，是否跳过设备验证步骤，仅完成代码层面的修改和静态检查？
Q2: [任务 Y] 依赖 [任务 Z]，但 [任务 Z] 涉及 Qt C++ 代码修改，需要您确认是否允许修改 scidavis/src/main.cpp？
```

### 1.2 必须创建 Todo List

在开始执行前，必须使用 `todowrite` 创建详细的 Todo List。
每个 Todo 的标题必须包含：**文件名、做什么、为什么、预期结果**。

示例：
```
src/main.cpp: 在 scidavis_call 分发器中注册 "new_function" handler
  - 调用 ApplicationWindow::newFunctionPlot()
  - 预期: 点击菜单 new_function 后 Qt 创建函数图窗口，不崩溃
```

### 1.3 必须委派子代理执行

- 每个原子任务必须委派给一个子代理（`task(category=..., prompt="...")`）
- 主代理**不得直接修改代码**
- 子代理的 prompt 必须包含：**目标、涉及文件、实现思路、验收标准、约束条件**
- 多个独立任务可以并行委派

### 1.4 必须进行 Code Review

每个子代理完成任务后，主代理必须：
1. 收集子代理的产出
2. 派出一个或多个 Code Review 子代理（`category="unspecified-high"` 或 `subagent_type="oracle"`）
3. Review 的内容包括：
   - 代码是否符合项目规范（强类型、NAPI 防御性编程、ArkTS 规范）
   - 是否引入了新的问题（崩溃、死锁、性能退化）
   - 是否与现有代码风格一致
4. Review 不通过则退回修改，通过则标记 Todo 完成

### 1.5 必须确认完成并汇报

所有任务完成后，主代理必须：
1. 逐一确认 Todo List 中每个项目标记为 `completed`
2. 运行 `lsp_diagnostics` 检查修改过的文件
3. 运行 `python tools/verify_smoke.py` 执行静态检查
4. 向我提交总结报告，格式如下：

```
## 执行总结

### 完成情况
| 任务 | 状态 | 子代理 | Review 结果 |
|------|------|--------|-------------|
| ...  | ✅   | agent1 | 通过        |

### 修改文件清单
- [文件路径] — 变更摘要

### 静态检查
- lsp_diagnostics: 零新增错误
- verify_smoke.py: PASS/FAIL

### 未完成 / 延后
- [原因]

### 风险 / 备注
- [需要我注意的事项]
```

---

## 第二部分：今日修复任务（按优先级排列）

> 以下任务基于 2026-07-30 的代码审查结果制定。
> 每个任务包含：目标、涉及文件、实现思路、验收标准。
> 主代理在开始前必须就所有不明确之处向我提问。

---

### 任务 A：DataTable 单元格编辑（P0）

**目标**：在 `DataTable.ets` 中实现双击单元格进入编辑模式，支持键盘输入后按 Enter 提交、Esc 取消。

**涉及文件**：
- `entry/src/main/ets/components/DataTable.ets` — 修改
- `entry/src/main/ets/pages/TablePage.ets` — 可能需修改（刷新机制）
- 可能需要 Qt 侧新增 `setCellValue` 命令（`scidavis/src/main.cpp` `scidavis_call` 分发器）

**实现思路**：
1. DataTable 中每个单元格使用 `Text` + `TextInput` 组合：默认显示 `Text`，双击后切换为 `TextInput`
2. `TextInput.onSubmit` 时调用 `callQtCommand('setCellValue', {tableId, row, col, value})`
3. `TextInput.onBlur` 或按 Esc 时恢复 `Text` 显示，丢弃变更
4. 如果 Qt 侧没有 `setCellValue` 命令，需要在 `scidavis_call` 中新增，调用 `Table::setText(row, col, value)`
5. 编辑后自动刷新该行数据（或调用 `refreshUiState`）

**验收标准**：
1. 双击任意单元格，出现可编辑的 TextInput
2. 输入新值后按 Enter，单元格显示新值，hilog 显示 `setCellValue` 调用日志
3. 按 Esc 取消编辑，恢复原值
4. 编辑后 Qt 的 Ctrl+Z 撤销生效

**约束**：
- 不得引入 `any` 类型
- 所有 `callQtCommand` 必须 try-catch 包裹
- 如果涉及 C++ 修改，需要我确认是否允许修改 `scidavis/src/main.cpp`

---

### 任务 B：C++ 侧 KeyTextFixer 扩展（P0）

**目标**：在 Qt 侧 `KeyTextFixer` 事件过滤器中，将字母键（A-Z）和符号键（Shift+数字键）的 text 合成逻辑补充完整。当前只处理了数字键。

**涉及文件**：
- `scidavis/src/main.cpp` 或 `scidavis/src/` 下的 `KeyTextFixer` 实现文件
- 需要先找到 KeyTextFixer 的代码位置

**实现思路**：
1. 找到 `KeyTextFixer` 事件过滤器（在 `scidavis/src/` 中），阅读当前实现
2. 在数字键合成逻辑的基础上，增加字母键的 text 合成：
   - 按 `key()` 值判断字母（Qt::Key_A ~ Qt::Key_Z）
   - 检测 `QApplication::keyboardModifiers()` 中的 Shift 和 CapsLock 状态
   - 合成对应的大写或小写字母 text
3. 增加符号键的 text 合成：
   - Shift + 数字键 → 对应符号（`!@#$%^&*()`）
   - Shift + 符号键 → 对应上层符号
4. 保持 `Qt::MouseEventSynthesizedByApplication` 标记不变

**验收标准**：
1. 蓝牙键盘输入小写字母 a-z 在表格单元格中正确显示
2. Shift + 字母键输入大写字母
3. Shift + 数字键输入符号（`!@#$%^&*()`）
4. 无崩溃（faultlog 零新增）

**约束**：
- 必须修改的是 Qt 侧代码（`scidavis/` 目录），需要我确认是否允许

---

### 任务 C：scidavis_call 分发器扩展（P0）

**目标**：在 `scidavis/src/main.cpp` 的 `scidavis_call` 分发器中注册以下命令的 handler，消除"未适配"弹窗。

**涉及文件**：
- `scidavis/src/main.cpp` — `scidavis_call` 函数

**实现思路**：
在 `scidavis_call` 的 `else if` 链中新增以下分支：

| 命令 | 调用代码 | 说明 |
|------|---------|------|
| `new_function` | `g_mainWindow->newFunctionPlot()` | 创建函数图窗口 |
| `add_curve` | 弹 QtEventHost 的 contextMenu（已存在） | 路由到 `ApplicationWindow::showAddCurveDialog()` 的无 UI 路径 |
| `add_error_bars` | 同上 | `ApplicationWindow::showAddErrorBarsDialog()` 的无 UI 路径 |
| `add_function` | 同上 | `ApplicationWindow::addFunctionCurve()` |
| `rescale` | `g_mainWindow->activeWindow()->graph()->rescaleAxes()` | 自动缩放当前图表 |
| `graph_pointer` | `g_mainWindow->setActiveTool("pointer")` | 切换指针工具 |
| `zoom_in` | `g_mainWindow->setActiveTool("zoomIn")` | 切换放大工具 |
| `zoom_out` | `g_mainWindow->setActiveTool("zoomOut")` | 切换缩小工具 |
| `screen_reader` | `g_mainWindow->setActiveTool("screenReader")` | 切换屏幕读取工具 |
| `data_reader` | `g_mainWindow->setActiveTool("dataReader")` | 切换数据读取工具 |

**验收标准**：
1. 点击 `new_function` 在 Qt 中创建函数图窗口，hilog 显示 `menuAction(new_function)` 日志
2. `rescale` 使当前图表自动缩放
3. `graph_pointer`/`zoom_in`/`zoom_out` 切换 Qt 的交互模式
4. 所有新命令在真机测试中无崩溃（faultlog 零新增）

**约束**：
- 所有新命令必须返回 `{"success":true}` 或 `{"success":false,"error":"..."}` JSON
- 禁止在 handler 中创建任何 QDialog/QMessageBox（C1 约束）
- 需要我确认是否允许修改 `scidavis/src/main.cpp`

---

### 任务 D：偏好设置持久化接线（P1）

**目标**：`PreferencesDialog.ets` 的 UI 已完整，但 `Apply` 按钮中的 `get/setPreference` 命令是 TODO。
在 Qt 侧新增 `getPreference` / `setPreference` 命令，读写 `QSettings`，并在 ArkTS 侧调用。

**涉及文件**：
- `scidavis/src/main.cpp` — `scidavis_call` 分发器新增 `getPreference`/`setPreference`
- `entry/src/main/ets/pages/dialogs/PreferencesDialog.ets` — 修改 Apply 按钮逻辑

**实现思路**：
1. Qt 侧新增：
   - `getPreference`：接收 `{key: string}`，返回 `QSettings().value(key).toString()` 包裹在 `{"success":true,"value":"..."}` 中
   - `setPreference`：接收 `{key: string, value: string}`，调用 `QSettings().setValue(key, value)`
2. ArkTS 侧：
   - `aboutToAppear` 时调用 `getPreference` 获取当前设置
   - `Apply` 按钮调用 `setPreference` 写入
   - 语言切换保持现有 `setAppLanguage` 路径

**验收标准**：
1. 修改自动保存间隔为 10 分钟，点击 Apply
2. 重启应用后，Preferences 面板显示 10 分钟
3. 修改默认表格行列数，新建表格后生效

**约束**：
- `QSettings` 的存储路径必须在沙箱内（`filesDir`）
- 需要我确认是否允许修改 `scidavis/src/main.cpp`

---

### 任务 E：实时数据刷新机制（P1）

**目标**：Qt 后端数据变更后自动推送到 ArkTS 前端，消除手动点 Refresh 的必要。

**涉及文件**：
- `entry/src/main/ets/components/QtEventHost.ets` — 新增事件处理
- `entry/src/main/ets/pages/TablePage.ets` — 监听刷新事件
- `entry/src/main/ets/pages/PlotPage.ets` — 监听刷新事件
- `scidavis/src/main.cpp` 或 `scidavis/src/ohos_bridge.cpp` — 新增事件推送

**实现思路**：
1. 在 Qt 端，当 `Table::setCellValue()`、`Table::addCol()` 等变更发生时，通过 `scidavis_emit` 推送 `{kind: "tableDataChanged", tableId: "..."}` 事件
2. 在 `QtEventHost.handleEvent()` 中新增 `case 'tableDataChanged'`：将 `tableId` 写入 `AppStorage('pendingTableRefresh')`
3. `TablePage` 通过 `@StorageProp('pendingTableRefresh')` 监听，变更时自动调用 `loadCurrentTable()`
4. 同理 `plotDataChanged` 事件驱动 `PlotPage` 刷新
5. 防抖处理：500ms 内多次变更只触发一次刷新

**验收标准**：
1. 在 ArkTS 表格中编辑单元格后，TablePage 自动显示更新后的值
2. 通过 Qt 菜单新建表格后，TablePage 的表格列表自动更新
3. 日志中无重复刷新或循环刷新

**约束**：
- 变更命令 fire-and-forget（C2），事件推送必须在 Qt GUI 线程用 `QMetaObject::invokeMethod` 投递
- 需要我确认是否允许修改 Qt 侧代码

---

### 任务 F：数据变更事件推送（Qt 侧）（P1）

**目标**：在 Qt 端的关键数据变更点插入 `scidavis_emit` 调用，触发 ArkTS 侧的实时刷新。

**涉及文件**：
- `scidavis/src/main.cpp` 或 `scidavis/src/ohos_bridge.cpp` — 事件推送点
- 需要先找到 `scidavis_emit` 函数的定义位置

**实现思路**：
1. 找到 `scidavis_emit` 函数，确认其调用方式
2. 在以下变更点插入事件推送：
   - `Table::setCellValue()` 之后 → `scidavis_emit('{"kind":"tableDataChanged","tableId":"..."}')`
   - `Table::addCol()` 之后 → 同上
   - `ApplicationWindow::newTable()` 之后 → `scidavis_emit('{"kind":"tableListChanged"}')`
   - `ApplicationWindow::multilayerPlot()` 之后 → `scidavis_emit('{"kind":"plotListChanged"}')`
3. 确保事件推送在 Qt GUI 线程中执行

**验收标准**：
1. 在 Qt 中修改表格数据后，hilog 中出现 `SciDAVisChain` 的 tableDataChanged 事件
2. ArkTS 侧的 `QtEventHost` 收到该事件并处理
3. 无性能退化（连续快速编辑 100 次不卡顿）

**约束**：
- 需要我确认是否允许修改 Qt 侧代码

---

### 任务 G：修复 DataTable / 矩阵显示缺第一行和标题行（P0）

**现象**：在 TablePage 中查看表格数据时，表格的第一行数据不显示，内容从第二行开始显示；列标题行（colNames 渲染的 header）也完全不可见。矩阵（Matrix）的数据查看也存在同样的偏移问题。

**目标**：定位根因并修复，使表格和矩阵的数据完整显示，包含标题行和所有数据行。

**涉及文件**：
- `entry/src/main/ets/components/DataTable.ets` — 渲染逻辑排查
- `entry/src/main/ets/pages/TablePage.ets` — 布局排查
- 可能涉及 Qt 侧 `getTableData` / `getMatrixData` 命令的响应构建

**诊断思路**（必须先诊断，再修复）：
1. 在 `DataTable.loadCurrentTable()` 中增加结构化日志，打印 `getTableData` 的原始 JSON 响应，检查：
   - `colNames` 数组是否为空或缺失第一个元素
   - `data` 数组的长度是否比 `rows` 少 1
   - `data[0]` 是否包含第一行数据，还是从第二行开始
2. 检查 `ForEach(this.colNames, ...)` 的渲染：
   - 如果 `colNames` 有值但 header 不显示，可能是布局问题（被 chrome 遮挡、高度为 0、zIndex 问题）
   - 检查 TablePage 的 Column 布局是否给 DataTable 分配了足够空间
3. 检查 `ForEach(this.cells, (rowData, rowIdx) => ...)` 的迭代：
   - 如果 `data` 数组确实从第二行开始，需要检查 Qt 侧 `getTableData` 的响应构建代码
   - 如果 `data` 数组完整但第一行渲染后不可见，可能是 Scroll 的偏移量或高度计算问题
4. 矩阵数据查看：检查 `MatrixOpsDialog` 是否有类似的 `getMatrixData` 调用和渲染路径，确认是否同一病根

**修复方向**（根据诊断结果选择）：
- **如果 Qt 侧返回的数据从第二行开始**：在 Qt 侧 `scidavis_call` 的 `getTableData` handler 中，确认 `data` 数组从 `row=0` 开始构建，而不是从 `row=1` 开始
- **如果 ArkTS 侧渲染跳过第一行**：检查 `ForEach` 的 key 生成逻辑或 `rowIdx` 的使用方式
- **如果标题行被遮挡**：检查 TablePage 的布局、DataTable 的 `border` 和 `height` 计算

**验收标准**：
1. 表格第一行数据完整显示，列标题行（colNames 渲染的灰色 header 行）可见
2. 数据行号从 1 开始，与桌面版一致
3. 矩阵数据查看同样完整显示
4. 新建表格后数据同样完整显示
5. 无崩溃（faultlog 零新增）

**约束**：
- 先诊断，定位根因后向我汇报诊断结果，再执行修复
- 如果根因在 Qt 侧，需要我确认是否允许修改

---

## 第三部分：执行顺序与依赖关系

```
第一批（先诊断，再执行）：
  └─ 任务 G：修复表格/矩阵缺第一行和标题行（先诊断根因，向我汇报后再修复）

第二批（可并行，无依赖，可和第一批并行）：
  ┌─ 任务 A：DataTable 单元格编辑（依赖任务 G 的修复，否则编辑的是错位的数据）
  ├─ 任务 C：scidavis_call 分发器扩展（需确认 Qt 侧修改权限）
  ├─ 任务 D：偏好设置持久化接线（需确认 Qt 侧修改权限）
  └─ 任务 E：实时数据刷新机制（ArkTS 侧）

第三批（依赖第二批）：
  └─ 任务 F：数据变更事件推送（Qt 侧，依赖任务 E 的 ArkTS 侧就绪）

独立（可并行）：
  └─ 任务 B：KeyTextFixer 扩展（需确认 Qt 侧修改权限）
```

---

## 第四部分：通用约束

1. **禁止修改代码**：主代理不得直接修改任何文件。所有代码变更必须通过子代理委派。
2. **强类型**：ArkTS 代码禁止 `any` 类型、禁止 `require()`。
3. **NAPI 防御性编程**：每个 `callQtCommand` 必须 try-catch 包裹。
4. **Qt 侧修改需确认**：涉及 `scidavis/` 目录的修改，必须先问我是否允许。
5. **Todo List 必须用 `todowrite` 创建**，不得手动记录。
6. **每个任务完成后必须 Code Review**，不通过则退回修改。
7. **最终必须运行 `python tools/verify_smoke.py`** 并汇报结果。