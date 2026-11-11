# Triple-format delivery model: Shiny · Quarto · HTML

Every Taiga project ships **one front end, three ways**:

| Format | What the user gets | Typical use |
|---|---|---|
| **Shiny** | A running app: `pkg::run_app()` / `pkg_app()`, deployable to Posit Connect, Shiny Server or shinyapps.io | Team use, server-side computation, persistence, anything secret |
| **Quarto** | A document: a `.qmd` (plus include files) that renders to HTML with the same front end, between the author's own prose | Publishing, reports, teaching material, commentary around the tool |
| **Standalone HTML** | One self-contained `.html` file: data, styles, scripts and fonts inline, with no server and no network | E-mail, intranets, document systems, offline, archiving |

This is the delivery model QuantSkill and lumenJourney's study story already follow. This document turns
it into requirements for every Taiga project and states the status of each app.

---

## 1. Reference implementations

- **QuantSkill**: `srcjs/` → `data-raw/build.{R,py}` → three targets from one source:
  `inst/app/www/quantskill.{js,css}` (Shiny), `inst/quarto/_quantskill-{head,body}.html` +
  `quantskill.qmd` (Quarto), `inst/html/quantskill.html` (standalone). R API: `run_app()`,
  `quantskill_app()`, `qs_export_quarto()`, `qs_export_html()`. The front end picks a **transport**
  (`srcjs/js/30-transport.js`): `LocalTransport` (HTML and Quarto: bank embedded, graded in the browser)
  or `ShinyTransport` (bank sent *without* answer keys, every answer graded and stored server-side, over a
  request/response protocol: `input$qs_msg` ↔ custom message `qs-msg`).
- **lumenJourney story**: `story_html(data, standalone, mode = c("html", "shiny", "quarto"))` builds
  the same fragment for every host (root `<div class="lumen-story" data-mode=…>`, inline CSS, JSON data
  and profiles in `<script type="application/json">`, inline JS). R API: `export_story_html()`,
  `run_story()`, `story_quarto()` / `story_quarto_block()`, plus `export_story_pdf()`. A Shiny bridge
  (`inst/story/lumen-story-shiny.js`) adds uploads and server folders.

## 2. Architecture

```
            ┌───────────────────────── one front end (no dependencies) ─────────────────────────┐
            │  app.js + app.css (+ fonts)   ·   reads its payload from <script type="application/json">│
            │  mode = data-mode / transport:  "html" | "quarto" | "shiny"                           │
            └─────────────┬───────────────────────────────┬───────────────────────────┬──────────┘
                          │                               │                           │
        Shiny host  ──────┘        Quarto host ───────────┘      HTML host ───────────┘
        htmlDependency (www/)      include-in-header/body, or     everything inline in one file
        payload from the server    a raw-HTML block from R        (fonts as base64 data URIs)
        protocol: input$<id>_msg   payload embedded at render     payload embedded at export
                  ↔ '<id>-msg'
```

## 3. Requirements

### 3.1 Front end

| ID | Requirement |
|---|---|
| DLV-01 | There is **one** front-end source (JS/CSS), built to all three targets by one build script. The three targets are never edited by hand. |
| DLV-02 | The front end has **no external requests**: no CDN, web fonts or analytics. Fonts ship in the package and are inlined as data URIs in the HTML target. |
| DLV-03 | All styles are **namespaced** under one root class (`.qs`, `.lumen-story`, `.tn-*`, `.bk-*`) so the front end can live inside a Quarto or Shiny page without leaking styles. Host-page resets are scoped (`html.qs-host`). |
| DLV-04 | The front end detects its host from `data-mode` (or an equivalent) and degrades per §4. It never assumes a server. |
| DLV-05 | Data is embedded as JSON in `<script type="application/json" id="…">` with every `<` written as `\u003c`, so no host (browser, pandoc, Quarto) can read markup in the data. |
| DLV-06 | Assets are **ASCII only** (other characters as `\u` escapes) and contain no literal `<script`, `</body>` or `<!--`. Hosts such as pandoc re-parse inline scripts. Build such strings from pieces. (lumenJourney enforces this in `tests/testthat/test-story.R`.) |
| DLV-07 | The initial theme is set in the markup (`data-theme`, or a head script run before first paint), so no host shows a flash of the wrong theme. |

### 3.2 Hosts and R API

| ID | Requirement |
|---|---|
| DLV-10 | **Shiny:** `run_app(...)` starts the app and `<pkg>_app(...)` returns a `shinyApp` for deployment. `app.R` in the package root is the deployment entry point. Assets come through one `htmlDependency`. |
| DLV-11 | **Shiny protocol:** client → server over one input (`input$<id>_msg`, JSON with a request id), server → client over one custom message (`<id>-msg`). It must survive reconnects (`session$allowReconnect(TRUE)`, re-attach on `shiny:connected`). |
| DLV-12 | **Quarto:** `export_quarto(dir, ...)` (or `<pkg>_quarto()`) writes a ready-to-render `.qmd` and its include files. A `*_quarto_block()` returns a raw-HTML block for authors who write their own `.qmd`. The document renders with `embed-resources: true`. |
| DLV-13 | **HTML:** `export_html(file, ...)` writes one self-contained file and returns its path invisibly. Opening it needs only a browser. |
| DLV-14 | The same options (data source, setup, theme) are accepted by all three entry points, with the same names. |

