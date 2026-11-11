#!/usr/bin/env python3
"""Extract design tokens from the canonical stylesheets of the six Taiga apps.

    python3 taiga-design-system/tools/extract_tokens.py            # writes inst/extdata/tokens/<app>.json + summary.md

Read-only with respect to the apps: it only opens their CSS files. Output is
quantitative (counts, frequencies) so the styleguides can cite numbers that
anyone can re-derive by running this script again.
"""
from __future__ import annotations

import collections
import json
import os
import re
import sys

import tinycss2

HERE = os.path.dirname(os.path.abspath(__file__))
DS = os.path.dirname(HERE)
WS = os.path.dirname(DS)
OUT = os.path.join(DS, "inst", "extdata", "tokens")      # installed with the package: taiga_extracted()

# Canonical sources only (stale copies such as QuantSkill/src, QuantSkill/www and
# lumenJourney/lumenJourney are excluded on purpose; see VERIFICATION.md).
APPS = {
    "QuantSkill": {"framework": "lumen", "css": ["QuantSkill/srcjs/css/quantskill.css"]},
    "DirectoR": {"framework": "lumen", "css": ["DirectoR/inst/app/www/director.css"],
                 "extra": ["DirectoR/inst/engine/stage/stage.css"]},
    "RockShiny": {"framework": "lumen", "css": ["RockShiny/inst/app/app.css", "RockShiny/inst/highway/highway.css",
                                                "RockShiny/inst/dropzone/dropzone.css"]},
    "lumenJourney": {"framework": "lumen", "css": ["lumenJourney/inst/story/lumen-story.css"]},
    "teal_neue": {"framework": "neue", "css": ["teal_neue/inst/www/teal_neue.css", "teal_neue/inst/www/tlg_catalog.css"]},
    "BlockR": {"framework": "neue", "css": ["BlockR/inst/www/blockr.css", "BlockR/inst/www/blockr_canvas.css",
                                            "BlockR/inst/www/tlg_catalog.css"]},
}

HEX = re.compile(r"#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})\b")
FUNC_COL = re.compile(r"\b(?:rgba?|hsla?|oklch|oklab|color-mix)\([^()]*(?:\([^()]*\)[^()]*)*\)")
LEN = re.compile(r"-?\d*\.?\d+(?:px|rem|em|%|vh|vw|vmax|vmin)?")
DARK_HINT = re.compile(r"dark|\[data-bs-theme=.?dark|\.qs\[data-theme=.?dark|night", re.I)


def norm_hex(h):
    h = h.lower()
    if len(h) in (4, 5):
        h = "#" + "".join(c * 2 for c in h[1:])
    return h


def walk_rules(rules, media=None, out=None):
    """flatten qualified rules, remembering the enclosing @media/@supports"""
    out = [] if out is None else out
    for r in rules:
        if r.type == "qualified-rule":
            sel = tinycss2.serialize(r.prelude).strip()
            decls = tinycss2.parse_declaration_list(r.content, skip_comments=True, skip_whitespace=True)
            out.append((sel, media, decls))
        elif r.type == "at-rule":
            kw = r.lower_at_keyword
            prelude = tinycss2.serialize(r.prelude).strip()
            if kw in ("media", "supports", "layer", "container") and r.content is not None:
                inner = tinycss2.parse_rule_list(r.content, skip_comments=True, skip_whitespace=True)
                walk_rules(inner, (media + " && " if media else "") + "@%s %s" % (kw, prelude), out)
            elif kw == "keyframes":
                out.append(("@keyframes " + prelude, media, []))
            elif kw == "font-face":
                decls = tinycss2.parse_declaration_list(r.content, skip_comments=True, skip_whitespace=True)
                out.append(("@font-face", media, decls))
    return out


def luminance(hexstr):
    h = norm_hex(hexstr)[1:7]
    rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return round((hi + 0.05) / (lo + 0.05), 2)


