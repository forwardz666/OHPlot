# 2026-08-02 工作日志：OpenCode 引用 DevEco Code 技能与 MCP 配置

## 工作内容
- 将 OpenCode（`C:\Users\Forwardz\.config\opencode\opencode.json`）配置为**原地引用** DevEco Code 的资源，而非复制文件：
  - `skills.paths` 指向 DevEco 的三个 skill 目录（只读引用）
  - `mcp` 块声明两个 MCP server（远程华为知识库 + 本地 qwen_vision，server 文件按绝对路径原地引用）

## 完成项
- [x] `opencode.json` 添加 `skills.paths`，引用 `~/.local/share/deveco/skills`、`~/.config/deveco/skills`、`~/.cache/deveco/skills`
- [x] `opencode.json` 添加 `mcp` 块：`harmonyos_developer_knowledge`（remote）+ `qwen_vision`（local，指向 `~/.local/share/deveco/mcp/qwen_vision_mcp.py`）
- [x] JSON 合法性校验通过（`node JSON.parse`），`provider` 块（含 apiKey）逐字节保留

## 技术决策
- **决策 1：反向同步采用"引用"而非"合并"**：DevEco Code 与 OpenCode 共用一个配置 schema（`https://opencode.ai/config.json`），但为了不污染 DevEco 的配置目录、避免结构性问题，OpenCode 侧只声明引用路径，不复制任何文件。
- **决策 2：MCP server 本体原地引用**：OpenCode 无 include 其他配置文件机制，MCP 配置块必须在 opencode.json 内声明，但 server 文件路径直接指向 DevEco 数据目录（`qwen_vision_mcp.py` 自包含 stdio server，靠 `QWEN_VISION_*` 环境变量运行）。
- **决策 3：session 历史不同步**：两库 SQLite schema 分叉（migration 35 vs 38，`session_context_epoch` 多 3 列），直接拷贝 DB 有损坏风险，本次不迁移会话。

## 文件变更
| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `C:\Users\Forwardz\.config\opencode\opencode.json` | 修改 | 新增 `skills.paths`（3 条 DevEco skill 目录）与 `mcp`（远程知识库 + 本地 qwen_vision） |

## 遗留问题
- 鸿蒙专用 skill（arkts-*、deveco-create-project、harmonyos-docs、ohos-qt-skills 等）依赖 DevEco 内置工具（`build_project`/`hdc_log`/`arkts_check` 等），在 OpenCode 中会加载但不可用
- `QWEN_VISION_MODEL` 暂设为 `qwen-vl`，需按本地实际模型名调整
- `image-recognition` 在 share 与 config 目录各有一份，可能重复加载（无害）

## 环境信息
- 项目: scidavis-ohos（工作日志归档于此，本次为工具链配置任务）
- 日期: 2026-08-02
- 依赖变更: 无

## 后续建议
- 在 OpenCode 中验证 `skills` 与 MCP 是否实际加载成功（`/skills` 列表、MCP 连接状态）
- 如需完整会话历史迁移，可写一次性脚本从 `deveco.db` 导出 session/message/part，先小批量试迁移
