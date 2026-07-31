# ArkTS 多语言资源管理规范

## 一、资源目录结构

多语言资源严格遵循 **三级目录结构**：

```
resources/
├── base/                          # 默认语言（英文）
│   └── element/
│       └── string.json            # 默认英文字符串
├── en_US/                         # 英文（美国）覆盖
│   └── element/
│       └── string.json
└── zh_CN/                         # 中文（简体）覆盖
    └── element/
        └── string.json
```

## 二、资源引用规范

1. **所有 UI 文本必须通过 `$r()` 系统函数引用**
   ```typescript
   Text($r('app.string.hello'))
   Button($r('app.string.confirm'))
   ```

2. **禁止硬编码文本**，以下写法不符合规范：
   ```typescript
   // 禁止
   Text('你好')
   Button('Confirm')
   ```

3. **新增 UI 组件时**必须创建对应的语言资源条目

## 三、string.json 格式

```json
{
  "string": [
    { "name": "hello", "value": "Hello" },
    { "name": "confirm", "value": "Confirm" },
    { "name": "cancel", "value": "Cancel" }
  ]
}
```

中文覆盖文件 `zh_CN/element/string.json`：
```json
{
  "string": [
    { "name": "hello", "value": "你好" },
    { "name": "confirm", "value": "确认" },
    { "name": "cancel", "value": "取消" }
  ]
}
```

## 四、规范要点
- `resources/base/element/string.json`：默认英文
- `resources/en_US/element/string.json`：英文覆盖（当与 base 不同时）
- `resources/zh_CN/element/string.json`：中文覆盖
- 国际化测试时验证资源加载是否匹配系统语言设置

## 五、Qt/C++ 侧翻译加载（.qm）规范（2026-07-29 增补）

ArkTS 的 `$r('app.string.*')` 只覆盖 **ArkUI 前端**文本；Qt/C++ 后端
（表格、矩阵、绘图对话框等所有 QWidget 文本）由 Qt 自己的 **QTranslator +
.qm** 机制本地化，两条链路必须同时打通，缺一不可（否则出现「ArkTS 中文、
Qt 面板英文」的半汉化状态）。

### 5.1 .qm 加载候选路径：绝对沙箱路径优先
**教训**：编译进二进制的 `TS_PATH`（CMake 相对路径 `share/scidavis/translations`）
在 OHOS 沙箱内运行期失效——CMake 的路径变量不会随 HAP 沙箱重定位。因此
`QTranslator::load()` 必须以**绝对沙箱路径为首选候选**，编译期路径仅作兜底：
```cpp
const QString fname = QStringLiteral("/scidavis_") + tag + ".qm";
const QStringList candidates = {
    QStringLiteral("/data/storage/el2/base/haps/entry/files/translations") + fname,
    QString(TS_PATH) + fname   // 兜底，OHOS 上通常无效
};
bool ok = false; QString used;
for (const QString &qm : candidates) { used = qm; if (qtTranslator.load(qm)) { ok = true; break; } }
if (ok) app.installTranslator(&qtTranslator);
```

### 5.2 .qm 打包管线：rawfile 暂存 → 沙箱 files 释放
- 构建期 CMake POST_BUILD 将 `scidavis_zh-cn.qm` / `zh-tw.qm` 拷入
  `entry/src/main/resources/rawfile/translations/`（随 HAP 打包）；
- 运行期首启由 Ability 从 rawfile 释放到
  `/data/storage/el2/base/haps/entry/files/translations/`（即 5.1 首选路径）；
- **Windows 构建注意**：POST_BUILD 中的 `mkdir -p` / `cp` 为 Unix 命令，在
  Windows cmd 下必然报错并使 ninja 以 exit 1 结束，但 **.so 已在该步骤之前
  完成链接**，属已知无害失败——判据是看到 `Linking CXX shared library` 已打印。

### 5.3 验证判据（hilog）
必须同时出现三条日志，`loaded=1` 才算 Qt 侧本地化成功：
```
system language=zh-Hans -> LANG=zh_CN.UTF-8
locale name=zh_CN lang=25 LANG=zh_CN.UTF-8
QTranslator qm=/data/storage/el2/base/haps/entry/files/translations/scidavis_zh-cn.qm loaded=1
```
加载语句必须打 `loaded=%{public}d` 日志，`loaded=0` 表示所有候选路径均未命中，
须回到 5.1 检查路径。

### 5.4 bindPopup / tooltip 文本的本地化
`bindPopup` 的 `message` 字段类型是 **`string` 而非 `ResourceStr`**，不能直接传
`$r(...)`。需经资源管理器同步解析为纯字符串（详见规范 11）：
```typescript
private tipText(name: string): string {
  try { return getContext(this).resourceManager.getStringByNameSync(name); }
  catch (e) { return ''; }
}
```
此类字符串同样纳入 base/en_US/zh_CN 三份 string.json 对齐管理。

