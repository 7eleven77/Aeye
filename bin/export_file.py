#!/usr/bin/env python3
"""Aeye universal zero-dependency file exporter (.txt, .md, .pdf, .html, .json, or any extension)."""

from __future__ import annotations

import datetime
import html
import json
import os
import re
import sys
import tempfile
import textwrap
from pathlib import Path

FORBIDDEN_ROOTS = (
    "/etc",
    "/usr",
    "/boot",
    "/sys",
    "/proc",
    "/dev",
    "/bin",
    "/sbin",
    "/lib",
    "/lib64",
    "/root",
    "/var/lib",
)

UNICODE_REPLACEMENTS = {
    "\u2014": "--",   # em dash
    "\u2013": "-",    # en dash
    "\u2212": "-",    # minus sign
    "\u2022": "*",    # bullet
    "\u25cf": "*",    # black circle
    "\u25aa": "*",    # small square
    "\u2192": "->",   # right arrow
    "\u2190": "<-",   # left arrow
    "\u2194": "<->",  # left-right arrow
    "\u21d2": "=>",   # double right arrow
    "\u2197": "->",   # NE arrow
    "\u2234": "*",    # therefore (visual reasoning)
    "\u2726": "*",    # 4-point star
    "\u2605": "*",    # star
    "\u2713": "[ok]", # check mark
    "\u2714": "[ok]",
    "\u2715": "[x]",  # multiplication x
    "\u2717": "[x]",
    "\u26a0": "[!]",  # warning
    "\u201c": '"',    # left double quote
    "\u201d": '"',    # right double quote
    "\u2018": "'",    # left single quote
    "\u2019": "'",    # right single quote
    "\u2026": "...",  # ellipsis
    "\u00a0": " ",    # nbsp
    "\u200b": "",     # zero-width space
    "\ufeff": "",     # BOM
    "\t": "    ",
}


def resolve_target_path(raw_path: str) -> Path:
    cleaned = raw_path.strip()
    if not cleaned:
        raise ValueError("Destination path is empty")
    if "\x00" in cleaned:
        raise ValueError("Invalid path")

    home = Path.home()
    if cleaned == "~":
        raise ValueError("Destination must be a file path, not a directory")
    if cleaned.startswith("~/"):
        target = home / cleaned[2:]
    elif cleaned.startswith("./"):
        target = home / cleaned[2:]
    elif cleaned.startswith("/"):
        target = Path(cleaned)
    else:
        target = home / cleaned

    if cleaned.endswith("/") or (target.exists() and target.is_dir()):
        stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S")
        target = target / f"aeye-{stamp}.txt"

    resolved = target.expanduser().resolve(strict=False)
    res_str = str(resolved)
    for root in FORBIDDEN_ROOTS:
        if res_str == root or res_str.startswith(root + "/"):
            raise ValueError(f"Refusing to write inside protected system path: {root}")
    return resolved


def strip_inline_md(text: str) -> str:
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"__([^_]+)__", r"\1", text)
    text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"\1", text)
    return text


def parse_blocks(md_text: str) -> list[dict]:
    lines = md_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    blocks: list[dict] = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        m_fence = re.match(r"^\s*```([A-Za-z0-9_+#.\-]*)\s*$", line)
        if m_fence:
            lang = m_fence.group(1) or ""
            code_lines: list[str] = []
            i += 1
            while i < n and not re.match(r"^\s*```\s*$", lines[i]):
                code_lines.append(lines[i])
                i += 1
            if i < n:
                i += 1
            blocks.append({"kind": "code", "lang": lang, "text": "\n".join(code_lines)})
            continue

        if not line.strip():
            i += 1
            continue

        m_head = re.match(r"^\s*(#{1,6})\s+(.+)$", line)
        if m_head:
            blocks.append({"kind": "heading", "level": len(m_head.group(1)), "text": m_head.group(2).strip()})
            i += 1
            continue

        m_bullet = re.match(r"^\s*(?:[-*+]|(\d+)[.)])\s+(.+)$", line)
        if m_bullet:
            marker = f"{m_bullet.group(1)}." if m_bullet.group(1) else "*"
            blocks.append({"kind": "bullet", "marker": marker, "text": m_bullet.group(2).strip()})
            i += 1
            continue

        para = [line.strip()]
        i += 1
        while i < n:
            nxt = lines[i]
            if not nxt.strip():
                break
            if (
                re.match(r"^\s*```", nxt)
                or re.match(r"^\s*#{1,6}\s+", nxt)
                or re.match(r"^\s*(?:[-*+]|\d+[.)])\s+", nxt)
            ):
                break
            para.append(nxt.strip())
            i += 1
        blocks.append({"kind": "paragraph", "text": " ".join(para)})
    return blocks


