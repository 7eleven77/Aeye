#!/usr/bin/env python3
"""Discover active vision models per provider with rich hover descriptions.

Queries live local Omarchy CLIs (`agy models`, `grok models`) with short
timeouts and short-lived caching, falling back to curated vision catalogs
when a provider uses manual/env API keys or a CLI is unavailable.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\r")

# Curated fallback catalogs (used when a CLI is absent or offline, and for OpenAI)
FALLBACK_CATALOG = {
    "gemini": [
        ("gemini-4-neon-xhigh", "Gemini 4 Neon (XHigh)"),
        ("gemini-4-neon-high", "Gemini 4 Neon (High)"),
        ("gemini-4-neon-medium", "Gemini 4 Neon (Medium)"),
        ("gemini-4-neon-low", "Gemini 4 Neon (Low)"),
        ("gemini-4-argon-high", "Gemini 4 Argon (High)"),
        ("gemini-4-argon-medium", "Gemini 4 Argon (Medium)"),
        ("gemini-4-argon-low", "Gemini 4 Argon (Low)"),
        ("gemini-4-hydrogen-high", "Gemini 4 Hydrogen (High)"),
        ("gemini-3.8-flash-high", "Gemini 3.8 Flash (High)"),
        ("gemini-3.8-flash-medium", "Gemini 3.8 Flash (Medium)"),
        ("gemini-2.5-pro", "Gemini 2.5 Pro"),
        ("gemini-2.5-flash", "Gemini 2.5 Flash"),
    ],
    "anthropic": [
        ("claude-opus-5-5-high", "Claude Opus 5.5 (High)"),
        ("claude-opus-5-5-medium", "Claude Opus 5.5 (Medium)"),
        ("claude-opus-5-5-low", "Claude Opus 5.5 (Low)"),
        ("claude-sonnet-5-5-high", "Claude Sonnet 5.5 (High)"),
        ("claude-sonnet-5-5-medium", "Claude Sonnet 5.5 (Medium)"),
        ("claude-sonnet-5-5-low", "Claude Sonnet 5.5 (Low)"),
        ("claude-opus-4-6", "Claude Opus 4.6"),
        ("claude-sonnet-4-6", "Claude Sonnet 4.6"),
    ],
    "xai": [
        ("grok-4.7", "Grok 4.7"),
        ("grok-4.7-build-fast", "Grok 4.7 Build Fast"),
        ("grok-4.6", "Grok 4.6"),
        ("grok-4.5", "Grok 4.5"),
        ("grok-4.3", "Grok 4.3"),
        ("grok-4.20-0309-non-reasoning", "Grok 4.20 Non-Reasoning"),
        ("grok-4.20-0309-reasoning", "Grok 4.20 Reasoning"),
        ("grok-4.20-multi-agent-0309", "Grok 4.20 Multi-Agent"),
    ],
    "openai": [
        ("gpt-4o", "GPT-4o"),
        ("gpt-4.1", "GPT-4.1"),
        ("gpt-4.1-mini", "GPT-4.1 Mini"),
        ("o4-mini", "o4-mini"),
        ("gpt-4o-mini", "GPT-4o Mini"),
    ],
}


def _effort_info(model_id: str, lang: str) -> tuple[str, str]:
    low = model_id.lower()
    is_no = lang == "no"
    if low.endswith("-xhigh"):
        return (
            "XHigh",
            "Maksimal tenkedybde — tregere, men best på vanskeligste oppgaver."
            if is_no
            else "Maximum reasoning depth — slower, best for the hardest problems.",
        )
    if low.endswith("-high"):
        return (
            "High",
            "Høy presisjon og grundig analyse med god balanse."
            if is_no
            else "High reasoning accuracy with thorough visual analysis.",
        )
    if low.endswith("-medium"):
        return (
            "Medium",
            "Balansert fart og kvalitet for daglig bruk."
            if is_no
            else "Balanced speed and reasoning quality for everyday use.",
        )
    if low.endswith("-low"):
        return (
            "Low",
            "Rask respons med lett resonnering og lav ventetid."
            if is_no
            else "Fast response with light reasoning and low latency.",
        )
    return ("", "")


def _short_label(model_id: str, display: str) -> str:
    s = display.strip()
    low = model_id.lower()
    if "non-reasoning" in low:
        ver = re.search(r"grok-([0-9.]+)", low)
        return f"Grok {ver.group(1)} Non-Reason" if ver else "Grok Non-Reason"
    if "multi-agent" in low:
        ver = re.search(r"grok-([0-9.]+)", low)
        return f"Grok {ver.group(1)} Multi" if ver else "Grok Multi-Agent"
    if "reasoning" in low and low.startswith("grok-"):
        ver = re.search(r"grok-([0-9.]+)", low)
        return f"Grok {ver.group(1)} Reason" if ver else "Grok Reasoning"
    for prefix in ("Gemini 4 ", "Gemini 3.8 ", "Gemini 2.5 ", "Claude "):
        if s.startswith(prefix) and len(s) > len(prefix) + 2:
            return s[len(prefix) :]
    if s.startswith("Orchestrator "):
        return s.replace("Orchestrator ", "Orch ")
    return s if len(s) <= 22 else model_id[:22]


def describe_model(vendor: str, model_id: str, display: str, lang: str, source: str) -> dict:
    low = model_id.lower()
    is_no = lang == "no"
    effort_tag, effort_desc = _effort_info(model_id, lang)

    tier = "Vision"
    summary = ""

    if vendor == "gemini":
        if "orchestrator" in low:
            tier = "Orchestrator"
            summary = (
                "Flerstegs planlegging og orkestrering for komplekse arbeidsflyter og systemoppgaver."
                if is_no
                else "Multi-step planning and orchestration variant for complex multi-part workflows."
            )
        elif "neon" in low:
            tier = f"Flagship · {effort_tag}" if effort_tag else "Flagship"
            summary = (
                "Flaggskip-modell fra Gemini 4. Eksepsjonell på kompleks kode, arkitektur, feilsøking og detaljert skjermbildeanalyse."
                if is_no
                else "Gemini 4 flagship model. Excels at complex code, architecture, deep debugging, and detailed visual analysis."
            )
        elif "argon" in low:
            tier = f"Deep Logic · {effort_tag}" if effort_tag else "Deep Logic"
            summary = (
                "Sterk analytisk resonneringsmodell for komplekse grafer, diagrammer, lange dokumenter og grundige sammenligninger."
                if is_no
                else "Deep analytical reasoning model tuned for dense charts, diagrams, long docs, and structured comparisons."
            )
        elif "hydrogen" in low:
            tier = f"Reasoning · {effort_tag}" if effort_tag else "Reasoning"
            summary = (
                "Allsidig Gemini 4-modell med sterk visuell forståelse, klare forklaringer og solid koding."
                if is_no
                else "Versatile Gemini 4 reasoning model with strong visual comprehension, clear explanations, and solid coding."
            )
        elif "flash" in low:
            tier = f"Fast OCR · {effort_tag}" if effort_tag else "Fast OCR"
            summary = (
                "Lynrask visjonsmodell — ideell for tekstuthenting (OCR), oversettelse, raske oppsummeringer og UI-spørsmål."
                if is_no
                else "Ultra-fast vision model — ideal for instant OCR, translations, quick summaries, and everyday UI checks."
            )
        elif "2.5-pro" in low:
            tier = "Pro · API"
            summary = (
                "Gemini 2.5 Pro via API — høy nøyaktighet på koding, skjermbilder og komplekse tekniske spørsmål."
                if is_no
                else "Gemini 2.5 Pro via API — high accuracy for coding, screenshots, and complex technical analysis."
            )
        else:
            tier = f"Gemini · {effort_tag}" if effort_tag else "Gemini"
            summary = (
                "Google Gemini visjonsmodell for bilde- og tekstanalyse."
                if is_no
                else "Google Gemini vision model for image and text analysis."
            )

    elif vendor == "anthropic":
        if "opus" in low:
            tier = f"Flagship · {effort_tag}" if effort_tag else "Flagship"
            summary = (
                "Anthropics sterkeste modell — best på krevende kodegjennomgang, arkitektur, subtile feil og nyansert skriving."
                if is_no
                else "Anthropic's strongest model — best for deep code review, architecture, subtle bugs, and nuanced writing."
            )
        elif "sonnet" in low:
            tier = f"Code & Text · {effort_tag}" if effort_tag else "Code & Text"
            summary = (
                "Rask og presis spesialist på koding, stacktraces, logger, refaktorering, grammatikk og polert tekst."
                if is_no
                else "Fast, crisp specialist for code debugging, stacktraces, logs, refactoring, grammar, and polished writing."
            )
        else:
            tier = "Claude"
            summary = (
                "Anthropic Claude-modell for kode, resonnering og tekstanalyse."
                if is_no
                else "Anthropic Claude model for code, reasoning, and text analysis."
            )

    elif vendor == "xai":
        if "non-reasoning" in low:
            tier = "Fast · Non-Reasoning"
            summary = (
                "Lynrask Grok uten ekstra tenkesteg — umiddelbare, direkte svar for OCR, UI-spørsmål, oversettelse og raske oppslag."
                if is_no
                else "Ultra-fast Grok without chain-of-thought overhead — instant direct answers for OCR, UI lookups, and rapid checks."
            )
        elif "multi-agent" in low:
            tier = "Multi-Agent · Deep"
            summary = (
                "Multi-agent Grok som kjører flere resonneringsspor parallelt — best for tyngre feilsøking, research og dype analyser."
                if is_no
                else "Multi-agent Grok running parallel reasoning threads — best for heavy debugging, deep research, and complex comparisons."
            )
        elif "reasoning" in low:
            tier = "Deep Reasoning"
            summary = (
                "Stegvis resonnerende Grok-modell — sterk på komplekse stacktraces, logikk, grafer og teknisk arkitektur."
                if is_no
                else "Step-by-step reasoning Grok model — strong on complex stacktraces, logic, charts, and technical architecture."
            )
        elif "fast" in low:
            tier = "Fast · Build"
            summary = (
                "Hastighetsoptimalisert Grok-variant med lav ventetid — perfekt for kjapp koding, CLI-feil og korte svar."
                if is_no
                else "Speed-optimized low-latency Grok variant — great for rapid coding, CLI errors, and quick direct answers."
            )
        elif "4.7" in low:
            tier = "Realtime · Flagship"
            summary = (
                "Nyeste Grok 4.7 — rett-på-sak svar, ferske teknologier, nye verktøyfeil og skarp teknisk feilsøking."
                if is_no
                else "Latest Grok 4.7 — blunt, direct answers for fresh tech topics, new tool errors, and sharp troubleshooting."
            )
        else:
            tier = "Realtime · Tech"
            summary = (
                "xAI Grok visjonsmodell for direkte tekniske svar og feilsøking."
                if is_no
                else "xAI Grok vision model for direct technical answers and troubleshooting."
            )

    elif vendor == "openai":
        if "gpt-oss" in low:
            tier = f"Open Weights · {effort_tag}" if effort_tag else "Open Weights"
            summary = (
                "OpenAI GPT-OSS åpen resonneringsmodell (tilgjengelig via agy)."
                if is_no
                else "OpenAI GPT-OSS open-weights reasoning model (available via agy)."
            )
        elif "4.1-mini" in low or "4o-mini" in low:
            tier = "Fast · Light"
            summary = (
                "Lett og rask OpenAI-modell for enkel OCR, korte oppsummeringer og raske UI-spørsmål."
                if is_no
                else "Fast, lightweight OpenAI model for quick OCR, short summaries, and everyday UI lookups."
            )
        elif low.startswith("o4") or low.startswith("o3"):
            tier = "Reasoning"
            summary = (
                "OpenAI resonneringsmodell for stegvis problemløsning, matematikk, grafer og teknisk feilsøking."
                if is_no
                else "OpenAI reasoning model for step-by-step problem solving, math, dense charts, and debugging."
            )
        elif "4.1" in low:
            tier = "Code & Vision"
            summary = (
                "OpenAI GPT-4.1 — svært sterk på kodeforståelse, strukturerte svar og nøyaktig instruksjonsfølging."
                if is_no
                else "OpenAI GPT-4.1 — strong at code comprehension, structured outputs, and precise instruction following."
            )
        else:
            tier = "UI & General"
            summary = (
                "OpenAI GPT-4o — sterk allrounder for UI/UX-tilbakemeldinger, tabeller/JSON og generell visjon."
                if is_no
                else "OpenAI GPT-4o — strong all-rounder for UI/UX feedback, tables/JSON extraction, and general vision."
            )

    requires_api = False
    auth_badge = "CLI / API"
    auth_note = ""
    if vendor == "gemini":
        if "2.5-pro" in low or "2.5-flash" in low:
            requires_api = True
            auth_badge = "API Only"
            auth_note = "Krever separat Gemini API-nøkkel." if is_no else "Requires a separate Gemini API key."
        else:
            auth_badge = "CLI (Pro)"
            auth_note = (
                "Inkludert i agy CLI (Pro-abonnement) uten ekstra API-kostnad — eller bruk API-nøkkel for direkte kall."
                if is_no
                else "Included in agy CLI (Pro subscription) at no extra API cost — or use an API key for direct calls."
            )
    elif vendor == "anthropic":
        auth_badge = "CLI (Pro)"
        auth_note = (
            "Inkludert i agy / claude CLI (Pro-abonnement) — CLI anbefales fremfor dyr API-bruk."
            if is_no
            else "Included in agy / claude CLI (Pro subscription) — CLI mode recommended over per-token API billing."
        )
    elif vendor == "xai":
        if low in ("grok-4.7", "grok-4.7-build-fast", "grok-4-fast", "grok-3-mini"):
            auth_badge = "CLI / API"
            auth_note = (
                "Støtter vanlig grok CLI-auth, eller xAI API-nøkkel (~2× raskere direkte strømming)."
                if is_no
                else "Works with standard grok CLI auth, or xAI API key (~2x faster direct streaming)."
            )
        else:
            requires_api = True
            auth_badge = "Requires API"
            auth_note = (
                "Krever separat xAI API-nøkkel (kun tilgjengelig via direkte xAI API, ~2× raskere respons)."
                if is_no
                else "Requires a separate xAI API key (direct xAI API model, ~2x faster response)."
            )
    elif vendor == "openai":
        if "gpt-oss" in low:
            auth_badge = "CLI (Pro)"
            auth_note = "Inkludert i agy CLI." if is_no else "Included in agy CLI."
        else:
            requires_api = True
            auth_badge = "Requires API"
            auth_note = "Krever separat OpenAI API-nøkkel." if is_no else "Requires a separate OpenAI API key."

    parts = [f"{display} ({model_id}) — {summary}"]
    if effort_desc:
        parts.append(effort_desc)
    if auth_note:
        parts.append(auth_note)

    return {
        "id": model_id,
        "label": display,
        "shortLabel": _short_label(model_id, display),
        "vendor": vendor,
        "tier": f"{tier} · {auth_badge}",
        "authBadge": auth_badge,
        "requiresApi": requires_api,
        "details": " ".join(parts),
        "source": source,
    }


def _clean_lines(raw: str) -> list[str]:
    cleaned = ANSI_RE.sub("", raw or "")
    return [line.strip() for line in cleaned.splitlines() if line.strip()]


def fetch_agy_models() -> dict[str, list[tuple[str, str]]]:
    out: dict[str, list[tuple[str, str]]] = {"gemini": [], "anthropic": [], "openai": []}
    if not shutil.which("agy"):
        return out
    try:
        proc = subprocess.run(
            ["agy", "models"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=6,
            check=False,
        )
    except Exception:
        return out

    seen: set[str] = set()
    for line in _clean_lines(proc.stdout):
        if "Fetching available models" in line:
            line = line.split("Fetching available models...")[-1].strip()
        if not line:
            continue
        m = re.match(r"^([a-zA-Z0-9][a-zA-Z0-9._:-]+)(?:\t+|\s{2,})(.+)$", line)
        if not m:
            continue
        mid, disp = m.group(1).strip(), m.group(2).strip()
        if mid in seen:
            continue
        seen.add(mid)
        low = mid.lower()
        if low.startswith("gemini"):
            out["gemini"].append((mid, disp))
        elif low.startswith("claude"):
            out["anthropic"].append((mid, disp))
        elif low.startswith(("gpt-", "o1", "o3", "o4")):
            out["openai"].append((mid, disp))
    return out


def _format_grok_display(mid: str) -> str:
    low = mid.lower()
    m = re.match(r"^grok-([0-9]+(?:\.[0-9]+)?)(.*)$", low)
    if not m:
        return mid.replace("-", " ").title()
    ver, rest = m.group(1), m.group(2)
    rest = re.sub(r"-\d{4}\b", "", rest)  # drop date suffix like -0309 from label
    if "non-reasoning" in rest:
        return f"Grok {ver} Non-Reasoning"
    if "multi-agent" in rest:
        return f"Grok {ver} Multi-Agent"
    if "reasoning" in rest:
        return f"Grok {ver} Reasoning"
    if "build-fast" in rest:
        return f"Grok {ver} Build Fast"
    if "fast" in rest:
        return f"Grok {ver} Fast"
    suffix = rest.strip("-").replace("-", " ").title()
    return f"Grok {ver} {suffix}".strip()


def _xai_api_key() -> str:
    cfg_dir = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    keys_path = os.path.join(cfg_dir, "omarchy", "aeye-keys.json")
    try:
        if os.path.isfile(keys_path):
            with open(keys_path, "r", encoding="utf-8") as f:
                val = str(json.load(f).get("xai", "")).strip()
                if val:
                    return val
    except Exception:
        pass
    return os.environ.get("XAI_API_KEY", "").strip()


def fetch_xai_api_models() -> list[tuple[str, str]]:
    key = _xai_api_key()
    if not key:
        return []
    out: list[tuple[str, str]] = []
    seen: set[str] = set()
    try:
        req = urllib.request.Request(
            "https://api.x.ai/v1/language-models",
            headers={"Authorization": f"Bearer {key}", "User-Agent": "aeye"},
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.load(resp)
        for item in data.get("models", []):
            mid = str(item.get("id", "")).strip()
            modalities = item.get("input_modalities") or []
            if not mid or mid in seen or not mid.lower().startswith("grok"):
                continue
            if modalities and "image" not in modalities:
                continue
            seen.add(mid)
            out.append((mid, _format_grok_display(mid)))
    except Exception:
        pass
    return out


def fetch_grok_models() -> list[tuple[str, str]]:
    cli_models: list[tuple[str, str]] = []
    seen: set[str] = set()
    if shutil.which("grok"):
        try:
            proc = subprocess.run(
                ["grok", "models"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                timeout=6,
                check=False,
            )
            for line in _clean_lines(proc.stdout):
                m = re.match(r"^[-*]\s+([a-zA-Z0-9._-]+)", line)
                if not m:
                    continue
                mid = m.group(1).strip()
                if not mid.lower().startswith("grok") or mid in seen:
                    continue
                seen.add(mid)
                cli_models.append((mid, _format_grok_display(mid)))
        except Exception:
            pass

    api_models = fetch_xai_api_models()
    # Merge: keep CLI models first (newest defaults like grok-4.7 & grok-4.7-build-fast),
    # then append all additional vision-capable models from xAI API (non-reasoning, reasoning, multi-agent, etc.)
    merged = list(cli_models)
    for mid, disp in reversed(api_models):
        if mid not in seen:
            seen.add(mid)
            merged.append((mid, disp))
    return merged


def build_catalog(lang: str, runtime_dir: str, force_refresh: bool) -> dict[str, list[dict]]:
    cache_path = os.path.join(runtime_dir, f"models-catalog-{lang}.json")
    if not force_refresh and os.path.isfile(cache_path):
        try:
            age = time.time() - os.path.getmtime(cache_path)
            if age < 600:
                with open(cache_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                if isinstance(data, dict) and "gemini" in data:
                    return data
        except Exception:
            pass

    with ThreadPoolExecutor(max_workers=2) as pool:
        f_agy = pool.submit(fetch_agy_models)
        f_grok = pool.submit(fetch_grok_models)
        agy_map = f_agy.result()
        grok_list = f_grok.result()

    live_by_vendor = {
        "gemini": agy_map.get("gemini", []),
        "anthropic": agy_map.get("anthropic", []),
        "xai": grok_list,
        "openai": agy_map.get("openai", []),
    }

    result: dict[str, list[dict]] = {}
    for vendor in ("gemini", "anthropic", "xai", "openai"):
        entries: list[dict] = []
        seen: set[str] = set()
        live = live_by_vendor.get(vendor, [])
        if live:
            for mid, disp in live:
                if mid not in seen:
                    seen.add(mid)
                    entries.append(describe_model(vendor, mid, disp, lang, "live"))
            # For OpenAI, also append standard vision API models alongside any agy gpt-oss
            if vendor == "openai":
                for mid, disp in FALLBACK_CATALOG["openai"]:
                    if mid not in seen:
                        seen.add(mid)
                        entries.append(describe_model(vendor, mid, disp, lang, "catalog"))
        else:
            for mid, disp in FALLBACK_CATALOG[vendor]:
                if mid not in seen:
                    seen.add(mid)
                    entries.append(describe_model(vendor, mid, disp, lang, "catalog"))
        result[vendor] = entries

    try:
        os.makedirs(runtime_dir, exist_ok=True)
        tmp = cache_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False)
        os.replace(tmp, cache_path)
    except Exception:
        pass

    return result


def main() -> int:
    lang = "en"
    vendor_filter = ""
    force_refresh = False
    runtime_dir = os.path.join(
        os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/aeye-{os.getuid()}", "aeye"
    )

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--lang" and i + 1 < len(args):
            lang = args[i + 1].strip().lower() or "en"
            i += 2
        elif a == "--vendor" and i + 1 < len(args):
            vendor_filter = args[i + 1].strip().lower()
            i += 2
        elif a == "--refresh":
            force_refresh = True
            i += 1
        elif a == "--runtime-dir" and i + 1 < len(args):
            runtime_dir = args[i + 1]
            i += 2
        else:
            i += 1

    catalog = build_catalog(lang, runtime_dir, force_refresh)
    if vendor_filter:
        print(json.dumps(catalog.get(vendor_filter, []), ensure_ascii=False))
    else:
        print(json.dumps(catalog, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
