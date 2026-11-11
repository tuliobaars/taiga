# HTML dependency and Bootstrap theme ----------------------------------------------------------

#' HTML dependency for a Taiga token sheet
#'
#' Attach the Lumen or Neue tokens to a Shiny UI, an R Markdown or Quarto document, or any
#' htmltools page. For Lumen, put your UI inside an element with the class `lm` (and
#' `data-theme="dark"` or `"paper"`, or the classes `lm-studio` / `lm-stage`). For Neue, the
#' tokens apply to the page (`html`), with `data-bs-theme="dark"` for dark mode.
#'
#' @param framework `"lumen"` or `"neue"`.
#' @return An [htmltools::htmlDependency()].
#' @seealso [taiga_css()], [taiga_bs_theme()]
#' @examples
#' dep <- taiga_dependency("neue")
#' dep$name
#' \dontrun{
#' shiny::fluidPage(taiga_dependency("lumen"), shiny::div(class = "lm", "Hello"))
#' }
#' @export
taiga_dependency <- function(framework = c("lumen", "neue")) {
  framework <- match.arg(framework)
  htmltools::htmlDependency(
    name = paste0("taiga-", framework), version = taiga_version(),
    src = c(file = dirname(taiga_css(framework))), stylesheet = basename(taiga_css(framework)), all_files = FALSE
  )
}

#' A bslib theme from Taiga tokens
#'
#' A Bootstrap 5 theme whose background, foreground, accent and font come from a Taiga theme, as
#' DirectoR and RockShiny set theirs with [bslib::bs_theme()]. For Neue products, the recommended
#' way is still to layer `neue-tokens.css` over the host's theme ([taiga_dependency()]); this
#' function is for new apps that start from bslib.
#'
#' @inheritParams taiga_tokens
#' @param ... Further arguments to [bslib::bs_theme()].
#' @return A `bs_theme` object.
#' @examples
#' \dontrun{
#' theme <- taiga_bs_theme("lumen", "studio")
#' bslib::page_fillable(theme = theme, "Hello")
#' }
#' @export
taiga_bs_theme <- function(framework = c("lumen", "neue"), theme = NULL, ...) {
  framework <- match.arg(framework)
  if (!requireNamespace("bslib", quietly = TRUE)) stop("taiga: taiga_bs_theme() needs the 'bslib' package", call. = FALSE)
  tk <- taiga_tokens(framework, theme)
  first_font <- function(stack) trimws(gsub("[\"']", "", strsplit(stack, ",", fixed = TRUE)[[1]]))
  if (framework == "lumen") {
    bslib::bs_theme(version = 5, bg = tk[["--lm-bg"]], fg = tk[["--lm-text"]], primary = tk[["--lm-accent"]],
                    base_font = bslib::font_collection(first_font(tk[["--lm-font"]])), ...)
  } else {
    bslib::bs_theme(version = 5, bg = tk[["--bs-body-bg"]], fg = tk[["--bs-body-color"]], primary = tk[["--tn-accent"]],
                    base_font = bslib::font_collection(c("Inter", "system-ui", "-apple-system", "Segoe UI", "Roboto", "sans-serif")),
                    "font-size-base" = "0.875rem", ...)
  }
}
