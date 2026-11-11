# Test benches: screenshots of Shiny apps without an R runtime

Four of the six apps (DirectoR, RockShiny, teal_neue, BlockR) are Shiny apps with no standalone
build, and no R package repository was reachable where this work was done (CRAN, r-universe, Posit
Package Manager and the webR package repository were all blocked; only PyPI and npm were open). So these
apps are photographed on **benches**: pages that use as much of the real app as can run, with the rest
replaced by clearly documented stand-ins. teal_neue's and BlockR's own `preview/` images were made the
same way (their `preview/README.md` calls it a test bench).

QuantSkill and lumenJourney need no bench. They ship standalone HTML builds of the same front end,
which are photographed directly (`provenance: "live"` in their manifests).

## How a bench is built

1. **R UI code, unmodified, in webR.** `run_r.mjs` runs base R 4.6 compiled to WebAssembly (the npm
   `webr` package, offline). It copies the app's files into webR's virtual file system (the app folders
   are only read) and sources the app's own `R/*.R`.
2. **`shim.R`: a markup stand-in for htmltools, shiny, bslib and jsonlite.** The apps call
   `shiny::uiOutput()`, `bslib::card()`, `htmltools::tags$div()` and so on. `::` is an ordinary R
   function, so `shim.R` defines `::` to route those calls to base-R functions that emit the same tags,
   classes and attributes as shiny 1.8 / bslib 0.8 with Bootstrap 5 (inputs, outputs, `tabsetPanel`,
   `page_sidebar`, `card`, `accordion`, `input_switch`, `modalDialog`…). `renderUI` returns a thunk.
   Observers are recorded, not run: a driver can fire one, so a dialog is built by the app's own handler.
   `moduleServer` runs the module server once. It also provides a base-R JSON reader and writer with
   `simplifyVector = FALSE` and `dataframe = "columns"` semantics.
3. **Drivers** (`director_driver.R`, `rockshiny_driver.R`, `neue_driver.R`) call the apps' own
   functions: `app_ui()`, the `srv_*` renderers, `ui()` from `app.R`, `teal_neue_header()`,
   `teal_neue_index()`, `teal_neue_app_overview()`, `ui_tlg_catalog()`, `srv_tlg_catalog()`,
   `ui_blockr_canvas()`, `blockr_template_graph()`, `blockr_run()`, `blockr_compile()`, `blockr_sas()`,
   `blockr_status_payload()`. They write the HTML and the server messages to `/tmp/taiga-bench/<app>/`.
4. **`sites.py`** assembles a static site per app: Bootstrap 5.3 from npm with the app's own bslib
   theme values as CSS variables, `assets/bench.css` (approximations of CSS that ships inside shiny and
   bslib: sidebar layout, the ionRangeSlider "shiny" skin, radio groups), the app's own stylesheets,
   scripts and fonts (loaded last, as in the app), and `assets/bench.js`, a minimal client stand-in
   for shiny.js. It lets the app's scripts register their bindings and message handlers, and the capture
   scripts change state by calling *the app's own handlers* (for example `dr-nav`, `dr-job`,
   `blockr-graph`, `blockr-status`, `rs-highway`).
5. **Capture** (`../screens/*.py`) drives the site in Chromium.

## What is real and what is a stand-in

| App | Real (the app's own code, assets, data) | Stand-in |
|---|---|---|
| **DirectoR** | `app_ui()`; every `renderUI` output of `srv_library`, `srv_source`, `srv_story`, `srv_shots`, `srv_sound`, `srv_look`, `srv_export`; `director.css`, `director.js`, Inter. The **films are real DirectoR engine projects**: `python -m director scout / plan / capture / timeline / render` run on QuantSkill's and lumenJourney's standalone builds (from `~/code/…`) and on BlockR's screenshots (a "screenshots & recordings" film). Scout screens, storyboards (written by DirectoR's built-in copywriter from the READMEs), footage, live preview, draft renders and doctor output are all genuine. Music previews are made by the engine's `demo` command. | Job progress in the autopilot and render-dock stills is sent as `dr-job` messages with texts of the kind the engine reports. Voice providers show this machine's real doctor result (only "Your voice" available). |
| **RockShiny** | `ui()` from `app.R` with `R/mod_*.R`; the highway (`inst/highway/*`: binding, clock, renderers, overlays); charts parsed from the bundled songs in `songs_all/` by RockShiny's **Python reference implementation** (`tests/reference/rockshiny_ref.py`, `instruments_ref.py`, the test mirror of its R parser); library labels, arrangements and sections as the server builds them. | Audio is a click track at every note onset (as in the project's frontend tests), because Wwise audio needs vgmstream. The library lists `songs_all/` (a legitimate `rockshiny.library_dir`). The selects are filled the way `updateSelectInput()` would fill them. |
| **teal_neue** | Header, footer, module nav (58 modules from `teal_neue_modules()`), command-bar index, **study overview** (`R/overview.R`, base R, computed on the bundled ADaM cache `cache/lumen_adam.rds`), TLG Catalog pages, their headers (`srv_tlg_catalog()`) and "Show R code" dialog; `teal_neue.css/js`, fonts. The command bar, Where to?, Appearance panel, shortcut sheet, breadcrumbs, hover tools and dark mode are the app's JS. | teal's page chrome mirrors its Bootstrap markup (tabs with dropdown menus). The Kaplan-Meier module view is a bench layout (encodings, plot card, filter panel) with a **base-R plot of the real ADTTE OS data** in the app's arm colours (teal.modules.clinical and ggplot2 are not available). The TLG output bodies (tern) are not shown. |
| **BlockR** | Header, footer, module nav, the canvas page and its config (block registry, 135 templates), **template graphs** (`blockr_template_graph()`), **block statuses** (`blockr_run()`), **compiled R code** (`blockr_compile()`), **SAS code** (`blockr_sas()`), status payloads; `blockr*.css/js`, `blockr_tutorial.js`, fonts. The canvas, inspector, explanations, "+" menu and tutorial are the app's JS. | `blockr_standins.R`: the data verbs (`filter`, `mutate`, `select`, `arrange`, `distinct`, `count`, `left_join`, `df_explicit_na`, `var_relabel`, `as_listing`) are base-R versions with real semantics, so data-block row and column counts are true. (AET02's ADAE filter gives 1,586 rows, the same as BlockR's own preview made with dplyr.) Layout, table and plot functions return classed objects without content: those blocks show their kind, and no table dimensions are invented. Data previews are plain tables of the real first rows (the app uses DT). |

## Rebuild

```sh
cd taiga-design-system/tools/bench && npm install            # webR, Bootstrap, jQuery, ion.rangeSlider, Font Awesome
bash build_director.sh                                         # DirectoR: engine projects + webR render + site
bash build_rockshiny.sh                                        # RockShiny: charts and labels, webR render, site
bash build_neue.sh teal_neue && bash build_neue.sh BlockR      # teal_neue / BlockR
```

Nothing in the six project folders is written by these steps (bytecode writing is switched off for the
Python engines). Outputs go to `/tmp/taiga-bench/`, `/tmp/taiga-dr/`, `~/code/` (DirectoR's sources).
