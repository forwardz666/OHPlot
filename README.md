# OHPlot for OpenHarmony

**OHPlot** 是 [SciDAVis](https://scidavis.org/)（Scientific Data Analysis and Visualization）开源科学数据分析与可视化软件的 **OpenHarmony** 平台适配版本。目标设备为华为 MatePad 11.5 平板。

本仓库包含 ArkTS 前端界面层、NAPI 桥接层及构建配置，底层的 Qt C++ 应用引擎从上游 SciDAVis 源码交叉编译。

---

## 适配状态

| 功能模块 | 状态 | 说明 |
|----------|------|------|
| **基础运行环境** | ✅ 完成 | Qt 5.15.12 for OpenHarmony 交叉编译，HAP 构建部署 |
| **Qt 引擎启动** | ✅ 完成 | 独立 C++ pthread 启动，绕过 NAPI 死锁 |
| **高 DPI 适配** | ✅ 完成 | 禁用 HighDpi 缩放，1:1 物理像素渲染 |
| **QPA 插件加载** | ✅ 完成 | require() 动态导入 + 备选路径 + 错误捕获 |
| **蓝牙鼠标左键** | ✅ 完成 | ETS 覆盖层 + NAPI sendMouse + `scidavis_inject_mouse` 注入通道 |
| **蓝牙键盘数字键** | ✅ 完成 | KeyTextFixer 事件过滤器合成 text 字段 |
| **JS 桥接** | ✅ 完成 | 窗口管理、输入法、区域设置、标准路径、光标 5 个对象 |
| **文件导入对话框** | ✅ 完成 | ArkTS DocumentViewPicker + 沙箱拷贝 + 队列命令 |
| **表格操作对话框** | ✅ 完成 | 添加列、设置列值、排序（Phase 2） |
| **2D 绘图对话框** | ✅ 完成 | 选择 Y 列绘图（Phase 2） |
| **分析操作对话框** | ✅ 完成 | 拟合、FFT、平滑等（Phase 3） |
| **矩阵操作对话框** | ✅ 完成 | 矩阵维度设置与值编辑（Phase 3） |
| **ArkTS 菜单栏** | ✅ 完成 | 精确悬停切换 + 点击保持交互逻辑 |
| **Qt 事件通道** | ✅ 完成 | `scidavis_emit` → NAPI TSFN → ArkUI 弹窗替换 |
| **粘贴板桥接** | 🔄 进行中 | pasteboard NAPI read/write 集成 |
| **Shift 组合键** | ⏳ 计划中 | KeyRelease text 补全 |
| **软键盘唤起** | ⏳ 计划中 | IME attach 链路 |

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 应用引擎 | SciDAVis (C++ / Qt 5.15.12 Widgets) |
| 前端界面 | ArkTS (ArkUI) |
| 平台适配 | C++ NAPI |
| 图形层 | Qt for OpenHarmony QPA 插件 (`libplugins_platforms_qopenharmony.so`) |
| 构建系统 | CMake + Ninja (Qt 层) / hvigor (HAP 层) |

---

## 项目结构

```
ohos/
├── AppScope/                  # 应用级配置 (app.json5, 图标资源)
├── entry/                     # 主模块
│   ├── libs/arm64-v8a/        # 预编译 native 库 (libentry.so 等)
│   └── src/main/
│       ├── cpp/               # qohos.cpp (NAPI 桥接, Qt 启动器)
│       ├── ets/               # ArkTS 页面与 Ability
│       │   ├── entryability/  # OHPlotAbility.ets (JS 桥接, 窗口管理)
│       │   └── pages/         # Index.ets (XComponent + 输入转发)
│       └── resources/         # 字符串、颜色、图标等资源
├── docs/                      # 开发文档
│   ├── DEVELOPMENT_GUIDE.md   # 开发规范与注意事项
│   └── archive/               # 历史诊断文档归档
├── tools/                     # 诊断脚本与辅助工具
├── hvigor/                    # hvigor 构建配置
├── build-profile.json5        # 项目级构建配置
├── oh-package.json5           # 包管理配置
└── .gitignore
```

> **注意**: SciDAVis Qt 源码不在本仓库内，需从上游单独获取并通过 CMake 交叉编译生成 `libentry.so`。

---

## 环境依赖

| 工具 | 版本/路径 |
|------|-----------|
| DevEco Studio | 5.0+ (含 HarmonyOS SDK) |
| Qt for OpenHarmony | 5.15.12 交叉编译工具链 |
| CMake | 3.16+ |
| Ninja | 1.10+ (推荐 Strawberry Perl 附带的版本) |
| hdc | 随 HarmonyOS SDK 安装 |
| 目标设备 | OpenHarmony 平板 (已验证: 华为 MatePad 11.5, 2456x1600) |

---

## 构建流程

### 1. 编译 Qt 应用层 (libentry.so)

```bash
# 在 build-ohos 目录 (Qt CMake 构建目录) 执行
ninja -C <build-ohos-dir> scidavis
```

> **Windows 注意**: CMakeLists 的 POST_BUILD 步骤使用 Unix `cp`/`mkdir -p` 命令，在 Windows 上会报 `FAILED`，但 **链接产物 `libentry.so` 是有效的**，可直接取用。

### 2. 复制产物到 HAP 打包目录

```powershell
Copy-Item <build-ohos-dir>/scidavis/libentry.so entry/libs/arm64-v8a/libentry.so -Force
```

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

---

## 已知限制与适配说明

- **蓝牙鼠标左键**: QPA 插件的触摸分发链路会丢弃左键事件（ArkUI 将左键转为触摸管线后 QPA 的 `touchDown` 为空实现）。通过 ETS 透明覆盖层 + NAPI `sendMouse` + `scidavis_inject_mouse` 注入通道解决。
- **蓝牙键盘数字键**: QPA `handleKeyEvent` 的 text 字段恒为空，可打印字符无法进入编辑器。通过 `KeyTextFixer` 事件过滤器在 libentry.so 内合成 text 重投递。
- **HighDpi**: 已禁用 (`QT_ENABLE_HIGHDPI_SCALING=0`)，所有坐标均为物理像素。

---

## 文档

| 文档 | 说明 |
|------|------|
| [DEVELOPMENT_GUIDE.md](docs/DEVELOPMENT_GUIDE.md) | 开发规范、编码约定、构建与调试注意事项 |
| [CHANGELOG.md](CHANGELOG.md) | 版本变更记录与里程碑 |
| [LICENSE](LICENSE) | 许可协议 (GPL-2.0) |
| [docs/archive/](docs/archive/) | 历史诊断文档归档 |

---

## License

上游 SciDAVis 项目采用 **GPL-2.0** 许可。OHPlot 作为其 OpenHarmony 适配版本，遵循相同的 GPL-2.0 许可协议。

详见 [LICENSE](LICENSE) 文件。
