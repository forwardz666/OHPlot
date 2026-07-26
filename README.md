# SciDAVis for OpenHarmony

**SciDAVis** (Scientific Data Analysis and Visualization) 是一款开源科学数据分析与可视化软件。本仓库包含其在 **OpenHarmony** 平台上的移植适配层，目标设备为华为 MatePad 11.5 平板。

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 应用逻辑 | SciDAVis (C++ / Qt 5.15.12 Widgets) |
| 平台适配 | ArkTS + C++ NAPI |
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
│       │   ├── entryability/  # SciDAVisAbility.ets (JS 桥接, 窗口管理)
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
hdc shell "aa force-stop org.scidavis.ohos; hilog -r; aa start -a SciDAVisAbility -b org.scidavis.ohos"
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

SciDAVis 上游项目采用 **GPL-2.0** 许可。本 OpenHarmony 适配层代码跟随上游许可协议。

详见 [LICENSE](LICENSE) 文件。
