# L2 fix2: T2/T3/T4 ETS — new_project confirm dialog, real quit, fallback toast (GLM-5.1).
# cwd = repo root so the agent can read the ohos/ tree.
$root = 'c:\Users\Forwardz\scidavis-ohos'

$task = @'
任务：修改 ArkTS 文件 ohos/entry/src/main/ets/pages/MainLayout.ets，共 3 处改动。这是 OHPlot（HarmonyOS NEXT，ArkTS 严格模式）主布局页。只改这一个文件，不要读或改仓库其他目录。

背景：菜单点击经 onMenuItemClick(itemId) -> dispatchMenuItem(itemId) 的 switch 分发。callQtCommand 经 qtInjector（文件顶部已有 interface QohosInjector 与 const qtInjector）。文件已 import common from '@ohos.app.ability.common' 和 hilog。DOMAIN/TAG 常量已有。MenuActionArgs 接口（{itemId: string}）已有。refreshUiState() 私有方法已有。@State projectPath: string 已有。

改动 1（new_project 确认对话框）：在 dispatchMenuItem 的 switch 中、case 'new_table' 之前，新增 case 'new_project'：调用 this.getUIContext().showAlertDialog({...})，title: 'New Project'，message: '当前项目中未保存的内容将丢失。确定新建项目？'，primaryButton: { value: '取消', action: () => {} }，secondaryButton: { value: '确定', fontColor: Color.Red, action: () => { ... } }。确定回调里：const result: string = qtInjector.callQtCommand('menuAction', JSON.stringify({ itemId: 'new_project' } as MenuActionArgs)); hilog.info 记录 result；this.projectPath = ''; this.refreshUiState(); 然后 break。注意 ArkTS 严格模式：回调用箭头函数保持 this。

改动 2（quit 真正退出）：把现有的
      case 'quit':
        // In offscreen mode, just log
        hilog.info(DOMAIN, TAG, 'Quit requested - would shut down Qt');
        break;
改为：hilog.info 记 'Quit requested - terminating ability'，然后 (getContext(this) as common.UIAbilityContext).terminateSelf()，break。

改动 3（default 分支未实现项 Toast）：现有 default 分支是
      default: {
        const result: string = qtInjector.callQtCommand('menuAction',
          JSON.stringify({ itemId: itemId } as MenuActionArgs));
        hilog.info(DOMAIN, TAG, 'fallback menuAction(%{public}s): %{public}s', itemId, result);
        break;
      }
保留 callQtCommand 与 hilog 不动，在 hilog 之后新增：解析 result（JSON.parse(result) as CmdResult，需在文件顶部接口区新增 interface CmdResult { success: boolean; error?: string; }，放在 MenuActionArgs 接口附近），若 resp.success === false 则 this.getUIContext().getPromptAction().showToast({ message: '功能开发中', duration: 2000 })。JSON.parse 要包 try-catch（catch 里 hilog.error 即可），不能让解析异常打断 UI 线程。

风格要求：与文件现有 case 写法一致（2 空格缩进、hilog 带 %{public}s、注释英文简短）。ArkTS 严格模式禁止 any/unknown，对象字面量必须有显式接口类型。不要动其他 case。完成后回复 done 并简述 3 处改动位置。
'@

Set-Location $root
deveco run $task --model deveco/GLM-5.1 2>&1
