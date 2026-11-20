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
python3 -B -m py_compile "$ROOT/bin/vision_api.py" "$ROOT/bin/annotate.py" "$ROOT/bin/extract.py" "$ROOT/bin/stream_parser.py" \
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

# 7. QML compliance checks (PlainText, Style.duration, zero hardcoded UI chrome hex colors)
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
