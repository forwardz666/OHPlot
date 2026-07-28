# L3 batch 1: four non-overlapping small tasks via deepseek-v4-flash (parallel jobs <=4).
$root = 'c:\Users\Forwardz\scidavis-ohos\ohos'

$t1 = @'
编辑文件 entry/src/main/resources/zh_CN/element/string.json（JSON资源文件，保持合法JSON，不动其他条目）：
1. 在 "string": [ 数组开头新增3个条目：
{ "name": "module_desc", "value": "OHPlot Qt 应用" },
{ "name": "read_pasteboard_reason", "value": "从其他应用粘贴数据到表格" },
{ "name": "ability_desc", "value": "OHPlot 主入口" },
2. 修改4个已有条目的value（品牌由SciDAVis改为OHPlot）：
help_about 改为 "关于 OHPlot..."；about_title 改为 "关于 OHPlot"；about_version 改为 "OHPlot 2.0.0"；about_copyright 改为 "版权所有 (C) 2024 SciDAVis 团队 — OHPlot OpenHarmony 移植"。
只改这个文件。完成后回复 done。
'@

$t2 = @'
编辑文件 entry/src/main/resources/en_US/element/string.json（JSON资源文件，保持合法JSON，不动其他条目）：
1. 在 "string": [ 数组开头新增3个条目：
{ "name": "module_desc", "value": "OHPlot Qt application" },
{ "name": "read_pasteboard_reason", "value": "Paste data from other apps into tables" },
{ "name": "ability_desc", "value": "OHPlot main ability" },
2. 修改4个已有条目的value：
help_about 改为 "About OHPlot..."；about_title 改为 "About OHPlot"；about_version 改为 "OHPlot 2.0.0"；about_copyright 改为 "Copyright (C) 2024 SciDAVis Team — OHPlot OpenHarmony port"。
只改这个文件。完成后回复 done。
'@

$t3 = @'
新建文件 entry/src/main/ets/pages/dialogs/PreferencesDialog.ets（HarmonyOS ArkTS，@CustomDialog 组件，仅UI样板不接逻辑）。
先读 entry/src/main/ets/pages/dialogs/AboutDialog.ets 学习本项目的 @CustomDialog 写法/命名/缩进约定，然后照该风格实现：
- @CustomDialog export struct PreferencesDialog，含 controller: CustomDialogController；
- 左侧分类列表（General / Tables / Plots 三项，@State 记录选中索引）；右侧内容区按选中分类显示占位设置项：General 页放一个 Toggle（"Autosave"，@State boolean）和一个 TextInput（"Autosave interval (min)"）；Tables 页放 Toggle（"Show comments"）；Plots 页放 Toggle（"Antialiasing"）；
- 底部 Row 两个按钮：Cancel（关 controller）、Apply（暂时只关 controller，留 TODO 注释说明后续经 get/setPreference 命令接线）；
- 遵守 ArkTS 静态约束：不用 any，所有变量显式类型，struct 成员逐个初始化。
只创建这一个文件，不改其他文件。完成后回复 done。
'@

$t4 = @'
新建文件 entry/src/main/ets/pages/dialogs/ScriptConsoleDialog.ets（HarmonyOS ArkTS，@CustomDialog 组件，占位桩）。
先读 entry/src/main/ets/pages/dialogs/AboutDialog.ets 学习本项目的 @CustomDialog 写法/命名/缩进约定，然后照该风格实现：
- @CustomDialog export struct ScriptConsoleDialog，含 controller: CustomDialogController；
- 标题 "Script Console"；内容区一个只读多行 TextArea（enabled(false)，占位文本 "Scripting backend is not yet available on OpenHarmony."）和一行灰色说明 Text（"TODO: muParser/Python console will be wired in a later phase."）；
- 底部 Close 按钮关闭 controller；
- 遵守 ArkTS 静态约束：不用 any，所有变量显式类型。
只创建这一个文件，不改其他文件。完成后回复 done。
'@

$jobs = @(
  (Start-Job -ArgumentList $root, $t1 { param($r, $p) Set-Location $r; deveco run $p --model deepseek/deepseek-v4-flash 2>&1 }),
  (Start-Job -ArgumentList $root, $t2 { param($r, $p) Set-Location $r; deveco run $p --model deepseek/deepseek-v4-flash 2>&1 }),
  (Start-Job -ArgumentList $root, $t3 { param($r, $p) Set-Location $r; deveco run $p --model deepseek/deepseek-v4-flash 2>&1 }),
  (Start-Job -ArgumentList $root, $t4 { param($r, $p) Set-Location $r; deveco run $p --model deepseek/deepseek-v4-flash 2>&1 })
)
Wait-Job $jobs -Timeout 600 | Out-Null
$i = 1
foreach ($j in $jobs) {
  Write-Output "===== JOB $i state=$($j.State) ====="
  Receive-Job $j
  $i++
}
