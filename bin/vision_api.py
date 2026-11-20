#!/usr/bin/env python3
"""Direct HTTPS vision API client for Gemini, Anthropic, xAI (Grok), and OpenAI.

Uses only the Python standard library so Aeye works on any Omarchy system
even when a vendor's CLI agent is not installed.
"""

import base64
import json
import pathlib
import sys
import urllib.error
import urllib.request


TIMEOUT_SEC = 65
MAX_RESPONSE_BYTES = 2 * 1024 * 1024


def post_json(url, headers, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as resp:
            raw = resp.read(MAX_RESPONSE_BYTES)
            return json.loads(raw.decode("utf-8", errors="replace"))
    except urllib.error.HTTPError as exc:
        body = ""
        try:
            body = exc.read(4096).decode("utf-8", errors="replace")
            parsed = json.loads(body)
            err = parsed.get("error")
            if isinstance(err, dict) and err.get("message"):
                body = str(err["message"])
            elif isinstance(err, str):
                body = err
        except Exception:
            pass
        msg = f"HTTP {exc.code}: {body.strip() or exc.reason}"
        sys.stderr.write(msg[:220] + "\n")
        sys.exit(1)
    except Exception as exc:
        sys.stderr.write(f"API request failed: {exc}\n")
        sys.exit(1)


def call_gemini(api_key, model, prompt, img_b64):
    # Map Antigravity CLI aliases to standard public Gemini API model IDs if needed
    model_map = {
        "gemini-3.8-flash-high": "gemini-2.5-flash",
        "gemini-4-argon-high": "gemini-2.5-pro",
    }
    api_model = model_map.get(model, model or "gemini-2.5-flash")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{api_model}:generateContent"
    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": api_key,
    }
    payload = {
        "contents": [
            {
                "parts": [
                    {"text": prompt},
                    {"inline_data": {"mime_type": "image/png", "data": img_b64}},
                ]
            }
        ]
    }
    res = post_json(url, headers, payload)
    candidates = res.get("candidates") or []
    for cand in candidates:
        parts = (cand.get("content") or {}).get("parts") or []
        texts = [p.get("text", "") for p in parts if isinstance(p, dict) and p.get("text")]
        if texts:
            return "\n".join(texts).strip()
    return ""


def call_anthropic(api_key, model, prompt, img_b64):
    model_map = {
        "claude-sonnet-5-5-medium": "claude-sonnet-4-20250514",
    }
    api_model = model_map.get(model, model or "claude-sonnet-4-20250514")
    url = "https://api.anthropic.com/v1/messages"
    headers = {
        "Content-Type": "application/json",
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
    }
    payload = {
        "model": api_model,
        "max_tokens": 600,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/png",
                            "data": img_b64,
                        },
                    },
                    {"type": "text", "text": prompt},
                ],
            }
        ],
    }
    res = post_json(url, headers, payload)
    blocks = res.get("content") or []
    texts = [b.get("text", "") for b in blocks if isinstance(b, dict) and b.get("type") == "text"]
    return "\n".join(texts).strip()


def call_openai_compat(url, api_key, api_model, prompt, img_b64):
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    }
    payload = {
        "model": api_model,
        "max_tokens": 600,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/png;base64,{img_b64}"},
                    },
                ],
            }
        ],
    }
    res = post_json(url, headers, payload)
    choices = res.get("choices") or []
    if choices:
        msg = choices[0].get("message") or {}
        content = msg.get("content")
        if isinstance(content, str):
            return content.strip()
        if isinstance(content, list):
            texts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("text")]
            return "\n".join(texts).strip()
    return ""


def call_xai(api_key, model, prompt, img_b64):
    model_map = {
        "grok-4.7": "grok-2-vision-latest",
    }
    api_model = model_map.get(model, model or "grok-2-vision-latest")
    return call_openai_compat(
        "https://api.x.ai/v1/chat/completions", api_key, api_model, prompt, img_b64
    )


def call_openai(api_key, model, prompt, img_b64):
    api_model = model or "gpt-4o-mini"
    return call_openai_compat(
        "https://api.openai.com/v1/chat/completions", api_key, api_model, prompt, img_b64
    )


def main():
    if len(sys.argv) < 6:
        sys.stderr.write("Usage: vision_api.py <vendor> <model> <image_path> <prompt_file> <key_file>\n")
        sys.exit(2)

    vendor = sys.argv[1].strip().lower()
    model = sys.argv[2].strip()
    image_path = pathlib.Path(sys.argv[3])
    prompt = pathlib.Path(sys.argv[4]).read_text(encoding="utf-8", errors="replace")
    api_key = pathlib.Path(sys.argv[5]).read_text(encoding="utf-8", errors="replace").strip()

    if not api_key:
        sys.stderr.write(f"Missing API key for {vendor}\n")
        sys.exit(1)

    img_b64 = base64.b64encode(image_path.read_bytes()).decode("ascii")

    if vendor == "gemini":
        out = call_gemini(api_key, model, prompt, img_b64)
    elif vendor == "anthropic":
        out = call_anthropic(api_key, model, prompt, img_b64)
    elif vendor == "xai":
        out = call_xai(api_key, model, prompt, img_b64)
    elif vendor == "openai":
        out = call_openai(api_key, model, prompt, img_b64)
    else:
        sys.stderr.write(f"Unknown API vendor: {vendor}\n")
        sys.exit(1)

    if out:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
