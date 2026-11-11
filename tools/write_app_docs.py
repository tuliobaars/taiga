#!/usr/bin/env python3
"""Write each project's docs/DESIGN.md and a Taiga section in its README.md, from the screenshot manifests
(<app>/docs/features/manifest.json) and the extracted tokens (tokens/<app>.json).

The README section sits between <!-- taiga:begin --> and <!-- taiga:end --> and is replaced on every run
(idempotent). It is inserted once, before the README's first second-level heading (or after a named
heading, see INSERT_AFTER). Nothing else in a README is changed, except the explicit FIXES below
(broken image links, recorded in VERIFICATION.md).

    python3 taiga-design-system/tools/write_app_docs.py
"""
from __future__ import annotations

import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
DS = os.path.dirname(HERE)
WS = os.path.dirname(DS)
BEGIN, END = "<!-- taiga:begin -->", "<!-- taiga:end -->"

# QuantSkill's README points at man/figures/*.png; the files in the project are .jpeg (pre-existing).
FIXES = {"QuantSkill": [(r"\(man/figures/([a-z_]+)\.png\)", r"(man/figures/\1.jpeg)")]}
INSERT_AFTER = {"lumenJourney": "## The study story: the same trial, for everyone", "QuantSkill": "## Install and run"}
INSERT_MODE = {"QuantSkill": "before", "lumenJourney": "before-next"}

FW = {"lumen": ("Lumen", "cinematic, high-contrast, glass-driven"), "neue": ("Neue", "minimalist, high-density enterprise")}

