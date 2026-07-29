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

---

## 三、createJsObject 桥对象注册规范（2026-07-27 补充）

QPA 插件在启动与运行期会经 TSFN 通道向 Ability 请求一系列 ArkTS 桥对象
（`createJsObject(type, name, ...args)`）。**每个被请求的类型都必须返回有效对象**，
返回 null 会导致对应 Qt 子系统静默失效（不崩溃、无异常，极难察觉）。

### 3.1 已知桥对象清单（SciDAVis 实测）
| 类型 | 承接的 Qt 子系统 | 缺失后果 |
|---|---|---|
| `JsLocale` | QLocale 系统区域 | 启动 SIGSEGV（见第一节） |
| `JsStandardPaths` | QStandardPaths 路径 | 路径查询失败 |
| `JsInputMethod` | 输入法（IME） | 无法唤起软键盘/提交文本 |
| `JsCursor` | 光标形状 | 光标不更新 |
| `JsWindowManager` / `JsWindow` | 窗口管理 | 窗口创建/属性失效 |
| `JsPasteBoard` | QClipboard 剪贴板 | copy/paste 全部静默失败（详见规范 08） |

### 3.2 强制要求
- 桥对象方法**必须同步返回**（TSFN 桥不支持异步返回值），只能用系统 `*Sync` API；
- 对象内部所有系统调用必须 try-catch，禁止异常穿透 TSFN 桥；
- 已创建对象放入 `jsObjectCache`（Map）复用，避免重复创建。

### 3.3 排查信号
- 启动日志出现 `createJsObject ENTER type=Xxx` 但返回 null → 该类型未注册；
- 运行期 `call js function <method>` 后紧跟 `get attached js object failed:<id>` →
  QPA 持有的桥对象为空，对应功能整链路静默失败；
- 未知类型的方法集可从 `libplugins_platforms_qopenharmony.so` 二进制字符串中提取。

---

## 四、全局 QSS 样式表字体陷阱（2026-07-29 增补）

**问题现象：**为统一浅色 UI 而注入全局样式表后，所有 Qt 面板（表格属性框、
对话框、菜单等）的文字明显变小。

**根因：** `QApplication::setStyleSheet` 中的 `QWidget{font-size:12px}` 是一条
**全局选择器**，会把所有控件的字号强制成 12px（比平台默认字号小），
而平台默认字号本应由系统 DPI / 字体度量决定。

**规范：**
- **禁止**在全局样式表中为 `QWidget`（或任何宽选择器）设置 `font-size` / `font`；
- 确需调整字号时，只针对**具体控件类**（如 `QLabel`、`QHeaderView`）局部设置，
  或通过 `QFont` 显式设置，不要依靠全局 QSS；
- 颜色 / 边框 / 背景等视觉样式可保留，仅删除 `font-size` 规则即可恢复
  Qt 默认（较大）字号：
```cpp
// 错误：全局压小所有控件字号
app.setStyleSheet("QWidget{font-size:12px;color:#333333}" ...);
// 正确：只保留颜色/面板样式，不碰字号
app.setStyleSheet("QWidget{color:#333333}" ...);
```

**验证：**真机截图对比面板文字（如表格属性面板的描述/类型/公式/小数位数）
字号是否恢复为默认大小。
