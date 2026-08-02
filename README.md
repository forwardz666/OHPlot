# OHPlot for OpenHarmony

**OHPlot** 是 [SciDAVis](https://scidavis.org/)（Scientific Data Analysis and Visualization）开源科学数据分析与可视化软件的 **OpenHarmony** 平台适配版本。目标设备为华为 MatePad 11.5 平板。

本仓库包含 ArkTS 前端界面层、NAPI 桥接层及构建配置，底层的 Qt C++ 应用引擎从上游 SciDAVis 源码交叉编译。

> 仓库地址：github.com/forwardz666/OHPlot（main 分支）
> 文档状态截至 **2026-08-02**。

---

## 适配状态 (Adaptation Status)

以下状态截至 2026-08-02。标注「待复核」的项表示代码已完成并入，等待人工真机最终确认。

| 功能模块 | 状态 | 说明 |
|----------|------|------|
| **基础运行环境** | ✅ 完成 | Qt 5.15.12 for OpenHarmony 交叉编译，HAP 构建部署 |
| **Qt 引擎启动** | ✅ 完成 | alpha_v6 QPA 插件 + `startQtApplication` + 独立 C++ pthread 启动，绕过 NAPI 死锁 |
| **高 DPI 适配** | ✅ 完成 | 禁用 HighDpi 缩放，1:1 物理像素渲染 |
| **QPA 插件加载** | ✅ 完成 | require() 动态导入 + 备选路径 + 错误捕获 |
| **JS 桥接** | ✅ 完成 | 窗口管理、输入法、区域设置、标准路径、光标、剪贴板 6 个对象 |
| **Qt 事件通道** | ✅ 完成 | `scidavis_emit` → NAPI TSFN → ArkUI 弹窗替换 |
| **命令通道** | ✅ 完成 | 55+ 已注册命令（查询 12 + 变更 43），`scidavis_call` JSON 协议 |
| **蓝牙鼠标左键** | ✅ 完成 | ETS 覆盖层 + NAPI sendMouse + `scidavis_inject_mouse` 注入通道 |
| **蓝牙键盘数字键** | ✅ 完成 | KeyTextFixer 事件过滤器合成 text 字段 |
| **Shift 组合键** | ✅ 完成 | KeyRelease text 补全（07-31 完成，待蓝牙键盘完整映射复核） |
| **剪贴板 Copy→Paste 回环** | ✅ 完成 | pasteboard NAPI read/write 集成（07-31 完成，待人工真机复核） |
| **ArkTS 菜单栏** | ✅ 完成 | 精确悬停切换 + 点击保持交互逻辑 |
| **工具栏 hover 提示** | ✅ 完成 | 自定义浮层覆盖 Qt XComponent，上下工具栏提示统一 |
| **Edit 组官方图标** | ✅ 完成 | 替换为桌面版官方图标资源 |
| **文件导入对话框** | ✅ 完成 | ArkTS DocumentViewPicker + 沙箱拷贝 + 队列命令 |
| **表格操作对话框** | ✅ 完成 | 添加列、设置列值、排序 |
| **2D 绘图对话框** | ✅ 完成 | 选择 Y 列绘图，plot2D 支持 13 种图型 |
| **分析操作对话框** | ✅ 完成 | 拟合、FFT、平滑等（analyzeCurve 11 种操作） |
| **矩阵操作对话框** | ✅ 完成 | 矩阵维度设置与值编辑 |
| **图编辑三功能** | ✅ 完成 | 添加曲线 / 误差棒 / 函数：参数化命令 + ArkTS 对话框 |
| **底部工具栏 Table 功能组** | ✅ 完成 | 尺寸 / 加列 / 列统计 / 行统计 4 按钮（table_size 按钮暂为占位，提示「未适配」） |
| **Qt 原生表格列控制面板** | ✅ 完成 | 恢复 d_control_tabs 原生面板，撤销 ArkTS 侧边栏方案 |
| **图形窗口打开即缩小** | ✅ 完成 | initMultilayerPlot showNormal |
| **用户反馈修复（5 项）** | ✅ 完成 | 侧边栏自动挂载、setViewportMargins 遮挡、工具栏右键、窗口控制状态机等 |
| **软键盘唤起** | ⏳ 计划中 | IME attach 链路 |
| **批次 2 缺失命令** | ⏳ 计划中 | normalize / convolve / getMatrixData / enrichments 6 命令 |
| **批次 3 全链路验收** | ⏳ 计划中 | 55 命令逐菜单点通，产出验收矩阵 |
| **打印 / 模板 / 脚本** | 远期 | P3（功能实施计划 F-32） |
| **3D 绘图** | 远期 | F-30，用户明确列为远期适配 |

---

## 技术栈 (Tech Stack)

| 层级 | 技术 |
|------|------|
| 应用引擎 | SciDAVis (C++ / Qt 5.15.12 Widgets) |
| 前端界面 | ArkTS (ArkUI) |
| 平台适配 | C++ NAPI |
| 图形层 | Qt for OpenHarmony QPA 插件 alpha_v6 (`libplugins_platforms_qopenharmony.so`) |
| 构建系统 | CMake + Ninja (Qt 层) / hvigor (HAP 层) |

> QPA 启动方式已定为 alpha_v6 插件 + `startQtApplication(dirs, appBinary)` + 自定义 C++ 线程回退方案（2026-07-31 真机实测结论）。AirStars 的 NEXT SDK 编译插件在 OpenHarmony 设备上缺少依赖库，已排除，详见 AGENTS.md。

---

## 项目结构 (Project Structure)

```
ohos/
├── AppScope/                  # 应用级配置 (app.json5, 图标资源)
├── entry/                     # 主模块
│   ├── libs/arm64-v8a/        # 预编译 native 库 (libentry.so 等)
│   └── src/main/
│       ├── cpp/               # qohos.cpp (NAPI 桥接, Qt 启动器)
│       ├── ets/               # ArkTS 页面与 Ability
│       │   ├── entryability/  # OHPlotAbility.ets (JS 桥接, 窗口管理)
│       │   ├── pages/         # MainLayout / TablePage / PlotPage / NoteEditor 等页面
│       │   │   └── dialogs/   # 13 个 ArkTS 对话框 (导入/导出/绘图/分析/矩阵/偏好等)
│       │   └── components/    # 12 个 ArkUI 组件 (MenuBar/ToolBar/BottomToolBar/DataTable 等)
│       └── resources/         # 字符串、颜色、图标等资源
├── docs/                      # 开发文档，索引见 docs/README.md (OHPlot 文档总览)
│   ├── README.md              # 文档总览（全部文档的索引入口）
│   ├── 功能计划/              # 功能实施计划路线图 (F-01 ~ F-32)
│   ├── 下一阶段/              # 下一阶段执行规格与 80% 功能实施计划
│   ├── 开发规范/              # 11 项编码/构建/调试/UI 开发规范
│   ├── 开发指南/              # 开发规范指南、菜单行为说明、修复规范
│   ├── 开发日志/              # 每日开发过程记录
│   ├── 验证报告/              # 真机验证报告
│   ├── 技能文档/              # Agent Skill 文档
│   └── 归档/                  # 历史归档文档
├── tools/                     # 诊断脚本与辅助工具
│   └── verify_smoke.py        # 冒烟验证入口（收编 verify_toolbar.py / verify_i18n.py）
├── diagnostics/               # 诊断产物存放（整体 .gitignore，不入库）
├── hvigor/                    # hvigor 构建配置
├── build-profile.json5        # 项目级构建配置
├── oh-package.json5           # 包管理配置
└── .gitignore
```

> **注意**: SciDAVis Qt 源码不在本仓库内，需从上游单独获取并通过 CMake 交叉编译生成 `libentry.so`。

---

## 环境依赖 (Environment)

| 工具 | 版本/路径 |
|------|-----------|
| DevEco Studio | 5.0+ (含 HarmonyOS SDK) |
| Qt for OpenHarmony | 5.15.12 交叉编译工具链 |
| CMake | 3.16+ |
| Ninja | 1.10+ (推荐 Strawberry Perl 附带的版本) |
| hdc | 随 HarmonyOS SDK 安装 |
| 目标设备 | OpenHarmony 平板 (已验证: 华为 MatePad 11.5, 2456x1600) |

---

## 构建流程 (Build)

### 1. 编译 Qt 应用层 (libentry.so)

```bash
# 在 Qt CMake 构建目录执行（该目录位于工作区外）
ninja -C <build-ohos-dir> scidavis
```

> **Windows 注意**: CMakeLists 的 POST_BUILD 步骤使用 Unix `cp`/`mkdir -p` 命令，在 Windows 上会报 `FAILED`，属预期现象。**链接产物 `libentry.so` 是有效的**，可直接取用。

### 2. 复制产物到 HAP 打包目录

```powershell
Copy-Item <build-ohos-dir>/scidavis/libentry.so entry/libs/arm64-v8a/libentry.so -Force
```

> 每次 native 构建后都需执行此复制；仅改 ArkTS 代码时无需复制。

### 3. 构建 HAP

```bash
"C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" \
  "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" \
  --mode module -p module=entry@default -p product=default \
  -p requiredDeviceType=tablet assembleHap \
  --analyze=normal --parallel --incremental --daemon
```

### 4. 部署到设备

```bash
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc shell "aa force-stop org.ohplot.ohos; hilog -r; aa start -a OHPlotAbility -b org.ohplot.ohos"
```

### 5. 冒烟验证

```bash
python tools/verify_smoke.py
```

> 核心功能改动须在真机（华为 MatePad 11.5）验证，「修复完成」声明须附带冒烟验证执行结果，详见 AGENTS.md。

---

## 已知限制与适配说明 (Known Limitations)

- **蓝牙鼠标左键**: QPA 插件的触摸分发链路会丢弃左键事件（ArkUI 将左键转为触摸管线后 QPA 的 `touchDown` 为空实现）。通过 ETS 透明覆盖层 + NAPI `sendMouse` + `scidavis_inject_mouse` 注入通道解决。
- **蓝牙键盘数字键**: QPA `handleKeyEvent` 的 text 字段恒为空，可打印字符无法进入编辑器。通过 `KeyTextFixer` 事件过滤器在 libentry.so 内合成 text 重投递；Shift 组合键的 KeyRelease text 补全已于 07-31 落地，完整映射待蓝牙键盘复核。
- **HighDpi**: 已禁用 (`QT_ENABLE_HIGHDPI_SCALING=0`)，所有坐标均为物理像素。
- **工具栏 hover 提示**: ArkUI 原生 bindPopup 浮层会被 Qt XComponent 渲染区域遮挡，已改为自定义浮层组件，上下工具栏提示样式与行为统一。

---

## 文档 (Documentation)

| 文档 | 说明 |
|------|------|
| [docs/README.md](docs/README.md) | OHPlot 文档总览（开发日志、开发规范、功能计划、验证报告等全部文档索引） |
| [CHANGELOG.md](CHANGELOG.md) | 版本变更记录与里程碑 |
| [LICENSE](LICENSE) | 许可协议 (GPL-2.0) |

---

## License

上游 SciDAVis 项目采用 **GPL-2.0** 许可。OHPlot 作为其 OpenHarmony 适配版本，遵循相同的 GPL-2.0 许可协议。

详见 [LICENSE](LICENSE) 文件。
