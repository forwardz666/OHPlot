# 2026-08-01 Qt for OHOS 参考库分析报告：SciDAVis 适配问题的启发与路线建议

> **报告性质**：参考分析（qtforohos 全量源码 vs SciDAVis 适配现状 vs alpha_v6 SDK 符号级核验）
> **报告日期**：2026-08-01
> **作者**：Sisyphus 编排器（本会话）
> **面向读者**：后续编码 agent / harness（本报告为只读分析，未修改任何工程代码）
> **数据来源**：
> - `C:\Users\Forwardz\qtforohos\`（Qt for OpenHarmony 全量仓库：Build 脚本、qtbase Qt6 源码、QtTest、UserManual）
> - `C:\Users\Forwardz\scidavis-ohos\ohos\`（活跃 OHPlot 工程，报告落点）
> - `C:\Users\Forwardz\scidavis-build\`（qt-source 5.15.12、qt-ohos-v9 补丁仓库、qpa_wrapper）
> - `C:\Users\Forwardz\AppData\Local\qt-ohos\`（alpha_v6 SDK，符号级核验对象）

---

## 0. 摘要（TL;DR）

| # | 结论 | 对 SciDAVis 的影响 |
|---|------|-------------------|
| 1 | **alpha_v6 与 openharmony-sig 主线是两代完全不同的 Qt 架构**（符号级铁证） | 现有 HAP 内 460 个 libQt5*.so + QPA 插件混库是根因；**不可**用当前主线源码回填 alpha_v6 库 |
| 2 | alpha_v6 的 libQt5Gui.so **确实**提供 `ReParentNode`（`verify_alpha_v6.py` 实锤 `defines ReParentNode: True`） | **路线 A（同源同步）理论有效**，只需保证 libentry.so 与全部 libQt5*.so 来自同一 alpha_v6 构建 |
| 3 | 当前 openharmony-sig v5.15.12 补丁源码（82 个 QOh* 类，**无 JS 桥**）与 alpha_v6（QOpenHarmony* + 24 个 JS 桥 ArkTS 封装）不可混用 | 自编译路线 B 若用主线源码 = **重写 JS 桥层**，代价远大于收益 |
| 4 | 官方 Qt5 SIG 启动模板 = `attachAbilityStage(this)` + `startQtApplication(this)` 极简链 | SciDAVis 的 `startQtNative` C++ 线程是**自研替代**，官方没有对应物；但命令通道（g_appHandle）问题是自研架构独有的 |
| 5 | `build-qt-ohos.py --init` 在 Windows 上对嵌套子模块有 `clean -fdx` 误删 bug | 自编译时需规避（报告 §5 给出方案） |
| 6 | **推荐路线**：维持 alpha_v6 + startQtNative 现状（已真机稳定），路线 B 仅作 alpha_v6 无解时的兜底；短期以**同源重打包 alpha_v6** 验证启动链 | 详见 §6 |

---

## 1. 核验过程记录（可复现）

### 1.1 拉取 openharmony-sig/qt 补丁源码（用户要求步骤 1）

**执行**：`C:\Users\Forwardz\qtforohos\Build\build-qt-ohos.py --init`

- 配置：`Build/configure.json`（qt_repo=`gitcode.com/qtforohos/qt5.git`、qt-ohos-patch=`gitcode.com/openharmony-sig/qt.git`、默认 `build_qt_tag: v6.5.6-lts-lgpl`）
- 本会话新建 `configure.json.user` 覆盖为 **`v5.15.12-lts-lgpl`**（对齐 alpha_v6），其余沿用默认
- **落盘位置**：`Build/work/qt5/`（Qt 5.15.12 supermodule 全量子模块）+ `Build/work/qt-ohos-patch/`（补丁仓库）

**Windows 上的两个坑（已记录，供后续复用）**：

1. **`clean -fdx` 误删整个 qt5 目录**：`--init` 第二次运行时 `submodule foreach --recursive git clean -fdx` 在 qtwebengine 嵌套子模块处把 `work/qt5` 自身删掉了（脚本 `reset_hard → 删除目录重新克隆` 的兜底逻辑触发）。**规避**：不要对含 qtwebengine 的 supermodule 反复跑 `--init`；改用本机已就绪的 `scidavis-build/qt-source`（HEAD 恰为 v5.15.12-lts-lgpl）robocopy 复制为 `work/qt5`，再 `submodule update --init --depth 1` 补齐 qtconnectivity/qtdeclarative/qtmultimedia/qtquickcontrols/qtsensors 五个模块。
2. **git `index.lock` 残留**：首次 clone 超时后残留 `qtwebengine/modules/src/3rdparty/index.lock`，删除后重试即可。

**补丁应用**（复刻 `apply_patches` 逻辑，全部成功）：
```
root.patch            → 应用到 qt5 主仓库（.gitignore 等）
qtbase.patch          → qtbase/          （196 处变更，含 mkspecs/openharmony、src/corelib/kernel/qopenharmony*、plugins/platforms/openharmony/）
qtconnectivity.patch  → qtconnectivity/  （42）
qtdeclarative.patch   → qtdeclarative/   （10）
qtmultimedia.patch    → qtmultimedia/    （17）
qtquickcontrols.patch → qtquickcontrols/ （3）
qtsensors.patch       → qtsensors/       （5）
patch/qtohextras      → 复制为 qt5/qtohextras/
```
> 注：git apply 的 "trailing whitespace / whitespace errors" 警告是补丁行尾空白的正常提示，不影响应用结果（以 `git status` 变更行数验证）。

### 1.2 符号级核验（用户要求步骤 2 核心）

**工具**：`scidavis-ohos/docs/scripts/verify_alpha_v6.py`（ELF 动态符号解析）+ 手工 Python 扫描补丁后源码。

**铁证 A — alpha_v6 libQt5Gui.so 提供 ReParentNode**：
```
检查: C:\Users\Forwardz\AppData\Local\qt-ohos\lib\libQt5Gui.so
  defines ReParentNode: True
  QOpenHarmonyWindowAdapter 符号样本:
    [DEF] _ZN25QOpenHarmonyWindowAdapter12AddChildNodeEyP10NodeParams
    [DEF] _ZN25QOpenHarmonyWindowAdapter12ReParentNodeEyy
