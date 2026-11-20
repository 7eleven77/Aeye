#!/usr/bin/env python3
"""Stream NDJSON output from agy or grok into live Aeye IPC lines + final raw file.

Emits tab-separated lines to stdout (flushed immediately):
  STEP\t<short progress status>
  DELTA\t<json string chunk>

Writes the complete extracted response text to <out_file> at EOF.
"""

import json
import os
import sys


def emit(kind, payload):
    sys.stdout.write(f"{kind}\t{payload}\n")
    sys.stdout.flush()


def handle_agy(out_path):
    chunks = []
    final_response = ""
    raw_lines = []

    for line in sys.stdin:
        s = line.strip()
        if not s:
            continue
        raw_lines.append(s)
        try:
            ev = json.loads(s)
        except json.JSONDecodeError:
            # Plain text fallback if agy emitted non-JSON
            chunks.append(line)
            emit("DELTA", json.dumps(line))
            continue

        etype = ev.get("event", "")
        if etype == "init":
            model = (ev.get("init") or {}).get("model", "")
            emit("STEP", f"Connected to {model}" if model else "Model initialized")
        elif etype == "step_update":
            su = ev.get("step_update") or {}
            stype = su.get("step_type", "")
            state = su.get("state", "")
            usage = su.get("usage") or {}
            think_tok = usage.get("thinking_tokens", 0) or 0

            if stype == "tool":
                tname = su.get("tool_name", "tool")
                dur = su.get("duration_seconds")
                if state == "ACTIVE":
                    if tname in ("read_file", "view_file"):
                        emit("STEP", "Inspecting screenshot pixels…")
                    else:
                        emit("STEP", f"Running {tname}…")
                elif state == "DONE":
                    if tname in ("read_file", "view_file"):
                        dtxt = f" ({dur:.1f}s)" if isinstance(dur, (int, float)) else ""
                        emit("STEP", f"Screenshot loaded{dtxt} — reasoning…")
            elif stype == "agent_response":
                delta = su.get("text_delta")
                thinking_delta = su.get("thinking_delta") or su.get("reasoning_delta")
                if isinstance(thinking_delta, str) and thinking_delta:
                    emit("THINK", json.dumps(thinking_delta))
                if isinstance(delta, str) and delta:
                    chunks.append(delta)
                    emit("DELTA", json.dumps(delta))
                elif state == "DONE" and think_tok > 0 and not chunks:
                    emit("STEP", f"Visual analysis ({think_tok} thinking tokens)…")
        elif etype == "result":
            res = ev.get("result") or {}
            resp = res.get("response")
            if isinstance(resp, str) and resp.strip():
                final_response = resp.strip()

    text = final_response or "".join(chunks).strip()
    if not text and raw_lines:
        # Fallback if unexpected format
        text = "\n".join(raw_lines).strip()
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(text)


def handle_grok(out_path):
    chunks = []
    raw_lines = []
    seen_text = False

    for line in sys.stdin:
        s = line.strip()
        if not s:
            continue
        raw_lines.append(s)
        try:
            ev = json.loads(s)
        except json.JSONDecodeError:
            continue

        etype = ev.get("type", "")
        if etype == "text":
            data = ev.get("data", "")
            if isinstance(data, str) and data:
                if not seen_text:
                    seen_text = True
                    emit("STEP", "Streaming response…")
                chunks.append(data)
                emit("DELTA", json.dumps(data))
        elif etype in ("thinking", "reasoning"):
            data = ev.get("data", "")
            if isinstance(data, str) and data:
                emit("THINK", json.dumps(data))
        elif etype == "tool_call":
            tname = ev.get("name", "read_file")
            if tname == "read_file":
                emit("STEP", "Inspecting screenshot pixels…")
            else:
                emit("STEP", f"Running {tname}…")
        elif etype == "usage":
            rtok = ((ev.get("usage") or {}).get("reasoning_tokens") or 0)
            if rtok > 0 and not seen_text:
                emit("STEP", f"Visual reasoning ({rtok} tokens)…")
        elif etype == "end":
            res = ev.get("result")
            if isinstance(res, str) and res.strip() and not chunks:
                chunks.append(res.strip())

    text = "".join(chunks).strip()
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    if len(sys.argv) < 3:
        sys.exit(2)
    provider = sys.argv[1]
    out_path = sys.argv[2]
    if provider == "agy":
        handle_agy(out_path)
    elif provider == "grok":
        handle_grok(out_path)
    else:
        data = sys.stdin.read().strip()
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(data)


if __name__ == "__main__":
    main()
