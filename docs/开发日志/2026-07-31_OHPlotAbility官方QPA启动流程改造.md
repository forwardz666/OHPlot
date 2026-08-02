# 2026-07-31 工作日志：OHPlotAbility 切换官方 QPA 启动流程（P0-3）

## 工作内容
将 `OHPlotAbility.ets` 从 alpha_v6 插件 API 改造为 AirStars 新版 QPA 插件的官方启动流程
（`startQtApplication(this)` + `launchApplication/launchParams/launchWant` 属性 + 实验参数注入），
并用能力探测（`hasFn`）处理新旧插件 API 差异。解决真机上 `setDeviceType undefined` 导致 Qt 无法启动的问题。

## 完成项
- [x] QpaModule 接口重写：仅保留新插件实测导出符号 `startQtApplication(ability: object): boolean` /
      `handleGeometryChange` / `handleWindowEvent`（仍 `extends QpaInput`），删除全部 alpha_v6 setter 声明。
- [x] 新增能力探测辅助 `hasFn(k)` 与 `QpaOptionalModule`（旧插件可选符号，仅在有能力时调用）。
- [x] 新增 Ability 属性：`launchApplication='libentry.so'` / `launchParams=''` / `launchWant={} as Want`。
- [x] onCreate 注入三个实验参数（enableGlBackingStore / enableVsyncOnSoftwareBackingStore /
      enableSwapBufferSync = false）并保存原始 want 到 `this.launchWant`。
- [x] 删除 onWindowStageCreate 中全部 setter 调用块（含字体枚举逻辑）。
- [x] 启动改为 `qpa.startQtApplication(this)`（try-catch 包裹），保留 `!qtStarted` 时
      `qohos.startQtNative(dirs 三元组)` C++ 线程回退分支。
- [x] initQtBridge 的 `qtMajorVersion()` 改为能力探测，保证 `initJsObjectLoader` 桥注册必定执行（V0 关卡）。
- [x] `setJsQuitFunction`（Qt 退出后 2 秒 killAllProcesses）与 `quitQtApplication` 改为条件调用；
      两者都无时 Qt 退出依赖系统行为（已注释说明）。
- [x] arkts_check 通过：0 错误。

## 技术决策
- **决策 1**：接口只声明新插件确定存在的符号；旧插件符号放在独立的 `QpaOptionalModule` 接口中，
  全部调用置于 `hasFn()` 守卫之后，避免调用不存在的函数抛错。
- **决策 2**：`qpa as QpaOptionalModule` 直接转换被 ArkTS 拒绝（接口不重叠），改为
  `qpa as object as QpaOptionalModule` 双转。能力探测下标访问 `(qpa as object)[k]` 经 arkts_check 验证通过。
- **决策 3**：`qpaOpt.qtMajorVersion()` 探测失败不再阻断桥注册——桥注册（V0 关键）移到版本探测之后且
  版本探测不抛错（hasFn 返回 false 时跳过）。
- **决策 4**：移除 3 个因 setter 块删除而不再使用的 import（`@ohos.display` / `@ohos.font` / `@ohos.deviceInfo`），
  未引入任何新 import。

## 文件变更
| 文件 | 变更类型 | 说明 |
|------|---------|------|
| ohos/entry/src/main/ets/entryability/OHPlotAbility.ets | 修改 | 官方启动流程 + 能力探测，417 → 454 行 |

## 遗留问题
- **V0 真机验证点**：scidavis 的 libQt5Core.so 保留 JS 桥（initJsObjectLoader/QOpenHarmonyJsObject），
  新插件是否仍走桥通道需真机验证。
- 真机当前部署的是新插件；本改动是 P0-3，需在真机运行确认 Qt 启动（此前因 setDeviceType undefined 无法启动）。
- MyAbilityStage.ets 已调用 `attachAbilityStage(this)`，与本次 Ability 侧改造共同构成完整官方流程，未改动。

## 环境信息
- 项目: scidavis-ohos
- 日期: 2026-07-31
- Qt: 5.15.12
- QPA 插件: AirStars 新版（导出 attachAbilityStage/startQtApplication/launchApplication/launchParams/
  launchWant/handleGeometryChange/handleWindowEvent；不导出 setDeviceType/setDisplayMetrics/
  setResourceManager/setFontInfos/setTouchPad/setJsQuitFunction/qtMajorVersion/quitQtApplication）
- 依赖变更: 无（仅移除 3 个未用 import）
- 备份: backup-20260731-160829-airstars-p0/OHPlotAbility.ets.bak

## 后续建议
- 部署后真机验证：`hilog -x | grep SciDAVisChain` 与 `hilog -x | grep OHPlot` 确认
  startQtApplication(this) 返回、桥注册、heartbeat 顺序。
- 若官方流程生效，可评估移除 `startQtNative` C++ 线程回退分支（按 AGENTS.md 长期方案）。