APPS = {
    "QuantSkill": dict(
        fw="lumen", dialect="Daylight glass",
        look="Light by default (`#fbfbfd`, text `#1d1d1f`, accent `#0071e3`) with a true-black dark theme; drifting colour blobs, glass cards and navigation (`blur(20px) saturate(160–180%)`), pill buttons, display type `clamp(52px, 9.2vw, 112px)` at −.045em, per-area category colours, gamified feedback (XP, streaks, badges, confetti).",
        tokens=".qs", files="`srcjs/css/quantskill.css` (source) → `inst/app/www/`, `inst/html/`, `inst/quarto/` (built by `data-raw/build.{R,py}`)",
        delivery=[("Shiny", "✓", "`run_app()`, `quantskill_app()`, `app.R`", "Answer keys stay on the server; answers graded, saved per session and archived; resume codes."),
                  ("Quarto", "✓", "`qs_export_quarto()`, `inst/quarto/quantskill.qmd`", "The same front end inside a document; the team's own guidance in markdown."),
                  ("HTML", "✓", "`qs_export_html()`, `inst/html/quantskill.html`", "One offline file; answer keys are in the page source (use Shiny when integrity matters).")],
        plan=None, top=["01-landing", "03-question", "04-scenario", "06-results", "08-team-dashboard", "02-landing-dark"]),
    "lumenJourney": dict(
        fw="lumen", dialect="Cinema story (dark) and paper (light)",
        look="The study story is dark by default (`#000`, text `#f5f5f7`, accent `#2997ff`): full-bleed chapters, a gradient hero title, count-up figures, one dot per patient, glass navigation and a floating glass filter pill. The paper light theme (`#f8f7f3`, Helvetica Neue at 200–300 weights, hairline shadows) is the editorial variant, also used for print.",
        tokens=".lumen-story", files="`inst/story/lumen-story.{css,js}` (one front end for all outputs, assembled by `story_html()`)",
        delivery=[("Shiny", "✓", "`run_story()`, `app_story.R`", "Uploads and server folders (Study setup); the analyst teal app is `run_app()` (Shiny only)."),
                  ("Quarto", "✓", "`story_quarto()`, `story_quarto_block()`", "The story between your own commentary; render to HTML."),
                  ("HTML", "✓", "`export_story_html()` (+ `export_story_pdf()`)", "One self-contained file; statistics computed in the browser.")],
        plan=None, top=["01-hero", "03-journey", "05-efficacy", "02-glance", "08-study-setup", "10-light-efficacy"]),
    "DirectoR": dict(
        fw="lumen", dialect="Studio dark",
        look="Dark only (`#07070a`, text `#f4f4f6`), Inter (shipped), white-at-low-alpha panels (`.032 / .055 / .085`), the brand gradient `linear-gradient(120deg, #6366f1, #a855f7 48%, #ec4899)` on the logo, primary actions and key words, a glass rail (84 px) with a glowing active indicator, choice cards with live visual previews, drifting radial glows.",
        tokens=":root (--bg, --panel, --a1…--a4, --grad)", files="`inst/app/www/director.{css,js}`, `R/ui.R`, `R/components.R`; film look: `inst/engine/stage/`",
        delivery=[("Shiny", "✓", "`run_app()`, `director_app()`, `app.R`", "The studio: scout, script, record, score, cut."),
                  ("Quarto", "gap", "planned `dr_export_quarto(project)`", "A press-kit document: film, script with timings, storyboard, stills."),
                  ("HTML", "gap", "planned `dr_export_html(project)`", "One file per film: video, captions (WebVTT), poster, script; or the engine's live preview inlined.")],
        plan="DirectoR", top=["01-library", "04-story", "05-shots", "08-autopilot", "03-source-scout", "07-look"]),
    "RockShiny": dict(
        fw="lumen", dialect="Stage dark",
        look="A bslib theme (`bg #0b0d13`, `fg #e8eaf1`, `primary #f5a524`, `.9rem`, radius `.55rem`) around an immersive 3-D highway on a radial stage (`#1a2035 → #0b0d13`); glass HUD cards (`rgba(14,17,26,.72)`, `blur(10px) saturate(140%)`); instrument colours in code (`STRING_COLORS`: `#e8203a #f2d40c #1f9cf0 #f5891d #22c55e #b04ee6`).",
        tokens=".rs-hw (--rs-*)", files="`inst/app/app.css`, `inst/highway/{highway.css, renderer*.js, binding.js}`, theme in `app.R`",
        delivery=[("Shiny", "✓", "`shiny::runApp()` (`app.R`)", "PSARC/MIDI import, audio conversion, scoring history saved by R."),
                  ("Quarto", "gap", "planned `rs_quarto_block(song, …)`", "A highway inside a lesson document; sections and loops as links."),
                  ("HTML", "gap", "planned `rs_export_html(song, arrangement, instrument)`", "Chart JSON + highway assets inline; guide tones; audio only with redistribution rights.")],
        plan="RockShiny", top=["01-highway", "02-bass", "03-practice-loop", "04-piano", "05-harmonica", "06-html-renderer"]),
    "teal_neue": dict(
        fw="neue", dialect="Instrument, ink-blue dark",
        look="Ruled white panels on a dot-grid canvas (`#f3f5f6`), one teal accent (`#0e8f83`, dark `#2cc5b4`), Inter for reading and JetBrains Mono for datasets, IDs and figures (both shipped), 14 px body, 34 px controls, quiet section tints (explore blue, safety terracotta, efficacy green, catalog violet), an appearance system (text, density, accent, corners, contrast, canvas, motion), and an ink-blue dark palette with white-paper plots.",
        tokens="html:root / [data-bs-theme] (--tn-*, bridged to --bs-*)", files="`inst/www/teal_neue.{css,js}`, `tlg_catalog.{css,js}`, `R/app_ui.R` (header, index), `R/overview.R`, `R/plot_theme.R`",
        delivery=[("Shiny", "✓", "`run_app()`, `teal_neue_app()`, `app.R`", "The teal app: 58 modules, TLG Catalog, filters, Show R code."),
                  ("Quarto", "gap", "planned `teal_neue_export_quarto(outputs, data)`", "A report: chosen TLG outputs with their runnable code as chunks, and the overview."),
                  ("HTML", "gap", "planned `teal_neue_export_html(data)`", "The study-at-a-glance page plus a static TLG appendix, with the filters stated.")],
        plan="teal_neue", top=["01-home", "03-analysis-module", "04-command-bar", "07-tlg-catalog", "06-appearance", "02-home-dark"]),
    "BlockR": dict(
        fw="neue", dialect="Instrument canvas, lifted-slate dark",
        look="teal_neue's token system (`--tn-*`) with a canvas layer (`--bk-*`): stacks of blocks with a category colour (data blue, prep teal, layout violet, analyze plum, output amber, plot terracotta, value olive, code slate), wires coloured by the kind of value they carry, mono row counts, plain-language block summaries, a `?` explanation on every part, and the one loud element, the Tutorial button (`#ff5f45 → #e93d8f → #7b4dff`). Dark mode is the *lifted slate* palette (panels `#1e262e`).",
        tokens="html:root / [data-bs-theme] (--tn-*) + .bk-app (--bk-*)", files="`inst/www/blockr.{css,js}`, `blockr_canvas.{css,js}`, `blockr_tutorial.js`, `R/canvas.R`, `R/blocks_*.R`",
        delivery=[("Shiny", "✓", "`run_app()`, `blockr_app()`, `app.R`", "The canvas evaluates blocks on the server, block by block, on the filtered data."),
                  ("Quarto", "gap", "planned `blockr_export_quarto(canvas)`", "The canvas as a document: one chunk per stack (`blockr_compile()`), block summaries as prose, the SAS translation."),
                  ("HTML", "gap", "planned `blockr_export_html(canvas)`", "A read-only canvas (the editor runs without Shiny) with the result rendered in.")],
        plan="BlockR", top=["01-canvas-template", "03-derived-columns", "04-code-r", "05-code-sas", "08-tutorial", "09-dark-explain"]),
}


