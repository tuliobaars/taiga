# Design tokens ------------------------------------------------------------------------------

#' Path to a Taiga token sheet
#'
#' The token sheets are plain CSS custom properties. `lumen-tokens.css` is scoped to the class
#' `.lm` (themes through `data-theme` and the classes `.lm-studio` and `.lm-stage`). `neue-tokens.css`
#' sets `--tn-*` tokens and the Bootstrap bridge (`--bs-*`) on `html`, with attributes for the
#' colour mode and the user appearance settings.
#'
#' @param framework `"lumen"` or `"neue"`.
#' @return The path of the installed CSS file.
#' @seealso [taiga_tokens()], [taiga_dependency()]
#' @examples
#' css <- taiga_css("neue")
#' substr(paste(readLines(css, n = 3), collapse = "\n"), 1, 120)
#' @export
taiga_css <- function(framework = c("lumen", "neue")) {
  framework <- match.arg(framework)
  taiga_path("css", paste0(framework, "-tokens.css"))
}

#' Custom properties declared in a stylesheet
#'
#' A small CSS reader in base R: it returns every custom property (`--name: value`) with the
#' selector that declares it, and the enclosing `@media` or `@supports` rule, if any. It works on the
#' Taiga token sheets and on any application stylesheet, for audits.
#'
#' @param css Path to a CSS file, or CSS text (any string that contains an opening brace).
#' @param all Return every declaration, not only custom properties.
#' @return A data frame with columns `selector`, `at_rule`, `name` and `value`, in source order.
#' @seealso [taiga_tokens()], [taiga_contrast_audit()]
#' @examples
#' v <- taiga_css_vars(taiga_css("lumen"))
#' head(v[v$selector == ".lm", c("name", "value")])
#' taiga_css_vars(".card { --r: 12px; color: red }", all = TRUE)
#' @export
taiga_css_vars <- function(css, all = FALSE) {
  txt <- if (length(css) == 1 && !grepl("{", css, fixed = TRUE) && file.exists(css)) read_text(css) else paste(css, collapse = "\n")
  txt <- gsub("(?s)/\\*.*?\\*/", "", txt, perl = TRUE)
  rows <- list()
  walk <- function(text, at_rule) {
    chars <- strsplit(text, "", fixed = TRUE)[[1]]
    depth <- 0L; start <- 1L; open_at <- 0L
    for (i in seq_along(chars)) {
      ch <- chars[i]
      if (ch == "{") {
        if (depth == 0L) open_at <- i
        depth <- depth + 1L
      } else if (ch == "}") {
        depth <- depth - 1L
        if (depth == 0L) {
          selector <- trimws(paste(chars[start:(open_at - 1L)], collapse = ""))
          body <- if (i - 1L > open_at) paste(chars[(open_at + 1L):(i - 1L)], collapse = "") else ""
          if (startsWith(selector, "@media") || startsWith(selector, "@supports") || startsWith(selector, "@layer")) {
            walk(body, selector)
          } else if (!startsWith(selector, "@")) {
            decl <- trimws(strsplit(body, ";", fixed = TRUE)[[1]])
            decl <- decl[grepl(":", decl, fixed = TRUE)]
            if (length(decl)) {
              nm <- trimws(sub(":.*$", "", decl)); val <- trimws(sub("^[^:]*:", "", decl))
              keep <- all | startsWith(nm, "--")
              if (any(keep)) rows[[length(rows) + 1L]] <<- data.frame(selector = gsub("\\s+", " ", selector), at_rule = at_rule %||% NA_character_,
                                                                     name = nm[keep], value = gsub("\\s+", " ", val[keep]), stringsAsFactors = FALSE)
            }
          }
          start <- i + 1L
        }
      }
    }
  }
  walk(txt, NULL)
  if (!length(rows)) return(data.frame(selector = character(), at_rule = character(), name = character(), value = character(), stringsAsFactors = FALSE))
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Themes of each framework
#'
#' @return A data frame with the `framework`, the `theme` name and the CSS `selectors` whose tokens
#'   make up that theme (applied in order; later selectors override earlier ones).
#' @examples
#' taiga_themes()
#' @export
taiga_themes <- function() {
  lm <- ".lm"
  nd <- 'html:not([data-bs-theme="dark"])'; dk <- 'html[data-bs-theme="dark"]'
  data.frame(
    framework = c(rep("lumen", 5), rep("neue", 3)),
    theme = c("daylight", "dark", "paper", "studio", "stage", "light", "dark", "slate"),
    selectors = c(lm, paste(lm, '.lm[data-theme="dark"]', sep = " | "), paste(lm, '.lm[data-theme="paper"]', sep = " | "),
                  paste(lm, ".lm.lm-studio", sep = " | "), paste(lm, ".lm.lm-stage", sep = " | "),
                  paste("html:root", nd, sep = " | "), paste("html:root", dk, sep = " | "),
                  paste("html:root", dk, 'html[data-bs-theme="dark"][data-tn-dark="slate"]', sep = " | ")),
    stringsAsFactors = FALSE
  )
}

#' Design tokens of a framework theme
#'
#' @param framework `"lumen"` or `"neue"`.
#' @param theme A theme of that framework (see [taiga_themes()]). Lumen: `"daylight"` (default),
#'   `"dark"`, `"paper"`, `"studio"`, `"stage"`. Neue: `"light"` (default), `"dark"`, `"slate"`
#'   (BlockR's lifted-slate dark palette).
#' @param prefix Keep only tokens whose name starts with this prefix (for example `"--tn-"`).
#' @return A named character vector: names are the custom properties, values their CSS values.
#' @seealso [taiga_css()], [taiga_contrast_audit()], [taiga_bs_theme()]
#' @examples
#' tk <- taiga_tokens("lumen", "dark")
#' tk[c("--lm-bg", "--lm-text", "--lm-accent")]
#' taiga_tokens("neue", "slate", prefix = "--tn-panel")
#' @export
taiga_tokens <- function(framework = c("lumen", "neue"), theme = NULL, prefix = NULL) {
  framework <- match.arg(framework)
  th <- taiga_themes(); th <- th[th$framework == framework, ]
  theme <- theme %||% th$theme[1]
  if (!theme %in% th$theme) stop(sprintf("taiga: unknown %s theme '%s' (one of: %s)", framework, theme, paste(th$theme, collapse = ", ")), call. = FALSE)
  sels <- strsplit(th$selectors[th$theme == theme], " | ", fixed = TRUE)[[1]]
  v <- taiga_css_vars(taiga_css(framework))
  v <- v[is.na(v$at_rule), ]
  out <- character()
  for (s in sels) {
    d <- v[v$selector == s, ]
    out[d$name] <- d$value
  }
  if (!is.null(prefix)) out <- out[startsWith(names(out), prefix)]
  out
}

#' Design values extracted from a Taiga application
#'
#' The tokens, colours, type, radii, shadows, glass, motion, breakpoints and component inventory
#' extracted from each application's canonical stylesheets (by `tools/extract_tokens.py` in the
#' package sources), as recorded when the package was built.
#'
#' @param app One of the applications in [taiga_apps()], or `NULL` for the list of applications.
#' @return A list (the parsed JSON) for one application, or a character vector of application names.
#' @examples
#' taiga_extracted()
#' x <- taiga_extracted("teal_neue")
#' x$n_custom_properties
#' head(x$font_sizes)
#' @export
taiga_extracted <- function(app = NULL) {
  dir <- taiga_path("extdata", "tokens")
  apps <- sub("\\.json$", "", list.files(dir, pattern = "\\.json$"))
  if (is.null(app)) return(apps)
  if (!app %in% apps) stop(sprintf("taiga: no extracted tokens for '%s' (one of: %s)", app, paste(apps, collapse = ", ")), call. = FALSE)
  jsonlite::read_json(file.path(dir, paste0(app, ".json")), simplifyVector = TRUE)
}