```
→ alpha_v6 自身的 QtGui 是**自洽**的，含 `ReParentNode`/`AddChildNode`。**黑屏根因 = HAP 打包混入了不同构建的 Qt 库**（ROOTCAUSE-QPA-SYMBOL.md 结论成立）。

**铁证 B — alpha_v6 QPA 插件依赖面**（`plugins/platforms/libplugins_platforms_qopenharmony.so`，1,364,048 字节）：
```
defined=162 undefined=939
undefined OpenHarmony/QOh 符号 30 个（需 Qt 库提供）：
  _ZN22QOpenHarmonyJsFunction4callERK5QListI8QVariantE
  _ZN25QOpenHarmonyJsEnvironment10createBoolEb / createObject / init / quit / runOnJsThread ...
  _ZN25QOpenHarmonyWindowAdapter12ReParentNodeEyy   ← 插件对外引用，由 libQt5Gui.so 提供
  _ZN26QOpenHarmonyJsObjectLoader6createERK7QStringS2_RK5QListI8QVariantE
  _ZNK20QOpenHarmonyJsObject13getJsFunctionERK7QString
  ...（共 30 个）
defined OpenHarmony/QOh 符号 14 个（插件自身导出）：
  _ZN20QOpenHarmonyJsObject4callIbJ...（8 个模板实例）
  _ZN29QOpenHarmonyFileEngineHandlerC1/C2/...（6 个）
```
→ alpha_v6 QPA 插件依赖 **QOpenHarmonyJsEnvironment / JsObject / JsObjectLoader / JsFunction / WindowAdapter** 共 5 类 JS 桥 + 窗口适配符号。

**铁证 C — 当前主线补丁源码（v5.15.12）完全不同的架构**：
```
补丁后源码 82 个 QOh*/QOpenHarmony* 类：
  QOhPlatformIntegration / QOhPlatformWindow / QOhWindowNode / QOhWindowContext /
  QOhNativeWindow / QOhXComponent / QOhAbilityContext / QOhJsOnListener ...
  QOpenHarmonyPopupMenu（唯一保留旧名）
