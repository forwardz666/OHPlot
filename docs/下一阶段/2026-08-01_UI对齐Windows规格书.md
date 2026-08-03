# 2026-08-01 UI 对齐规格书：OHPlot 对齐 SciDAVis Windows 桌面版

> **性质**：UI 对齐规划基准（草案）。目标：①菜单栏子菜单与 Win 端一致；②子菜单打开的窗口/对话框与 Win 端基本一致；
> ③统一风格（消除制作时间不一导致的视觉差异），减小用户从 Win 端迁移到鸿蒙版的转移成本。
> **双源采集**：A = scidavis 源码（.ui + C++ 对话框代码 + 菜单定义，结构性 100% 精确）；
> B = Win 端运行态截图（视觉基准，用户配合采集）。

---

## 一、Win 端 UI 规格盘点（源码级，A 源）

> **⚠️ 2026-08-02 修正（源码实证）**：2.7.2 菜单栏是**动态菜单**（ApplicationWindow.cpp
> `customMenu()` L1120-1230），非固定 13 菜单。结构 = **6 常驻 + 按激活窗口类型追加**：
> - 常驻：File → Edit → View → Scripting → Windows → Help
> - **Table 激活**：+ Plot（plot2D）→ Analysis（dataMenu，表格形态）→ Table（tableMenu）
> - **MultiLayer 激活**：+ Graph（graph）→ **Tools（plotDataMenu，L1029 标题 "&Tools"）** →
>   Analysis（calcul，图形态）→ Format（format）
> - **Graph3D 激活**：+ Format（format）
> - **Matrix 激活**：+ 3D Plot（plot3DMenu）→ Matrix（matrixMenu）
> - **Note 激活**：无追加，Scripting 菜单扩展 Execute/Execute All/Evaluate
> - **Tools 菜单存在（2.7.2）**：内部变量 `plotDataMenu`，显示标题 "&Tools"，仅 MultiLayer 激活时出现
>   （L1148）。内容：Disable Tools / Zoom In / Zoom Out / Rescale to Show All · Screen Reader /
>   Data Reader / Select Data Range · Move Data Points... / Remove Bad Data Points...
> - **无 "Plot Data" 菜单**：`plotDataMenu` 仅是变量名，菜单栏显示为 "Tools"
> - **两个 Analysis 菜单内容不同**：Table 态（dataMenu）= Statistics/FFT/Correlate/Convolute；
>   Graph 态（calcul）= Translate▾/Differentiate/Integrate/Smooth▾/FFT Filter▾/Quick Fit▾
> - **Windows 菜单项**（L1225）：Cascade / Tile / Next / Previous / Rename Window / Duplicate /
>   Window Geometry... / Hide Window / Close Window / 窗口列表（截图实证）
> - 参照现有截图：Table 态菜单栏 = File·Edit·View·Scripting·Plot·Analysis·Table·Windows·Help（9 个，
>   `diagnostics/ui-alignment/1_菜单栏展开/` 18 张全部为此状态）

### 1.1 完整菜单树（ApplicationWindow.cpp: createActions 10304-10895 / initMainMenu 778-1023 / customMenu 1120-1230）

**菜单栏顺序**：File → Edit → View → Scripting → [窗口类型相关菜单] → Windows → Help

**File**：New▾(Project/Table/Matrix/Note-Script/Graph/Function Plot/3D Surface Plot) · Open...(Ctrl+O) · Recent Projects▾ · Open Image File · Import Image · Save Project(Ctrl+S) · Save As · Open Template / Save As Template · **Export Graph▾**(Current/All) · Print / Print All Plots · Export ASCII / Import ASCII · Quit

**Edit**：Undo / Redo · Cut / Copy / Paste / Delete · Delete Fit Tables / Clear Log Info · Preferences

**View**：Toolbars▾ / Lock Toolbars · Plot Wizard(Ctrl+Alt+W) / Project Explorer(Ctrl+E) / Results Log / Undo-Redo History / Scripting Console

