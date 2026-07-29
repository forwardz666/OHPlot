---
name: tiered-dev-delegation
description: Delegate development tasks to local DevEco Code CLI sub-agents using a three-tier model strategy - Qoder handles architecture/planning/root-cause analysis, GLM-5.1 (free) handles concrete HarmonyOS coding tasks, deepseek-v4-flash (ultra-cheap) handles batch small tasks in parallel terminals. Use when a task can be decomposed into well-defined subtasks, when doing batch edits/formatting/config/docs/scripts, when needing HarmonyOS API knowledge, or when the user asks to save tokens by delegating work to deveco/GLM/deepseek sub-agents.
---

# Tiered Dev Delegation (三层模型分工委派)

将开发任务按复杂度路由到三层执行者，Qoder 只保留高价值思考，其余外包给本地 DevEco Code CLI。

## 三层架构

| 层级 | 执行者 | 模型参数 | 职责 |
|------|--------|----------|------|
| L1 决策 | Qoder 主代理（本会话） | — | 读项目结构、拆任务、设计方案、分析 bug 根因、重构计划、验收 |
| L2 开发 | `deveco run` | `--model deveco/GLM-5.1` | 明确需求的改代码、补接口、写组件、修报错、加测试；鸿蒙 API/规范咨询 |
| L3 批量 | `deveco run`（并行 Job） | `--model deepseek/deepseek-v4-flash` | 格式化、批量替换、简单 CRUD、配置文件、文档、脚本 |

**核心原则**：L1 只出方案和验收，不写样板代码；L2/L3 只执行明确指令，不做设计决策。

## 工作流

```
Task Progress:
- [ ] Step 1: L1 分析任务，拆成自包含子任务并分层（L2/L3/自己做）
- [ ] Step 2: 环境自检（deveco --version && deveco models）
- [ ] Step 3: 逐个或并行委派子任务
- [ ] Step 4: L1 验收（diff 审查 / 编译 / 测试）
- [ ] Step 5: 失败子任务降级处理（重试一次 → L1 自己做）
```

### Step 1: 拆任务

每个子任务描述必须**自包含**（子代理无会话上下文）：带上文件绝对路径、报错原文、代码片段、期望输出形态（如"只输出代码不要解释"、"完成后回复done"）。

### Step 2: 环境自检

```powershell
deveco --version    # 期望 0.1.4+
deveco models       # 期望含 deveco/GLM-5.1 和 deepseek/deepseek-v4-flash
```

### Step 3: 委派

**L2 单任务**（知识咨询 / 明确编码需求）：

```powershell
deveco run "<自包含任务描述>" --model deveco/GLM-5.1
```

**L3 单任务**（小任务，需改文件时先 cd 到目标目录）：

```powershell
Set-Location <目标工程目录>
deveco run "<自包含任务描述>" --model deepseek/deepseek-v4-flash
```

**L3 批量并行**（多个互不重叠的小任务，模拟多终端）：

```powershell
$jobs = @(
  Start-Job { Set-Location <工程目录>; deveco run "<子任务1>" --model deepseek/deepseek-v4-flash 2>&1 },
  Start-Job { Set-Location <工程目录>; deveco run "<子任务2>" --model deepseek/deepseek-v4-flash 2>&1 }
)
Wait-Job $jobs -Timeout 300 | Out-Null
$jobs | ForEach-Object { Receive-Job $_ }
```

**程序化解析**：加 `--format json` 得 JSONL 事件流，答案取 `type=="text"` 事件的 `part.text`，`step_finish` 的 `cost` 字段核对成本。

### Step 4: 验收（必做）

- 子代理写入的代码必须 diff 审查后才算完成（ArkTS 静态语法、项目命名、TAG 约定）；
- 涉及构建的跑 hvigor 编译确认；
- 输出末尾的 `> build · <model>` 标记行和 `⚙/←` 工具记录行不是答案内容，解析时忽略。

### Step 5: 降级

委派失败（超时/限流/答案不合格）→ 同层重试一次 → 仍失败则 L1 自己完成，不阻塞主任务。

## 路由决策表

| 任务特征 | 路由 |
|----------|------|
| 架构设计、任务拆解、根因分析、重构方案、多文件复杂修改 | L1 自己做 |
| 鸿蒙 API/UI 规范咨询、ArkTS 疑难报错分析 | L2 GLM-5.1 |
| 单文件明确需求：写组件/补接口/修报错/加测试 | L2 GLM-5.1 |
| 格式化、批量替换、简单 CRUD、配置、文档、脚本 | L3 flash（量大并行） |
| 编译/部署/截图等纯命令操作 | 直接执行命令，零 token |

## 约束与注意

- GLM-5.1 免费但限流 **50 次/分钟**；flash 单次实测 ≈ $0.000001，也要避免无意义刷量。
- 并行子任务必须操作**不同文件/目录**，避免写冲突；每批 ≤ 4 个 Job。
- `deveco run` 每次是独立会话无记忆，多轮任务要在提示词里重复上下文。
- `deveco run` 文件读写以当前工作目录为根，改文件前必须先 `Set-Location`。
- `deveco acp` / `deveco mcp` 均为客户端模式，不能作为服务器挂载，桥接只走 CLI。
- 详细规范见项目文档 `specifications/DEVECO_CODE_SUBAGENT_SPEC.md`（OHPlot 仓库）。
