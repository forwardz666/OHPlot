# OHPlot (SciDAVis) OpenHarmony 开发规范

本文档涵盖本项目 ArkTS / C++ / 构建 / 调试各环节的编码约定与注意事项。

---

## 1. ArkTS 编码规范

### 1.1 类型安全

- **禁止 `any` 类型**。所有 NAPI 模块导入必须使用 ES6 `import` + `interface` + `as` 类型断言：

```typescript
import qohos from 'libqohos.so';

interface QohosInjector {
  sendMouse(x: number, y: number, button: number, action: number): boolean;
}

const qtInjector = qohos as QohosInjector;
```

- **禁止 `require()`**。仅在遗留归档代码中出现（`docs/archive/`），新代码一律使用 `import`。

### 1.2 XComponent 与事件转发

- XComponent 的 `libraryname` 为 `plugins_platforms_qopenharmony`，QPA 插件通过 native callback 直接注册输入事件。
- `.onMouse()` 在 XComponent 自身上**不会触发**（native callback 吞掉了所有事件），必须在 XComponent 上方放置透明覆盖层：

```typescript
Stack() {
  XComponent({ ... })  // 底层：Qt 渲染 surface
  Column()             // 顶层：透明鼠标事件观察层
    .backgroundColor(Color.Transparent)
    .hitTestBehavior(HitTestMode.Transparent)
    .focusable(false)
    .onMouse((event: MouseEvent) => { /* 转发逻辑 */ })
}
```

- **仅转发左键** press/release/drag。右键和中键由 QPA 原生链路处理，转发会导致双击。

### 1.3 坐标转换

- HighDpi 已禁用（`QT_ENABLE_HIGHDPI_SCALING=0`），Qt 使用物理像素坐标。
- ETS 层事件坐标为 vp（虚拟像素），转发前必须用 `vp2px()` 转换为物理像素。
- 设备物理分辨率 2456x1600，vp:px 系数约 1.5。

---

## 2. C++ 编码规范

### 2.1 变量初始化

- 复合类型优先使用**花括号初始化**，避免 most-vexing-parse：

```cpp
// CORRECT
const QPoint globalP{ int(x), int(y) };

// WRONG - 编译器解析为函数声明
const QPoint globalP(int(x), int(y));
```

### 2.2 导出符号

- 跨 DSO 调用的 C 函数必须声明 `extern "C"` 并设置可见性：

```cpp
extern "C" __attribute__((visibility("default")))
void scidavis_inject_mouse(float x, float y, int button, int action);
```

### 2.3 线程安全

- 从非 GUI 线程投递 Qt 事件，使用 `QMetaObject::invokeMethod` + `Qt::QueuedConnection`：

```cpp
QMetaObject::invokeMethod(QCoreApplication::instance(), [x, y, button, action]() {
    // 在 Qt GUI 线程执行
    QWindow *win = QGuiApplication::focusWindow();
    // ...
    QCoreApplication::sendEvent(win, &ev);
}, Qt::QueuedConnection);
```

### 2.4 事件合成标记

- 注入的鼠标事件必须标记 `Qt::MouseEventSynthesizedByApplication`，便于区分来源并防止双投递。

---

## 3. 构建注意事项

### 3.1 ninja POST_BUILD 在 Windows

CMakeLists 的 POST_BUILD 步骤使用 Unix 命令（`cp`、`mkdir -p`），在 Windows 上**必然报 FAILED**：

```
FAILED: scidavis/libentry.so
'cp' is not recognized as an internal or external command
```

**这是预期行为**。链接产物 `libentry.so` 是有效的（时间戳新、符号完整），直接取用即可：

```powershell
Copy-Item <build-ohos-dir>/scidavis/libentry.so entry/libs/arm64-v8a/ -Force
```

### 3.2 hvigor 增量构建

- 增量构建前**无需 clean**，hvigor 会自动检测变更。
- 仅修改 ArkTS 文件时构建耗时约 6-10 秒。
- 修改 native 库（替换 `libentry.so`）后需完整走 hvigor 流程。

### 3.3 libentry.so 位置

- Qt 构建目录（如 `C:\Users\Forwardz\ohplot-ohos\build-ohos`）不在 ohos 工作区内。
- 每次 ninja 构建后必须手动（或脚本）复制到 `entry/libs/arm64-v8a/`。
- 可用 `llvm-nm -D libentry.so` 验证导出符号是否完整。