def analyse(app, spec):
    files = spec["css"]
    raw = "".join(open(os.path.join(WS, f), encoding="utf-8").read() + "\n" for f in files)
    sheet = tinycss2.parse_stylesheet(raw, skip_comments=True, skip_whitespace=True)
    rules = walk_rules(sheet)

    custom = collections.OrderedDict()          # scope selector -> {var: value}
    colors = collections.Counter()
    fonts = collections.Counter()
    sizes = collections.Counter()
    weights = collections.Counter()
    tracking = collections.Counter()
    radii = collections.Counter()
    shadows = collections.Counter()
    easings = collections.Counter()
    durations = collections.Counter()
    zidx = collections.Counter()
    gradients = collections.Counter()
    medias = collections.Counter()
    keyframes = []
    fontfaces = []
    backdrop = 0
    backdrop_examples = collections.Counter()
    blur_filters = 0
    prefixes = collections.Counter()
    n_decl = 0

    for sel, media, decls in rules:
        if media:
            medias[media] += 1
        if sel.startswith("@keyframes"):
            keyframes.append(sel.split(" ", 1)[1]); continue
        if sel == "@font-face":
            d = {x.lower_name: tinycss2.serialize(x.value).strip() for x in decls if x.type == "declaration"}
            fontfaces.append({"family": d.get("font-family"), "weight": d.get("font-weight"), "src": (d.get("src") or "")[:60]})
            continue
        for cls in re.findall(r"\.([a-zA-Z][\w-]*)", sel):
            p = re.match(r"([a-zA-Z]+)[-_]", cls)
            prefixes[(p.group(1) if p else cls)] += 1
        for d in decls:
            if d.type != "declaration":
                continue
            n_decl += 1
            name = d.lower_name if not d.name.startswith("--") else d.name
            val = tinycss2.serialize(d.value).strip()
            if name.startswith("--"):
                scope = sel if not media else "%s  {%s}" % (sel, media)
                custom.setdefault(scope, collections.OrderedDict())[name] = val
            for h in HEX.findall(val):
                colors[norm_hex(h)] += 1
            for f in FUNC_COL.findall(val):
                colors[re.sub(r"\s+", " ", f)] += 1
            if name == "font-family":
                fonts[val] += 1
            elif name == "font-size":
                sizes[val] += 1
            elif name == "font-weight":
                weights[val] += 1
            elif name == "letter-spacing":
                tracking[val] += 1
            elif name.startswith("border") and "radius" in name:
                radii[val] += 1
            elif name == "box-shadow":
                shadows[val] += 1
            elif name in ("backdrop-filter", "-webkit-backdrop-filter"):
                if val != "none" and not val.startswith("none"):
                    backdrop += 1; backdrop_examples[val] += 1
            elif name == "filter" and "blur(" in val:
                blur_filters += 1
            elif name == "z-index":
                zidx[val] += 1
            if name in ("transition", "animation", "transition-timing-function", "animation-timing-function"):
                for e in re.findall(r"cubic-bezier\([^)]*\)|\bease(?:-in-out|-in|-out)?\b|\blinear\b|var\(--[\w-]+\)", val):
                    easings[e] += 1
                for t in re.findall(r"(?<![\w.-])(\d*\.?\d+m?s)\b", val):
                    durations[t] += 1
            for g in re.findall(r"(?:repeating-)?(?:linear|radial|conic)-gradient", val):
                gradients[g] += 1

    # theme scopes: which selectors redefine tokens for dark mode
    dark_scopes = [s for s in custom if DARK_HINT.search(s)]
    # contrast of the main text/background pairs, per scope, where both are plain hex
    pairs = []
    for scope, vars_ in custom.items():
        def hexof(v):
            v = vars_.get(v)
            return norm_hex(v) if v and HEX.fullmatch(v.strip()) else None
        for fg in [k for k in vars_ if re.search(r"^--[\w-]*(text|fg|ink|muted|dim|body-color|emphasis-color)[\w-]*$", k) and not re.search(r"(bg|rgb|shadow|decoration|size|font)", k)]:
            for bg in [k for k in vars_ if re.search(r"^--[\w-]*(bg|background|surface|paper|canvas|panel|card)[\w-]*$", k) and not re.search(r"(rgb|shadow|border|line|hover|glass|text|fg)", k)]:
                a, b = hexof(fg), hexof(bg)
                if a and b:
                    pairs.append({"scope": scope[:80], "fg": fg, "bg": bg, "fg_hex": a, "bg_hex": b, "ratio": contrast(a, b)})
    pairs.sort(key=lambda p: (p["scope"], -p["ratio"]))

    return {
        "app": app, "framework": spec["framework"], "files": files,
        "bytes": len(raw), "rules": len(rules), "declarations": n_decl,
        "custom_properties": {k: dict(v) for k, v in custom.items()},
        "n_custom_properties": sum(len(v) for v in custom.values()),
        "dark_scopes": dark_scopes,
        "colors_top": colors.most_common(60), "n_distinct_colors": len(colors),
        "font_families": fonts.most_common(12), "font_faces": fontfaces,
        "font_sizes": sizes.most_common(30), "font_weights": weights.most_common(12),
        "letter_spacing": tracking.most_common(15),
        "radii": radii.most_common(20), "shadows": shadows.most_common(15),
        "backdrop_filter_decls": backdrop, "backdrop_examples": backdrop_examples.most_common(8),
        "blur_filter_decls": blur_filters,
        "gradients": dict(gradients), "easings": easings.most_common(10), "durations": durations.most_common(15),
        "z_index": zidx.most_common(15), "media_queries": medias.most_common(25),
        "keyframes": keyframes, "component_prefixes": prefixes.most_common(40),
        "contrast_pairs": pairs,
    }


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for app, spec in APPS.items():
        r = analyse(app, spec)
        if spec.get("extra"):
            r["extra"] = {f: analyse(app + ":" + os.path.basename(f), {"framework": spec["framework"], "css": [f]}) for f in spec["extra"]}
        json.dump(r, open(os.path.join(OUT, app + ".json"), "w"), indent=1)
        rows.append(r)
        print("%-13s %-6s %7d bytes  %5d rules  %5d decls  %4d vars  %4d colours  backdrop=%d blur=%d gradients=%d keyframes=%d"
              % (app, r["framework"], r["bytes"], r["rules"], r["declarations"], r["n_custom_properties"], r["n_distinct_colors"],
                 r["backdrop_filter_decls"], r["blur_filter_decls"], sum(r["gradients"].values()), len(r["keyframes"])))
    # compact comparison table for the docs
    with open(os.path.join(OUT, "summary.md"), "w") as f:
        f.write("# Token extraction summary\n\nGenerated by `tools/extract_tokens.py` from the canonical stylesheets (read-only).\n\n")
        f.write("| App | Framework | CSS bytes | Rules | Declarations | Custom properties | Distinct colours | `backdrop-filter` | `filter: blur()` | Gradients | Keyframes |\n")
        f.write("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n")
        for r in rows:
            f.write("| %s | %s | %d | %d | %d | %d | %d | %d | %d | %d | %d |\n" % (
                r["app"], r["framework"], r["bytes"], r["rules"], r["declarations"], r["n_custom_properties"], r["n_distinct_colors"],
                r["backdrop_filter_decls"], r["blur_filter_decls"], sum(r["gradients"].values()), len(r["keyframes"])))
        f.write("\nSource files:\n\n")
        for r in rows:
            f.write("- **%s**: %s\n" % (r["app"], ", ".join("`%s`" % x for x in r["files"])))


if __name__ == "__main__":
    sys.exit(main())
