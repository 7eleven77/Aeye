#!/usr/bin/env python3
"""Direct HTTPS vision API client for Gemini, Anthropic, xAI (Grok), and OpenAI.

Uses only the Python standard library so Aeye works on any Omarchy system
even when a vendor's CLI agent is not installed. Supports `--stream <out_file>`
to emit live `STEP\t` and `DELTA\t` chunks directly to the Aeye HUD in a single
network roundtrip (no extra tool-call turn needed to read the image).
"""

import base64
import json
import pathlib
import sys
import urllib.error
import urllib.request


TIMEOUT_SEC = 65
MAX_RESPONSE_BYTES = 2 * 1024 * 1024
MAX_TOKENS = 2048


def emit(kind: str, payload: str) -> None:
    sys.stdout.write(f"{kind}\t{payload}\n")
    sys.stdout.flush()


def _format_http_err(exc: urllib.error.HTTPError) -> str:
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
    return f"HTTP {exc.code}: {body.strip() or exc.reason}"[:220]


def post_json(url, headers, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as resp:
            raw = resp.read(MAX_RESPONSE_BYTES)
            return json.loads(raw.decode("utf-8", errors="replace"))
    except urllib.error.HTTPError as exc:
        sys.stderr.write(_format_http_err(exc) + "\n")
        sys.exit(1)
    except Exception as exc:
        sys.stderr.write(f"API request failed: {exc}\n")
        sys.exit(1)


def resolve_gemini_model(model: str) -> str:
    low = (model or "").strip().lower()
    if not low or low.startswith("gemini-3.8-flash"):
        return "gemini-2.5-flash"
    if low.startswith("gemini-4-") or low.startswith("gemini-pro-orchestrator"):
        return "gemini-2.5-pro"
    return model


def resolve_anthropic_model(model: str) -> str:
    low = (model or "").strip().lower()
    if low.startswith("claude-opus-5-5") or low == "claude-opus-4-6":
        return "claude-opus-4-20250514"
    if not low or low.startswith("claude-sonnet-5-5") or low == "claude-sonnet-4-6":
        return "claude-sonnet-4-20250514"
    return model


def resolve_xai_model(model: str) -> str:
    m = (model or "").strip()
    if not m or m == "grok-4.7-build-fast":
        return "grok-4.7"
    if m == "grok-4-1-fast-non-reasoning":
        return "grok-4.20-0309-non-reasoning"
    return m


def call_gemini(api_key, model, prompt, img_b64):
    api_model = resolve_gemini_model(model)
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
    api_model = resolve_anthropic_model(model)
    url = "https://api.anthropic.com/v1/messages"
    headers = {
        "Content-Type": "application/json",
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
    }
    payload = {
        "model": api_model,
        "max_tokens": MAX_TOKENS,
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


def call_openai_compat(url, api_key, api_model, prompt, img_b64, stream=False):
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
        "User-Agent": "aeye/2.5",
    }
    payload = {
        "model": api_model,
        "max_tokens": MAX_TOKENS,
        "stream": bool(stream),
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
    if not stream:
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

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    chunks: list[str] = []
    seen_text = False
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as resp:
            for raw_line in resp:
                line = raw_line.decode("utf-8", errors="replace").strip()
                if not line or not line.startswith("data:"):
                    continue
                body = line[5:].strip()
                if body == "[DONE]":
                    break
                try:
                    ev = json.loads(body)
                except json.JSONDecodeError:
                    continue
                choices = ev.get("choices") or []
                if not choices:
                    continue
                delta = choices[0].get("delta") or {}
                r_chunk = delta.get("reasoning_content")
                if isinstance(r_chunk, str) and r_chunk:
                    emit("THINK", json.dumps(r_chunk))
                t_chunk = delta.get("content")
                if isinstance(t_chunk, str) and t_chunk:
                    if not seen_text:
                        seen_text = True
                        emit("STEP", "Streaming response…")
                    chunks.append(t_chunk)
                    emit("DELTA", json.dumps(t_chunk))
    except urllib.error.HTTPError as exc:
        sys.stderr.write(_format_http_err(exc) + "\n")
        sys.exit(1)
    except Exception as exc:
        if not chunks:
            sys.stderr.write(f"API stream failed: {exc}\n")
            sys.exit(1)
    return "".join(chunks).strip()


def call_xai(api_key, model, prompt, img_b64, stream=False):
    api_model = resolve_xai_model(model)
    return call_openai_compat(
        "https://api.x.ai/v1/chat/completions", api_key, api_model, prompt, img_b64, stream=stream
    )


def call_openai(api_key, model, prompt, img_b64, stream=False):
    api_model = model or "gpt-4o-mini"
    if api_model.startswith("gpt-oss"):
        api_model = "gpt-4o"
    return call_openai_compat(
        "https://api.openai.com/v1/chat/completions", api_key, api_model, prompt, img_b64, stream=stream
    )


def main():
    args = sys.argv[1:]
    stream_out = ""
    if len(args) >= 2 and args[0] == "--stream":
        stream_out = args[1]
        args = args[2:]

    if len(args) < 5:
        sys.stderr.write("Usage: vision_api.py [--stream <out_file>] <vendor> <model> <image_path> <prompt_file> <key_file>\n")
        sys.exit(2)

    vendor = args[0].strip().lower()
    model = args[1].strip()
    image_path = pathlib.Path(args[2])
    prompt = pathlib.Path(args[3]).read_text(encoding="utf-8", errors="replace")
    api_key = pathlib.Path(args[4]).read_text(encoding="utf-8", errors="replace").strip()

    if not api_key:
        sys.stderr.write(f"Missing API key for {vendor}\n")
        sys.exit(1)

    img_b64 = base64.b64encode(image_path.read_bytes()).decode("ascii")
    is_stream = bool(stream_out)

    if vendor == "gemini":
        out = call_gemini(api_key, model, prompt, img_b64)
        if is_stream and out:
            emit("DELTA", json.dumps(out))
    elif vendor == "anthropic":
        out = call_anthropic(api_key, model, prompt, img_b64)
        if is_stream and out:
            emit("DELTA", json.dumps(out))
    elif vendor == "xai":
        out = call_xai(api_key, model, prompt, img_b64, stream=is_stream)
    elif vendor == "openai":
        out = call_openai(api_key, model, prompt, img_b64, stream=is_stream)
    else:
        sys.stderr.write(f"Unknown API vendor: {vendor}\n")
        sys.exit(1)

    if is_stream:
        pathlib.Path(stream_out).write_text(out or "", encoding="utf-8")
    elif out:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
