# GitHub 上传与仓库内容管理规范

> 适用于 OHPlot 全部分支（main / docs）。目标：仓库只包含可复现构建与协作
> 所必需的内容，杜绝涉密、临时、过程性文件入库。
> 修订记录：2026-08-02 依据当日实际上传（forwardz666/OHPlot）的教训增补，
> 新增内容均以（2026-08-02）日期标注，便于溯源。

## 一、六项基本原则

### 1. 非必要文件不上传
- 与构建、运行、协作无关的文件一律不入库。
- 本项目实例（保持未跟踪，不 `git add`）：调试取证脚本 `debug_tb*.py`、`hit_test.py`、
  布局 dump `layout_*.json`、`_dbg*.json`、探针源码副本 `tools/main_probe.cpp` 等。
- 判据：删除该文件后 `clone + 构建 + 验证` 是否仍可完整进行；可以则不上传。
- 一次性取证脚本的**方法论**沉淀到 specifications/ 规范文档，脚本本身不入库；
  可复跑的正式回归脚本（如 `tools/verify_toolbar.py`）属于质量资产，**应当**入库。

### 2. 涉密内容不上传
- API key、密码、token、私钥、证书/签名材料（`.p12`、`.p7b`、`.cer`、keystore、
  `signingConfigs` 中的明文口令）一律禁止入库。
- 防护措施：
  1. `.gitignore` 覆盖签名目录与本地配置（`local.properties`、`*.p12` 等）；
  2. 提交前自检：`git diff --cached | Select-String -Pattern 'password|token|apikey|secret'`；
  3. 一旦误提交，视为已泄露：**立即吊销/更换凭据**，仅从历史中删除不足以补救。
- **推送前全量扫描（2026-08-02 补充）**：推送前对待推送的全部提交执行更完整的扫描，
  覆盖私钥与证书 blob：
  ```powershell
  git log origin/main..main -p | Select-String -Pattern "password|apikey|secret|\.p12|BEGIN.*PRIVATE" -CaseSensitive:$false
  ```
  命中解读：命中项若为文档正文引用（规范引文、示例代码、变更日志提及），并非真实泄密；
  须逐条核对命中的文件与行号上下文后再下结论（08-02 实例：3 处命中均为文档正文引用，
  判定无需处理）。仅真实凭据（密钥值、`.p12` blob、原始 token）需要按上条吊销/更换。

### 3. 非开源内容不上传
- 授权不明的第三方资源（字体、图标、图片、代码片段）入库前必须核验许可证。
- 本项目实例：工具栏图标源自 SciDAVis 原仓库（GPL），与本项目授权兼容，合规入库；
  从任意网页/商业软件截取的素材禁止入库。
- 引入第三方开源代码时保留其 LICENSE 文件与版权头。

### 4. 测试过程文件不上传
- 验证截图（`scr*.jpeg`、`tb_*.jpeg` 等取证图）、hilog dump（`hilog_*.txt`）、
  faultlog 摘录（`faultlist*.txt`、`crash*.txt`）、回归运行日志（`_vt_run*.log`）
  均为过程产物，留存本地，不入库。
- 验证**结论**（PASS/FAIL 统计、根因、证据要点）写入 docs 审计文档或 dev-logs
  开发日志入库，做到"结论入库、过程留档本地"。

### 5. 临时文件和缓存文件不上传
- 构建/IDE 缓存一律走 `.gitignore`：`.hvigor/`、`build/`、`entry/build/`、
  `entry/.cxx/`、`oh_modules/`、`.idea/`（除必要共享配置）、`__pycache__/`、
  `*.bak`、`.git-push-log.txt` 等。
- 新增工具链产生新缓存目录时，第一时间补 `.gitignore`，而非事后清理历史。
- **untracked 缓存误报核查（2026-08-02 补充）**：git 的 untracked-cache 可能过期误报，
  使已被 `.gitignore` 覆盖的路径仍显示为 `??` 未跟踪（08-02 实例：`git status --short`
  误报 `?? build/`、`?? _docs_export.tar`，实际两者均已被 `.gitignore` 覆盖）。
  处置：出现意外的 `??` 条目时，先执行 `git check-ignore -v <path>` 查看命中的
  `.gitignore` 规则，再重跑 `git status` 确认；已命中忽略规则则无需处理。
  禁止在出现意外 `??` 条目时直接 `git add -A`：若忽略规则真的缺失，该命令会把
  构建产物一并提交入库。

