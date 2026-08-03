# DevEco Code 模型配置与视觉代理路由规范

本规范沉淀 2026-08-03 会话中关于 DevEco Code（opencode 内核）**provider/模型配置、视觉子代理（mini-vision / multimodal-looker / visual-engineering）模型路由**的全部排查经验与最终结论。

> 状态：✅ 已在本机端到端验证通过（图片识别实测），文中所有命令可直接复用。
> 适用环境：Windows + DevEco Studio 内置 `deveco` CLI，配置文件位于 `~/.config/deveco/` 与 `~/.omo/`。

---

## 1. 核心机制：模型列表从哪来（为什么"没配置却看到很多模型"）

**结论：模型选择器/CLI 中看到的模型，主要来自 models.dev 全局目录，而不是你的配置文件。**

1. DevEco Code（opencode 内核）每次启动会从 `https://models.dev/api.json` 拉取模型目录，缓存到 `~/.cache/deveco/models.json`（约 178 个 provider）。
2. `provider.<id>.models` 字段只做**叠加/覆盖**，不会裁剪目录里的模型。
3. **真正控制"显示哪些模型"的是 `whitelist`（只留这些）和 `blacklist`（排除这些）**。

### 1.1 验证命令（不启动 GUI 的安全检查）

```powershell
deveco models                # 列出所有可用模型
deveco models <provider>     # 列出指定 provider 的模型，如 deveco models alibaba
deveco providers list        # 查看 auth.json 中已连接的凭证（含 provider 显示名与类型）
```

`deveco models` / `deveco providers list` 会完整执行"配置加载 + schema 校验"流程——**配置有错会直接报错（exit 1），不会启动 GUI**。这是修改配置前后最可靠的安全验证手段，比重启 DevEco Code 快得多。

### 1.2 临时注入验证（零风险测试配置，不动真实文件）

```powershell
$env:DEVECO_CONFIG_CONTENT = '{"provider":{"alibaba":{"whitelist":["qwen3.6-plus","qwen3.5-35b-a3b"]}}}'
deveco models alibaba   # 验证注入效果
Remove-Item Env:\DEVECO_CONFIG_CONTENT
```

`DEVECO_CONFIG_CONTENT` 作为最终 local 作用域 merge 注入，改配置前先用它验证目标写法是否合法，可避免改坏真实配置。

---

## 2. Provider 名称一致性（本次最大的坑）

**硬约束：config 中自定义 provider 的名字，必须与 auth.json 中的凭证 ID 一致，否则模型路由失效。**

### 2.1 现象
配置里把 provider 命名为 `aliyun`（自建，`api: openai` + 私有 baseURL），但：
- auth.json 凭证 ID 是 `alibaba`（models.dev 内置 provider 名）
- oh-my-openagent 插件通过 `client.provider.list()` 拿到 `connectedProviders` 列表，其中只有 `alibaba`，**没有 `aliyun`**
- 插件判断 `connectedProviders.includes("aliyun")` 永远为 false → 认为该模型不可用 → **静默 fallback 到其他 provider**

### 2.2 排查证据链
1. subagent 派发时警告：`⚠️ Model routing: ... used sensenova/sensenova-6.7-flash-lite (via category: unknown)` —— 说明实际用的是 fallback 而非目标模型。
2. 日志确认：`stream providerID=sensenova modelID=sensenova-6.7-flash-lite agent=mini-vision`。
3. `deveco providers list` 显示已连接凭证：deveco / LongCat / OpenCode Go / **Alibaba** —— 证实 ID 是 `alibaba` 而非 `aliyun`。

### 2.3 正确做法
把配置中的 provider 名、所有模型引用统一改为与凭证一致的 `alibaba`：
```jsonc
"provider": {
  "alibaba": {
    "api": "openai",
    "whitelist": ["qwen3.6-plus", "qwen3.5-35b-a3b"],
    "options": {
      "baseURL": "https://...maas.aliyuncs.com/compatible-mode/v1",
      "apiKey": "sk-..."
    },
    "models": { ... }
  }
}
```
修复后日志变为：`stream providerID=alibaba modelID=qwen3.5-35b-a3b agent=mini-vision` ✅

