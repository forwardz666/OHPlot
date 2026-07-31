# 2026-07-31 工作日志：ColumnSidebar 列属性侧边栏实现

## 工作内容
- 新增 ColumnSidebar 组件，在表格页面右侧展示选中列的属性信息
- 修改 DataTable 将 `selectedCol`/`selectedRow` 从 `@State` 升级为 `@Link`，使父组件可观察选中变化
- 修改 TablePage 布局为 Row（DataTable + ColumnSidebar），通过 `$` 语法传递双向绑定

## 完成项
- [x] `components/DataTable.ets`: `@State selectedCol`/`selectedRow` → `@Link`，供父组件双向绑定
- [x] `components/ColumnSidebar.ets`: 新建组件，展示列列表（高亮选中列）+ 选中列属性（列名、描述、类型、格式、绘图指定、公式）
- [x] `pages/TablePage.ets`: 新增 `@State selectedCol`/`selectedRow`，导入 ColumnSidebar，build() 改为 Row 布局

## 技术决策
- **决策 1: @Link 而非 @Event 回调** — ArkTS 的 `@Link` 双向绑定更符合声明式 UI 范式，DataTable 和 ColumnSidebar 均可直接修改 selectedCol 并通过父组件 `@State` 同步，无需手动回调
- **决策 2: ColumnSidebar 内部 fetch 列信息** — 组件通过 `callQtCommand('getColumnInfo', ...)` 自行获取列属性 JSON 数组，避免父组件传递大量数据；`@Watch('onTableNameChange')` 监听表切换自动重载
- **决策 3: @Builder propRow 参数化** — 复用 MatrixOpsDialog.ets 的标签-值行样式（标签 fontSize 13/#555555，值 fontSize 13/#333333），通过参数化 @Builder 减少重复代码
- **决策 4: Format 字段占位** — 后端 `getColumnInfo` 暂不返回 format 字段，显示 em dash（—）占位符，为后续后端扩展预留

## 文件变更
| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `ohos/entry/src/main/ets/components/DataTable.ets` | 修改 | `@State` → `@Link` for selectedCol/selectedRow (line 33-34) |
| `ohos/entry/src/main/ets/components/ColumnSidebar.ets` | 新增 | 列属性侧边栏组件 (167 lines) |
| `ohos/entry/src/main/ets/pages/TablePage.ets` | 修改 | 新增 @State/import, build() Row 布局 (line 5, 34-35, 145-160) |

## 遗留问题
- `getColumnInfo` Qt 命令尚未在 C++ 后端实现 — 需并行任务完成后才能实际获取列数据
- 侧边栏暂为只读展示，后续可扩展为可编辑模式
- Format 字段后端未提供，当前显示占位符

## 环境信息
- 项目: scidavis-ohos
- 日期: 2026-07-31
- 依赖变更: 无

## 后续建议
- C++ 后端实现 `getColumnInfo` 命令后，需确认返回的 JSON 字段名（col, name, type, description, formula, plotDesignation）与 ColumnSidebar 接口定义一致
- 如需列属性的编辑功能，可在 ColumnSidebar 中将 Text 替换为 TextInput，参考 DataTable 的编辑模式
