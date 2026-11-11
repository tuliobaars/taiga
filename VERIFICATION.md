# Verification

The automated checks are in `tools/verify.py` (workspace) and `tools/check.sh` (the taiga R package), with results in `tools/verify.json`. Run it again with
`PYTHONDONTWRITEBYTECODE=1 python3 tools/verify.py`.

## 1. Summary

| Deliverable | Result |
|---|---|
| Styleguides | [Lumen](inst/guides/lumen/STYLEGUIDE.md), [Neue](inst/guides/neue/STYLEGUIDE.md): foundations, components, dialects, do/don't, built from extracted values |
| Requirements | [Lumen](inst/guides/lumen/REQUIREMENTS.md), [Neue](inst/guides/neue/REQUIREMENTS.md): RFC 2119 requirements with IDs, a conformance table for the current apps, acceptance checklists |
| Delivery model | [DELIVERY_MODEL.md](inst/guides/DELIVERY_MODEL.md): requirements DLV-01 to DLV-32, status per project, plans for the gaps |
| Token data | `inst/extdata/tokens/<app>.json` (6 apps), `summary.md`, `contrast.md` (76 pairs); starter sheets `inst/css/lumen-tokens.css`, `inst/css/neue-tokens.css` (both parse without errors) |
| Feature screenshots | **53** images at 2880 × 1800 (1440 × 900 @2×): QuantSkill 10 and lumenJourney 10 from the **live** shipped builds; DirectoR 9, RockShiny 6, teal_neue 9 and BlockR 9 from **benches** (§3). Every image is in a manifest with its provenance. Manifest and files match in every project. |
| Embedded in docs | Each project: `docs/DESIGN.md` (full gallery, look, tokens, delivery) and a "Feature tour" section in `README.md` (6 images, delivery table, links) |
| Triple-format delivery | Specified in every project's README and DESIGN.md. Shipped today: QuantSkill and lumenJourney (story). Specified with a plan, not yet built: DirectoR, RockShiny, teal_neue, BlockR. |
| Promo video | `DirectoR/media/DirectoR_teaser_30s.mp4`, made with QuantSkill's video utility: 1920 × 1080, 60 fps, H.264 High + AAC 48 kHz, 30.0 s, −14.0 LUFS, −1.9 dBTP, with a poster and `media/README.md` |
| Links | 226 relative links and images in all 70 Markdown files of the workspace: all resolve (`verify.py`) |
| R package | `taiga` 0.1.0 (this folder): 26 exported functions, 27 help pages, a vignette, 90 test expectations; checked in webR by `tools/check.sh` (§8) |
| Source code | **Application code unchanged.** Against the workspace's baseline commit, the only code files that differ are QuantSkill's two screenshot generators (`dev/screens.py`, `dev/simulate/team_reports.py`), changed at your request to write JPEG (§9). The other modified files are documentation: the six `README.md`, `teal_neue/preview/README.md` and `RockShiny/docs/IMPLEMENTATION_GUIDE.md` (§5, §9). |

## 2. Environment, and how it shaped the work

- **No R runtime, and no way to install one.** CRAN, r-universe, Posit Package Manager, conda-forge,
  GitHub and the webR package repository were unreachable. PyPI and npm were reachable. So:
  - QuantSkill and lumenJourney were photographed from their shipped standalone HTML builds (the same
    front end as their Shiny apps).
  - The four Shiny-only apps were photographed on **test benches** (§3). The bench runs the apps' own R
    UI code in **webR** (base R 4.6 compiled to WebAssembly, from npm) with a markup stand-in for
    htmltools, shiny and bslib.
- **Python engines ran for real.** DirectoR's film engine (`inst/engine`) and RockShiny's reference
  parser (`tests/reference`) are Python and ran unmodified: scouting, planning, recording and rendering
  real films, and parsing the bundled songs.
- **Canonical sources.** Tokens were extracted from the canonical stylesheets only. Stale copies were
  excluded: QuantSkill `src/`, `www/`, `build/`, `dist/` (older builds; `srcjs/` is the source per
  `data-raw/build.py` and is byte-identical to `inst/app/www/quantskill.css`), and the nested older
  package `lumenJourney/lumenJourney/` (v0.2.0, "lumen").

