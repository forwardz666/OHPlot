## 蓝牙鼠标左键修复验证

**根本原因**：ArkUI `mousetransEnable=1` 将左键 Press/Release 转换为 touch 事件，QPA 插件 `touchDown` 为空函数（反汇编确认：单条 `ret` 指令），导致左键被双重丢弃。

**修复方案**：在 XComponent 上方放置透明覆盖层（`HitTestMode.Transparent`），通过 `.onTouch` 捕获被 ArkUI 转换的 touch 事件，经 NAPI `sendMouse` → `scidavis_inject_mouse` 注入到 Qt 事件循环。

**验证结果**（2026-07-26 14:45）：
```
uinput: -M -m 825 144 -d 0 -u 0 (左键点击)

QtInput:  forward touch->mouse action=0 px=(825,144) ok=true
QtInput:  forward touch->mouse action=1 px=(825,144) ok=true

InputProbe: mouse press  recv=QWidgetWindow pos=(825,144) global=(825,144) btn=0x1
InputProbe: mouse press  recv=QTabBar      pos=(227,19)  global=(825,144) btn=0x1
InputProbe: mouse release recv=QWidgetWindow pos=(825,144) global=(825,144) btn=0x1
InputProbe: mouse release recv=QTabBar      pos=(227,19)  global=(825,144) btn=0x1
```

完整链路：uinput → ArkUI touch → ETS .onTouch → NAPI sendMouse → scidavis_inject_mouse → QWidgetWindow → QTabBar。坐标正确。

## 蓝牙键盘数字键修复验证

**根本原因**：QPA `handleKeyEvent` 的 `sKeyMap` 有数字映射但 text 字段恒为空，编辑器无 text 不插入字符。

**修复方案**：libentry.so 内 `KeyTextFixer` 事件过滤器拦截 `spontaneous && text.isEmpty()` 的 KeyPress，按 key+modifier 合成 text 重投递。

**验证结果**（2026-07-26 14:46）：
```
uinput: -K -d 2001 -u 2001 (KEYCODE_1)

InputProbe: key press recv=QWidget key=0x31 text='1'
InputProbe: key press recv=Table   key=0x31 text='1'
InputProbe: key press recv=QMdiArea key=0x31 text='1'
InputProbe: key press recv=ApplicationWindow key=0x31 text='1'
```

text 字段从空字符串成功修复为 '1'。

## HighDpi 修复验证

**修复方案**：qohos.cpp 注入 `QT_ENABLE_HIGHDPI_SCALING=0`，确保 UI 1:1 物理像素渲染。

**验证结果**：左键点击坐标 (825,144) 全局 → (227,19) 在 QTabBar 上的局部坐标，与预期一致。全分辨率 2456x1600。