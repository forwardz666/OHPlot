# L2 T4-B: new GraphPropsDialog for plot customization (GLM-5.1). Standalone file; L1 wires it later.
$root = 'c:\Users\Forwardz\scidavis-ohos\ohos'

$task = @'
任务：为 HarmonyOS ArkTS 应用 OHPlot 新建对话框文件 entry/src/main/ets/pages/dialogs/GraphPropsDialog.ets（当前激活 Graph 的属性面板）。只创建这一个文件，不改任何其他文件。

先读参考文件学习本项目约定：
- entry/src/main/ets/pages/dialogs/Plot2DDialog.ets（@CustomDialog 结构、callQtCommand 用法、按钮布局）

数据来源（C++ 侧命令，正在并行开发，按契约写即可），全部经 qtInjector.callQtCommand(cmd, argsJson)（从 'libqohos.so' 导入 qohos，接口 interface QohosInjector { callQtCommand(cmd: string, argsJson: string): string; }，参考 Plot2DDialog 现有写法）：
- setGraphTitle  参数 {"title": string}
- setAxisTitle   参数 {"axis": number, "text": string}   axis: 0=左(Y) 1=右 2=下(X) 3=上
- setAxisScale   参数 {"axis": number, "scale": "log"|"linear"}
- toggleLegend   参数 {}
这四个都是 mutation 命令（fire-and-forget），返回值不必解析，调用包 try-catch 即可。

UI 设计（照此实现）：
1. @CustomDialog export struct GraphPropsDialog，controller: CustomDialogController；
2. 标题 'Graph Properties'；
3. 表单区（Column，间距 8vp）：
   - TextInput 'Graph title' -> @State titleText: string = ''，旁边 Apply 小按钮：调 setGraphTitle；
   - TextInput 'X axis title' + Apply：setAxisTitle axis=2；
   - TextInput 'Y axis title' + Apply：setAxisTitle axis=0；
   - 两个 Toggle：'Log X axis'（@State logX: boolean = false，onChange 调 setAxisScale axis=2 scale=log/linear）、'Log Y axis'（同理 axis=0）；
   - Button 'Toggle Legend'：调 toggleLegend；
4. 底部 Close 按钮关闭 controller；
5. ArkTS 静态约束：不用 any；argsJson 用 JSON.stringify 于显式类型的局部 record/接口对象，或直接拼接字符串（参考 Plot2DDialog 的现有做法保持一致）；所有成员显式类型与初值。
完成后回复 done。
'@

Set-Location $root
deveco run $task --model deveco/GLM-5.1 2>&1