## 3. How each screenshot set was made

| App | Provenance | What is real | What is a stand-in |
|---|---|---|---|
| QuantSkill | live | `inst/html/quantskill.html`, driven with QuantSkill's own flows (`dev/screens.py`, imported, with its output redirected). Seeded randomness. Team dashboard from the 47-person simulated cohort in `examples/`. | – |
| lumenJourney | live | Study-story pages assembled by the project's `tools/story-dev/build.mjs` (the same assembly as `story_html()`) from the current `inst/story/`. | – (the study is fictitious by design, as the app itself says) |
| DirectoR | bench | `app_ui()` and every `renderUI` output from DirectoR's R code; `director.css/js`. Films are real engine projects (scout, storyboard, footage, preview, draft renders). | Job-progress messages in the autopilot and render-dock stills. Voice providers show this machine's real doctor result. |
| RockShiny | bench | `app.R`'s `ui()`; the whole highway; charts parsed from the bundled songs by RockShiny's reference implementation. | Click-track audio (as in its frontend tests). Selects filled as `updateSelectInput()` would. |
| teal_neue | bench | Header, 58-module nav, index, **study overview computed by `R/overview.R` on the bundled data**, TLG pages and headers, the code dialog, and all of `teal_neue.js`'s overlays. | teal's chrome markup. The Kaplan-Meier module view (layout and a base-R plot of the real ADTTE data), labelled so in its caption. |
| BlockR | bench | Canvas UI and config, template graphs, **block statuses from `blockr_run()`**, compiled R and SAS code, and all of the canvas JS. | Base-R data verbs (real semantics: AET02's ADAE filter gives 1,586 rows, matching BlockR's own preview made with dplyr). Layout, table and plot blocks show their kind only. Data previews are plain tables of real rows. |

Details: [`tools/bench/README.md`](tools/bench/README.md). The bench approach is the one the teal_neue
and BlockR projects used for their own `preview/` images.

Quality review: every image was inspected, and 9 shots were re-taken to fix problems found:
- lumenJourney: cropped sections, journey steps caught mid-fade, the light theme scrolled to the wrong
  place.
- QuantSkill: the question shot depended on a random draw, and a screenshot timed out.
- teal_neue: one shot had an empty TLG output area and was replaced by the code dialog.
- BlockR: two interactions needed real mouse events.
- DirectoR: sandbox paths on the film cards were replaced by real `~/code/…` sources.

All capture scripts fail loudly on page errors. The final runs had none.

## 4. The promo video

- **Utility.** QuantSkill's `dev/video` modules (`recorder`, `stage/stage.js`, `render`, `music`, `ff`,
  `fonts`) are imported and never edited. DirectoR-specific parts (`tools/video/directoR/`): the shot
  script, the timeline, the mux. QuantSkill's `make.py` cannot be reused for the mux because it
  hard-codes QuantSkill's file names.
