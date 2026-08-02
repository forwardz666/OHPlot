# 2026-07-31 工作日志：剪贴板 Copy→Paste 回环链路审查与修复

> P1a 收尾：审查系统剪贴板 ↔ Qt QClipboard 双向同步链路（JsPasteBoard + PasteButton 安全控件），修复读方向时序缺陷。

## 工作内容

对 Copy→Paste 回环链路做全链路审查（4 个 ArkTS 文件 + Qt 原生侧只读核查），识别并修复读方向缺陷。

## 链路审计结论

### ① 写方向（Qt Copy → 系统剪贴板）— 完整，无需改动
- Qt `QClipboard::setText`（main.cpp `setClipboardText` 命令）→ QPA `QOpenHarmonyPlatformClipboard` → `JsPasteBoard.setClipboardText` → `pasteboard.setDataSync`（无需权限）
- 冗余辅助路径：`QClipboard::dataChanged` → `clipboardChanged` 事件 → `QtEventHost` 镜像写回系统剪贴板（无害）
- P0 已真机验证（2026-07-31）：`createJsObject type=JsPasteBoard name=JsPasteBoard → ok`

### ② 读方向（系统剪贴板 → Qt Paste）— 发现并修复 1 处缺陷
- MenuBar.ets PasteButton（121-140 行）：点击授予一次性临时 READ_PASTEBOARD 授权，`result === PasteButtonOnClickResult.SUCCESS` 才派发 ✓
- onItemClick('paste') → dispatchMenuItem → `menuAction {itemId:'paste'}`（scidavis_call 通道）→ `ApplicationWindow::pasteSelection()` → `Table::pasteIntoSelection()` → `clipboard->mimeData()` → JsPasteBoard.clipboardText → `getDataSync` ✓ 链路存在

**缺陷**：`MainLayout.ets::pasteWithSystemClipboard()` 使用**异步** `pasteboard.getSystemPasteboard().getData()`。await 在 onClick 回调返回后的下一个事件循环任务才恢复，而 PasteButton 一次性临时授权是否跨越回调边界无保证。违反规范 §2.2（"授权是一次性的，必须在 onClick 回调链上尽快完成 pasteboard 读取"）与 §1.3（桥接只用 *Sync API）。若授权在回调返回后被回收，读取失败 → `setClipboardText` 被跳过 → Qt 用陈旧/空剪贴板执行 paste → 回环失败。

**修复**（最小化）：`getData()` 异步 → `getDataSync()` 同步，与 JsPasteBoard 桥同一 API。读取现在确定性地在 onClick 授权窗口内完成，先于 Qt paste 命令派发。

## 完成项
- [x] MainLayout.ets: pasteWithSystemClipboard() 改同步 getDataSync() - 修复一次性授权时序缺陷
- [x] PlotPage.ets: 修复 349 行注释损坏字节（`\xe2\x80?` → `\xe2\x80\x94` em-dash，非 UTF-8 字节导致 verify_smoke.py 崩溃）— 仅注释，无行为影响

## 技术决策
- **决策 1**: 读方向采用「ArkTS 同步预读 getDataSync → setClipboardText 预推 Qt 缓存 → menuAction paste」组合。Qt 侧 paste 经 `clipboard->mimeData()` 会重新走平台读（JsPasteBoard.clipboardText → getDataSync）；授权仍有效时平台读到同一文本，授权被回收时 QClipboard 缓存兜底。双重保障。
- **决策 2**: 保留 `setClipboardText` 预推与「读取失败 fall-through 到 Qt 自有剪贴板」的既有行为 — 应用内 Copy→Paste 时 Qt 缓存本就含正确文本，fall-through 正是期望语义，不做行为变更。

## 文件变更
| 文件 | 变更类型 | 说明 |
|------|---------|------|
| ohos/entry/src/main/ets/pages/MainLayout.ets | 修改 | pasteWithSystemClipboard(): async getData() → 同步 getDataSync()，更新注释说明授权时序约束 |
| ohos/entry/src/main/ets/pages/PlotPage.ets | 修改 | 349 行注释损坏字节修复（验证门禁预存问题，非剪贴板链路） |

## 验证结果
- arkts_check: MainLayout.ets + PlotPage.ets 0 错误
- verify_smoke.py: 6/6 PASS（napi 契约 / ArkTS 门禁 / libentry 存在 / 诊断卫生）
- 修改仅限 ArkTS 层；未动 Qt 原生侧、未加权限声明、未动 PasteButton 逻辑

## 遗留问题
- 剪贴板 Copy→Paste 真机人工验证仍待执行（P0 遗留项），验证步骤见下。

## 真机验证点清单（HUAWEI MatePad 11.5 / OpenHarmony-7.0.0.32，hdc 部署）
仅改 ArkTS，无需复制 libentry.so，直接 hvigor 构建 HAP 部署即可。

1. 启动日志确认 `createJsObject type=JsPasteBoard name=JsPasteBoard → ok`
2. 应用内 Copy→Paste 回环：
   a. 选中表格单元格 → Edit 菜单 → Copy Selection
   b. hilog 出现 `JsPasteBoard setData text/plain (N chars)`，且**无** `get attached js object failed` / `PBS: VerifyPermission# no permission`
   c. 选中目标单元格 → Edit 菜单 → 点 PasteButton（"粘贴"）
   d. hilog 出现 `PasteButton click result: 0`（SUCCESS），随后**不应出现** `pasteboard read skipped`，最后出现 `paste dispatched`
   e. 确认目标单元格出现复制的值
3. 外部应用 → 本应用：其他应用复制文本 → 回 OHPlot → Edit → PasteButton → 值出现在单元格
4. 本应用 → 外部：表格内 Copy → 切到其他应用 → 粘贴 → 值出现（写方向）
5. 反向异常：系统剪贴板为空时点 PasteButton → hilog 出现 `pasteboard read skipped` → 无崩溃、无误粘贴陈旧数据

## 环境信息
- 项目: scidavis-ohos
- 日期: 2026-07-31
- 依赖变更: 无

## 后续建议
- 按验证点清单在真机执行 Copy→Paste 回环人工验证，完成 P1a 收尾
- PlotPage.ets 编码修复后，verify_smoke.py 全绿，后续所有"修复完成"声明可直接引用
