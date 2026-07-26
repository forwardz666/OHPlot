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