- **Checks.** `ffprobe`: H.264 High, 1920 × 1080, 60/1 fps, yuv420p, AAC LC 48 kHz stereo, 30.000 s.
  `ebur128`: −14.0 LUFS integrated, −1.9 dBTP. (QuantSkill's own teaser measures −13.9 LUFS, −1.0 dBTP.)
- **Audio fixes.** The mux measures in two passes and adds a limiter, because the AAC encoder added
  about 1 dB of overshoot over the −1 dBTP target. UI click sounds sit on the seven real cursor clicks:
  marker names that are not clicks were renamed, after a first mix had put ticks on the autopilot
  phase markers.
- **Contents check.** A contact sheet of 15 frames was reviewed. Disclosures (bench footage, real films
  inside it, simulated progress texts, original music) are in `DirectoR/media/README.md`.

## 5. Integrity: what was written, and where

| Where | What |
|---|---|
| `teal_neue/preview/README.md`, `RockShiny/docs/IMPLEMENTATION_GUIDE.md`, QuantSkill `dev/screens.py` and `dev/simulate/team_reports.py` | `.png` references changed to the JPEG files (§9). |
| `<project>/README.md` ×6 | One marked section (`<!-- taiga:begin/end -->`): Feature tour, delivery table, links. **QuantSkill only:** 10 broken image links fixed (`man/figures/*.png` → the existing `*.jpeg`), the only edit outside the section. |
| `<project>/docs/features/`, `<project>/docs/DESIGN.md` ×6 | New. |
| `DirectoR/media/` | New: video, poster, README. |
| `taiga-design-system/` | New: this folder (`tools/bench/node_modules/` is git-ignored; `npm install` restores it). |

**Incident, fixed.** During the work, Python bytecode caches were written into
`QuantSkill/dev/__pycache__`, `QuantSkill/dev/video/__pycache__` (from importing QuantSkill's `dev`
modules) and `DirectoR/inst/engine/director/__pycache__/*.cpython-312.pyc` (from one early
`python3 -m director --help` run without `PYTHONDONTWRITEBYTECODE`). They were deleted. DirectoR's
original `*.cpython-313.pyc` files pre-date the baseline and are untouched. All scripts now set
`sys.dont_write_bytecode`, and `verify.py` scans the project folders on disk (git-ignored files
included) for anything written after the baseline. Also, `git status` refreshed the stat cache
(`.git/index`) of four nested project repositories. No content changed.

## 6. Issues found in the codebases (not fixed: reported)

| Project | Issue |
|---|---|
| lumenJourney, teal_neue, BlockR | Their `.gitignore` ignores `docs/`, so the new `docs/features/` and `docs/DESIGN.md` are on disk but **not picked up by git** in those repos. Either `git add -f docs/features docs/DESIGN.md`, or change `docs/` to `docs/*` and add `!docs/features/` and `!docs/DESIGN.md`. |
| DirectoR | `.Rbuildignore` has no `^docs$`, `^media$` or `^DirectoR_showcase$`, so these folders would go into the package tarball (and R CMD check notes non-standard top-level folders). The other five projects already ignore `docs/`. |
| DirectoR | `DirectoR_showcase/README.md` lists films (`*.mp4`) and `studio/` screenshots that are not in the upload (only `.srt` and script files are). |
| DirectoR | `director.js` plays bundled previews from `www/demos/music_*.mp3`, but `inst/app/www/demos/` is not in the package. The app falls back to composing previews on the server. |
| DirectoR | `inst/engine/director/render.py` line 19: `SyntaxWarning: invalid escape sequence '\d'` (Python ≥ 3.12). |
| DirectoR, RockShiny | No `prefers-reduced-motion` rules. DirectoR has no `:focus-visible` styles (LUM-M-02, LUM-A-02). |
| lumenJourney | `DESCRIPTION` says `Package: lumenJourney` (0.3.0), but the README (`library(lumen)`), `app.R`, `app_story.R` and `story.R` call `lumen::`, and NEWS is headed `lumen 0.2.0`. Those calls fail once the package is installed as lumenJourney. A nested older copy `lumenJourney/lumenJourney/` (v0.2.0) sits inside the package folder. |
| QuantSkill | README image links pointed to `.png` files that exist only as `.jpeg` (**fixed**, with the generators; §9). Stale older builds in `src/`, `www/`, `build/`, `dist/`. A stray `.Rprofle` (typo copy of `.Rprofile`). |
| RockShiny | `tests/reference/make_fixtures.py` reads its songs from `songs/`, which holds one song; the others are in `songs_all/`. |
| All | Contrast (from `inst/extdata/tokens/contrast.md`): tertiary text tokens below 4.5:1; Neue `--tn-ink-4` 2.41–2.64:1 in light mode; white on the teal accent 3.98:1; white on QuantSkill's dark accent 3.65:1. These are covered as rules in the styleguides and requirements. |

## 7. Limitations

- Bench screenshots are faithful to the apps' markup, styles and scripts, but they are not a running
  Shiny session. CSS that ships inside shiny and bslib (sidebar layout, slider skin, radio styling) is
  approximated in `tools/bench/assets/bench.css`, and bslib's dark-mode web component is drawn as a plain
  icon button. Re-take these images against a live R session when one is available: the capture
  scripts only need a URL.
- The DirectoR teaser is music-only. No voice-over was produced, because no TTS voice was available.
  QuantSkill's pipeline supports a launch film with voice once one is.
- Links from the project READMEs to `../taiga-design-system/` assume this workspace layout. If the
  projects are published separately, copy the relevant styleguide or link to its published URL.

## 8. The taiga R package

The design system is an R package, `taiga` (folder `taiga-design-system/`, like `teal_neue/` holds
`teal.neue`). The guides are in `inst/guides/`, the token sheets in `inst/css/`, the extracted values in
`inst/extdata/tokens/`, and an example front end in `inst/examples/hello/`. Development tooling stays
in `tools/` (build-ignored).

No R runtime was available, so `R CMD check` could not run. Instead:

- **Documentation.** `man/*.Rd` and `NAMESPACE` are generated from the roxygen comments by
  `tools/document.py`. DESCRIPTION sets `Roxygen: list(markdown = TRUE)`, so `devtools::document()`
  regenerates them from the same comments.
- **Checks** (`tools/check.sh`, in webR; htmltools and jsonlite through the bench stand-in, testthat through
  QuantSkill's `dev/tests/testthat_shim.R`). Result: **CHECK: OK**.
  - DESCRIPTION fields.
  - All 8 R files parse and are ASCII.
  - `tools::checkRd` passes on all 27 Rd files.
  - Every export exists and is documented.
  - All examples run (26 help pages; `\dontrun` for Shiny and bslib).
  - The vignette's 10 evaluated chunks run.
  - 90 test expectations pass, 0 fail.
- **The checks found a bug.** `taiga_css_vars()` kept multi-line comments in selectors. It was fixed and
  a test was added.
- **End to end.** `taiga_export_html()` output of the example front end opens in Chromium without errors,
  in daylight and dark themes. `taiga_export_quarto()` writes a valid `.qmd` (`embed-resources`, a raw-HTML
  block). It could not be rendered, because `quarto` is not installed here.
- **To do where R is available.** Run `devtools::document()`, `devtools::test()` and
  `R CMD check --as-cran`. The Shiny and bslib paths (`taiga_shiny_app()`, `taiga_bs_theme()`,
  `taiga_dependency()` in a live page) were only checked against the stand-ins.

## 9. `.png` references changed to the JPEG files

The README figures were converted to JPEG to reduce file size. References were corrected where the
`.png` target no longer exists and a JPEG of the same image does:

| File | Change |
|---|---|
| `QuantSkill/README.md` | 10 image links `man/figures/*.png` → `*.jpeg` |
| `teal_neue/preview/README.md` | 12 file names `*.png` → `* Medium.jpeg`. The two `*.gif` entries were converted too: `home.gif` → `home Medium 2.jpeg`, `interaction.gif` → `interaction Medium.jpeg` (noted as stills). |
| `QuantSkill/dev/screens.py`, `QuantSkill/dev/simulate/team_reports.py` | The generators of those figures now write JPEG under the current names (`man/figures/<name>.jpeg`, quality 82; `docs/screenshots/<name> Large.jpeg`, 1280 px wide, quality 80), so a regeneration keeps the README links valid. These are the only code files changed, at your request. |
| `RockShiny/docs/IMPLEMENTATION_GUIDE.md` | Its 4 images (`highway.png`, `highway-neck.png`, `piano.png`, `harmonica.png`) never existed in any format. They now point at the new feature screenshots (`features/01-highway.jpg`, `02-bass.jpg` for the ghost neck and headstock, `04-piano.jpg`, `05-harmonica.jpg`). This is a judgement call: revert it if you have the originals. |

Left unchanged, because they are not references to missing files: `.png` names in code that writes
temporary or test files, file names inside quiz questions, remote URLs, and files that exist as `.png`
(`favicon.png`, the video posters, lumenJourney's `man/figures/story-*.png`). After the changes, every
relative link and image in every Markdown file of the workspace resolves.

