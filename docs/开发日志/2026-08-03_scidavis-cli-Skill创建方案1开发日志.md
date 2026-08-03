# 2026-08-03 工作日志：scidavis-cli Skill 创建（方案 1）

## 工作内容

创建 `scidavis-cli` skill，让 DevEco Code 在用户提到 SciDAVis / 科学绘图 / 数据分析出图时，无需明确提醒即可自动发现并使用已安装的 `cli-anything-scidavis` v0.1.0 命令行工具。这是"DevEco Code 能否自行调用 SciDAVis"调研的落地方案 1（主动注入知识）。

## 完成项

- [x] 调研 DevEco skill 规范：`~/.config/deveco/skills/<name>/SKILL.md`，frontmatter 含 `name` + `description`（description 是触发机制核心）
- [x] 收集 cli-anything-scidavis 完整命令集（--help 实测）
- [x] 委派 subagent 编写 SKILL.md（163 行，中文正文，触发词 pushy 设计）
- [x] 修正两处技术错误：`.sciprj` 是纯 XML（非 gzip 压缩，`.sciprj.gz` 才是）；默认表名是 `Table1`（非 `Data`）
- [x] 验证：frontmatter 可解析、目录与其他 skill 对齐、UTF-8 无 BOM 编码
- [x] 触发覆盖度验证：11 条模拟提示语，8 条应触发命中，4 条正确拒绝（Excel/matplotlib/Python 场景本就不应触发）

## 技术决策

- **决策 1（触发词设计）**：description 采用 skill-creator 的"pushy"原则——明确列出 SciDAVis/scidavis/科学绘图/科学作图/数据绘图/数据画图/数据制图/数据可视化/曲线拟合/数据拟合/qtiplot/.sciprj 等触发词，并声明"即使用户没明确要求用 CLI 也应使用本技能"，对抗模型 undertrigger 倾向。
- **决策 2（安全边界写入 skill）**：将"仅支持纯表格项目"和"无法无头渲染图片"两条限制显著写入 SKILL.md，防止 agent 误操作含 graph/matrix 的项目或承诺无法兑现的无头出图。
- **决策 3（与 cli-hub-meta-skill 分工）**：cli-hub 负责发现/安装其他软件 CLI，scidavis-cli 负责已装工具的具体使用，互补关系写入 skill 正文。

## 文件变更

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `C:\Users\Forwardz\.config\deveco\skills\scidavis-cli\SKILL.md` | 新增 | 163 行：触发词、命令参考、工作流、Windows 注意、安全边界 |

## 遗留问题

- 当前会话的技能列表是启动时快照，**需新开会话**才能看到 scidavis-cli 进入 available_skills
- 触发依赖模型的相关性判断（description 匹配非硬性规则），极端边缘场景（如"分析这组 CSV 数据"无任何 scidavis 关键词）可能不触发
- 方案 2（注册进全局 instructions）未执行，若实测触发率不理想可补做双保险

## 环境信息

- 项目: scidavis-ohos
- 日期: 2026-08-03
- 依赖变更: 无新增（skill 为纯文档）

## 后续建议

- 新开会话后，可用提示语实测触发："帮我用 scidavis 画个图"、"我有个 .sciprj 想加一列数据"
- 若触发率不理想 → 补做方案 2（新增 `instructions/scidavis-cli.md` 并注册进 `deveco.json` 的 `instructions` 数组）
