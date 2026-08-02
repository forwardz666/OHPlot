# 2026-08-01 工作日志：Open Code Review 集成 DevEco Code（Skill + 插件双轨）

## 工作内容

将阿里开源 AI 代码审查工具 **Open Code Review（OCR，alibaba/open-code-review v1.8.4）** 集成到 DevEco Code（OpenCode 分支，v0.1.5）。用户决策采用 **Skill + 插件双轨** 方案，全局安装。

## 完成项

- [x] 全局安装 ocr CLI：`npm install -g @alibaba-group/open-code-review`（v1.8.4，windows/amd64）
- [x] 复制官方可移植 SKILL.md → `~/.config/deveco/skills/open-code-review/SKILL.md`（9,419 B，字节级保留，frontmatter 校验通过）
- [x] 适配官方 OpenCode 插件 → `~/.config/deveco/plugins/open-code-review.ts`（注册 `ocr_review`/`ocr_health` 原生工具 + `/ocr-review`/`/ocr-health` 命令）
- [x] 安装插件运行时依赖：`npm install --prefix ~/.config/deveco @opencode-ai/plugin`（含 zod 传递依赖）
- [x] 插件 TypeScript 严格模式类型检查通过（tsc --noEmit --strict，0 错误）
- [x] 与官方源码逐行对比：仅 import 行差异（3 行），其余 353 行一致

## 技术决策

- **决策 1：Skill 而非 MCP 作为主集成形态**。关键事实：OCR 官方是 MCP *client* 而非 server（`internal/mcp/client.go`，文档明确 "OCR can act as an MCP client"），其 "MCP Server" 链接实为扩展审查 agent 的外部工具接入，不对外提供 server。市面上 `ocr_scan/ocr_heal/ocr_explain` MCP 工具属另一产品线 `@opencodereview/cli`（codes.evallab.ai）。因此 DevEco 侧接 MCP 无官方通路，Skill 是官方推荐的可移植形态。
- **决策 2：插件直接复用官方 OpenCode 插件**。DevEco Code 基于 OpenCode 内核（`deveco.json` schema 即 `opencode.ai/config.json`，插件 API 同构），官方 `plugins/open-code-review/opencode/open-code-review.ts` 可几乎原样使用。
- **决策 3：import 拆分降低运行时依赖面**。`@deveco-ai/plugin` 不存在于公共 npm registry（E404，仅文档示意名）；实际用 `@opencode-ai/plugin@1.18.10`。其 `tool()` 是 identity 函数（`return input`），故运行时仅需 `@opencode-ai/plugin/tool` 子路径（只加载 zod）；`Plugin` 类型用 `import type` 编译期擦除。
- **决策 4：依赖安装在 `~/.config/deveco/node_modules/`**（`npm --prefix`），bun 运行时从插件文件向上解析 node_modules 可命中。
- **决策 5：导出保持 `export const OpenCodeReviewPlugin`**（DevEco 支持任意命名导出，无需转 default）。
- **决策 6：LLM 采用 OpenCode Go 的 deepseek-v4-flash**（用户指定，不用 OCR 内置 provider）。端点 `https://opencode.ai/zen/go/v1`（OpenAI 兼容），经 deveco.exe 二进制分析确认其 provider 定义（env `OPENCODE_API_KEY`、协议 openai-compatible、模型列表含 deepseek-v4-flash）。API key 由用户提供，配置完成后 `ocr llm test` 验证通过。

## 文件变更

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `~/.config/deveco/skills/open-code-review/SKILL.md` | 新增 | 官方可移植 skill（9,419 B） |
| `~/.config/deveco/plugins/open-code-review.ts` | 新增 | 官方插件适配版（11,355 B，import 拆分） |
| `~/.config/deveco/node_modules/` | 新增 | `@opencode-ai/plugin` + zod 等运行时依赖 |
| `~/.config/deveco/package.json` / `package-lock.json` | 新增 | npm --prefix 生成 |

## LLM 配置（已完成：opencode-go / deepseek-v4-flash）

用户明确不使用 OCR 内置 provider，改用 **OpenCode Go**（DevEco Code 内核内置的官方托管 provider）。通过二进制分析确认其定义：

- provider: `opencode-go`
- baseURL: `https://opencode.ai/zen/go/v1`（OpenAI 兼容协议，`@ai-sdk/openai-compatible`）
- env key: `OPENCODE_API_KEY`
- 模型: `deepseek-v4-flash`（DeepSeek V4 Flash，内核模型列表中确认存在）

已执行配置：
```bash
ocr config set provider opencode-go
ocr config set custom_providers.opencode-go.url https://opencode.ai/zen/go/v1
ocr config set custom_providers.opencode-go.protocol openai
ocr config set custom_providers.opencode-go.model deepseek-v4-flash
ocr config set custom_providers.opencode-go.api_key "<用户提供的 key>"
ocr llm test   # ✅ 连接测试成功
```

`ocr llm test` 输出确认：`Source: provider:opencode-go`，`URL: https://opencode.ai/zen/go/v1`，`Model: deepseek-v4-flash`，连接成功。

## 遗留问题

- [x] LLM 配置已完成（opencode-go / deepseek-v4-flash，连接测试通过）
- [ ] 重启 DevEco Code 后验证 skill 与插件加载（配置/插件仅在启动时加载）
- [ ] 验证后建议实测：`/ocr-review` 命令审查当前项目变更
- [ ] `~/.config/deveco/node_modules` 为手工安装，DevEco 升级后如插件加载失败需重装

## 环境信息

- 项目: scidavis-ohos（本集成与项目无关，属 DevEco Code 全局工具配置）
- 日期: 2026-08-01
- 依赖变更: `@alibaba-group/open-code-review@1.8.4`（全局）、`@opencode-ai/plugin@1.18.10`（~/.config/deveco）
- 前置条件已满足: Git 2.53.0（要求 ≥2.41）、Node v24.14.1

## 后续建议

- 审查 ArkTS 项目时，OCR 内置 `arkts.md` 审查规则（`internal/config/rules/rule_docs/arkts.md`）自动生效
- 如需团队共享，可将插件与 skill 移入项目 `.deveco/` 目录并提交仓库
- 若未来需要跨 IDE（Claude Desktop/Cursor）共享审查能力，再评估 MCP 方案（此时才值得引入 `@opencodereview/cli` 或自写 wrapper）