---

## 3. 配置文件的多源 merge（只改一个文件不够）

DevEco Code 的配置是 **deep-merge** 的，多个位置都会加载并合并：

| 配置源 | 路径 | 优先级 |
|--------|------|--------|
| 全局配置 | `~/.config/deveco/deveco.json` / `deveco.jsonc` | 低 → 高（后加载覆盖） |
| oh-my-openagent 插件配置 | `~/.config/deveco/oh-my-openagent.json` | 覆盖角色/category 模型 |
| OMO 插件配置 | `~/.omo/omo.jsonc`（`[opencode]` 块内） | 同样会覆盖角色/category 模型 |
| 项目级配置 | `<项目>/.deveco/deveco.jsonc` | 局部 |

**经验：修改视觉代理模型时，必须同步检查全部 5 个位置**（`deveco.jsonc`、`deveco.json`、`oh-my-openagent.json`、`agents/mini-vision.md`、`~/.omo/omo.jsonc`），否则 merge 后旧值残留，表现为"改了没用"。

`~/.omo/omo.jsonc` 是 JSONC 格式（可含 `//` 注释），`background_task`、角色模型等必须嵌套在 `[opencode]` harness 块内（09 号规范 3.4 已记录：`~/.config/opencode/oh-my-openagent.json` 不在插件配置发现路径内，写入无效）。

---

## 4. 三个视觉角色与它们的模型配置位置

| 角色 | 类型 | 模型配置位置 |
|------|------|--------------|
| `mini-vision` | subagent | `deveco.jsonc` agent 段 + `oh-my-openagent.json` agents + `agents/mini-vision.md` frontmatter |
| `multimodal-looker` | subagent | `deveco.jsonc` / `deveco.json` agent 段 + `oh-my-openagent.json` agents + `~/.omo/omo.jsonc` |
| `visual-engineering` | **category 路由**（非 subagent） | `oh-my-openagent.json` categories + `~/.omo/omo.jsonc` categories |

**关键区别**：`visual-engineering` 是 category 不是 subagent type，不能用 `task(subagent_type="visual-engineering")` 派发，只能通过 `task(category="visual-engineering", ...)` 触发（会创建 Sisyphus-Junior 实例并按 category 路由模型）。

### 4.1 subagent 派发验证方法
```typescript
task(subagent_type="mini-vision", prompt="分析图片 C:\\...\\cywl.jpg ...")
task(subagent_type="multimodal-looker", prompt="...")
task(category="visual-engineering", prompt="...")
```
派发结果中的路由警告会直接说明实际使用的模型：
- `used sensenova/sensenova-6.7-flash-lite` = fallback，目标模型未生效 ❌
- `used alibaba/qwen3.5-35b-a3b` = 目标模型生效 ✅

---

## 5. 视觉多模态模型配置要点

### 5.1 limit 字段（schema 强制要求）
opencode 的模型 `limit` 对象 **`context` 和 `output` 必填**（schema: `required: [context, output]`），只写 `input`+`output` 会导致配置校验失败、DevEco Code 无法启动：

```
Configuration is invalid at ...deveco.jsonc
↳ Missing key provider.alibaba.models.qwen3.6-plus.limit.context
```

正确写法（2026-08-03 实测值，K = 1000 单位）：
```jsonc
"qwen3.6-plus": {
  "limit": { "context": 991000, "input": 991000, "output": 65536 }
},
"qwen3.5-35b-a3b": {
  "limit": { "context": 254000, "input": 254000, "output": 65536 }
}
```

### 5.2 多模态能力声明
视觉模型需要声明 `attachment: true` 和 modalities，subagent 才能用 `Read` 工具读取图片 + 模型多模态分析：
```jsonc
"qwen3.5-35b-a3b": {
  "attachment": true,
  "modalities": { "input": ["text", "image", "video", "audio"], "output": ["text"] }
}
```