**Scripting**：Scripting Language / Restart Scripting；Note 激活时追加 Execute(Ctrl+J) / Execute All / Evaluate Expression

**Graph**（MultiLayer 激活）：Add/Remove Curve(Alt+C) · Add Error Bars(Ctrl+B) · Add Function(Ctrl+Alt+F) · Add Text / Draw Arrow / Draw Line / Add Time Stamp / Add Image / New Legend · Automatic Layout / Add Layer / Remove Layer / Arrange Layers

**Format**（MultiLayer 激活）：Plot... / Scales... / Axes... / Grid... / Title...

**Tools**（绘图工具）：Disable Tools / Zoom In / Zoom Out / Rescale · Screen Reader / Data Reader / Select Data Range · Move Data Points / Remove Bad Data Points

**Plot**（Table 激活）：Line / Scatter / Line+Symbol · **Special▾**(Drop Lines/Spline/Vertical Steps/Horizontal Steps) · Vertical Bars / Horizontal Bars / Area / Pie / Vectors XYXY / Vectors XYAM · **Statistical▾**(Box/Histogram/Stacked Histogram) · **Panel▾**(2L/2H/4L/Stacked) · **3D Plot▾**(Ribbon/Bars/Scatter/Trajectory)

**Analysis**：Table 上下文 = Statistics on Columns/Rows · FFT · Correlate/Autocorrelate · Convolute/Deconvolute · Fit Wizard；
MultiLayer 上下文 = **Translate▾** · Differentiate / Integrate · **Smooth▾**(SavGol/FFT Filter/Moving Average) · **FFT Filter▾**(LP/HP/BP/BR) · Interpolate / FFT · **Quick Fit▾**(Linear/Polynomial/Exp Decay 一~三阶/Exp Growth/Boltzmann/Gaussian/Lorentzian/Multi-peak) · Fit Wizard

**Table**（Table 激活）：动态列操作 + Export ASCII + Convert to Matrix
**Matrix**：动态矩阵操作 + Invert/Determinant + Convert to Table
**3D Plot**（Matrix 激活）：Wire Frame/Hidden Line/Polygons/Wire Surface · Bars/Scatter · Contour-Color/Lines/Gray Map

**Windows**：Cascade / Maximize / Minimize / Close + 实时窗口列表
**Help**：Help / Choose Help Folder / Homepage / Search Updates / Manual / Forums / Report Bug / About

### 1.2 对话框类清单（30 个 QDialog + 4 个 ExtensibleFileDialog 子类）

