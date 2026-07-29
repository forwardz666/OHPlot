# Specifications 规范总览

OHPlot（SciDAVis OpenHarmony 适配版）开发规范文档，按编号排序，供 AI 编码助手与开发者统一调阅。

## 索引

| # | 文档 | 主题 |
|---|------|------|
| 01 | [ArkTS代码编写与NAPI集成规范](01_ArkTS代码编写与NAPI集成规范.md) | ArkTS 类型安全、NAPI 模块导入、接口断言、@Builder 响应性传参（2026-07-28 增补） |
| 02 | [Qt_for_OpenHarmony平台开发规范](02_Qt_for_OpenHarmony平台开发规范.md) | Qt/QPA 插件约束、C++ 编码、跨 DSO 导出、全局 QSS 字体陷阱（2026-07-29 增补） |
| 03 | [混合架构UI事件交互规范](03_混合架构UI事件交互规范.md) | XComponent 事件透传、鼠标转发、坐标转换、mutation 队列化语义与浮层遮挡（2026-07-28 增补） |
| 04 | [UI缩放实现规范](04_UI缩放实现规范.md) | HighDpi 策略、vp/px 换算 |
| 05 | [开发工作流与质量验证规范](05_开发工作流与质量验证规范.md) | 构建、部署、真机验证流程、逐控件自动化回归（2026-07-28 增补） |
| 06 | [调试与日志规范](06_调试与日志规范.md) | hilog 标签体系、崩溃日志获取、hit-test 拦截者定位与控制台编码陷阱（2026-07-28 增补） |
| 07 | [ArkTS多语言资源管理规范](07_ArkTS多语言资源管理规范.md) | string.json 资源管理、Qt/C++ 侧 .qm 翻译加载与验证（2026-07-29 增补） |
| 08 | [OHOS剪贴板桥接与安全控件规范](08_OHOS剪贴板桥接与安全控件规范.md) | 粘贴板 JS 桥接、安全控件 |
| 09 | [DevEco_Code三层子代理调用规范](09_DevEco_Code三层子代理调用规范.md) | 三层模型分工（Qoder / GLM-5.1 / deepseek-v4-flash）、并行委派、验收规则 |
| 10 | [GitHub上传与仓库内容管理规范](10_GitHub上传与仓库内容管理规范.md) | 六项上传原则（涉密/临时/过程文件不入库）、大二进制处理、提交推送流程 |
| 11 | [工具栏悬停提示规范](11_工具栏悬停提示规范.md) | onHover+bindPopup 悬停 tooltip、API 兼容性选型、tip 资源本地化（2026-07-29 新增） |

## 配套资源

- 开发过程使用的 Agent Skills 见 [../skills/](../skills/) 目录
- 开发日志见 [../dev-logs/](../dev-logs/) 目录
- 功能实现计划见 [../FEATURE_IMPLEMENTATION_PLAN.md](../FEATURE_IMPLEMENTATION_PLAN.md)
