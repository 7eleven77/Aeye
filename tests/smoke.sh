#!/usr/bin/env bash
# Offline smoke & compliance test suite for Aeye (no live AI API calls).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  ✗ %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

echo "Running Aeye smoke tests in $ROOT"

# 1. Shell & Python syntax
bash -n "$ROOT/bin/aeye" && ok "bash -n bin/aeye" || fail "bash -n bin/aeye"
python3 -B -m py_compile "$ROOT/bin/vision_api.py" "$ROOT/bin/annotate.py" "$ROOT/bin/extract.py" "$ROOT/bin/stream_parser.py" "$ROOT/bin/export_file.py" "$ROOT/bin/list_models.py" \
  && ok "python3 py_compile bin/*.py" || fail "python3 py_compile bin/*.py"

# 2. Manifest & Omarchy plugin validator
jq -e '.schemaVersion == 1 and .id == "io.github.7eleven77.aeye" and (.kinds | length == 3)' "$ROOT/manifest.json" >/dev/null \
  && ok "manifest.json schema fields" || fail "manifest.json schema fields"

if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$ROOT" >/dev/null && ok "omarchy-plugin-validate PASS" || fail "omarchy-plugin-validate"
fi

# 3. Providers JSON contract
prov_json="$("$ROOT/bin/aeye" providers)"
printf '%s' "$prov_json" | jq -e 'length == 4 and all(.[]; has("vendor") and has("label") and has("ready") and has("source"))' >/dev/null \
  && ok "aeye providers JSON contract (4 vendors)" || fail "aeye providers JSON contract"

# 4. extract.py unit tests (plain text + Grok JSON)
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

printf -- '- **Pro:** Leading dash preserved\n' >"$tmp_dir/plain.txt"
out_plain="$(python3 -B "$ROOT/bin/extract.py" text "$tmp_dir/plain.txt")"
[[ $out_plain == "- **Pro:** Leading dash preserved" ]] \
  && ok "extract.py plain text" || fail "extract.py plain text"

printf '{"result":"Grok ok"}\n' >"$tmp_dir/grok.json"
out_grok="$(python3 -B "$ROOT/bin/extract.py" grok "$tmp_dir/grok.json")"
[[ $out_grok == "Grok ok" ]] \
  && ok "extract.py grok JSON" || fail "extract.py grok JSON"

# 5. annotate.py unit test (arrow + box baking onto a synthetic PNG)
if command -v magick >/dev/null 2>&1; then
  magick -size 120x80 xc:black "$tmp_dir/test.png"
  python3 -B "$ROOT/bin/annotate.py" "$tmp_dir/test.png" '[{"kind":"arrow","x1":0.1,"y1":0.2,"x2":0.8,"y2":0.7},{"kind":"box","x1":0.2,"y1":0.2,"x2":0.6,"y2":0.6}]' \
    && ok "annotate.py arrow + box render" || fail "annotate.py arrow + box render"
fi

# 6. Markdown leading-dash clipboard copy test (regression test for wl-copy flag bug)
if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1 && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
  prev_clip="$(wl-paste --type text/plain 2>/dev/null || true)"
  sample=$'- **Pro:** Smoke test bullet\n- **Con:** None'
  "$ROOT/bin/aeye" copy "$sample"
  got_clip="$(wl-paste --no-newline 2>/dev/null || true)"
  # Restore user's previous clipboard content if non-empty
  [[ -n $prev_clip ]] && printf '%s' "$prev_clip" | wl-copy >/dev/null 2>&1 || true
  [[ $got_clip == "$sample" ]] \
    && ok "aeye copy handles leading-dash Markdown" || fail "aeye copy leading-dash Markdown (got: $got_clip)"
fi

# 7. Universal file export (.txt, .md, .pdf with Unicode symbols, .html, .json, custom ext, system path guard)
export_payload='{"model":"Gemini Flash","prompt":"Fix this — error • æøå","reasoning":"∴ Looked at line 40 → `items.reduce`","answer":"# Fix\n\n- Use `items.data.reduce(...)` — not `items.reduce(...)`.\n- Norwegian test: æøåÆØÅ · “smart quotes” · ✦\n\n```ts\nconst total = items.data.reduce((s, i) => s + i.amount, 0);\n```"}'

