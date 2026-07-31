---
name: vision-recognize
description: Recognize and understand image content (not OCR) using a local llama.cpp vision model, returning full Markdown text. Use when the user provides an image file path, asks to recognize/describe/understand image content, or needs image content converted to Markdown. Supports screenshots, photos, charts, UI captures, and documents.
---

# Vision Recognize (本地视觉模型图像识别)

调用本地 llama.cpp 视觉模型（Qwen3.6-35B-A3B-UD-Q4_K_M）识别图片内容，返回 Markdown 文本供会话后续使用。

## 前置条件

1. **本地 llama.cpp server 已启动**，监听 `http://127.0.0.1:8080`（OpenAI 兼容 API）。
2. **Python venv**：统一使用 `C:\Users\Forwardz\.qoder\venv\Scripts\python.exe`。
   若 venv 不存在，先执行：

```powershell
python -m venv C:\Users\Forwardz\.qoder\venv
C:\Users\Forwardz\.qoder\venv\Scripts\python.exe -m pip install pillow requests
```

## 使用方法

**默认识图**（使用内置提示词"识别图片里所有信息，使用 markdown 输出全部内容，并保持排版的一致"）：

```powershell
C:\Users\Forwardz\.qoder\venv\Scripts\python.exe C:\Users\Forwardz\.qoder\skills\vision-recognize\scripts\recognize.py "<图片绝对路径>"
```

**自定义提示词**：

```powershell
C:\Users\Forwardz\.qoder\venv\Scripts\python.exe C:\Users\Forwardz\.qoder\skills\vision-recognize\scripts\recognize.py "<图片绝对路径>" --prompt "描述这张图中的错误信息"
```

**覆盖 API 地址或模型名**（可选）：

```powershell
... recognize.py "<图片路径>" --api-base http://127.0.0.1:8080 --model Qwen3.6-35B-A3B-UD-Q4_K_M
```

## 脚本行为

`scripts/recognize.py` 自动完成：
1. 图片缩放到最长边 ≤ 1280 px（等比缩放，小图不放大），转 JPEG + Base64；
2. 以 OpenAI 兼容格式（`image_url` data URI）POST 到 `/v1/chat/completions`；
3. 将返回的 Markdown 文本打印到 stdout。

读取 stdout 即可获得识别结果，直接用于会话后续操作。

## 错误处理

| 现象 | 处理 |
|------|------|
| `[ERROR] API connection failed` | llama.cpp server 未启动，提示用户先启动 llama-server |
| `[ERROR] API timeout` | 大图/模型加载中，可重试；默认超时 300 秒 |
| `[ERROR] Image file not found` | 检查图片路径是否正确（需绝对路径） |
| `ModuleNotFoundError` | venv 依赖缺失，重新执行 pip install pillow requests |

## 注意事项

- 这是**图像识别/理解**（描述场景、图表、UI、排版结构），不是单纯 OCR。
- 支持格式：jpg / jpeg / png / webp / bmp / gif（取首帧）。
- 输出为 UTF-8，PowerShell 中若出现乱码，先执行 `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`。