### 3.3 Security and capability

| ID | Requirement |
|---|---|
| DLV-20 | Anything that must stay secret (answer keys, credentials, unpublished data) is **Shiny-only**. The HTML and Quarto targets carry only what the reader may see. (QuantSkill's README warns that HTML/Quarto contain the answer keys.) |
| DLV-21 | Each project documents a **capability matrix** (§4): what each format can and cannot do. |
| DLV-22 | Third-party content (for example song audio in RockShiny, or licensed data) is never embedded in the portable formats without the right to redistribute it. |

### 3.4 Verification

| ID | Requirement |
|---|---|
| DLV-30 | CI builds all three targets and runs a headless smoke test on each (page loads, no console errors, the main view renders). |
| DLV-31 | Engine parity: logic that runs both in R and in the browser is tested for identical results (QuantSkill: `tests/testthat/fixtures/engine_cases.json`; lumenJourney: `tools/story-dev/check-stats.mjs`). |
| DLV-32 | Feature screenshots are regenerated from the built targets (`docs/features/`, with a `manifest.json` recording provenance). |

## 4. Capability matrix template

| Capability | Shiny | Quarto | HTML |
|---|---|---|---|
| Runs without a server | – | ✓ (rendered page) | ✓ |
| Server-side computation / secrets | ✓ | – | – |
| Persistence across sessions and devices | ✓ (server) | browser only | browser only |
| Uploads / reading server folders | ✓ | – (browser file pickers only) | – (browser file pickers only) |
| Author commentary around the tool | – | ✓ | – |
| Works offline / e-mailable | – | if `embed-resources` | ✓ |

---

## 5. Status by project

| Project | Shiny | Quarto | HTML | Notes |
|---|---|---|---|---|
| QuantSkill | ✓ `run_app()`, `quantskill_app()` | ✓ `qs_export_quarto()`, `inst/quarto/` | ✓ `qs_export_html()`, `inst/html/quantskill.html` | Reference implementation. Secure grading in Shiny only. |
| lumenJourney, study story | ✓ `run_story()` | ✓ `story_quarto()`, `story_quarto_block()` | ✓ `export_story_html()` (+ PDF) | Reference implementation. The analyst **teal app** (`run_app()`) is Shiny-only, by nature. |
| DirectoR | ✓ `run_app()` (studio) | **gap** | **gap** | Outputs today are MP4/SRT/poster files. |
| RockShiny | ✓ `shiny::runApp()` | **gap** | **gap** | The highway is already dependency-free JS fed by chart JSON. |
| teal_neue | ✓ `run_app()` (teal) | **gap** | **gap** | The overview is already JSON → plain HTML/SVG. TLG outputs come with runnable code. |
| BlockR | ✓ `run_app()` (teal) | **gap** | **gap** | The canvas editor is plain JS. `blockr_compile()` gives complete R (and SAS) code. |

### 5.1 Plans for the gaps

Each plan reuses what the app already has. None requires a rewrite.

**DirectoR**
- *HTML:* `dr_export_html(project)`: one file per film with the film, captions (SRT → WebVTT
  `<track>`), poster, script and storyboard. A lighter variant inlines the engine's existing live
  preview (`preview.html`: stage + timeline + proxies) so the film plays without an MP4.
- *Quarto:* `dr_export_quarto(project)`: a "press kit" `.qmd` with the film (`{{< video >}}`), the
  voice-over script with timings, the storyboard as a table, and stills (`python -m director stills`).

**RockShiny**
- *HTML:* `rs_export_html(song, arrangement, instrument)`: chart JSON (`chart_json()`) + `inst/highway/`
  assets inline. It plays with guide tones (synthesised in the browser). The song audio is included
  only if the user has the right to redistribute it (DLV-22). Microphone scoring works in the browser;
  personal bests stay in `localStorage`.
- *Quarto:* `rs_quarto_block(song, …)`: a highway block inside a lesson document (practice notes,
  loops and sections as links that seek the player).

**teal_neue**
- *HTML:* `teal_neue_export_html(data)`: the **study at a glance** page (`teal_neue_overview()` JSON +
  the overview widgets from `teal_neue.js`) plus a static TLG appendix (`rtables::as_html()` tables,
  PNG graphs), with the filters stated.
- *Quarto:* `teal_neue_export_quarto(outputs, data)`: a report `.qmd` with one section per chosen TLG
  output, its **runnable code** (what "Show R code" gives) as chunks, and the overview as a raw-HTML block.

**BlockR**
- *HTML:* `blockr_export_html(canvas)`: a **read-only canvas** (`blockr_canvas.js` runs without Shiny,
  given the graph and a status payload) with the result rendered in, so reviewers can inspect every
  block offline.
- *Quarto:* `blockr_export_quarto(canvas)`: the canvas as a `.qmd`, with one chunk per stack from
  `blockr_compile()`, block summaries as prose, and optionally the SAS translation (`blockr_sas()`) as
  a non-executed chunk for double programming.

Acceptance for every plan: DLV-01 to DLV-32, and a "Delivery formats" table in the project's README
(status, entry points, capability matrix).
