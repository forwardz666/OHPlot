# DevEco Code 子代理调用规范（Windows / Qoder）

本规范定义在 Windows 环境下，Qoder 作为主代理时，如何调用本地 DevEco Code CLI 作为子代理，按**三层模型分工架构**委派任务，节省主会话 token 消耗。

> 状态：✅ 已在本机端到端验证通过（见文末验证记录）。

## 0. 三层模型分工架构

| 层级 | 执行者 | 模型 | 职责 | 成本 |
|------|--------|------|------|------|
| **L1 决策层** | Qoder 主代理 | 极致模型 | 深度思考、架构规划、复杂改造：读项目结构、拆任务、设计方案、分析 bug 根因、重构计划 | 高 |
| **L2 开发层** | `deveco run` | `deveco/GLM-5.1` | 具体任务开发：根据明确需求改代码、补接口、写组件、修报错、加测试（鸿蒙知识库加持） | 免费（限流 50 次/分钟） |
| **L3 批量层** | `deveco run`（可多终端并行） | `deepseek/deepseek-v4-flash` | 大量小任务/批量修改/低成本 Agent：格式化、批量替换、简单 CRUD、配置文件、文档、脚本 | 极低（实测单次 ≈ $0.000001） |

核心原则：**L1 只出方案和验收，不写样板代码；L2/L3 只执行明确指令，不做设计决策。** 模型切换由 Qoder 在 `deveco run` 命令中通过 `--model` 参数直接指定，无需修改 deveco 配置。

---

## 1. 环境与前置条件

| 项目 | 值 |
|------|-----|
| CLI 包 | `@deveco/deveco-code@0.1.4` |
| 安装位置 | `C:\Program Files\Huawei\DevEco Studio\tools\node\deveco.cmd`（已在 PATH 中） |
| 免费模型 | `deveco/GLM-5.1`（`cost: 0`，每分钟限 50 次请求） |
| 其他可用模型 | `deepseek/deepseek-v4-flash`、`deepseek/deepseek-v4-pro`、`qwen-local/Qwen3.6-35B-A3B`（本地 llama.cpp） |
| 登录状态 | 已通过 `deveco providers login` OAuth 授权（一次性） |

环境自检命令（任一失败则先修复环境再委派任务）：

```powershell
deveco --version          # 应输出版本号，如 0.1.4
deveco models             # 应包含 deveco/GLM-5.1
```

## 2. 调用方式

### 2.1 标准调用（文本输出，推荐）

```powershell
deveco run "<任务描述>" --model deveco/GLM-5.1
```

- 结果直接打印到 stdout，末尾带 `> build · GLM-5.1` 标记行和工具调用记录（`⚙ ...`），解析时忽略这两类行。
- GLM-5.1 会自动调用内置的 `arkts_knowledge_search` 鸿蒙知识库工具（2000 万字语料），知识查询类问题优先委派给它而不是联网搜索。

### 2.2 程序化调用（JSON 事件流）

```powershell
deveco run "<任务描述>" --model deveco/GLM-5.1 --format json
```

- 输出为 JSONL 事件流，每行一个 JSON 对象，`type` 取值：`step_start` / `text` / `step_finish`。
- 提取答案：取所有 `type == "text"` 事件的 `part.text` 拼接。
- 验证免费：`step_finish` 事件中 `cost` 字段应为 `0`。

### 2.3 提示词写法约束

- **必须自包含**：子代理没有主会话上下文，任务描述里要带全部必要信息（报错原文、代码片段、API 名称）。
- **约束输出形态**：加"只输出代码不要解释"、"不超过 3 句话"等限定，便于直接采纳结果。
- 单引号/双引号：PowerShell 下任务描述用双引号包裹；描述内部含双引号时改用单引号包裹或转义。

## 3. 任务委派决策树

Qoder 拿到任务后先分类，再按层级路由：

