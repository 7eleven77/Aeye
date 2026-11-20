#!/usr/bin/env python3
"""Pull the model's answer out of a provider's stdout."""

import json
import pathlib
import sys


def grok_text(data):
    if isinstance(data, str):
        return data.strip()
    if not isinstance(data, dict):
        return ""
    result = data.get("result")
    if isinstance(result, str) and result.strip():
        return result.strip()
    if isinstance(result, dict):
        nested = grok_text(result)
        if nested:
            return nested
    for key in ("response", "text", "message", "output"):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def main():
    provider = sys.argv[1]
    raw = pathlib.Path(sys.argv[2]).read_text(errors="replace").strip()
    if not raw:
        return
    if provider == "grok":
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            start = raw.find("{")
            end = raw.rfind("}")
            parsed = None
            if start >= 0 and end > start:
                try:
                    parsed = json.loads(raw[start : end + 1])
                except json.JSONDecodeError:
                    parsed = None
        text = grok_text(parsed) if parsed is not None else ""
        sys.stdout.write(text or raw)
        return
    sys.stdout.write(raw)


if __name__ == "__main__":
    main()
