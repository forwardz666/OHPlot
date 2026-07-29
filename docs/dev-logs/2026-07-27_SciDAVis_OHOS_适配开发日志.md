# SciDAVis OHOS 适配开发日志 — 2026-07-27（今日）

> 本文档为 **2026-07-27 当日** 执行《SciDAVis OHOS 可用性路线图》Spec 的完整工作记录，
> 供次日额度刷新后接续开发使用。代码分支：`ohos-port-20260727-025100`（本地领先远程 9 个提交）。

---

## 一、Spec 执行进度总览

路线图三阶段：Phase 1（看得过去）→ Phase 2（真正能用）→ Phase 3（对齐桌面版）。

| 状态 | 条目 | 说明 |
|---|---|---|
| ✅ | infra1 定位 qohos NAPI 源码与 ohos_compat.h 注入机制 | 完成 |
| ✅ | infra2 Qt→ArkTS 事件通道 | `scidavis_emit(json)` + NAPI `onQtEvent(callback)`（napi_threadsafe_function） |
| ✅ | infra3 scidavis_call 命令注册表重构 + getUiState | if-else 链 → `map<string, handler>`；getUiState 驱动菜单置灰 |
| ✅ | p1dlg QMessageBox/QFileDialog 符号插桩拦截 | ohos_bridge + `-Bsymbolic-functions` 修复运行时绑定 |
| ✅ | p1toast ArkTS Toast/确认框承接后端消息 | 经事件通道 |
| ✅ | p1menu 菜单体系对齐桌面版 + getUiState 置灰 | File/Edit/View/Table/Plot/Analysis/Windows/Help |
| ✅ | p1verify 构建部署 + Phase1 崩溃清零回归 | faultlog 零新增 |
| ✅ | p1fix-gsl GSL 完整重建 | 修复残缺 libgsl.a stub 导致的 new_graph 崩溃 |
| ✅ | p1mdi MDI 窗口列表/最大化/关闭命令 | Windows 菜单 |
| ✅ | p2proj openProject/saveProject + DocumentViewPicker | .sciprj 全量持久化打通 |
| ✅ | p2ascii 导入/导出 ASCII | picker 接入完成 |
| ✅ | p2edit 单元格编辑 IME 链路 | tap → JsInputMethod → Qt 提交，真机验通 |
| ✅ | p2table 表格操作（加列/公式/排序/统计） | 真机验证全部通过 |
| ✅ | p2plot 2D 绘图菜单全类型 | line/scatter/bar/histogram/pie/errorbar… 真机验证通过 |
| 🔶 | **p2clip 剪贴板双向桥接** | **进行中，双根因已定位，差最后一步注册+验证（见第三节）** |
| ✅ | p3matrix 矩阵支持（维度/公式/转置/求逆） | 真机验证全部通过 |
| ✅ | p3export 图形导出 PNG + picker 另存 | 真机验证通过（78KB PNG 写入 Docs） |
| ✅ | p3analysis 分析套件（Fit/FFT/Smooth/积分/微分…） | 真机验证通过 |
| ⬜ | p3browser 项目浏览器 getProjectTree | 未开始 |
| ⬜ | p3plotcust 绘图定制最小集（标题/对数轴/图例） | 未开始 |
| ⬜ | p3misc 3D timebox + Preferences/本地化/脚本控制台 | 未开始 |
| ⬜ | 用户故事端到端验收（建表→录入→绘图→保存→重开） | 待 p2clip 完成后统一跑 |

---

## 二、今日完成的主要工作

1. **p2table / p2plot / p3matrix / p3analysis / p3export 真机回归全部通过**
   （代码此前已完成，今日完成设备重连后的逐项验证，faultlog 零新增）。
2. **p2clip 剪贴板桥接深度排查**（本日主要战场，详见第三节）：
   - 定位并否决了 READ_PASTEBOARD 声明方案（受限 ACL，debug 签名装不上）；
   - 落地 PasteButton 安全控件方案并真机验证授权成功；
   - 从 QPA 插件二进制符号表提取出 `JsPasteBoard` 桥对象完整接口，编写 `JsPasteBoard.ets`。
3. **IME 数据录入正确姿势固化**（uitest doubleClick + 无坐标 text + Enter 2054）。

---

## 三、p2clip 剪贴板：双根因分析与修复进展（明日第一优先级）

### 根因 #1：READ_PASTEBOARD 权限被拒（已解决）
- 现象：`pasteboard_service/PBS: VerifyPermission# no permission` + `Invalid raw data size:0`。
- API 12+ 读系统 pasteboard 需 `ohos.permission.READ_PASTEBOARD`，它是**受限 ACL + user_grant**：
  在 module.json5 声明后安装直接失败
  `error: install failed due to grant request permissions failed ... code:9568289`（debug 自动签名 profile 无法承载）。
- **解决方案**：Edit 菜单中 paste 项替换为 **PasteButton 安全控件**（`MenuBar.ets` SubMenuItems 中
  `subItem.id === 'paste'` 分支），用户点击即获一次性临时读授权。
  真机已验证：渲染正常（系统文案"粘贴"+图标），点击返回 `PasteButtonOnClickResult.SUCCESS`（=0），无权限报错。
- module.json5 / SciDAVisAbility.ets 的权限声明与运行时申请代码**已全部回退**。