def sanitize_pdf_text(text: str) -> bytes:
    out = text
    for src, dst in UNICODE_REPLACEMENTS.items():
        if src in out:
            out = out.replace(src, dst)
    # Remove any remaining control chars except newline
    out = re.sub(r"[\x00-\x08\x0b-\x1f\x7f]", "", out)
    raw = out.encode("cp1252", errors="replace")
    # Escape PDF literal string delimiters
    escaped = bytearray()
    for b in raw:
        if b in (0x5C, 0x28, 0x29):  # \ ( )
            escaped.append(0x5C)
        escaped.append(b)
    return bytes(escaped)


def render_pdf(payload: dict) -> bytes:
    """Pure-Python stdlib A4 PDF 1.4 generator with WinAnsiEncoding & multi-page support."""
    page_w = 595.0
    page_h = 842.0
    margin_x = 50.0
    margin_top = 56.0
    margin_bottom = 52.0

    model = str(payload.get("model") or "Aeye").strip()
    timestamp = str(payload.get("timestamp") or datetime.datetime.now().strftime("%Y-%m-%d %H:%M")).strip()
    prompt = str(payload.get("prompt") or "").strip()
    reasoning = str(payload.get("reasoning") or "").strip()
    answer = str(payload.get("answer") or "").strip()

    # Build drawing commands per page: list of (page_commands_bytes_list)
    pages: list[list[bytes]] = [[]]
    y = page_h - margin_top

    def ensure_space(needed: float) -> None:
        nonlocal y
        if y - needed < margin_bottom:
            pages.append([])
            y = page_h - margin_top

    def draw_text(x: float, baseline_y: float, font_key: str, size: float, text: str, rgb: tuple[float, float, float]) -> None:
        r, g, b = rgb
        enc = sanitize_pdf_text(text)
        cmd = (
            f"BT /{font_key} {size:.1f} Tf {r:.3f} {g:.3f} {b:.3f} rg "
            f"1 0 0 1 {x:.2f} {baseline_y:.2f} Tm ("
        ).encode("ascii") + enc + b") Tj ET"
        pages[-1].append(cmd)

    def draw_rule(y_pos: float, rgb: tuple[float, float, float] = (0.82, 0.84, 0.88)) -> None:
        r, g, b = rgb
        pages[-1].append(
            f"q {r:.3f} {g:.3f} {b:.3f} RG 0.7 w {margin_x:.2f} {y_pos:.2f} m {page_w - margin_x:.2f} {y_pos:.2f} l S Q".encode("ascii")
        )

    def draw_rect(x: float, y_bottom: float, w: float, h: float, fill_rgb: tuple[float, float, float], stroke_rgb: tuple[float, float, float]) -> None:
        fr, fg, fb = fill_rgb
        sr, sg, sb = stroke_rgb
        pages[-1].append(
            f"q {fr:.3f} {fg:.3f} {fb:.3f} rg {sr:.3f} {sg:.3f} {sb:.3f} RG 0.5 w "
            f"{x:.2f} {y_bottom:.2f} {w:.2f} {h:.2f} re B Q".encode("ascii")
        )

    # Header
    draw_text(margin_x, y, "F2", 16.0, "Aeye", (0.10, 0.14, 0.22))
    meta = f"{model}  |  {timestamp}"
    draw_text(margin_x + 56.0, y + 1.5, "F1", 9.5, meta, (0.40, 0.44, 0.52))
    y -= 14.0
    draw_rule(y)
    y -= 18.0

    if prompt:
        for idx, line in enumerate(textwrap.wrap(f"Prompt: {prompt}", width=84) or [prompt]):
            ensure_space(14.0)
            draw_text(margin_x, y, "F2" if idx == 0 else "F1", 9.5, line, (0.28, 0.33, 0.42))
            y -= 13.5
        y -= 6.0

    if reasoning:
        ensure_space(22.0)
        draw_text(margin_x, y, "F2", 10.5, "Visual Reasoning", (0.18, 0.36, 0.62))
        y -= 14.5
        for raw_line in reasoning.splitlines():
            wrapped = textwrap.wrap(strip_inline_md(raw_line), width=86) or [""]
            for wl in wrapped:
                ensure_space(13.5)
                draw_text(margin_x + 8.0, y, "F1", 9.5, wl, (0.34, 0.38, 0.46))
                y -= 13.0
        y -= 8.0
        draw_rule(y + 2.0, (0.88, 0.90, 0.93))
        y -= 12.0

    blocks = parse_blocks(answer)
    if not blocks and answer:
        blocks = [{"kind": "paragraph", "text": answer}]

    for blk in blocks:
        kind = blk["kind"]
        if kind == "heading":
            size = 13.0 if blk.get("level", 2) <= 2 else 11.5
            wrapped = textwrap.wrap(strip_inline_md(blk["text"]), width=72) or [""]
            ensure_space(len(wrapped) * (size + 4.0) + 8.0)
            y -= 4.0
            for wl in wrapped:
                draw_text(margin_x, y, "F2", size, wl, (0.10, 0.16, 0.28))
                y -= size + 4.0
            y -= 2.0
        elif kind == "bullet":
            marker = blk.get("marker", "*")
            wrapped = textwrap.wrap(strip_inline_md(blk["text"]), width=78) or [""]
            for idx, wl in enumerate(wrapped):
                ensure_space(15.0)
                if idx == 0:
                    draw_text(margin_x + 6.0, y, "F2", 10.5, marker, (0.18, 0.36, 0.62))
                draw_text(margin_x + 22.0, y, "F1", 10.5, wl, (0.12, 0.14, 0.18))
                y -= 14.5
            y -= 2.5
        elif kind == "code":
            code_lines: list[str] = []
            for cl in blk["text"].splitlines():
                if not cl:
                    code_lines.append("")
                else:
                    code_lines.extend(textwrap.wrap(cl, width=78, replace_whitespace=False, drop_whitespace=False) or [cl])
            if not code_lines:
                code_lines = [""]
            lang = blk.get("lang", "").upper()
            chunk_idx = 0
            while chunk_idx < len(code_lines):
                avail_lines = max(1, int((y - margin_bottom - 18.0) // 12.5))
                if avail_lines < 2 and y < page_h - margin_top - 40.0:
                    pages.append([])
                    y = page_h - margin_top
                    avail_lines = max(1, int((y - margin_bottom - 18.0) // 12.5))
                chunk = code_lines[chunk_idx : chunk_idx + avail_lines]
                chunk_idx += len(chunk)
                header_h = 13.0 if (lang and chunk_idx == len(chunk)) else 0.0
                box_h = len(chunk) * 12.5 + 12.0 + header_h
                draw_rect(margin_x, y - box_h + 9.0, page_w - 2 * margin_x, box_h, (0.95, 0.96, 0.98), (0.82, 0.85, 0.90))
                if header_h > 0:
                    draw_text(margin_x + 8.0, y - 1.0, "F2", 8.0, lang, (0.38, 0.44, 0.54))
                    y -= 13.0
                for cl in chunk:
                    draw_text(margin_x + 8.0, y - 2.0, "F3", 9.0, cl, (0.12, 0.15, 0.22))
                    y -= 12.5
                y -= 14.0
        else:
            wrapped = textwrap.wrap(strip_inline_md(blk["text"]), width=82) or [""]
            for wl in wrapped:
                ensure_space(15.0)
                draw_text(margin_x, y, "F1", 10.5, wl, (0.12, 0.14, 0.18))
                y -= 14.5
            y -= 5.0

    # Add page footers
    total_pages = len(pages)
    for idx, cmds in enumerate(pages, start=1):
        footer = sanitize_pdf_text(f"Exported by Aeye  |  Page {idx} / {total_pages}")
        cmds.append(
            f"BT /F1 8.5 Tf 0.500 0.540 0.600 rg 1 0 0 1 {margin_x:.2f} 26.00 Tm (".encode("ascii")
            + footer
            + b") Tj ET"
        )

    # Assemble PDF 1.4 objects
    objects: list[bytes] = []

    def add_obj(body: bytes) -> int:
        objects.append(body)
        return len(objects)

    # Reserve catalog (1) and pages (2)
    add_obj(b"")
    add_obj(b"")

    f1 = add_obj(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
    f2 = add_obj(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
    f3 = add_obj(b"<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>")

    page_ids: list[int] = []
    for cmds in pages:
        stream = b"\n".join(cmds) + b"\n"
        content_id = add_obj(
            f"<< /Length {len(stream)} >>\nstream\n".encode("ascii") + stream + b"endstream"
        )
        page_id = add_obj(
            (
                f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {page_w:.0f} {page_h:.0f}] "
                f"/Resources << /Font << /F1 {f1} 0 R /F2 {f2} 0 R /F3 {f3} 0 R >> >> "
                f"/Contents {content_id} 0 R >>"
            ).encode("ascii")
        )
        page_ids.append(page_id)

    kids = " ".join(f"{pid} 0 R" for pid in page_ids)
    objects[0] = b"<< /Type /Catalog /Pages 2 0 R >>"
    objects[1] = f"<< /Type /Pages /Kids [ {kids} ] /Count {len(page_ids)} >>".encode("ascii")

    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets: list[int] = [0]
    for idx, obj in enumerate(objects, start=1):
        offsets.append(len(out))
        out.extend(f"{idx} 0 obj\n".encode("ascii"))
        out.extend(obj)
        out.extend(b"\nendobj\n")

    xref_pos = len(out)
    out.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    out.extend(b"0000000000 65535 f \n")
    for off in offsets[1:]:
        out.extend(f"{off:010d} 00000 n \n".encode("ascii"))

    out.extend(
        (
            f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
            f"startxref\n{xref_pos}\n%%EOF\n"
        ).encode("ascii")
    )
    return bytes(out)


def inline_md_to_html(text: str) -> str:
    esc = html.escape(text)
    esc = re.sub(r"`([^`]+)`", r"<code>\1</code>", esc)
    esc = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", esc)
    esc = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<em>\1</em>", esc)
    return esc


def render_html(payload: dict) -> str:
    model = html.escape(str(payload.get("model") or "Aeye"))
    ts = html.escape(str(payload.get("timestamp") or datetime.datetime.now().strftime("%Y-%m-%d %H:%M")))
    prompt = str(payload.get("prompt") or "").strip()
    reasoning = str(payload.get("reasoning") or "").strip()
    answer = str(payload.get("answer") or "").strip()

    parts: list[str] = []
    if prompt:
        parts.append(f'<p class="meta"><strong>Prompt:</strong> {html.escape(prompt)}</p>')
    if reasoning:
        parts.append(
            f'<section class="reasoning"><h3>Visual Reasoning</h3><p>{html.escape(reasoning).replace(chr(10), "<br/>")}</p></section>'
        )

    blocks = parse_blocks(answer)
    in_list = False
    for blk in blocks:
        kind = blk["kind"]
        if kind != "bullet" and in_list:
            parts.append("</ul>")
            in_list = False
        if kind == "heading":
            lvl = min(6, max(1, int(blk.get("level", 2))))
            parts.append(f"<h{lvl}>{inline_md_to_html(blk['text'])}</h{lvl}>")
        elif kind == "bullet":
            if not in_list:
                parts.append("<ul>")
                in_list = True
            parts.append(f"<li>{inline_md_to_html(blk['text'])}</li>")
        elif kind == "code":
            lang = html.escape(blk.get("lang", ""))
            cls = f' class="language-{lang}"' if lang else ""
            parts.append(f"<pre><code{cls}>{html.escape(blk['text'])}</code></pre>")
        else:
            parts.append(f"<p>{inline_md_to_html(blk['text'])}</p>")
    if in_list:
        parts.append("</ul>")

    body = "\n    ".join(parts)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Aeye Export — {ts}</title>
  <style>
    :root {{ color-scheme: light dark; }}
    body {{ font-family: system-ui, -apple-system, sans-serif; max-width: 820px; margin: 2.5rem auto; padding: 0 1.25rem; line-height: 1.6; }}
    header {{ border-bottom: 1px solid rgba(128,128,128,.3); padding-bottom: .75rem; margin-bottom: 1.5rem; display: flex; justify-content: space-between; align-items: baseline; }}
    .meta {{ opacity: .78; font-size: .95rem; }}
    .reasoning {{ border-left: 3px solid #6b9eff; padding: .5rem 1rem; margin: 1rem 0; background: rgba(107,158,255,.08); border-radius: 6px; }}
    pre {{ background: rgba(128,128,128,.12); padding: .9rem 1rem; border-radius: 8px; overflow-x: auto; }}
    code {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .92em; }}
  </style>
</head>
<body>
  <header>
    <strong>Aeye</strong>
    <span class="meta">{model} &middot; {ts}</span>
  </header>
  <main>
    {body}
  </main>
</body>
</html>
"""


def render_markdown(payload: dict) -> str:
    model = str(payload.get("model") or "Aeye").strip()
    ts = str(payload.get("timestamp") or datetime.datetime.now().strftime("%Y-%m-%d %H:%M")).strip()
    prompt = str(payload.get("prompt") or "").strip()
    reasoning = str(payload.get("reasoning") or "").strip()
    answer = str(payload.get("answer") or "").strip()

    out = [f"# Aeye Note ({ts})", f"_Model: {model}_", ""]
    if prompt:
        out.append(f"**Prompt:** {prompt}")
        out.append("")
    if reasoning:
        out.append("## Visual Reasoning")
        out.append("")
        out.append(reasoning)
        out.append("")
    out.append(answer)
    return "\n".join(out).rstrip() + "\n"


def render_plain(payload: dict) -> str:
    reasoning = str(payload.get("reasoning") or "").strip()
    answer = str(payload.get("answer") or "").strip()
    if reasoning:
        return f"Visual Reasoning:\n{reasoning}\n\nAnswer:\n{answer}\n"
    return answer.rstrip() + "\n"


def atomic_write(target: Path, data: bytes) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=".aeye-export-", dir=str(target.parent))
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_name, target)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def main() -> int:
    if len(sys.argv) < 2:
        print("ERR\tMissing destination path")
        return 0
    raw_dest = sys.argv[1]
    raw_in = sys.stdin.read()
    if not raw_in.strip():
        print("ERR\tNothing to export")
        return 0
    try:
        payload = json.loads(raw_in)
        if not isinstance(payload, dict):
            payload = {"answer": str(payload)}
    except json.JSONDecodeError:
        payload = {"answer": raw_in}

    if not payload.get("timestamp"):
        payload["timestamp"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    try:
        target = resolve_target_path(raw_dest)
        ext = target.suffix.lower()
        if ext == ".pdf":
            data = render_pdf(payload)
        elif ext in (".html", ".htm"):
            data = render_html(payload).encode("utf-8")
        elif ext in (".md", ".markdown"):
            data = render_markdown(payload).encode("utf-8")
        elif ext == ".json":
            data = (json.dumps(payload, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
        else:
            data = render_plain(payload).encode("utf-8")
        atomic_write(target, data)
        print(f"OK\t{target}")
    except Exception as exc:
        msg = str(exc).replace("\n", " ").strip() or "Export failed"
        print(f"ERR\t{msg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
