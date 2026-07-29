# OHOS 剪贴板桥接与安全控件规范

> 新增于 2026-07-27，来源：p2clip 剪贴板双向桥接真机排查经验。
> 适用范围：所有基于 Qt for OpenHarmony QPA 插件、需要 cut/copy/paste 功能的混合应用。

## 一、QPA `JsPasteBoard` 桥对象契约（必须实现）

### 1.1 机制
QPA 插件的 `QOpenHarmonyPlatformClipboard` 把 QClipboard **完全代理**到一个名为
`JsPasteBoard` 的 ArkTS 桥对象：插件启动时经 createJsObject TSFN 通道请求
`createJsObject("JsPasteBoard")`，之后 Qt 侧所有剪贴板读写都调用该对象的方法。

**若 Ability 的 createJsObject 未实现该类型（返回 null），Qt 侧 copy/paste 全部静默失败**，
且无崩溃、无异常，仅有 hilog 特征：
- 启动期：`createJsObject type=JsPasteBoard` 后返回 null；
- 运行期：`call js function clearData / setClipboardText` 后紧跟 `get attached js object failed:<id>`。

### 1.2 必须实现的方法全集
（从 `libplugins_platforms_qopenharmony.so` 符号表提取，方法名精确匹配）：

| 分类 | 方法 |
|---|---|
| 清空 | `clearData()` |
| 写入 | `setClipboardText(text)` / `setClipboardHtml(html)` / `setClipboardUri(uri)` / `setClipboardPixelMap(pixelMap)` |
| 探测 | `hasClipboardText()` / `hasClipboardHtml()` / `hasClipboardUri()` / `hasClipboardPixelMap()` |
| 读取 | `clipboardText()` / `clipboardHtml()` / `clipboardUri()` / `clipboardPixelMap()` |
| 回调 | `pasteChanged`（QPA 侧 napi 静态回调，用于系统剪贴板变化通知） |

### 1.3 同步性硬约束
TSFN 桥调用要求**同步返回**，因此实现中只能使用 pasteboard 的 `*Sync` API：
`setDataSync` / `getDataSync` / `hasDataType` / `clearDataSync`。
禁止使用 Promise/callback 异步 API（返回值无法回传给 Qt）。

### 1.4 参考实现要点（`JsPasteBoard.ets`）
- 写入：`pasteboard.createData(mimeType, value)` → `getSystemPasteboard().setDataSync(data)`（无需权限）；
- 探测：`hasDataType(mimeType)`（无需权限）；
- 读取：`getDataSync().getPrimaryText()/getPrimaryHtml()/getPrimaryUri()`，
  **必须 try-catch 兜底返回空串**（无临时授权时读取抛错，不能让异常穿透 TSFN 桥）；
- PixelMap 不需要时可 no-op：set 忽略、has 返回 false、get 返回 null。
- 注册位置：Ability 的 `createJsObject`（OHPlot 参考：`entry/src/main/ets/entryability/OHPlotAbility.ets`）追加分支 `} else if (type == 'JsPasteBoard') { obj = new JsPasteBoard(); }`；2026-07-28 真机 Copy→Paste 回环验证通过。

### 1.5 排查未知桥对象接口的方法
当 QPA 请求了未文档化的 JS 对象类型时，用 PowerShell 直接读插件二进制提取字符串，
即可得到方法名清单（napi 调用方法名以明文字符串存在于 .rodata）。

## 二、READ_PASTEBOARD 权限限制与 PasteButton 方案

### 2.1 权限限制（踩坑结论）
- API 12+ 读系统 pasteboard 需要 `ohos.permission.READ_PASTEBOARD`；
- 该权限是 **受限 ACL + user_grant**：在 module.json5 中声明后，**debug 自动签名 profile
  无法承载 ACL，安装直接失败**：
  `error: install failed due to grant request permissions failed. code:9568289`；
- 因此声明权限 + `requestPermissionsFromUser` 的常规方案在 debug 签名下**不可行**，必须回退声明。

### 2.2 正确方案：PasteButton 安全控件
- 使用系统安全控件 `PasteButton`：用户点击即获得**一次性临时读授权**，无需声明任何权限；
- 判定授权成功：`result === PasteButtonOnClickResult.SUCCESS`（值为 0），仅在成功时派发粘贴动作；
- 文案与图标为**系统固定**（中文系统显示"粘贴"），不可自定义文本，只能调字号/颜色/图标样式
  （`PasteIconStyle.LINES`、`PasteDescription.PASTE`、`buttonType: ButtonType.Normal`）使其融入菜单；
- 授权是一次性的，必须在 onClick 回调链上**尽快**完成 pasteboard 读取（Qt 经 JsPasteBoard
  的 `clipboardText()` 读取同样受益于该临时授权）。

### 2.3 菜单集成模式
菜单渲染时对 `id === 'paste'` 且 enabled 的项单独渲染 PasteButton 分支（替代普通 Text 项），
保留快捷键提示文本与行高对齐；点击后关闭菜单并派发原 paste 命令。

## 三、验证清单（Copy→Paste 回环）
1. 启动日志出现 `createJsObject type=JsPasteBoard` 且返回非 null；
2. Qt 侧 Copy 后 hilog 出现 JsPasteBoard `setData` 日志，且**无** `get attached js object failed`；
3. `hdc shell` 侧无 `PBS: VerifyPermission# no permission`；
4. PasteButton 点击日志 result=0，目标单元格出现复制的值；
5. 反向（系统应用复制 → 本应用粘贴）同样验证一遍。
