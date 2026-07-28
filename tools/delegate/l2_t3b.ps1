# L2 T3-B: new ProjectTree sidebar component (GLM-5.1). Standalone file; L1 wires it into MainLayout later.
$root = 'c:\Users\Forwardz\scidavis-ohos\ohos'

$task = @'
任务：为 HarmonyOS ArkTS 应用 OHPlot 新建组件文件 entry/src/main/ets/components/ProjectTree.ets（项目浏览器侧栏树）。只创建这一个文件，不改任何其他文件。

先读两个参考文件学习本项目约定：
- entry/src/main/ets/components/StatusBar.ets（组件结构/命名/缩进）
- entry/src/main/ets/pages/MainLayout.ets 顶部（libqohos.so 的导入与 QohosInjector 接口写法、hilog 用法）

数据来源（C++ 侧命令，正在并行开发，按契约写即可）：
qtInjector.callQtCommand('getProjectTree', '{}') 返回 JSON 字符串：
{"success":true,"data":{"name":"UNTITLED","type":"Folder","children":[{"name":"Table1","type":"Table","children":[]},...]}}
type 取值：Folder | Table | Matrix | MultiLayer | Note。命令可能失败或返回 {"success":false,...}，必须 try-catch 且判 success。

组件设计（照此实现，不要自行更改设计）：
1. 文件内定义接口：
   interface TreeNode { name: string; type: string; children: TreeNode[]; }
   interface TreeResponse { success: boolean; data?: TreeNode; error?: string; }
   interface FlatRow { name: string; type: string; depth: number; isFolder: boolean; expanded: boolean; }
2. @Component export struct ProjectTree：
   - @Prop @Watch('onTickChange') refreshTick: number = 0;  // 父组件自增触发重载
   - @Prop activeName: string = '';                          // 当前激活窗口名，行高亮用
   - onActivate: (name: string) => void = (name: string) => {}; // 双击窗口节点回调，父组件负责调 activateWindow
   - @State private rows: FlatRow[] = [];
   - @State private collapsed: Set<string> 不允许（ArkTS @State 用数组）：改用 @State private collapsedKeys: string[] = [];
   - 私有方法 reload()：调 callQtCommand('getProjectTree','{}')，解析后深度优先把树拍平成 rows（跳过被折叠文件夹的子孙；key 用 depth+'/'+name 判断是否在 collapsedKeys）；aboutToAppear() 和 onTickChange() 都调 reload()。
3. build()：Column 内 Scroll + ForEach(this.rows)。每行 Row：
   - 左缩进 padding = depth * 14vp；
   - 文件夹行显示 '▸'/'▾'（依折叠态）+ 名称，onClick 切换折叠并重建 rows；
   - 窗口行显示类型图标字符（Table:'▦' Matrix:'▩' MultiLayer:'◪' Note:'▤' 其他:'•'）+ 名称，name === activeName 时背景 '#3A6EA5' 文字白色；
   - 窗口行双击激活：用 TapGesture({ count: 2 }) 调 this.onActivate(row.name)；
   - 行高 28vp，字号 12fp，超长 TextOverflow.Ellipsis。
4. 顶部一行小标题 'Project' + 右侧刷新小按钮（文本 '⟳'）点击调 reload()。
5. ArkTS 静态约束：不用 any/unknown 直用，JSON.parse 结果 as 到接口；所有成员显式类型与初值；不用对象字面量以外的动态属性。
完成后回复 done。
'@

Set-Location $root
deveco run $task --model deveco/GLM-5.1 2>&1