### 5.3 模型 ID 与服务端对照
配置的模型 ID 必须以服务端 `/models` 接口返回为准（如 `qwen3.5-35b-a3b`），注意区分相似 ID：服务端同时存在 `qwen3.5-35b-a3b` 与 `qwen3.6-35b-a3b`，是两个不同的模型。修改前用 API 实测确认目标 ID 与调用均正常。

---

## 6. API Key 管理与验证

1. **更换 key 后先实测再改配置**：用 `Invoke-RestMethod` 直接调用 `{baseURL}/models` 和 `{baseURL}/chat/completions`，确认新 key 有效、目标模型可调用（含图片输入），再改配置文件。
2. **旧 key 失效会导致 subagent 报 `Invalid API-key provided`**，且**当前运行中的进程不会热加载新配置**——所有配置修改必须重启 DevEco Code 才生效（09 号规范 3.4 同理）。
3. **残留旧 key 的坑**：`deveco.json` 与 `deveco.jsonc` 都可能有 aliyun 定义（旧 key + 旧模型），deep-merge 后旧 key 会污染。清理时两个文件都要处理。

---

## 7. 排查 checklist（模型路由不生效时按序执行）

1. **确认配置语法**：`node` 解析 JSONC（去注释后 `JSON.parse`），或直接 `deveco models <provider>` 看是否报 schema 错误。
2. **确认 provider 名称与凭证一致**：`deveco providers list` 对照 config 中 provider 名。
3. **确认没有 `disabled_providers` 误伤**：`"disabled_providers": ["alibaba"]` 会令 CLI 报 `Provider not found`，插件同样视为不可用。
4. **确认所有配置源已同步**：5 个文件逐一检查（见第 3 节），尤其 `~/.omo/omo.jsonc`。
5. **重启后派发实测**：subagent 路由警告显示 `used <provider>/<model>` 即为最终生效值；再用日志 `stream providerID=... modelID=...` 二次确认。
6. **API 实测**：绕过 DevEco Code，用新 key 直接调 chat/completions（含图片 base64），区分"配置问题"与"服务端问题"。

---

## 8. 最终生效配置快照（2026-08-03）

- 视觉模型统一：`alibaba/qwen3.5-35b-a3b`（多模态，254K 输入 / 64K 输出，实测识别图片正常）
- 备用模型：`alibaba/qwen3.6-plus`（991K 输入 / 64K 输出）保留在 provider models 中
- 主模型：`opencode-go/deepseek-v4-flash`；`deepseek/deepseek-v4-flash` 等不参与视觉
- `alibaba` provider：`whitelist: ["qwen3.6-plus", "qwen3.5-35b-a3b"]`，无 `disabled_providers`
- 视觉 fallback：`sensenova/sensenova-6.7-flash-lite`

### 本机验证记录（2026-08-03）

| # | 验证项 | 结果 |
|---|--------|------|
| 1 | `deveco models alibaba` | ✅ 仅 `qwen3.5-35b-a3b` + `qwen3.6-plus` |
| 2 | `deveco models deepseek / opencode-go` | ✅ 正常 |
| 3 | alibaba key 实测 chat/completions | ✅ 新 key 有效 |
| 4 | qwen3.5-35b-a3b 图片识别（cywl.jpg 初音未来） | ✅ 准确识别人物/发型/服饰/姿势 |
| 5 | mini-vision subagent 派发 | ✅ `used alibaba/qwen3.5-35b-a3b` |
| 6 | multimodal-looker subagent 派发 | ✅ `used alibaba/qwen3.5-35b-a3b` |
| 7 | visual-engineering category 派发 | ✅ `used alibaba/qwen3.5-35b-a3b` |
| 8 | 日志 stream 记录 | ✅ `providerID=alibaba modelID=qwen3.5-35b-a3b` |