def manifest(app):
    return json.load(open(os.path.join(WS, app, "docs", "features", "manifest.json")))


def provenance_note(app, m):
    kinds = {s["provenance"] for s in m["shots"]}
    if kinds == {"live"}:
        return ("Captured from the app's own shipped front end (%s), driven in Chromium at 1440 × 900 and 2× DPR."
                % m["shots"][0]["source"])
    return ("Captured from a **test bench**, not the full running app (no R runtime was available where these were made). "
            "The page is built from the app's own unmodified R UI code (run in webR, R compiled to WebAssembly) and its own "
            "stylesheets, scripts and fonts. Server results come from the app's own functions where they can run in base R; "
            "the rest are stand-ins, listed in `taiga-design-system/VERIFICATION.md`. This is the same kind of bench the "
            "project's own `preview/` images were made on.")


def design_md(app, a, m, tok):
    fw_name, fw_desc = FW[a["fw"]]
    rel = "../../taiga-design-system"
    shots = m["shots"]
    gal = ["| | |", "|---|---|"]
    for i in range(0, len(shots), 2):
        cells = []
        for s in shots[i:i + 2]:
            cells.append("![%s](features/%s)<br>**%s**: %s" % (s["title"], s["file"], s["title"], s["caption"]))
        if len(cells) == 1: cells.append("")
        gal.append("| %s |" % " | ".join(cells))
    n_vars = tok["n_custom_properties"]; n_bd = tok["backdrop_filter_decls"]; n_grad = sum(tok["gradients"].values())
    fonts = ", ".join("`%s`" % f[0][:70] for f in tok["font_families"][:2])
    prefixes = ", ".join("`%s`" % p for p, _ in tok["component_prefixes"][:8])
    lines = [
        "# %s: design and delivery" % app, "",
        "%s belongs to the **%s** framework (%s) of the Taiga design system. Its dialect: **%s**." % (app, fw_name, fw_desc, a["dialect"]), "",
        "- Framework styleguide: [`%s/inst/guides/%s/STYLEGUIDE.md`](%s/inst/guides/%s/STYLEGUIDE.md) (in R: `taiga::taiga_guide(\"%s-styleguide\")`)" % (rel, a["fw"], rel, a["fw"], a["fw"]),
        "- Requirements for new projects: [`%s/inst/guides/%s/REQUIREMENTS.md`](%s/inst/guides/%s/REQUIREMENTS.md)" % (rel, a["fw"], rel, a["fw"]),
        "- Delivery model (Shiny · Quarto · HTML): [`%s/inst/guides/DELIVERY_MODEL.md`](%s/inst/guides/DELIVERY_MODEL.md)" % (rel, rel),
        "- Extracted tokens: [`%s/inst/extdata/tokens/%s.json`](%s/inst/extdata/tokens/%s.json) (in R: `taiga::taiga_extracted(\"%s\")`), contrast: [`contrast.md`](%s/inst/extdata/tokens/contrast.md)" % (rel, app, rel, app, app, rel), "",
        "## Look", "", a["look"], "",
        "| | |", "|---|---|",
        "| Where the look lives | %s |" % a["files"],
        "| Token scope | `%s` |" % a["tokens"],
        "| Custom properties | %d |" % n_vars,
        "| `backdrop-filter` / gradients / keyframes | %d / %d / %d |" % (n_bd, n_grad, len(tok["keyframes"])),
        "| Font stacks | %s |" % fonts,
        "| Component namespaces (most used) | %s |" % prefixes, "",
        "## Feature screenshots", "",
        provenance_note(app, m), "",
        "Files: `docs/features/*.jpg` (%d × %d), with titles, captions and provenance in `docs/features/manifest.json`. "
        "Regenerate: `python3 taiga-design-system/tools/screens/%s.py`." % (shots[0]["width"], shots[0]["height"], SCRIPT[app]), "",
    ] + gal + ["",
        "## Delivery formats: Shiny · Quarto · HTML", "",
        "Every Taiga project specifies the triple-format delivery model (one front end, three hosts). Status for %s:" % app, "",
        "| Format | Status | Entry point | What it gives |", "|---|---|---|---|"] + \
        ["| %s | %s | %s | %s |" % (f, "✓ shipped" if s == "✓" else "**specified, not yet built**", e, w) for f, s, e, w in a["delivery"]] + [""]
    if a["plan"]:
        lines += ["The Quarto and HTML formats are specified in the delivery model, with a plan that reuses what the app "
                  "already has: [`DELIVERY_MODEL.md` §5.1](%s/inst/guides/DELIVERY_MODEL.md#51-plans-for-the-gaps). Requirements: DLV-01 to DLV-32." % rel, ""]
    lines += ["Capability matrix:", "", "| Capability | Shiny | Quarto | HTML |", "|---|---|---|---|",
              "| Runs without a server | – | ✓ | ✓ |", "| Server-side computation / secrets | ✓ | – | – |",
              "| Persistence across sessions and devices | ✓ | browser only | browser only |",
              "| Author commentary around the tool | – | ✓ | – |", "| Works offline / e-mailable | – | with `embed-resources` | ✓ |", ""]
    if app == "DirectoR":
        lines += ["## Promotional video", "",
                  "[![DirectoR teaser](../media/DirectoR_teaser_30s_poster.png)](../media/DirectoR_teaser_30s.mp4)", "",
                  "`media/DirectoR_teaser_30s.mp4`: 30 s, 1920 × 1080, 60 fps, H.264 + AAC, −14 LUFS, music only. It was made with "
                  "**QuantSkill's video utility** (`QuantSkill/dev/video`: deterministic recorder, stage engine, synthesised score), "
                  "driven by `taiga-design-system/tools/video/directoR/`. See [`../media/README.md`](../media/README.md).", ""]
    return "\n".join(lines) + "\n"


