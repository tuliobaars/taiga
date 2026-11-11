# Contrast (WCAG 2.x) -------------------------------------------------------------------------

#' Relative luminance of colours
#'
#' @param col Colours: hex (`"#rgb"`, `"#rrggbb"`, `"#rrggbbaa"`, alpha ignored), R colour names,
#'   or `rgb()` / `rgba()` strings (alpha ignored).
#' @return A numeric vector of WCAG relative luminances (0 = black, 1 = white).
#' @seealso [taiga_contrast()]
#' @examples
#' taiga_luminance(c("#000", "#ffffff", "rgb(0, 113, 227)"))
#' @export
taiga_luminance <- function(col) {
  col <- trimws(as.character(col))
  short <- grepl("^#[0-9A-Fa-f]{3,4}$", col)
  col[short] <- vapply(col[short], function(h) paste0("#", paste(rep(strsplit(substring(h, 2), "")[[1]][1:3], each = 2), collapse = "")), "")
  fn <- grepl("^rgba?\\(", col)
  col[fn] <- vapply(col[fn], function(s) {
    n <- as.numeric(strsplit(gsub("^rgba?\\(|\\)$|\\s", "", s), ",", fixed = TRUE)[[1]])[1:3]
    grDevices::rgb(n[1], n[2], n[3], maxColorValue = 255)
  }, "")
  m <- grDevices::col2rgb(col) / 255
  lin <- ifelse(m <= 0.04045, m / 12.92, ((m + 0.055) / 1.055)^2.4)
  as.numeric(0.2126 * lin[1, ] + 0.7152 * lin[2, ] + 0.0722 * lin[3, ])
}

#' Contrast ratio between two colours
#'
#' @param fg,bg Foreground and background colours (recycled), in any form [taiga_luminance()]
#'   accepts.
#' @return The WCAG 2.x contrast ratios, from 1 to 21.
#' @seealso [taiga_wcag()], [taiga_contrast_audit()]
#' @examples
#' taiga_contrast("#1d1d1f", "#fbfbfd")     # Lumen daylight text on canvas
#' taiga_contrast("#ffffff", "#0e8f83")     # white on the Neue teal accent
#' @export
taiga_contrast <- function(fg, bg) {
  a <- taiga_luminance(fg); b <- taiga_luminance(bg)
  (pmax(a, b) + 0.05) / (pmin(a, b) + 0.05)
}

#' WCAG level of a contrast ratio
#'
#' @param ratio Contrast ratios, for example from [taiga_contrast()].
#' @return A character vector: `"AAA"` (at least 7), `"AA"` (at least 4.5, body text),
#'   `"AA large/UI"` (at least 3: text of 24 px or more, or 18.7 px bold, and UI components) or
#'   `"fail"`.
#' @examples
#' taiga_wcag(c(18, 5, 3.5, 2))
#' @export
taiga_wcag <- function(ratio) {
  ifelse(ratio >= 7, "AAA", ifelse(ratio >= 4.5, "AA", ifelse(ratio >= 3, "AA large/UI", "fail")))
}

#' Contrast audit of a framework theme
#'
#' Every text token of the theme against every surface token, with the ratio and the WCAG level.
#' The styleguides' contrast rules come from this audit: tertiary text (`--lm-text-3`,
#' `--tn-ink-4`) is for large or non-essential text only.
#'
#' @inheritParams taiga_tokens
#' @return A data frame with `framework`, `theme`, `fg`, `fg_value`, `bg`, `bg_value`, `ratio` and
#'   `wcag`, sorted by foreground and then by ratio.
#' @seealso [taiga_contrast()], [taiga_tokens()]
#' @examples
#' a <- taiga_contrast_audit("neue", "light")
#' a[a$wcag != "AAA", c("fg", "bg", "ratio", "wcag")]
#' @export
taiga_contrast_audit <- function(framework = c("lumen", "neue"), theme = NULL) {
  framework <- match.arg(framework)
  tk <- taiga_tokens(framework, theme)
  theme <- theme %||% taiga_themes()$theme[taiga_themes()$framework == framework][1]
  if (framework == "lumen") {
    fg <- c("--lm-text", "--lm-text-2", "--lm-text-3"); bg <- c("--lm-bg", "--lm-bg-2", "--lm-bg-3", "--lm-card-solid")
  } else {
    fg <- c("--tn-ink", "--tn-ink-2", "--tn-ink-3", "--tn-ink-4", "--tn-accent-ink"); bg <- c("--tn-panel", "--tn-panel-2", "--tn-canvas")
  }
  opaque <- function(v) !is.na(v) & grepl("^#[0-9A-Fa-f]{3,8}$", v)
  fg <- fg[opaque(tk[fg])]; bg <- bg[opaque(tk[bg])]
  g <- expand.grid(fg = fg, bg = bg, stringsAsFactors = FALSE)
  out <- data.frame(framework = framework, theme = theme, fg = g$fg, fg_value = unname(tk[g$fg]), bg = g$bg, bg_value = unname(tk[g$bg]),
                    stringsAsFactors = FALSE)
  out$ratio <- round(taiga_contrast(out$fg_value, out$bg_value), 2)
  out$wcag <- taiga_wcag(out$ratio)
  out <- out[order(match(out$fg, fg), -out$ratio), ]
  rownames(out) <- NULL
  out
}