| 类别 | 类名 | 功能 | 核心控件 |
|------|------|------|---------|
| 绘图 | CurvesDialog | 增删曲线 | 双列 QListWidget + 样式 QComboBox + Add/Remove/OK/Close |
| | ErrDialog | 误差棒 | 2 个 QGroupBox(误差来源:列/百分比/标准差 + X/Y方向) + 曲线下拉 |
| | FunctionDialog | 函数曲线 | 类型 QComboBox + QStackedWidget 3 页(公式/参数/极坐标) |
| | AxesDialog | 轴/刻度/网格/边框 | QTabWidget 4 页 + From/To/ScaleType |
| | PlotDialog | 逐曲线样式(14 页) | QTreeWidget 曲线树 + 14 页 QTabWidget + PlotType |
| | PlotWizard | 选列绘图向导 | X/XErr/Y/YErr/Z 按钮 + 表/列双列表 + 关联表 |
| | Plot3DDialog | 3D 曲面选项 | 5 页 Tab + QDoubleSpinBox 缩放/比例 |
| | SurfaceDialog | 定义 3D 曲面 | 3 个轴 QGroupBox + 公式下拉 |
| 分析 | IntDialog | 积分 | QGroupBox + 方法/起止 |
| | FFTDialog | FFT | 正/逆 + 实/虚列 + 采样/归一化 |
| | FilterDialog | 滤波 | 起止 + 偏移 + 颜色 |
| | InterpolationDialog | 插值 | 方法 + 点数 + 起止 |
| | SmoothCurveDialog | 平滑 | 阶数 + 左右点数 |
| | ExpDecayDialog | 指数拟合参数 | 5 个初值输入 |
| | PolynomFitDialog | 多项式拟合 | 阶数 + 起止 + 显示公式 |
| | FitDialog | Fit Wizard | 3 页 Stacked + 函数类别/函数列表 + 参数表 |
| | DataSetDialog | 选数据集 | QGroupBox + 下拉 |
| | CurveRangeDialog | 曲线行范围 | QGroupBox + 起止 SpinBox |
| 数据 | ImportASCIIDialog | 导入 ASCII | 系统文件框 + 高级选项 QGroupBox(模式/分隔符/跳行/去空格/数字locale) |
| | ExportDialog | 导出 ASCII | 表下拉 + 分隔符 + 选项 |
| | ImageExportDialog | 导出图 | 系统文件框 + 格式/尺寸 |
| | OpenProjectDialog | 打开工程 | 系统文件框 + 打开模式/编码 |
| | TeXTableExportDialog | 导出 LaTeX | 系统文件框 + 设置 |
| 其他 | ConfigDialog | 偏好设置 | QListWidget 导航 + QStackedWidget 5 页(App/Table/Plot/Plot3D/Fit) |
| | RenameWindowDialog | 重命名窗口 | 名称/标签/两者单选 + 输入 |
| | FindDialog | 查找窗口 | 搜索框 + 范围(窗口名/标签/文件夹) + 选项 |
| | ImageDialog | 图片几何 | 原点/尺寸 + 保持比例 |
| | TextDialog | 文本标签选项 | 字体/颜色/对齐/背景透明度 |
| | LineDialog | 线条选项 | 画笔 + 箭头头/尾 + 几何 |
| | SymbolDialog | 特殊字符选择 | 字符按钮网格 |
| | LayerDialog | 图层排列 | 4 个 QGroupBox(图层/对齐/网格/画布尺寸) |
| | AssociationsDialog | 绘图关联 | QTableWidget 列/职责 + 关联列表 |
| | ScriptingLangDialog | 脚本语言 | 语言列表 |

### 1.3 Win 对话框通用设计要素（9 条，ArkTS 主题依据）

1. 行式 label+控件网格（QGroupBox + QGridLayout，label col0 / 控件 col1）
2. 按钮两范式：右侧纵向列 / 底部横向 addStretch+OK(默认)+Cancel(+Apply/Help)
3. 主按钮一律默认（Enter 触发），Esc=取消
4. QGroupBox 分组逻辑区块
5. 互斥选项 QButtonGroup+QRadioButton
6. 复杂对话框 Tab/Stacked 导航（4/14/5/3 页）
7. 图标化小按钮（增删箭头、折叠 <<）
8. setSizeGripEnabled（可拖角）、ColorButton、QSpinBox 带 suffix
9. Set As Default / Apply 预设记忆

---

## 二、OHPlot ↔ Win 差异矩阵

### 2.1 菜单差异（OH 动态菜单 vs Win 动态菜单）

| 差异项 | 现状 | 对齐动作 |
|--------|------|---------|
| **Scripting 菜单缺失** | OH 无 | 搭框架（脚本语言/控制台，可先灰显） |
| **Format 菜单缺失** | OH 并入 Graph | MultiLayer 激活时拆出 Format(Plot/Scales/Axes/Grid/Title)，GraphPropsDialog 展开为 AxesDialog 4 页 |
| **Tools 菜单缺失（OH）** | OH 无独立 Tools 菜单（Zoom/Reader 工具在别处） | MultiLayer 激活态补 Tools 菜单（Disable Tools/Zoom In/Out/Rescale/Reader/Range/Move/Remove）——变量 `plotDataMenu` 标题即 "&Tools"，仅图形态出现 |
| **QuickFit 子菜单拍平** | OH 单层 11 项 | 恢复子菜单层级（Quick Fit▾/Smooth▾/FFT Filter▾/Multi-peak▾） |
| **View-Toolbars/PlotWizard/History 缺失** | OH 无 | 搭框架 |
| **Plot 子菜单拍平** | OH 12 项平铺 | 恢复 Special/Statistical/Panel/3D 子菜单层级 |
| **3D Plot 菜单禁用** | 远期 | 保持禁用（F-30 远期） |
| **New 子菜单缺 3 项** | OH New 5 项 | 补 Function Plot / 3D Surface(禁用) |
| **底部工具栏缺 Table 功能组** | OH BottomToolBar 仅 Plot+Plot3D 组 | 在 Plot 组旁加 Table 组（对齐 Win `table_tools`）✅ 已做（08-02） |
| **Windows/Help 基本对齐** | ✅ | 微调（Win 实测含 Tile/Next/Previous/Rename/Duplicate/Window Geometry/Hide） |