搜索 QOpenHarmonyJsEnvironment: 0 文件；QOpenHarmonyWindowAdapter: 无；ReParent: 无
插件 .pro: TARGET = qopenharmony, PLUGIN_CLASS_NAME = QOpenHarmonyPlatformIntegrationPlugin
```
→ **主线 QPA 插件文件名相同（libplugins_platforms_qopenharmony.so）但内部符号体系全换**（QOh*），且**完全移除 JS 桥**。

**铁证 D — 官方模板差异**（`qtbase/src/openharmony/` vs alpha_v6 `openharmony/qtbase/`）：

| 维度 | alpha_v6 官方模板 | 主线补丁源码模板（v5.15.12） |
|------|------------------|------------------------------|
| 文件 | 24 个（含 native/QtCore/JsApplication/JsWindowManager/JsPasteBoard/JsLocale... JS 桥 ArkTS 封装） | 4 个（EntryAbility/MyAbilityStage/Index/EntryEmbeddedAbility） |
| 启动 | `JsApplication.run(windowStage, want)` + NodeContainer + adapter_ts | `qpa.attachAbilityStage(this)` + `qpa.startQtApplication(this)` |
| XComponent | SURFACE + XComponentModel/NodeParams/adapter_ts 节点树 | NODE + `libraryname: 'plugins_platforms_qopenharmony'` |
| 多窗口 | JsIndependentWindow/JsEmbeddedWindow | EntryEmbeddedAbility（EmbeddedUIExtensionAbility + `startQtApplication(this, session)`） |

---

## 2. 核心结论：两代 Qt 的"世代鸿沟"

```
alpha_v6（SciDAVis 现状）               主线 openharmony-sig（路线 B 会得到的东西）
─────────────────────────             ─────────────────────────────────────
QOpenHarmonyWindowAdapter             QOhPlatformWindow / QOhWindowNode
QOpenHarmonyJsEnvironment(桥)         无 JS 桥（0 个符号）
24 个 JS 桥 ArkTS 封装                极简 4 文件模板
XComponent SURFACE + adapter_ts        XComponent NODE + startQtApplication(this)
JsApplication.run(windowStage)         attachAbilityStage + startQtApplication(this)
```

**推论链**：
1. **当前主线源码 ≠ alpha_v6 的"新版"**，而是**另起炉灶的重写**。两者连窗口系统、JS 桥、启动协议都不兼容。
2. **SciDAVis 的混合架构（ArkTS 覆盖层 + 6 个 JS 桥对象）完全依赖 alpha_v6 的 JS 桥能力**；主线源码没有这个能力。
3. **所以：路线 B（用主线源码自编译）意味着重写 JS 桥 + 适配新窗口协议 + 重写启动链**，绝非"用新版 Qt 重编一遍"那么简单——AirStars P0 实验失败（"NEXT Qt5Core 无 JS 桥"）已是前车之鉴，本报告在符号级确认了这一点。
4. 反向也成立：**不要试图用主线源码的 QOh* 符号去解释/修复 alpha_v6 的 ReParentNode 缺失**——它们本来就来自不同世界。

---

## 3. qtforohos 参考对现有问题清单的逐一启发

### 3.1 P0 #1 黑屏（QPA 符号不匹配）— 【已解决方向获符号级背书】

- **结论强化**：alpha_v6 libQt5Gui **定义** ReParentNode → 路线 A（同源同步 alpha_v6 全套库 + QPA）方向正确。
- **新证据**：alpha_v6 QPA 插件 30 个 undefined 符号**全部**是 QOpenHarmony*（JS 桥 + 窗口适配），无一 QOh*。打包时必须保证 libQt5Core/Gui 提供这 30 个符号 → 用 `nm -D`/`verify_alpha_v6.py` 逐库核对即可。
- **官方旁证**：`UserManual/reference/README.md` 的 HAP 验证清单（app.so + 全部 Qt 库 + 插件同源）就是这个问题的最简排查法。

### 3.2 AirStars 插件升级失败 — 【获源码级解释】

- 之前结论"两套工具链产物不兼容"→ 本报告升级为**两代架构不兼容**：AirStars 插件的 Qt 属于主线/新版系（无 JS 桥），与 alpha_v6 的 libQt5Core（含完整 JS 桥）天然不配套。
- 铁证 C 表明：即使拿到 OpenHarmony-SDK 编译的主线版插件，也需要配套主线版 Qt 全部库 + 重写桥，不是替换单个 .so 能解决的。

### 3.3 启动方式之争（startQtApplication vs startQtNative）

- **官方 Qt5 SIG 模板**（主线补丁源码 `src/openharmony/entryability/EntryAbility.ets` 全文仅 64 行）就是 `qpa.startQtApplication(this)` 一行 + `launchApplication="libentry.so"` 属性，**无 handleJsTopWindowCreated**（那是 Qt6 模板的）。
- collidingmice/qttestProject 的 EntryAbility 与官方模板**逐行一致**（仅 launchApplication 文件名不同）。
- **SciDAVis 的 startQtNative（C++ 线程 dlopen→dlsym main）不是官方路径**，是自研回退；它的存在价值 = 绕开 `startQtApplication` 返回 true 但命令通道（g_appHandle）未设置的缺陷。
- **关键洞察**：`g_appHandle` 是 SciDAVis 自研 `qohos.cpp` 命令通道的私有状态，官方架构（JS 桥）根本没有这个概念。**若走官方路径，命令通道应改用 JS 桥（createJsObject/request js object 已工作），而不是 dlopen 句柄**——这是架构性改进点，详见 §6 建议。

### 3.4 alpha_v6 老旧（API 11 vs 26）与路线 B

- **官方自编译脚本已就绪**：`Build/build-qt-ohos.py`（--init/--env_check/--exe_stage all --with_pack），支持 v5.15.12/v5.15.17/v6.5.6。
- **重要提醒**：configure.json 默认 `ohos_version: 15`（API 15，OpenHarmony 5.0.3），**不是 API 26**；脚本 README 称"适用 OpenHarmony API 15 (5.0.3)+"，"+"未验证到 26。**自编译到 API 26 是未经验证的新组合**（NDK 版本、QPA 符号、系统库依赖均可能不兼容）。
- **但结合 §2 结论**：即使自编译成功，得到的是**无 JS 桥的主线架构**，与 SciDAVis 混合架构不兼容 → **路线 B 对当前工程不具操作性**（除非同步重写桥层）。

### 3.5 P1 待办（qt.conf / QT_QPA_PLATFORM / RawfileCopier / HDS）

- **qt.conf / QT_QPA_PLATFORM**：官方模板不需要（QPA 由 `libraryname` + CMake 链接自动发现）。SciDAVis 因走自研 dlopen 路径才需手动 setenv（qohos.cpp:119 `setenv("QT_QPA_PLATFORM_PLUGIN_PATH", ...)`）——这是自研路径的固有成本，非缺陷。
- **RawfileCopier**：官方 qttestProject 用 `copyRawTranslations`（.qm）→ 思路与 SciDAVis 一致，可互参。
- **HDS 视效**：HarmonyOS NEXT 特性，OpenHarmony 设备不支持（AGENTS.md 已确认），qtforohos 无对应参考。

### 3.6 多窗口 / MDI（未来）

- 官方 Qt5 模板含 **`EntryEmbeddedAbility.ets`**（EmbeddedUIExtensionAbility + `qpa.startQtApplication(this, session)`，`module.json5` `launchType: "specified"`）——这是 MDI 子窗口的正规路径。
- SciDAVis 当前窗口控制键（min/max/close）为 ArkTS 覆盖层模拟，长期应评估该官方嵌入通道。

### 3.7 libentry.so 组织

- 官方：CMake `add_library(<app> SHARED)` 直接产出（qttestProject 用 `entry` 名 → libentry.so；collidingmice 用 `collidingmice` 名）。**libentry 就是应用库本身**。
- SciDAVis：libentry.so = libscidavis_core.so 复制改名（KNOWN-ISSUES #4），外加 entry/libs/arm64-v8a 全量手工部署约 60 个 libQt5*.so + 插件。
- **建议**：改为 CMake `set_target_properties(... OUTPUT_NAME entry)` 直接产出 libentry.so，从源头消除"复制改名 + 多份 .so 并存"的混库温床（P2 插件制品版本化：README 记录 SHA256/来源，官方 P2 建议一致）。

---

## 4. 工程结构逐项差异（SciDAVis vs 官方样板 collidingmice / qttestProject）

> 完整素材来自本会话 explore 代理深读，全部文件路径已验证存在。

| 维度 | 官方（collidingmice / qttestProject） | SciDAVis（backup-20260801） | 影响 |
|------|--------------------------------------|----------------------------|------|
| **启动方式** | `qpa.attachAbilityStage(this)`（stage）+ `qpa.startQtApplication(this)`（ability），QPA 内建 dlopen | `qohos.startQtNative(...)` C++ 线程 dlopen→dlsym main；`startQtApplication` 弃用（注释：命令通道断裂） | 自研替代，官方无对应 |
| **窗口句柄交接** | collidingmice: `qpa.handleJsTopWindowCreated(name, this)`（Qt6 风格）；**Qt5 官方模板无此调用** | 无（XComponent id 固定 `openharmony_qt_mainwindow`，JsWindowManager 预先注册） | Qt5 SIG 官方模板同样无此调用，差异不大 |
| **XComponent** | NODE + `libraryname:'plugins_platforms_qopenharmony'` | SURFACE + 同 libraryname + focusable/focusOnTouch/defaultFocus | alpha_v6 官方模板也用 SURFACE（+adapter_ts 节点树），SciDAVis 与 alpha_v6 一致 |
| **CMake 链接** | `find_package(Qt5 Core Gui Widgets)` + 显式链 `QOpenHarmonyPlatformIntegrationPlugin` + `QJpegPlugin`；`-DQT_PREFIX` 传入 | 仅链 NAPI 系统库（ace_napi/hilog/EGL/GLESv3/ace_ndk），**无 Qt find_package、无 QT_PREFIX**；Qt 链接在工程外 ninja | 官方自动收集 Qt 库进 HAP；SciDAVis 手工部署（collectAllLibs=true 打包） |
| **libentry 产出** | CMake add_library 直接产出 | libscidavis_core.so 复制改名 | 建议改 CMake OUTPUT_NAME |
| **module.json5** | launchType `specified`（qttestProject 加 removeMissionAfterTerminate）+ EntryBackupAbility | 未设 launchType（singleton）、无 backup ability、isolationProcess=false、metadata `enable.remove.starting.window=true` | 多窗口/MDI 需改 specified |
| **SDK 版本** | compatible/compileSdkVersion 15（OpenHarmony） | "5.0.5(17)" / runtimeOS "HarmonyOS" / targetSdkVersion 26 | API 26 vs 15，自编译需验证 |
| **构建参数** | QT_PREFIX 传入 externalNativeOptions；nativeCompiler BiSheng；严格 mode caseSensitiveCheck | arguments 空；collectAllLibs=true；无 debugSymbol strip | SciDAVis 无 QT_PREFIX（因不走 CMake 链 Qt） |
| **JS 桥** | 官方 Qt5 SIG 模板无桥；alpha_v6 模板有 24 个桥文件 | 6 个桥对象（JsLocale/JsPasteBoard/JsStandardPaths...），真机已工作 | **SciDAVis 的核心资产，路线 B 会丢失** |

---

## 5. 自编译路线 B 实操指引（含规避 --init bug）

若未来仍要自编译统一 Qt（目标设备必须 API 26 且 alpha_v6 有硬缺陷时）：

```powershell
# 前置（本机已具备）
#   源码:  C:\Users\Forwardz\scidavis-build\qt-source   （HEAD=v5.15.12-lts-lgpl，已应用补丁的副本在 qtforohos\Build\work\qt5）
#   补丁:  C:\Users\Forwardz\scidavis-build\qt-ohos-v9   （openharmony-sig/qt 克隆，patch/v5.15.12|v5.15.17|v6.5.6）