### 6. 大型二进制文件妥善处理
- 原则：> 10MB 的二进制不直接入库；替代方案按优先级：
  1. 构建脚本从官方源拉取（首选，可复现）；
  2. GitHub Release 附件 + 文档记录下载与校验（sha256）步骤；
  3. Git LFS（需评估配额与协作者环境）。
- **GitHub 50MB 警告线（2026-08-02 补充）**：GitHub 对超过 50MB 的文件发出 GH001
  "Large files detected" 警告（建议改用 LFS），但 push 本身仍会成功（08-02 实例：
  推送 97.89MB 的 `libentry.so` 成功，同时收到 GH001）。判据：单个二进制接近或超过
  约 50MB 即处于边缘区，应评估 LFS / Release 附件迁移，而非无限期直接入库。
- 本项目现状说明：`entry/libs/arm64-v8a/` 预编译 Qt `.so` 因 Qt for OpenHarmony
  交叉编译链路复杂、为保证协作者开箱即构建而历史入库；后续若体积失控或链路
  固化，应迁移至 Release 附件方案，并在 README 记录获取步骤。

## 二、提交与推送流程

1. **原子化提交**：一个提交只做一件事，遵循 `type(scope): description`
   （详见 [05_开发工作流与质量验证规范](05_开发工作流与质量验证规范.md)）。
2. **提交前三查**：
   - `git status --porcelain` 逐行确认无过程文件混入；
   - `git diff --cached --stat` 确认改动范围与提交主题一致；
   - 敏感词自检（见原则 2）。
3. **推送前征求确认**：向远程 push 属外发动作，AI 辅助流程中必须先展示提交
   清单并获得明确确认后执行；禁止对 main/docs 分支 force push。
4. **分支职责**：`main` 为代码分支；`docs` 为 AI 辅助开发资产分支
   （dev-logs/、specifications/、skills/），文档类改动不混入 main 的代码提交。
5. **推送前分叉检查与合并（2026-08-02 新增）**：
   - 每次 push 前先执行：
     ```powershell
     git fetch origin
     git rev-list --left-right --count origin/main...main
     ```
     输出为 `<远端独有提交数> <本地独有提交数>`。若左侧（远端独有）计数 > 0，
     说明远端存在本地没有的提交，两端已分叉，此时 push 会被拒（08-02 实例：
     远端经 GitHub 网页上传产生 2 个本地没有的提交，首次 push 被拒）。
   - 分叉后的处置流程：
     1. `git fetch origin`；
     2. 对比两端目录树，判定远端内容是本地的子集/超集/冲突：
        `git diff --name-status <本地分叉基点提交> <远端提交> -- <目录>`；
     3. 若远端文件为本地逐字节一致的子集（diff 仅显示删除 D，无新增 A / 修改 M），
        直接 `git merge origin/main` 通常是安全的，且大概率零冲突（08-02 实例：
        ort 策略零冲突合并，合并提交 3d8d224）；
     4. 禁止 force push（本规范已禁 main/docs force push）；禁止在可用一个合并提交
        解决时对十几个本地提交做 rebase 重写历史（08-02 实例：12 个提交未 rebase，
        以合并提交收敛）。
6. **仓库内容禁止经 GitHub 网页上传（2026-08-02 新增）**：任何仓库内容一律走本地
   `git add / commit / push` 流程，不使用 GitHub 网页的 "Add files via upload"。
   网页上传会产生与本地平行的历史，造成分叉与重复内容（08-02 实例：网页上传的
   b6d818a 创建 OHPlot-docs/，与本地 docs/ 工作重复，后须合并收敛）。
   若已发生网页上传，按第 5 条的分叉处置流程合并。

## 三、检查清单（提交前逐项勾选）

- [ ] 无调试/取证/临时脚本混入
- [ ] 无截图、日志 dump、回归运行日志
- [ ] 无 key/密码/token/签名材料
- [ ] 新增第三方内容已核验许可证
- [ ] 新增缓存目录已补 .gitignore
- [ ] 大于 10MB 的新二进制已改用替代方案
- [ ] 提交信息符合 type(scope): description
- [ ] push 前已展示清单并获确认
- [ ] 意外 `??` 条目已用 `git check-ignore -v` 核实（2026-08-02）
- [ ] 待推送提交已做全量敏感词扫描（`git log origin/main..main -p`，含 `.p12` / `PRIVATE`）（2026-08-02）
- [ ] push 前已 `git fetch` + `git rev-list --left-right --count origin/main...main` 确认无分叉（或已按流程合并）（2026-08-02）
- [ ] 新增/更新的二进制未超过约 50MB，超过则已评估 LFS / Release 迁移（2026-08-02）
- [ ] 本次改动未使用 GitHub 网页上传（2026-08-02）
