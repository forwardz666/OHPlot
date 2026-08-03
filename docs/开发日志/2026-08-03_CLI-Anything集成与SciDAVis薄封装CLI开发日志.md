# 2026-08-03 工作日志：CLI-Anything 集成与 SciDAVis 薄封装 CLI 开发

## 工作内容

调研 CLI-Anything 项目（HKUDS/CLI-Anything）与 DevEco Code 的结合方式，落地 A+C 路线（直接调用 CLI + Skill 发现），并为 SciDAVis 手动构建薄封装 CLI。

## 完成项

- [x] 调研 CLI-Anything：非 GUI 自动化，而是将软件真实后端封装为状态化 CLI（Click + `--json` + REPL）
- [x] 安装 `cli-anything-hub` v0.4.1（CLI-Hub 包管理器，路径 A 基础设施）
- [x] 安装 `cli-hub-meta-skill` 并复制到 DevEco Code 技能目录（路径 C）
- [x] 确认 SciDAVis 不在 CLI-Hub 注册表；本机安装为纯 Qt GUI（无 Python 脚本支持，`-x` 模式不可用）
- [x] 克隆 SciDAVis 源码，逐行验证 `.sciprj` XML schema（version=133378、creation_time 日月格式、type/mode 配对、child_aspect 包裹、可选元素）
- [x] 手动实现 `cli-anything-scidavis` Click CLI（`C:\Users\Forwardz\dev\cli-anything-scidavis`）
- [x] 代码审查发现 3 严重 + 4 中等问题，全部修复，46 个测试通过

## 技术决策

- **决策 1（A 路线）**：SciDAVis 不在注册表 → 不装现成 CLI，改为**手动薄封装**：直接生成/解析 `.sciprj` XML（纯 XML 格式，已从源码确认），用 `launch` 命令调用 scidavis.exe 打开。规避了"无 Python 脚本支持"的约束。
- **决策 2（C 路线）**：`npx skills add` 安装到 `~\.agents\skills\`，需手动复制到 `~\.config\deveco\skills\` 才能被 DevEco Code 发现。
- **决策 3（安全边界）**：CLI 只支持纯表格项目；load 时检测 graph/matrix/note/嵌套 folder，保存时明确拒绝（防静默数据丢失）。
- **决策 4（XML 简化）**：省略 `input_filter`/`output_filter`/`column_width`（源码 load 逻辑验证缺失时用默认值，不报错），大幅简化生成。

## 文件变更

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `C:\Users\Forwardz\dev\cli-anything-scidavis\cli_anything_scidavis\model.py` | 新增 | .sciprj XML 读写模型（Column/Table/SciDAVisProject + schema 常量） |
| `C:\Users\Forwardz\dev\cli-anything-scidavis\cli_anything_scidavis\cli.py` | 新增 | Click 命令集：project/table/data/import/export/launch + REPL |
| `C:\Users\Forwardz\dev\cli-anything-scidavis\cli_anything_scidavis\backend.py` | 新增 | scidavis.exe 定位与启动（SCIDAVIS_EXE 环境变量覆盖） |
| `C:\Users\Forwardz\dev\cli-anything-scidavis\setup.py` | 新增 | 打包配置，入口 `cli-anything-scidavis` |
| `C:\Users\Forwardz\dev\cli-anything-scidavis\tests\test_model.py` | 新增 | 46 个测试（单元 + CLI 子进程） |
| `C:\Users\Forwardz\dev\cli-anything-scidavis\README.md` | 新增 | 使用说明 + 纯表格限制警告 |
| 环境 | 变更 | `pip install cli-anything-hub`；`npx skills add cli-hub-meta-skill` |
| 环境 | 变更 | `cli-hub-meta-skill` 复制到 `~\.config\deveco\skills\` |
| 临时 | 删除 | `%TEMP%\deveco\scidavis-src`（源码克隆，仅研究用） |

## 遗留问题

- SciDAVis 本机版本无 Python 支持，无法无头渲染 PNG/PDF（需 GUI 打开后手动导出）
- `cli-anything-scidavis` 未发布到 CLI-Hub 注册表（可后续按 CONTRIBUTING 提交）
- scidavis.exe 测试时曾误杀用户可能打开的实例（已致歉，后续避免）

## 环境信息

- 项目: scidavis-ohos（工作日志目录）
- 目标软件: SciDAVis 2.9.2 @ `C:\Program Files (x86)\SciDAVis\scidavis.exe`
- CLI 项目: `C:\Users\Forwardz\dev\cli-anything-scidavis`
- 日期: 2026-08-03
- 依赖变更: cli-anything-hub==0.4.1（全局 pip）；cli-hub-meta-skill（全局 skill）

## 后续建议

- 使用示例：
  ```powershell
  cli-anything-scidavis project new -o demo.sciprj --table Data --columns 2 --rows 10
  cli-anything-scidavis data set --project demo.sciprj --table Data --column X --values "1,2;3,4"
  cli-anything-scidavis --json project info --project demo.sciprj
  cli-anything-scidavis launch --project demo.sciprj
  ```
- 如需无头出图，考虑安装带 Python 支持的 SciDAVis 构建，或改用 LibreOffice/Blender 等注册表现成 CLI
