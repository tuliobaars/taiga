#' taiga: the Taiga design system for Shiny, Quarto and HTML
#'
#' Taiga has two frameworks, extracted from six Taiga applications. **Lumen** is cinematic,
#' high-contrast and glass-driven (QuantSkill, lumenJourney, DirectoR, RockShiny). **Neue** is
#' minimalist, high-density and enterprise (teal_neue, BlockR). The package ships:
#'
#' - the styleguides, requirements and delivery model as Markdown guides: [taiga_guide()];
#' - design-token sheets for both frameworks, as files, as R vectors and as an HTML dependency:
#'   [taiga_css()], [taiga_tokens()], [taiga_dependency()], [taiga_bs_theme()];
#' - the values extracted from the six applications: [taiga_extracted()];
#' - WCAG contrast tools: [taiga_contrast()], [taiga_contrast_audit()];
#' - helpers for the triple-format delivery model (one front end, shipped as a Shiny app, a Quarto
#'   document and a standalone HTML file): [taiga_fragment()], [taiga_export_html()],
#'   [taiga_export_quarto()], [taiga_shiny_app()], [taiga_json_script()], [taiga_check_assets()];
#' - the framework and application registry: [taiga_frameworks()], [taiga_apps()],
#'   [taiga_choose_framework()].
#'
#' @keywords internal
"_PACKAGE"