### 根因 #2：QPA JsPasteBoard 桥对象缺失（代码已写，未注册）
- 现象：PasteButton 授权成功后 pasteboard 仍为空（`GetPasteDataInner# data is invalid`）。
  Copy 时 QPA 日志 `call js function clearData / setClipboardText` 后紧跟
  `get attached js object failed`；启动日志 `createJsObject type=JsPasteBoard → null`。
- 机制：QPA 的 `QOpenHarmonyPlatformClipboard` 把 QClipboard **完全代理**到名为
  `JsPasteBoard` 的 ArkTS 桥对象（经 createJsObject TSFN 请求）。该对象未注册 → Qt 侧
  copy/paste 全部静默失败。
- 接口全集（从 `entry\libs\arm64-v8a\libplugins_platforms_qopenharmony.so` 符号表提取）：
  `clearData`、`setClipboardText/Html/Uri/PixelMap`、`hasClipboardText/Html/Uri/PixelMap`、
  `clipboardText/Html/Uri/PixelMap`、`pasteChanged`（napi 静态回调）。
- **已完成**：新建 `entry/src/main/ets/native/JsPasteBoard.ets`（115 行，全部 *Sync API，
  读方法 try-catch 兜底返回空串）。
- **未完成（明日第一步）**：在 `entry/src/main/ets/entryability/SciDAVisAbility.ets` 的
  `createJsObject`（约 L67-108）中注册：
  ```typescript
  import { JsPasteBoard } from '../native/JsPasteBoard';
  // createJsObject 中追加分支：
  } else if (type == 'JsPasteBoard') {
    obj = new JsPasteBoard();
  }
  ```
  然后构建部署 + Copy→Paste 回环真机验证。

---

## 四、明日接续清单（按优先级）

1. **p2clip 收尾**：
   ① `SciDAVisAbility.ets` 注册 JsPasteBoard（上文代码）→
   ② `hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon` →
   ③ `hdc install -r` + 重启应用 →
   ④ 重启 hilog 后台流（旧流必死，见第五节）→
   ⑤ 回环验证：doubleClick 单元格(1,1) → `uitest uiInput text 42.5` → Enter →
      Edit→Copy Selection（确认出现 JsPasteBoard setData 日志、无 `get attached js object failed`）→
      选中(3,2) → Edit→粘贴(PasteButton) → 确认单元格出现 42.5。
2. **用户故事端到端验收**：新建表→录入→散点图→Save Project→杀进程重开→Open Project→数据还在。
3. **p3browser**：新命令 `getProjectTree` + ArkTS 树组件，双击激活窗口。
4. **p3plotcust**：图/轴标题、对数坐标、图例（ArkTS 属性面板 → Graph API）。
5. **p3misc**：3D timebox（qwtplot3d + GLES3 离屏，2 天不通则保持桩灰显）、Preferences、本地化、脚本控制台。
6. **遗留 bug**：Windows 菜单窗口列表重复项（Smoothed1/Derivative1/Integration1 各出现两次）。
7. **代码提交**：工作分支 `ohos-port-20260727-025100` 领先远程 9 个提交；未提交文件：
   - `entry/src/main/ets/components/MenuBar.ets`（PasteButton 改造，M）
   - `entry/src/main/resources/base/element/string.json`（read_pasteboard_reason 字符串，M，无害保留）
   - `entry/src/main/ets/native/JsPasteBoard.ets`（新文件，??）
   p2clip 验证通过后按原子化提交规范 commit（推送需用户确认）。

---

## 五、关键操作沉淀（真机 2456×1600）

### 坐标表（物理坐标 = 截图坐标 × 1.228）
| 目标 | 物理坐标 |
|---|---|
| 菜单栏 y=30：File / Edit / View / Table / Plot / Analysis / Windows / Help | x = 49 / 147 / 253 / 368 / 479 / 607 / 772 / 913 |
| 空 Table1 单元格 (1,1) / (3,2) | (104,184) / (225,262) |
| Edit→Copy Selection / 粘贴 PasteButton | (257,290) / (225,351) |

### uitest 命令精确用法（今日踩坑修正）
- 双击是 `doubleClick`（**不是** dbClick，报 Invalid parameters）；
- `inputText <x> <y> <text>` 会先点击坐标，**破坏已激活的单元格编辑态**；
  正确姿势：`doubleClick` 激活编辑 → `uitest uiInput text <text>`（无坐标，聚焦输入）→ `keyEvent 2054`（Enter）。

### hilog 后台流
- `hdc shell hilog -x > file.txt`（后台）会随 hdc 重连/应用重启而死；
- **每轮验证前必须重启流并确认文件在增长**（今日 stream→stream2→stream3 三次踩坑）。

### 构建
- 项目根**无 hvigorw.bat**，直接用 PATH 上的 `hvigorw`；
- `hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`。

### 设备
- `192.168.0.116:5555`；包名 `org.scidavis.ohos`；今日最后 pid 45200。

---

## 六、今日新增/修订的规范文档

- 新增 `specifications/08_OHOS剪贴板桥接与安全控件规范.md`（JsPasteBoard 桥契约 + PasteButton 方案）；
- 修订 `specifications/02_Qt_for_OpenHarmony平台开发规范.md`（createJsObject 桥对象注册清单）；
- 修订 `specifications/06_调试与日志规范.md`（hilog 后台流维护 + uitest 命令精确性 + 坐标换算）。