> **用户明确需求（2026-08-01）**：底部工具栏（下方一行）在已有图标旁边补加 "table" 功能图标。
> 对齐 Win 端 `table_tools`（future_Table.cpp:1120-1128 fillProjectToolBar）：
> ① 行列数设置(dimensions) ② 加列(add_column) ③ 列统计(statistics_columns) ④ 行统计(statistics_rows)。
> 图标：Win 端 add_column.png 等；OH 已有 tb_table.png 可作基础。功能接口：已做命令直接接
> （add_columns→AddColumnsDialog、statistics_columns/rows→tableStatistics），dimensions 若无对应先搭按钮。

### 2.2 对话框差异（13 有 + 17 缺失）

**已有（13）**：PreferencesDialog↔ConfigDialog、ImportDialog↔ImportASCIIDialog、ExportDialog↔ExportDialog、AboutDialog↔About、AddCurveDialog↔CurvesDialog、ErrorBarsDialog↔ErrDialog、AddFunctionDialog↔FunctionDialog、Plot2DDialog(特有)、GraphPropsDialog↔AxesDialog(子集)、AnalysisDialog↔11 种分析聚合、TableOpsDialog↔3 表格操作聚合、MatrixOpsDialog↔2 矩阵操作、ScriptConsoleDialog(占位)

**缺失（17，需搭框架）**：PlotDialog(14 页) / PlotWizard / AssociationsDialog / CurveRangeDialog / TextDialog / LineDialog / ImageDialog / SymbolDialog / LayerDialog / RenameWindowDialog / FindDialog / Plot3DDialog(远期) / SurfaceDialog(远期) / ScriptingLangDialog / TableStatistics / ImageExportDialog / TeXTableExportDialog

---

## 三、对齐实施策略

### 3.1 统一设计 Token（先建主题，消除风格不一）
新建 `components/Theme.ts`（或扩展 Theme.ets）：字体/字号/颜色/间距/控件样式（按钮/输入框/下拉/复选框/单选/分组框/Tab）——所有新对话框强制引用，存量对话框逐批迁移。

### 3.2 菜单树对齐（搭框架）
按 §2.1 差异矩阵：Scripting/Format/Tools 菜单、QuickFit 等子菜单层级、New 子菜单补项——**已做功能改接口，缺失搭框架（灰显或占位）**。

### 3.3 对话框分批对齐（Win 布局为准）
| 批次 | 内容 | 说明 |
|------|------|------|
| 1 | AxesDialog(4 页) 展开 GraphProps、PlotWizard、AssociationsDialog、CurveRangeDialog | 与 AddCurve 同链路高频项 |
| 2 | PlotDialog 逐页拆分(先 line/symbols/errors 核心页)、TextDialog/LineDialog/ImageDialog/SymbolDialog(图 enrichment) | 图编辑完备 |
| 3 | RenameWindowDialog/FindDialog/TableStatistics/LayerDialog/ConfigDialog 补页 | 系统功能 |
| 4 | 3D(Plot3DDialog/SurfaceDialog)/TeX 导出 | 远期 |

### 3.4 验收
每个对话框：ArkTS 截图 vs Win 截图并排核对（存档 `diagnostics/`），逐控件比对布局/文本/行为。

