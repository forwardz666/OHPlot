# Qt for OpenHarmony 平台开发规范

## 一、QPA 启动规范：`startQtApplication` 必须传入 Ability 实例

**问题现象：**
- Qt 应用启动后立即崩溃
- 日志显示 `request js object: JsLocale` 后立即触发 `SIGSEGV`
- 白屏闪退且无 `cppcrash` 日志

**根因：**
Qt for OpenHarmony 的 QPA 插件 `startQtApplication` 必须传入 **Ability 实例（`this`）** 而非 `ApplicationDirs` 等普通对象，才能正确初始化 JS 桥接（`QOpenHarmonyJsObject`）。若传入普通对象，Qt Core 在调用 `getSystemLocale` 时因 JS 桥接为 NULL 而触发 SIGSEGV。

**正确方式：**
```typescript
// 错误
qpa.startQtApplication(dirs, 'libentry.so');

// 正确
qpa.startQtApplication(this);
```

---

## 二、Qt OHOS 开发防御性编程实践

### 2.1 根因分析原则
修改前必须进行根因分析，避免表面修复。每一处代码修改需要明确回答：
- 问题的根本原因是什么？
- 此修改是否真正解决了根因？
- 是否引入了新的风险？

### 2.2 修改验证闭环
每项修改后必须执行：**构建 → 部署 → 实时 hilog 日志验证** 的完整闭环。
```powershell
hvigorw assembleHap --mode module -p product=default --daemon
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc hilog -x | Select-Object -First 100
```

### 2.3 临界区保护
关键共享资源访问必须加 `std::mutex` 临界区保护，防止多线程竞态条件。

### 2.4 窗口有效性检查
Qt 窗口事件处理前需校验 `win->isExposed()`，确保窗口已正确映射和可见后方可处理事件。

### 2.5 外部事件注入保护
外部事件注入（如 `sendEvent`）必须用 `try-catch` 包裹以防止崩溃，因为事件接收方可能在处理过程中抛出异常。

### 2.6 C++ 跨线程调用规范
跨线程调用必须使用 `QMetaObject::invokeMethod()` 并指定 `Qt::QueuedConnection`：
```cpp
QMetaObject::invokeMethod(receiverObj, "slotName", Qt::QueuedConnection,
                          Q_ARG(QString, value));
```
禁止在非 GUI 线程中直接操作 QWidget/QWindow。
