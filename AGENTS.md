# AGENTS.md — OHPlot (SciDAVis) OpenHarmony 移植

面向编码代理的路由与硬约束。**只列硬约束与去处，不复制正文**。
详细规范见 [`docs/README.md`](docs/README.md)（文档总览）。

## 路由

| 主题 | 去处 |
|------|------|
| ArkTS / C++ / 构建 / 部署 / 调试完整规范 | `docs/README.md`（开发规范目录见 `docs/开发规范/`） |
| 冒烟验证入口 | `tools/verify_smoke.py`（收编 `verify_toolbar.py` / `verify_i18n.py`） |
| 诊断入口（Qt 日志分类） | `tools/dump_logcats.ps1` |
| 诊断产物存放 | `diagnostics/`（整体 `.gitignore`，不入库） |

## 硬约束（恒定）

1. **真机验证**：模拟器不能替代真机。核心功能改动须在真机（华为 MatePad 11.5 / OpenHarmony）验证；“修复完成”声明**必须附带 `python tools/verify_smoke.py` 的执行结果**（静态检查为最低要求，触及设备行为时附真机结果）。

2. **双层构建与部署路径**：
   - Qt native 库在**工作区外**的 Qt 构建目录（如 `C:\Users\Forwardz\ohplot-ohos\build-ohos`）用 ninja 构建；Windows 上 CMake POST_BUILD 的 `cp`/`mkdir -p` 报 FAILED 属**预期**，产物 `libentry.so` 仍有效。
   - 每次 native 构建后须手动复制 `libentry.so` 到 `entry/libs/arm64-v8a/`，再走 hvigor 生成 HAP；仅改 ArkTS 无需复制。

3. **诊断产物存放**：所有截图/日志/dump 一律放入 `diagnostics/` 对应子目录。**禁止**在仓库根目录留下 `*.jpeg`、`*.png`、`hilog_*.txt`、`crash*.txt`、`layout_*.json` 等调试残留。`tools/` 仅保留可复用脚本；一次性排查脚本放 `diagnostics/scratch/`。

4. **NAPI 边界**：ArkTS 侧 `libqohos.so` 导入必须用 `import` + `interface` + `as` 断言，禁 `any`/`require`；每个 `callQtCommand` 必须 try-catch 包裹。结构化链路日志统一标签 `SciDAVisChain`。

5. **QPA 启动方式（2026-07-31 实测结论，P0 已验证）**：
   - **结论：维持 alpha_v6 插件 + `startQtApplication(dirs, appBinary)` + 自定义 C++ 线程回退方案**。真机验证：`qpa.startQtApplication` 返回 true，6 个 JS 桥对象全部注册，heartbeat 正常。
   - **已排除 AirStars 插件升级路径**：AirStars 的 `libplugins_platforms_qopenharmony.so`（3.22MB，支持 `attachAbilityStage`）是 **HarmonyOS NEXT SDK 编译**的 Qt 插件，DT_NEEDED 依赖 19 个 NEXT 系统库（libudmf/libpasteboard/libohinputmethod/libnative_window_manager 等），在 OpenHarmony 7.0.0.32（MatePad 11.5）设备上全部缺失 → dlopen 失败 → NAPI 模块未注册 → ArkTS `import qpa` 返回 undefined → `attachAbilityStage failed: {}`。**切勿在 OpenHarmony 设备上再次尝试该插件**。
   - **能力探测模式（可保留）**：P0-3 尝试的 `hasFn(k) = typeof qpa[k] === 'function'` 条件调用是防御性编程的好实践，未来若插件 API 面变化可复用；但当前 alpha_v6 插件的 setter API（setDeviceType 等）完整存在，无必要。
   - 长期方案：仅当获得 **OpenHarmony SDK 编译**的支持 `attachAbilityStage` 的插件版本时，才可切换到官方启动流程。