---

## 4. 部署与调试

### 4.1 完整部署命令链

```bash
# 1. 安装 HAP
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap

# 2. 强制停止 + 清空日志 + 启动
hdc shell "aa force-stop org.ohplot.ohos; hilog -r; aa start -a OHPlotAbility -b org.ohplot.ohos"
```

### 4.2 日志过滤

关键标签（按模块）：

| 标签 | 模块 |
|------|------|
| `OHPlot` | Ability 生命周期、JS 桥接 |
| `SciDAVisNative` | qohos.cpp NAPI 层 |
| `InputProbe` | 输入事件探针 (libentry.so 内) |
| `QtInput` | ETS 侧输入转发日志 |
| `QtForOpenHarmony` | QPA 插件内部日志 |
| `JsWinMgr` | 窗口管理 JS 桥接 |

```bash
# 查看应用日志
hdc shell "hilog -x" | Select-String -Pattern "InputProbe|QtInput|SciDAVisNative"
```

> Windows PowerShell 注意：`hdc shell` 管道输出需用 `Select-String` 或 `Select-Object`，不能用 `head`/`grep`。

### 4.3 uinput 注入测试

**必须单会话调用**（分开调用会导致指针重置到 0,0）：

```bash
# 鼠标左键点击 (物理像素坐标)
uinput -M -m 825 144 -d 0 -u 0

# 鼠标右键点击
uinput -M -m 825 144 -d 1 -u 1

# 键盘按键 (OH keycode)
uinput -K -d 2001 -u 2001    # 数字键 1 (KEYCODE_1)
uinput -K -d 2013 -u 2013    # 方向键 LEFT
```

常用 OH keycode 对照：

| Keycode | 按键 |
|---------|------|
| 2001 | KEYCODE_1 |
| 2002 | KEYCODE_2 |
| 2010 | KEYCODE_0 |
| 2012 | KEYCODE_DPAD_UP |
| 2013 | KEYCODE_DPAD_LEFT |
| 2014 | KEYCODE_DPAD_RIGHT |
| 2015 | KEYCODE_DPAD_DOWN |

---

## 5. QPA 插件约束

当前使用的 QPA 插件为 **官方 alpha_v6 版本**（`libplugins_platforms_qopenharmony.so`），无源码，只能通过反汇编分析行为。

### 5.1 NAPI 导出清单

可用的 IME 通道：`insertText`、`sendEnterKey`、`moveCursor`、`deleteLeft`、`deleteRight`、`setTouchPad`、`startQtApplication`。

**无鼠标/键盘注入接口**，左键转发必须通过自建 `scidavis_inject_mouse` 通道。

### 5.2 已知行为

- **左键丢失机理**: ArkUI `mousetransEnable=1` 将左键转为触摸事件投递 → QPA `touchDown(float, float)` 是空函数（反汇编确认：单条 `ret`）→ 左键被双重丢弃。
- **右键正常**: 不做 touch 转换，走纯鼠标通道 → `dispatchMouseEvent` → `handleMouseEvent` → 完整传播。
- **键盘 text 恒空**: `handleKeyEvent` 的 `sKeyMap` 静态哈希表有数字映射（keycode→Qt::Key），但生成的 `QKeyEvent::text()` 始终为空。
- **HighDpi**: `QT_ENABLE_HIGHDPI_SCALING=0` 环境变量在 qohos.cpp 中 `setenv` 注入，确保 UI 1:1 物理像素渲染。

---

## 6. Git 工作流

### 6.1 分支策略

- `main` — 稳定版本，始终可构建。
- `feature/<name>` — 功能开发分支，合并前需通过设备验证。
- `hotfix/<name>` — 紧急修复分支。

### 6.2 Commit Message 格式

```
<type>(<scope>): <description>

[optional body]
```

**type** 可选值：`feat`、`fix`、`docs`、`refactor`、`build`、`chore`。

**scope** 可选值：`ets`、`cpp`、`res`、`build`、`docs`。

示例：
```
feat(cpp): add scidavis_inject_mouse export for left-button injection
fix(ets): convert mouse coordinates from vp to physical px
docs: add DEVELOPMENT_GUIDE.md
```
