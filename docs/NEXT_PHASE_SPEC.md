# OHPlot 下一阶段执行规格说明（NEXT_PHASE_SPEC）

> 生成于 2026-07-28，依据 `develop-docs-for-harness` 分支的
> `dev-logs/2026-07-27_SciDAVis_OHOS_适配开发日志.md` 与 `specifications/01~09` 规范。
> 本文档是三层模型委派（tiered-dev-delegation）的任务输入与验收依据。
> 层级定义：L1 = Qoder 主代理（架构/拆解/根因/验收）；L2 = `deveco run --model deveco/GLM-5.1`；
> L3 = `deveco run --model deepseek/deepseek-v4-flash`（批量小任务，PowerShell 并行每批 ≤4）。

## 环境与通用约束

- 设备 `192.168.0.116:5555`；包名以 `entry/src/main/module.json5` 为准。
- 构建：`hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`（根目录无 hvigorw.bat）。
- 部署：`hdc install -r <hap>` + 重启应用。
- 每轮验证前重启 hilog 后台流并确认文件增长（规范 06）。
- uitest 输入姿势：`doubleClick` 激活编辑 → `uitest uiInput text <值>`（无坐标）→ `keyEvent 2054`。
- 坐标换算：物理坐标 = 截图坐标 × 1.228（真机 2456×1600）。
- 委派纪律：L1 不写样板代码；L2/L3 不做设计决策；子代理产出必须经 L1 diff 审查验收。

---

## T1 p2clip 剪贴板收尾 — P0（L1 亲自执行）

**状态**：代码已完成（2026-07-28 注册完毕），差真机验证。

- 目标：Copy→Paste 回环打通。
- 涉及文件：
  - `entry/src/main/ets/entryability/OHPlotAbility.ets` — createJsObject 已注册 `JsPasteBoard` 分支（完成）。
  - `entry/src/main/ets/native/JsPasteBoard.ets` — 桥对象（已提交）。
  - `entry/src/main/ets/components/MenuBar.ets` — PasteButton 安全控件（已提交）。
- 验收标准（规范 08 验证清单）：
  1. 启动日志 `createJsObject type=JsPasteBoard → ok`；
  2. Copy 后出现 JsPasteBoard setData 日志，无 `get attached js object failed`；
  3. 无 `PBS: VerifyPermission# no permission`；
  4. PasteButton 点击 result=0，目标单元格 (3,2) 出现复制值 42.5；
  5. 反向：系统应用复制 → 本应用粘贴成功。
- 验证步骤：doubleClick (104,184) → `uiInput text 42.5` → Enter 2054 →
  Edit(147,30)→Copy Selection(257,290) → 点 (225,262) 选中 (3,2) → Edit→粘贴 PasteButton(225,351)。

## T2 端到端用户故事验收 — P0（L1 执行，依赖 T1）

- 流程：新建表 → 录入数据 → 散点图 → Save Project(.sciprj) → 杀进程重开 → Open Project → 数据/图完好。
- 验收：全流程无崩溃（faultlog 零新增）；重开后表数据与图均恢复；用 vision-recognize 技能识别截图佐证。

## T3 p3browser 项目浏览器 — P1

- **L1**：设计 `getProjectTree` 返回 JSON 契约，建议：
  `{ name, type: "Table|Matrix|Graph|Note|Folder", children: [] }` 递归结构；确定双击激活复用现有 `activateWindow` 命令。
- **L2 子任务 A（C++）**：在 `scidavis_call` 命令注册表（map<string, handler>）新增 `getProjectTree`，
  遍历项目 Folder/MyWidget 树序列化为上述 JSON。
- **L2 子任务 B（ArkTS）**：MainLayout 侧栏树组件（可折叠），消费 getProjectTree；双击节点调 `scidavis_call('activateWindow', name)`。
- 验收：新建 Table/Graph/Matrix 后树实时可刷新显示；双击各节点对应 MDI 窗口置顶；faultlog 零新增。

## T4 p3plotcust 绘图定制最小集 — P1

- **L1**：定义命令注册表新条目：`setGraphTitle`、`setAxisTitle(axis,text)`、`setAxisScale(axis,log|linear)`、`toggleLegend`。
- **L2**：C++ 侧经 Graph API 实现四命令；ArkTS 侧属性面板（当前激活 Graph 时可用）。
- 验收：标题/轴标题即时生效；对数轴切换后曲线正确重绘；图例显隐可控；真机截图佐证。

## T5 Windows 菜单窗口列表重复项 bug — P1

- 现象：Smoothed1/Derivative1/Integration1 在 Windows 菜单各出现两次。
- **L1**：根因分析（怀疑分析结果窗口创建时 MDI 列表事件被推送两次，或 getUiState 拼接重复）。
- 修复归属视根因复杂度定：单点判重 → L3；事件链重构 → L1/L2。
- 验收：执行 Smooth/Derivative/Integrate 后 Windows 菜单每窗口仅一项。

## T6 p3misc 杂项 — P2

| 子项 | 层级 | 说明 |
|---|---|---|
| string.json 多语言补齐（base/zh_CN/en_US 缺失键对齐） | L3 并行 | 纯资源文件，规范 07 |
| Preferences 面板 UI 样板 | L3 | ArkTS 页面骨架 |
| Preferences 逻辑接线（读写 QSettings 经命令通道） | L2 | 需新增 get/setPreference 命令 |
| 脚本控制台桩（灰显入口 + TODO 页） | L3 | 占位 |
| 3D timebox（qwtplot3d + GLES3 离屏） | L1 评估 | 2 天不通保持桩灰显（日志既定策略） |

## T7 文档同步 — P2（L3）

- dev-logs 追加 2026-07-28 当日记录；T1 验证通过后修订规范 08 的"参考实现"一节补充注册代码位置。
- 注意：文档提交到 `develop-docs-for-harness` 分支体系，代码在 main/工作分支，不混提。

## 提交规范

- 每任务卡独立原子提交（规范 05）；推送前须经用户确认。
- 提交信息格式沿用现状：`feat:/fix:/docs:/chore:` 前缀。
