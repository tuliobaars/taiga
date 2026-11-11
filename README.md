# taiga: the Taiga design system for Shiny, Quarto and HTML

**taiga** is an R package. It holds the design system of six Taiga applications, in two frameworks:

| Framework | Voice | Applications | Guides |
|---|---|---|---|
| **Lumen** | Cinematic, high-contrast, glass-driven | QuantSkill · lumenJourney · DirectoR · RockShiny | [styleguide](inst/guides/lumen/STYLEGUIDE.md) · [requirements](inst/guides/lumen/REQUIREMENTS.md) |
| **Neue** | Minimalist, high-density enterprise | teal_neue · BlockR | [styleguide](inst/guides/neue/STYLEGUIDE.md) · [requirements](inst/guides/neue/REQUIREMENTS.md) |

Every Taiga project ships one front end three ways, as a Shiny app, a Quarto document and a standalone
HTML file: the [delivery model](inst/guides/DELIVERY_MODEL.md).

| | | |
|---|---|---|
| ![](../QuantSkill/docs/features/01-landing.jpg) QuantSkill | ![](../lumenJourney/docs/features/03-journey.jpg) lumenJourney | ![](../DirectoR/docs/features/04-story.jpg) DirectoR |
| ![](../RockShiny/docs/features/01-highway.jpg) RockShiny | ![](../teal_neue/docs/features/01-home.jpg) teal_neue | ![](../BlockR/docs/features/01-canvas-template.jpg) BlockR |

[![DirectoR teaser](../DirectoR/media/DirectoR_teaser_30s_poster.png)](../DirectoR/media/DirectoR_teaser_30s.mp4)
DirectoR teaser: 30 s, 1080p60 ([`DirectoR/media/`](../DirectoR/media/README.md)).

## Install

```r
# from the workspace folder (dependencies: htmltools, jsonlite; suggested: shiny, bslib, knitr, rmarkdown, testthat)
install.packages("taiga-design-system", repos = NULL, type = "source")   # or devtools::install("taiga-design-system")
library(taiga)
```

## Use

```r
# which framework?
taiga_choose_framework(reader = "analysts", session = "self-directed", density = "high")   # "neue"

# the guides
taiga_guide("lumen-styleguide")            # also: "lumen-requirements", "neue-styleguide", "neue-requirements", "delivery"

# tokens: CSS file, R vector, HTML dependency, bslib theme
taiga_tokens("neue", "dark")[c("--tn-panel", "--tn-ink", "--tn-accent")]
shiny::fluidPage(taiga_dependency("lumen"), shiny::div(class = "lm", `data-theme` = "dark", "..."))
bslib::page_fillable(theme = taiga_bs_theme("lumen", "studio"), "...")

# contrast
taiga_contrast_audit("lumen", "paper")
taiga_contrast("#ffffff", "#0e8f83")       # 3.98: AA for large text and UI only

# one front end, three formats
ex <- taiga_example()
data <- list(title = "Hello, Taiga", items = c("Shiny", "Quarto", "HTML"))
taiga_export_html(taiga_fragment("hello", css = ex$css, js = ex$js, data = data, framework = "lumen"), "hello.html")
taiga_export_quarto(taiga_fragment("hello", mode = "quarto", css = ex$css, js = ex$js, data = data, framework = "lumen"), "hello-quarto")
shiny::runApp(taiga_shiny_app(taiga_fragment("hello", mode = "shiny", css = ex$css, js = ex$js, data = data, framework = "lumen")))
```

See `vignette("taiga")` for a walkthrough.

| Area | Functions |
|---|---|
| Guides | `taiga_guides()`, `taiga_guide()` |
| Frameworks and applications | `taiga_frameworks()`, `taiga_apps()` (incl. the Shiny / Quarto / HTML status of each), `taiga_choose_framework()` |
| Tokens | `taiga_css()`, `taiga_themes()`, `taiga_tokens()`, `taiga_css_vars()` (reads custom properties from any stylesheet), `taiga_dependency()`, `taiga_bs_theme()` |
| Extracted values | `taiga_extracted()`: tokens, colours, type, radii, glass, motion and components of each application |
| Contrast | `taiga_luminance()`, `taiga_contrast()`, `taiga_wcag()`, `taiga_contrast_audit()` |
| Delivery | `taiga_fragment()`, `taiga_json_script()`, `taiga_check_assets()`, `taiga_html_page()`, `taiga_export_html()`, `taiga_quarto_block()`, `taiga_export_quarto()`, `taiga_shiny_app()`, `taiga_capabilities()`, `taiga_example()` |

## Package layout

```
DESCRIPTION  NAMESPACE  LICENSE  NEWS.md  taiga.Rproj
R/                       the functions (roxygen comments are the documentation source)
man/                     help pages (generated from R/ by tools/document.py, roxygen2-compatible)
inst/guides/             the guides: lumen/, neue/ (STYLEGUIDE.md, REQUIREMENTS.md), DELIVERY_MODEL.md
inst/css/                lumen-tokens.css, neue-tokens.css
inst/extdata/tokens/     values extracted from the six applications (<app>.json, summary.md, contrast.md)
inst/examples/hello/     a host-safe example front end
tests/testthat/          tests
vignettes/taiga.Rmd      getting started
tools/                   development only (not in the package build): extraction, screenshots, benches, video, checks
VERIFICATION.md          how the screenshots, video and documents of the workspace were made and checked
```

Feature screenshots of each application are in `<project>/docs/features/`. Each project's
`docs/DESIGN.md` covers its dialect, its tokens, its gallery and its delivery status.

## Development

```sh
python3 tools/document.py                      # man/ and NAMESPACE from the roxygen comments (or devtools::document() in R)
bash tools/check.sh                            # without R: DESCRIPTION, code, Rd, examples, vignette and tests, in webR
R CMD build . && R CMD check taiga_0.1.0.tar.gz   # with R
```

The extraction and screenshot tooling (Python, Node):

```sh
pip install tinycss2 playwright pillow numpy scipy fonttools brotli cryptography
(cd tools/bench && npm install)
python3 tools/extract_tokens.py && python3 tools/contrast_audit.py && python3 tools/make_neue_tokens.py
python3 tools/screens/quantskill.py && python3 tools/screens/lumen_journey.py
bash tools/bench/build_director.sh && python3 tools/screens/director.py
bash tools/bench/build_rockshiny.sh && python3 tools/screens/rockshiny.py
bash tools/bench/build_neue.sh teal_neue && python3 tools/screens/teal_neue.py
bash tools/bench/build_neue.sh BlockR && python3 tools/screens/blockr.py
python3 tools/video/directoR/make_promo.py
python3 tools/write_app_docs.py && PYTHONDONTWRITEBYTECODE=1 python3 tools/verify.py
```

The tools only read the six projects. They write to `<project>/docs/`, `<project>/README.md` (one
marked section), `DirectoR/media/`, this folder, and temporary folders under `/tmp`.
