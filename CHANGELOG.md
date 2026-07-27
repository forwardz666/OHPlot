# Changelog

OHPlot (SciDAVis OpenHarmony 适配层) 版本变更记录。

---

## [0.2.0] - 2026-07-26

### Added

- **蓝牙鼠标左键注入通道**: 通过 ETS 透明覆盖层捕获左键事件，经 NAPI `sendMouse` 转发至 libentry.so 的 `scidavis_inject_mouse` 导出函数，绕过 QPA 触摸管线丢弃问题。
- **蓝牙键盘数字键 KeyTextFixer**: InputProbe 事件过滤器拦截 `spontaneous && text.isEmpty()` 的 KeyPress 事件，按 key + modifier 合成 text 字段后重投递。
- **应用图标恢复**: 将 1x1 像素占位 PNG 替换为原版 128x128 OHPlot 图标（entry media + AppScope media）。
- **开发标准化文档**: README、DEVELOPMENT_GUIDE、CHANGELOG、LICENSE 全套文档。

### Fixed

- 左键点击在 QPA 层被双重丢弃的问题（ArkUI mousetransEnable 转触摸 + QPA touchDown 空实现）。
- 数字键输入无法进入编辑区域的问题（QPA handleKeyEvent text 字段恒空）。

---

## [0.1.0] - 2026-07-25

### Added

- **基础运行环境搭建**: 完成 Qt 5.15.12 for OpenHarmony 交叉编译工具链配置，成功构建并部署 SciDAVis HAP。
- **JS 桥接集成**: 实现 `initJsObjectLoader` + `createJsObject` 工厂，桥接 JsWindowManager / JsInputMethod / JsLocale / JsStandardPaths / JsCursor 五个 Qt Core JS 对象。

### Fixed

- **启动闪退 (NAPI 死锁)**: `startQtApplication` 从 ArkTS 主线程调用死锁 — 改为独立 C++ pthread 内 setenv -> dlopen -> dlsym main() -> 直接调用，完全绕过 NAPI。
- **黑屏**: `QT_QPA_PLATFORM_PLUGIN_PATH` 指向插件副本导致 XComponent surface 注册在另一实例 — 环境变量指向 `libs/arm64` 确保同一 dlopen 实例。
- **坐标减半 (HighDpi)**: `AA_EnableHighDpiScaling` + QPA 物理像素坐标导致落点偏左 — 注入 `QT_ENABLE_HIGHDPI_SCALING=0` 环境变量。
- **QPA 插件加载**: require() 动态导入 + 备选方案 + 错误捕获，增强容错。

---

## [Unreleased]

### Planned

- 真实蓝牙鼠标/键盘全流程实测验证。
- Shift 组合键、字母键、KeyRelease text 补全。
- 文本框 IME attach 链路（软键盘唤起）。
- InputProbe 诊断日志清理（保留 KeyTextFixer 和注入通道）。
- CMakeLists POST_BUILD 改用 `${CMAKE_COMMAND} -E` 实现跨平台兼容。
