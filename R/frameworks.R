# Frameworks and applications ----------------------------------------------------------------

#' The Taiga frameworks
#'
#' Lumen and Neue, with their voice, their reference applications and the files that describe them.
#'
#' @return A data frame with one row per framework: `framework`, `name`, `voice`, `apps`
#'   (comma-separated), `styleguide` and `requirements` (topics for [taiga_guide()]) and `tokens`
#'   (topic for [taiga_css()]).
#' @seealso [taiga_apps()], [taiga_choose_framework()], [taiga_guide()]
#' @examples
#' taiga_frameworks()
#' @export
taiga_frameworks <- function() {
  data.frame(
    framework = c("lumen", "neue"),
    name = c("Lumen", "Neue"),
    voice = c("Cinematic, high-contrast, glass-driven", "Minimalist, high-density enterprise"),
    apps = c("QuantSkill, lumenJourney, DirectoR, RockShiny", "teal_neue, BlockR"),
    styleguide = c("lumen-styleguide", "neue-styleguide"),
    requirements = c("lumen-requirements", "neue-requirements"),
    tokens = c("lumen", "neue"),
    stringsAsFactors = FALSE
  )
}

#' The Taiga applications
#'
#' The six applications the design system was extracted from: their framework, dialect, default
#' theme and the status of the three delivery formats (Shiny, Quarto, standalone HTML). The statuses
#' are `"shipped"` or `"specified"`: specified, with a plan in the delivery model guide
#' (`taiga_guide("delivery")`, section 5.1), but not yet built.
#'
#' @return A data frame with one row per application: `app`, `package`, `version`, `framework`,
#'   `dialect`, `default_theme`, `shiny`, `quarto`, `html`, and the entry points `shiny_entry`,
#'   `quarto_entry` and `html_entry`.
#' @seealso [taiga_frameworks()], [taiga_capabilities()]
#' @examples
#' apps <- taiga_apps()
#' apps[, c("app", "framework", "shiny", "quarto", "html")]
#' # projects that still have a format to build
#' apps$app[apps$quarto != "shipped" | apps$html != "shipped"]
#' @export
taiga_apps <- function() {
  s <- "shipped"; p <- "specified"
  data.frame(
    app = c("QuantSkill", "lumenJourney", "DirectoR", "RockShiny", "teal_neue", "BlockR"),
    package = c("quantskill", "lumenJourney", "DirectoR", "RockShiny", "teal.neue", "BlockR"),
    version = c("2.3.0", "0.3.0", "0.1.3", "0.1.0", "0.2.0", "0.1.3"),
    framework = c("lumen", "lumen", "lumen", "lumen", "neue", "neue"),
    dialect = c("Daylight glass", "Cinema story and paper", "Studio dark", "Stage dark",
                "Instrument, ink-blue dark", "Instrument canvas, lifted-slate dark"),
    default_theme = c("light", "dark", "dark", "dark", "light", "light"),
    shiny = c(s, s, s, s, s, s),
    quarto = c(s, s, p, p, p, p),
    html = c(s, s, p, p, p, p),
    shiny_entry = c("run_app(), quantskill_app()", "run_story()", "run_app(), director_app()", "shiny::runApp()",
                    "run_app(), teal_neue_app()", "run_app(), blockr_app()"),
    quarto_entry = c("qs_export_quarto()", "story_quarto(), story_quarto_block()", "dr_export_quarto() (planned)",
                     "rs_quarto_block() (planned)", "teal_neue_export_quarto() (planned)", "blockr_export_quarto() (planned)"),
    html_entry = c("qs_export_html()", "export_story_html()", "dr_export_html() (planned)",
                   "rs_export_html() (planned)", "teal_neue_export_html() (planned)", "blockr_export_html() (planned)"),
    stringsAsFactors = FALSE
  )
}

#' Choose a framework for a new project
#'
#' Applies the decision table of the requirements guides (section 0 of
#' `taiga_guide("lumen-requirements")`). Lumen fits products that *present* (short, guided sessions
#' for stakeholders, low density). Neue fits products people *work* in (long, self-directed sessions
#' for analysts, high density).
#'
#' @param reader Primary reader: `"stakeholders"` (or candidates, players, clients) or
#'   `"analysts"` (or programmers, statisticians).
#' @param session Session shape: `"guided"` (minutes, linear or story) or `"self-directed"`
#'   (hours, non-linear).
#' @param density Screen density: `"low"` (one idea per view) or `"high"` (many controls and
#'   outputs per view).
#' @return `"lumen"` or `"neue"`, with an attribute `score`: the number of signals, out of 3, that
#'   point to the chosen framework.
#' @examples
#' taiga_choose_framework("stakeholders", "guided", "low")
#' taiga_choose_framework("analysts", "self-directed", "high")
#' @export
taiga_choose_framework <- function(reader = c("stakeholders", "analysts"),
                                   session = c("guided", "self-directed"),
                                   density = c("low", "high")) {
  reader <- match.arg(reader); session <- match.arg(session); density <- match.arg(density)
  lumen <- sum(reader == "stakeholders", session == "guided", density == "low")
  out <- if (lumen >= 2) "lumen" else "neue"
  structure(out, score = if (out == "lumen") lumen else 3L - lumen)
}