---

## 四、Win 端截屏清单（B 源，用户配合）

> 在 Windows 电脑上启动 scidavis（建议中文界面，与鸿蒙版一致），逐项截屏。截图存 `ohos/diagnostics/ui-alignment/`（建子目录按菜单/对话框分类）。
>
> **采集状态（2026-08-02 盘点，已就位 70 张 / 待补拍）**：
> - ✅ 菜单栏 **Table 态** 9 个常驻+Table 相关菜单 18 张（File 主/New▾/Recent▾、Edit、View 主/Toolbars▾、
>   Scripting、Plot 主/Special▾/Statistical▾/Panel▾/3D▾、Analysis、Table 主/SetAs▾/Fill▾、Windows、Help）
> - ✅ 对话框 33 张：ConfigDialog 全 5 页（Preference-1~13）、file 10 张、view 5 张、FFT、Set Table Dim、
>   Export ASCII、Window Geometry、ScriptingLang、Help Files Not Found
> - ✅ **补拍（17 张，2026-08-02）**：Graph 菜单（多段拼合）、Tools 菜单（图形态）、Format 菜单（图形态）、
>   3D Plot 菜单、Matrix 菜单（矩阵态）、Analysis 菜单（图形态，顶层+QuickFit/MultiPeak/ExpDecay/FFT Filter/
>   Translate/Smooth 子菜单展开）、File→New 级联
> - ⬜ **待补拍**：
>   - **Graph 菜单中段**（Vertical Steps 与 Vectors XYXY 之间）：Area / Pie / Vertical Bars / Horizontal Bars / Histogram 等绘图类型
>   - **对话框全部未拍**（0 张）：P0 CurvesDialog/ErrDialog/FunctionDialog/AxesDialog(4 页)、P1 PlotDialog 核心页/
>     TextDialog/LineDialog/ImageDialog/AssociationsDialog、P2 Fit Wizard/SmoothCurve/Interpolation/Int/Filter/
>     PolynomFit、P3 LayerDialog/RenameWindowDialog/FindDialog/TableStatistics、Export Graph Image
>   - 主窗口全貌（4.3，表格+图+项目浏览器+结果日志典型布局）
> - 补齐方式：Win 端先新建 Graph/Matrix 窗口激活后截菜单；对话框须从对应菜单打开后截，放入对应子目录

### 4.1 菜单栏展开（每个菜单一张，含子菜单展开）
File / Edit / View / Scripting / Graph / Format / Tools / Plot(含 4 个子菜单各展开一次) / Analysis(含 5 个子菜单) / Table / Matrix / Windows / Help

### 4.2 对话框（每个打开后截一张；多页 Tab 的每页截一张）
| 优先级 | 对话框 |
|--------|--------|
| P0（高频） | 添加曲线 CurvesDialog · 添加误差棒 ErrDialog · 添加函数 FunctionDialog · 坐标轴设置 AxesDialog(4 页) · 偏好设置 ConfigDialog(5 页) |
| P1（图编辑） | 曲线样式 PlotDialog(核心页) · 绘图向导 PlotWizard · 文本 TextDialog · 线条 LineDialog · 图片 ImageDialog · 关联 AssociationsDialog |
| P2（分析） | Fit Wizard · FFT · 平滑 · 插值 · 积分 · 滤波 · 多项式拟合 |
| P3 | 图层排列 · 重命名窗口 · 查找 · 统计 |

### 4.3 整体窗口
主窗口全貌（含表格 + 图 + 项目浏览器 + 结果日志的典型布局）

---

## 五、环境与锚点

- 设备：HUAWEI MatePad 11.5（OpenHarmony-7.0.0.32, API 26, 192.168.0.116:46817）
- 源码锚点：ApplicationWindow.cpp（菜单 778-1230、actions 10304-10895）、MainLayout.ets（rebuildMenus 436-588、dispatch 615 起）
- 截图存档：`ohos/diagnostics/ui-alignment/`