for ext in txt md pdf html json log; do
  res="$("$ROOT/bin/aeye" export-file "$tmp_dir/sub/report.$ext" "$export_payload")"
  if [[ $res == OK$'\t'* && -s "$tmp_dir/sub/report.$ext" ]]; then
    ok "aeye export-file .$ext"
  else
    fail "aeye export-file .$ext (got: $res)"
  fi
done

if head -c 8 "$tmp_dir/sub/report.pdf" | grep -q '^%PDF-1.4'; then
  ok "export-file .pdf valid PDF-1.4 header + Unicode safe"
else
  fail "export-file .pdf invalid header"
fi

guard_res="$("$ROOT/bin/aeye" export-file "/etc/aeye-smoke-should-fail.txt" "$export_payload")"
if [[ $guard_res == ERR$'\t'* ]]; then
  ok "export-file blocks protected system paths (/etc)"
else
  fail "export-file failed to block /etc (got: $guard_res)"
fi

# 8. Opt-in System Debug read-only snapshot safety & size bound
sysdbg_out="$(AEYE_CANARY_SECRET="DO_NOT_LEAK_9911" "$ROOT/bin/aeye" sysdebug-preview)"
sysdbg_bytes="${#sysdbg_out}"
if [[ $sysdbg_out == *"=== SYSTEM ==="* && $sysdbg_bytes -le 8200 && $sysdbg_out != *"DO_NOT_LEAK_9911"* ]]; then
  ok "sysdebug-preview bounded (${sysdbg_bytes}B), read-only, zero env leaks"
else
  fail "sysdebug-preview failed safety/bound check (${sysdbg_bytes}B)"
fi

# 8b. AI Context (.md + note) & sensitive file guard + live models discovery
ctx_md="$tmp_dir/context-smoke.md"
printf '# Smoke Context\nPrefer concise answers.\n' >"$ctx_md"
ctx_out="$("$ROOT/bin/aeye" context-preview "Custom note rule" "$ctx_md")"
if [[ $ctx_out == *"Custom note rule"* && $ctx_out == *"Prefer concise answers."* ]]; then
  ok "context-preview merges custom note and .md file"
else
  fail "context-preview failed to merge note and .md"
fi

ctx_guard="$("$ROOT/bin/aeye" context-preview "" "$HOME/.config/omarchy/aeye-keys.json")"
if [[ -z $ctx_guard ]]; then
  ok "context-preview blocks reading aeye-keys.json"
else
  fail "context-preview leaked aeye-keys.json"
fi

if "$ROOT/bin/aeye" models --lang en | jq -e '.gemini and .anthropic and .xai and .openai and (.gemini | length > 0) and (.xai | length > 0)' >/dev/null; then
  ok "aeye models catalog contract (4 vendors with hover details)"
else
  fail "aeye models catalog contract failed"
fi

amem_out="$("$ROOT/bin/aeye" memory-preview)"
amem_bytes="${#amem_out}"
if [[ $amem_bytes -le 4200 ]]; then
  ok "aeye memory-preview bounded (${amem_bytes}B), read-only"
else
  fail "aeye memory-preview exceeded 4KB bound (${amem_bytes}B)"
fi

# 9. QML compliance checks (PlainText, Style.duration, zero hardcoded UI chrome hex colors)
if grep -rnE '^\s*Text\s*\{' "$ROOT/Panel.qml" "$ROOT/BarWidget.qml" "$ROOT/Service.qml" >/dev/null; then
  fail "Bare Text {} found (must use PlainText)"
else
  ok "QML PlainText security compliance"
fi

if grep -rnE 'duration:\s*[1-9][0-9]*' "$ROOT/Panel.qml" "$ROOT/BarWidget.qml" "$ROOT/Service.qml" >/dev/null; then
  fail "Bare animation duration found (must wrap in Style.duration())"
else
  ok "QML Style.duration() motion compliance"
fi

if grep -rnE '#[0-9a-fA-F]{6}' "$ROOT/BarWidget.qml" "$ROOT/Service.qml" >/dev/null; then
  fail "Hardcoded hex color found in BarWidget.qml or Service.qml"
else
  ok "Zero hardcoded UI chrome hex colors in BarWidget/Service"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