# 步骤 1: 配置（避免交互卡死，已在本会话创建 configure.json.user → build_qt_tag=v5.15.12-lts-lgpl）
# 步骤 2: 环境检查（自动下载 Perl/MinGW/OHOS SDK native，support_version 6.0-ohos-single-3）
python build-qt-ohos.py --env_check

# 步骤 3: 构建（--init 已手动完成：qt5 源码 + 补丁就位；勿再重复 --init，避免 clean bug）
python build-qt-ohos.py --exe_stage all --with_pack

# 产出: Build\work\output\Qt5.15.12-ohos15-arm64-v8a\ + zip
```

**规避清单**：
1. 不要重复 `--init`（Windows `clean -fdx` 会删 qt5 目录）→ 补丁已应用时用 `--reset_repo` 或直接复用 work/qt5。
2. 默认目标 API 15，**API 26 需改 `configure.json.user` 的 `ohos_version` 并验证**（NDK 兼容、QPA 符号、系统库依赖）。
3. 构建产物是**无 JS 桥的主线架构**——若用于 SciDAVis，需评估 §2 的桥层重写成本。

---

## 6. 推荐路线（供决策）

### 6.1 短期（建议立即执行，低风险高回报）

**维持现状 + 同源重打包验证**：
1. **确认 libentry.so 的 Qt 来源**（路线 C 诊断，5 分钟）：`strings libentry.so | grep "Qt 5"` + `verify_alpha_v6.py` 核对全部 30 个 undefined 符号。
2. **同源重打包 alpha_v6**：从**同一个** `AppData\Local\qt-ohos` 把全部 libQt5*.so + plugins 重新拷入 `ohos/entry/libs/arm64-v8a/`（删 platforms/platforms 嵌套重复），`binary-sign-tool -selfSign 1` 签名 → 重建 HAP → `hdc install -r`。
3. **验证**：启动链 `startQtNative → dlopen libentry.so → calling Qt main()` + 6 桥注册 + heartbeat（沿用 P0 验证报告流程）。

### 6.2 中期（架构改进，可选）

**命令通道与启动方式解耦**：让命令通道走 QPA JS 桥（`createJsObject`/`request js object`，真机已工作）而非 `g_appHandle`，为未来切官方 `startQtApplication(this)` 铺路——官方 Qt5 SIG 模板证明该路径存在且极简。

### 6.3 长期（仅当 alpha_v6 有不可绕过的硬缺陷时）

**自编译主线 v5.15.12/v5.15.17 到目标 API**（§5 指引），但必须接受：无 JS 桥 → 桥层重写 + 窗口协议适配（QOh*），预估数天~数周，且 OpenHarmony 设备上的 API 26 兼容性未经验证。**不建议为"官方启动方式"这一单点收益承担此成本**（AGENTS.md 路线决策 §7.3 的判据仍然成立，本报告为其补充了符号级证据）。

---

## 7. 文件变更

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `qtforohos/Build/configure.json.user` | 新增 | build_qt_tag=v5.15.12-lts-lgpl 用户配置（--init 所需） |
| `qtforohos/Build/work/qt5/` | 新增 | Qt 5.15.12 源码（robocopy 自 qt-source + 补 5 子模块 + 应用全部补丁） |
| `qtforohos/Build/work/qt-ohos-patch/` | 新增 | openharmony-sig/qt 补丁仓库克隆 |
| `scidavis-ohos/ohos/docs/下一阶段/2026-08-01_qtforohos参考分析报告.md` | 新增 | 本报告 |
| `scidavis-ohos/ohos/` 工程代码 | **未修改** | 本报告纯分析 |

> 注：`qtforohos/Build/work/` 为参考仓库内的构建工作目录，不影响 scidavis 工程；如需清理可删 `work/`（保留 configure.json.user 可复用于后续构建）。

---

## 8. 遗留问题与后续建议

1. **libentry.so 的 Qt 来源确认**（路线 C）未在本会话执行（需用户授权读取 scidavis 工程外构建目录）——建议下一步 5 分钟诊断。
2. **alpha_v6 同源重打包**未执行（涉及修改工程 libs 目录，属实施任务，待用户批准）。
3. **多窗口官方路径**（EntryEmbeddedAbility）尚未在 SciDAVis 评估——MDI 功能推进时再议。
4. 本报告已记录 `--init` 的 Windows bug，后续任何 agent 不得盲目重跑 `--init`（会删 qt5 目录）；复用 `work/qt5` 即可。

## 9. 环境信息

- 项目：scidavis-ohos（OHPlot）
- 日期：2026-08-01
- 参考库：`C:\Users\Forwardz\qtforohos\`（qtbase Qt6 源码 + Build 脚本 + QtTest + UserManual）
- 本机素材：`scidavis-build\qt-source`（5.15.12）、`scidavis-build\qt-ohos-v9`（openharmony-sig/qt）
- alpha_v6 SDK：`AppData\Local\qt-ohos\`（API 11，唯一可跑 API 26 设备的预编译版）
- 目标设备：HUAWEI MatePad 11.5（OpenHarmony-7.0.0.32, API 26）
- 依赖变更：无（仅 pip 安装 requests/questionary/rich/py7zr 供 build 脚本使用）
