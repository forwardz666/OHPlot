# Skills 总览（开发过程中使用的全部 Agent Skills）

本目录收录 OHPlot（SciDAVis OpenHarmony 适配版）开发过程中使用过的全部 Agent Skill，供 AI 编码助手（Qoder 等）复用。按用途排序如下。

## 索引

| # | Skill | 类型 | 用途 | 来源 |
|---|-------|------|------|------|
| 1 | [tiered-dev-delegation](tiered-dev-delegation/SKILL.md) | 工作流 | 三层模型分工委派：Qoder 主代理负责架构/拆任务/根因分析，`deveco run` GLM-5.1（免费）做具体开发，deepseek-v4-flash（极低成本）并行跑批量小任务 | 本项目自研 |
| 2 | [vision-recognize](vision-recognize/SKILL.md) | 工具 | 调用本地 llama.cpp 视觉模型（Qwen3.6-35B-A3B）识别图片内容并返回 Markdown，用于截图分析、UI 验证 | 本项目自研 |
| 3 | [harmonyos-arkui-hds-ui](harmonyos-arkui-hds-ui/SKILL.md) | UI 实践 | ArkUI/HDS UI 实现指南：沉浸式布局、悬浮 Tab 栏（HdsTabsFloatingStyle）、玻璃材质、安全区处理、真机截图验证流程 | 外部引入 |
| 4 | [arkts-syntax-assistant](arkts-syntax-assistant/SKILL.md) | 知识库 | ArkTS 语法助手：UI 结构、状态管理、类型约束等语法参考（中英双语），写 ArkTS 代码前查询 | OpenHarmony 社区 |
| 5 | [arkts-static-spec](arkts-static-spec/SKILL.md) | 知识库 | ArkTS 静态语言官方规范 + 144 条迁移食谱（cookbook），处理 TS→ArkTS 迁移和静态语法报错 | OpenHarmony 社区 |

## 使用约定

- **全局安装路径**（Qoder / Windows）：`C:\Users\<用户名>\.qoder\skills\<skill-name>\`
- 自研 skill 依赖的 Python 统一使用 `C:\Users\<用户名>\.qoder\venv\Scripts\python.exe`（venv 不存在时先创建并安装 pillow、requests）
- 社区 skill 保留其原始 LICENSE，仅作开发辅助，不属于本软件发布内容

## 相关规范

配套开发规范见 [../开发规范/](../开发规范/) 目录，其中与 skill 直接相关：

- `09_DevEco_Code三层子代理调用规范.md` — tiered-dev-delegation 的完整规范与本机验证记录
