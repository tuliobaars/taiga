# taiga 0.1.0

* `taiga_shiny_app()` takes extra UI in `...` before `server` and `title`, so
  `taiga_shiny_app(f, taiga_dependency("lumen"))` works. Its default server works in Shiny: a server
  whose body is `NULL` is skipped by Shiny. The app removes the page margin (`reset = TRUE`), as
  `taiga_html_page()` does.
* `taiga_guide()` uses `file.show()` from base R (it was called as `utils::file.show()`).
* Checked with `R CMD check` (R 4.3.3 and R 4.5.2): Status OK.
* Tests run from the sources (`test-build.R`) report two things that make `R CMD build` lose the
  vignette: a `.Rbuildignore` line that matches needed files, and files dated in the future (then
  `tools::buildVignettes()` deletes `vignettes/taiga.Rmd` as an intermediate file).
* `.Rbuildignore` also ignores `renv/` and `renv.lock`.

* The guides and the README carry their own pictures (`inst/guides/img/`): thumbnails that link to the
  full image. The delivery model guide has one picture per format and per reference implementation
  (Lumen: QuantSkill, lumenJourney, DirectoR, RockShiny; Neue: teal_neue, BlockR), an architecture
  diagram and a diagram of the Shiny protocol.

* First release: the Taiga design system as an R package.
* Guides (`taiga_guide()`, `taiga_guides()`): Lumen and Neue styleguides, requirements for new
  projects, and the Shiny · Quarto · HTML delivery model, installed as Markdown.
* Tokens: `taiga_css()`, `taiga_tokens()`, `taiga_themes()`, `taiga_css_vars()` (a base-R reader of
  CSS custom properties), `taiga_dependency()` and `taiga_bs_theme()`.
* Extracted design values of the six Taiga applications: `taiga_extracted()`.
* Contrast: `taiga_luminance()`, `taiga_contrast()`, `taiga_wcag()`, `taiga_contrast_audit()`.
* Delivery model: `taiga_fragment()`, `taiga_json_script()`, `taiga_check_assets()`,
  `taiga_html_page()`, `taiga_export_html()`, `taiga_quarto_block()`, `taiga_export_quarto()`,
  `taiga_shiny_app()`, `taiga_capabilities()`, and an example front end (`taiga_example()`).
* Registry: `taiga_frameworks()`, `taiga_apps()`, `taiga_choose_framework()`.