1. **架构设计 / 任务拆解 / bug 根因分析 / 重构方案 / 多文件复杂修改** → L1 主代理自己做，产出明确的子任务描述；
2. **鸿蒙 API / UI 规范咨询、ArkTS 疑难报错分析** → L2 `deveco run --model deveco/GLM-5.1`（内置知识库比联网搜索准）；
3. **根据明确需求写组件/补接口/修报错/加测试**（单文件、需求已明确） → L2 GLM-5.1，需要改文件时在目标目录下执行；
4. **格式化 / 批量替换 / 简单 CRUD / 配置文件 / 文档 / 脚本** → L3 `deveco run --model deepseek/deepseek-v4-flash`，量大时多终端并行；
5. **编译/部署/截图** → 直接用 hvigorw / hdc 命令，零 token；
6. **ArkTS 编译/语法错误** → 先查本地 skill（arkts-syntax-assistant / arkts-static-spec），再考虑 L2；
7. **git 提交拆分 / add / commit / push 前检查等版本控制机械操作** → 主代理（L1）直接执行，属编排职责，不委派子代理（边界与反面案例见 3.3，2026-08-02 教训）；
8. **确需委派的简单 git 操作**（无冲突、文件级分组已明确） → 仅可用 `quick` 类轻量子代理，禁止 `deep` / 研究类 category，prompt 必须附文件级分组映射（见 3.3）。

### 3.1 委派时的工作目录约束

`deveco run` 的文件读写以**当前工作目录**为根。委派改文件任务前必须 `Set-Location` 到目标工程目录（或在 Start-Job 脚本块内先 Set-Location），避免文件写错位置。

### 3.2 多终端并行（L3 批量任务）

已验证多个 deveco 进程可同时运行、互不干扰。PowerShell 并行模板：

```powershell
$jobs = @(
  Start-Job { Set-Location <工程目录>; deveco run "<子任务1>" --model deepseek/deepseek-v4-flash 2>&1 },
  Start-Job { Set-Location <工程目录>; deveco run "<子任务2>" --model deepseek/deepseek-v4-flash 2>&1 }
)
Wait-Job $jobs -Timeout 300 | Out-Null
$jobs | ForEach-Object { Receive-Job $_ }
```

- 并行子任务必须**互不重叠**（不同文件/目录），避免写冲突；
- 每批建议 ≤ 4 个并行，兼顾限流与机器负载；
- 全部结束后由 L1 统一验收（编译/测试/diff 审查）。

### 3.3 委派边界：git 提交类操作不委派（2026-08-02 教训）

**反面案例**：2026-08-02 GitHub 上传任务中，主代理将"脏工作区拆分为 5-6 个主题原子提交"委派给 `deep` 类子代理（带 git-master skill）。子代理在 hunk 级交互拆分（`git add -p` 手动编辑 hunk）上长时间卡死：MainLayout.ets 等共享文件横跨 3 个主题，非交互式子代理 shell 每个 hunk 需多轮往返，效率极低，最终只产出 6 个提交中的 2 个即被中止；剩余 4 个提交由主代理改用**文件级拆分**直接执行，约 10 分钟完成。根因有二：一是 category 选错，`deep` 面向自主研究与端到端攻坚，机械 git 暂存不是研究任务；二是过度工程，上传/入库场景不需要 hunk 级精确。

**规则**：

1. **git 提交/拆分类机械操作不委派子代理**：原子提交拆分、`git add` / `git commit`、push 前检查等版本控制操作由主代理（L1）直接执行，它们属于编排职责，不是"开发任务"。
2. 若确需委派（如无冲突的简单 git 操作），**禁止**使用 `deep` / 研究类 category，只可用 `quick`；prompt 必须给出**文件级**分组映射（每个文件归哪个提交），并明确禁止 hunk 级交互拆分（`git add -p` 手动编辑 hunk）。
3. **文件级拆分原则**：一个文件只归一个主题提交；跨主题的共享文件（如 MainLayout.ets）整体归入改动量最大的主题，不追求 hunk 级精确（对上传/入库目的，该原子性粒度已足够）。

### 3.4 主 AI 侧 subagent 监督纪律（2026-08-02 补充）

**背景**：2026-08-02 的 git 主题拆分委派中（见 3.3 反面案例），`deep` 类子代理卡在 hunk 级交互（`git add -p` 手动编辑 hunk）上 20+ 分钟无产出，最终手动中止。教训：仅靠子代理自身无法保证及时退出或纠偏，主 AI 必须对后台任务做主动监督，而不是派发后被动等待。

**监督规则**：

