# -*- coding: utf-8 -*-
"""Vision recognition via local llama.cpp OpenAI-compatible API.

Resizes the image (longest side <= 1280 px), sends it with a prompt to the
local vision model, and prints the returned Markdown text to stdout.

Usage:
    python recognize.py <image_path> [--prompt "..."] [--api-base URL] [--model NAME]
"""
import argparse
import base64
import io
import sys

# ── Defaults (edit here if your local setup changes) ─────────────────────────
DEFAULT_API_BASE = "http://127.0.0.1:8080"
DEFAULT_MODEL = "Qwen3.6-35B-A3B-UD-Q4_K_M"
DEFAULT_PROMPT = "识别图片里所有信息，使用 markdown 输出全部内容，并保持排版的一致"
MAX_SIDE = 1280
TIMEOUT_SECONDS = 300


def die(msg: str) -> None:
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(1)


def load_and_resize(image_path: str) -> bytes:
    """Load image, downscale so longest side <= MAX_SIDE, return JPEG bytes."""
    try:
        from PIL import Image
    except ImportError:
        die("Pillow not installed. Run: "
            r"C:\Users\Forwardz\.qoder\venv\Scripts\python.exe -m pip install pillow requests")

    try:
        img = Image.open(image_path)
    except FileNotFoundError:
        die(f"Image file not found: {image_path}")
    except Exception as e:  # noqa: BLE001 - report any decode failure
        die(f"Cannot open image: {e}")

    # Animated formats: take the first frame.
    if getattr(img, "is_animated", False):
        img.seek(0)

    # JPEG has no alpha channel; flatten transparency onto white.
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGBA")
        background = Image.new("RGB", img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[-1])
        img = background
    elif img.mode != "RGB":
        img = img.convert("RGB")

    w, h = img.size
    longest = max(w, h)
    if longest > MAX_SIDE:
        scale = MAX_SIDE / longest
        img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


def call_vision_api(api_base: str, model: str, prompt: str, jpeg_bytes: bytes) -> str:
    try:
        import requests
    except ImportError:
        die("requests not installed. Run: "
            r"C:\Users\Forwardz\.qoder\venv\Scripts\python.exe -m pip install pillow requests")

    b64 = base64.b64encode(jpeg_bytes).decode("ascii")
    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url",
                     "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
                ],
            }
        ],
        "temperature": 0.2,
    }

    url = api_base.rstrip("/") + "/v1/chat/completions"
    try:
        resp = requests.post(url, json=payload, timeout=TIMEOUT_SECONDS)
    except requests.exceptions.ConnectionError:
        die(f"API connection failed: {url} — is the llama.cpp server running?")
    except requests.exceptions.Timeout:
        die(f"API timeout after {TIMEOUT_SECONDS}s — model may still be loading; retry later.")

    if resp.status_code != 200:
        die(f"API returned HTTP {resp.status_code}: {resp.text[:500]}")

    try:
        data = resp.json()
        return data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, ValueError) as e:
        die(f"Unexpected API response format: {e} — body: {resp.text[:500]}")
    return ""  # unreachable


def main() -> None:
    parser = argparse.ArgumentParser(description="Local vision model image recognition")
    parser.add_argument("image", help="Absolute path to the image file")
    parser.add_argument("--prompt", default=DEFAULT_PROMPT, help="Custom prompt text")
    parser.add_argument("--api-base", default=DEFAULT_API_BASE, help="API base URL")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model name")
    args = parser.parse_args()

    # Force UTF-8 stdout so Chinese Markdown is not mangled on Windows consoles.
    if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
        sys.stdout.reconfigure(encoding="utf-8")

    jpeg_bytes = load_and_resize(args.image)
    markdown = call_vision_api(args.api_base, args.model, args.prompt, jpeg_bytes)
    print(markdown)


if __name__ == "__main__":
    main()