SCRIPT = {"QuantSkill": "quantskill", "lumenJourney": "lumen_journey", "DirectoR": "director", "RockShiny": "rockshiny", "teal_neue": "teal_neue", "BlockR": "blockr"}


def readme_block(app, a, m):
    by = {s["file"].rsplit(".", 1)[0]: s for s in m["shots"]}
    top = [by[k] for k in a["top"] if k in by]
    rows = ["| | | |", "|---|---|---|"]
    for i in range(0, len(top), 3):
        rows.append("| %s |" % " | ".join("![%s](docs/features/%s)<br>**%s**" % (s["title"], s["file"], s["title"]) for s in top[i:i + 3]))
    bench = any(s["provenance"] == "bench" for s in m["shots"])
    fw_name, fw_desc = FW[a["fw"]]
    lines = [BEGIN, "## Feature tour", ""] + rows + ["",
        ("*Screenshots from a test bench built from this package's own UI code and assets (no R runtime was available "
         "where they were made). See [docs/DESIGN.md](docs/DESIGN.md#feature-screenshots).*" if bench else
         "*Screenshots from the shipped front end, made by a script.*") + " All %d screenshots, with captions: [docs/DESIGN.md](docs/DESIGN.md)." % len(m["shots"]), ""]
    if app == "DirectoR":
        lines += ["**Promo video:** [`media/DirectoR_teaser_30s.mp4`](media/DirectoR_teaser_30s.mp4) (30 s, 1080p60), "
                  "made with QuantSkill's video utility.", ""]
    lines += ["### Delivery formats", "", "| Format | Status | Entry point |", "|---|---|---|"] + \
        ["| %s | %s | %s |" % (f, "✓" if s == "✓" else "specified, not yet built", e) for f, s, e, _ in a["delivery"]] + ["",
        "Design system: **%s** (%s), from the **taiga** R package in [`../taiga-design-system/`](../taiga-design-system/README.md): "
        "styleguide, requirements, tokens and the Shiny · Quarto · HTML delivery model (`taiga::taiga_guide()`, `taiga::taiga_export_html()`…). "
        "This project's page is [docs/DESIGN.md](docs/DESIGN.md)." % (fw_name, fw_desc),
        "", END]
    return "\n".join(lines)


def update_readme(app, block):
    p = os.path.join(WS, app, "README.md")
    s = open(p, encoding="utf-8").read()
    for pat, rep in FIXES.get(app, []):
        s = re.sub(pat, rep, s)
    if BEGIN in s:
        s = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), lambda _m: block, s, flags=re.S)
    else:
        lines = s.split("\n")
        anchor = INSERT_AFTER.get(app)
        if anchor and anchor in lines:
            i = lines.index(anchor)
            if INSERT_MODE.get(app) == "before-next":          # after that section: before the next ## heading
                j = next((k for k in range(i + 1, len(lines)) if lines[k].startswith("## ")), len(lines))
            else:                                               # before the anchor heading itself
                j = i
        else:
            j = next((k for k in range(1, len(lines)) if lines[k].startswith("## ")), len(lines))
        lines[j:j] = block.split("\n") + [""]
        s = "\n".join(lines)
    open(p, "w", encoding="utf-8").write(s)


def main():
    for app, a in APPS.items():
        m = manifest(app)
        tok = json.load(open(os.path.join(DS, "inst", "extdata", "tokens", app + ".json")))
        open(os.path.join(WS, app, "docs", "DESIGN.md"), "w", encoding="utf-8").write(design_md(app, a, m, tok))
        update_readme(app, readme_block(app, a, m))
        print("%-13s DESIGN.md + README (%d screenshots)" % (app, len(m["shots"])))


if __name__ == "__main__":
    main()