1. **默认后台化**：预计耗时 > 5 分钟的任务一律 `run_in_background=true` 异步派发，禁止同步长等。主 AI 立即获得 `bg_...` 任务 ID 后可继续其他工作，不阻塞主会话。
2. **轮询监督**：主 AI 对每个后台任务设定监督节奏，建议每 3-5 分钟检查一次 `background_output(task_id=...)` 或会话状态。连续 2 次轮询（约 10 分钟）无任何新产出（无新消息、无工具调用、状态无变化）即判定"疑似卡死"。
3. **核实后 cancel，禁止盲目杀**：判定疑似卡死后，先核实再处置：① 查看最近一次输出与最后工具调用，判断是否仍在推进（bash 长命令运行中、大文件构建中等属正常长任务，不得杀）；② 确认确实无进展（空转、重复相同动作、思考循环）后，才执行 `background_cancel(taskId="bg_...")`。核心原则：**宁可多等一轮，不误杀正常长任务**，防止"任务做一半被关掉"。
4. **重派与总结**：cancel 后记录中止原因与 session 延续 ID（`ses_...`），调整策略后重新派发：换 category（如 `deep` 改为 `quick` / `unspecified-high`）、换模型、或改为文件级/更小粒度任务（参照 3.3 的文件级拆分原则）。重派用 `task(task_id="ses_...")` 延续上下文，而非从零开始新任务。
5. **参数兜底**：底层 oh-my-openagent 的 background_task 已有自动监管（`taskTtlMs=90min` 总时长上限、`staleTimeoutMs=30min` 无进展超时、circuitBreaker 连续 8 次相同工具调用熔断）。主 AI 轮询是第一道监督，自动熔断是兜底；两者配合，主 AI 应在自动熔断触发前主动发现并处置异常任务。

## 4. 结果采纳规则

- 子代理返回的**代码必须经主代理审查**后才能写入工程（检查 ArkTS 静态语法约束、项目命名规范、TAG 约定等）。
- 子代理返回的**结论仅作参考**，与本项目 `docs/DEVELOPMENT_GUIDE.md` 或 memory 冲突时以项目规范为准。
- 委派失败（超时/限流/离线）时降级为主代理自行处理，不阻塞任务。
- 涉及 git 提交拆分的委派（2026-08-02）：子代理给出的 hunk 级拆分方案一律不采纳；prompt 未附文件级分组映射的 git 委派视为不合格委派，立即收回，由 L1 按 3.3 的文件级拆分原则直接执行。

## 5. 限制与注意事项

- GLM-5.1 免费额度：**每分钟 50 次请求**，批量委派时注意节流。
- `deveco acp` 是 stdio 客户端模式，**不能**单独作为服务启动。
- `deveco mcp` 是 MCP 客户端管理命令，**不能**暴露为 MCP 服务器供 Qoder 直接挂载，因此桥接方式只能是 CLI 调用（`deveco run`）。
- 每次 `deveco run` 是独立会话，无记忆；多轮任务需在提示词中重复上下文，或用 `deveco session` 管理。
- Windows 控制台输出中文正常；`deveco --help` 的 ASCII art 乱码不影响功能。

## 6. 本机验证记录（2026-07-27/28）

| # | 验证项 | 命令 | 结果 |
|---|--------|------|------|
| 1 | CLI 可用 | `deveco --version` | ✅ 0.1.4 |
| 2 | 模型列表 | `deveco models` | ✅ 含 deveco/GLM-5.1、deepseek/deepseek-v4-flash |
| 3 | L2 知识查询 | `deveco run "ArkUI 的 List 组件如何实现下拉刷新？" --model deveco/GLM-5.1` | ✅ 正确回答（Refresh 包裹 List），自动调用 arkts_knowledge_search |
| 4 | L2 代码生成 | `deveco run "写一个 ArkTS 工具函数 vpToPx..." --model deveco/GLM-5.1` | ✅ 返回正确 TypeScript 代码 |
| 5 | JSON 输出 | `deveco run "..." --format json` | ✅ JSONL 事件流，GLM-5.1 `cost: 0` 确认免费 |
| 6 | L3 模型切换 | `deveco run "..." --model deepseek/deepseek-v4-flash --format json` | ✅ 正确回答，单次 cost ≈ $0.000001254 |
| 7 | L3 文件修改 | `deveco run "在当前目录创建文件 mathutil.py..." --model deepseek/deepseek-v4-flash` | ✅ Write 工具实际创建了正确文件 |
| 8 | 多终端并行 | 两个 Start-Job 同时运行 deveco run 各写一个文件 | ✅ 互不干扰，均成功 |
