# The triple-format delivery model: one front end, shipped as Shiny, Quarto and HTML ---------
# See taiga_guide("delivery"). Requirement IDs (DLV-xx) refer to that guide.

#' Embed data as JSON for any host
#'
#' Writes a `<script type="application/json">` element with every `<` written as `\u003c`, so no
#' host (browser, pandoc, Quarto) can read markup in the data (requirement DLV-05). The front end
#' reads it with `JSON.parse(document.getElementById(id).textContent)`.
#'
#' @param x Data to serialise with [jsonlite::toJSON()], or a JSON string (class `"json"`).
#' @param id The element id.
#' @param auto_unbox Passed to [jsonlite::toJSON()].
#' @param ... Further arguments to [jsonlite::toJSON()].
#' @return A character string (class `"html"`).
#' @seealso [taiga_fragment()]
#' @examples
#' taiga_json_script(list(title = "</script> is safe", n = 3), "app-data")
#' @export
taiga_json_script <- function(x, id, auto_unbox = TRUE, ...) {
  json <- if (inherits(x, "json")) as.character(x) else as.character(jsonlite::toJSON(x, auto_unbox = auto_unbox, null = "null", na = "null", digits = NA, ...))
  json <- gsub("<", "\\u003c", json, fixed = TRUE)
  htmltools::HTML(sprintf('<script type="application/json" id="%s">%s</script>', htmltools::htmlEscape(id, attribute = TRUE), json))
}

#' Check front-end assets for host safety
#'
#' Requirement DLV-06: assets are ASCII only, and contain no literal markup that a host could
#' re-parse when the asset is inlined (`<script`, `</script`, `<style`, `<body`, `<html`, `<head`,
#' `<!DOCTYPE`, `<!--`). Build such strings from pieces in the source instead (`'<' + 'script'`).
#'
#' @param files Paths of CSS and JavaScript files.
#' @return A data frame with `file`, `ascii` (no byte above 127), `markup_free` and `ok`; invisibly
#'   when every file is ok. Use `stopifnot(all(taiga_check_assets(f)$ok))` in tests.
#' @seealso [taiga_fragment()]
#' @examples
#' ex <- taiga_example()
#' taiga_check_assets(c(ex$css, ex$js))
#' @export
taiga_check_assets <- function(files) {
  if (!length(files)) return(invisible(data.frame(file = character(), ascii = logical(), markup_free = logical(), ok = logical(), stringsAsFactors = FALSE)))
  res <- lapply(files, function(f) {
    raw <- readBin(f, "raw", file.info(f)$size)
    txt <- rawToChar(raw[raw != as.raw(0)])
    data.frame(file = f, ascii = !any(as.integer(raw) > 127L),
               markup_free = !grepl("</?(script|style|body|html|head)\\b|<!DOCTYPE|<!--", txt, ignore.case = TRUE, perl = TRUE),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, res)
  out$ok <- out$ascii & out$markup_free
  if (all(out$ok)) invisible(out) else out
}

#' Build a front-end fragment for any host
#'
#' The one front end of the delivery model: a root element (`class` and `id` for namespacing,
#' `data-mode` so the front end knows its host, and optionally `data-theme` so the first paint has the
#' right theme), the styles and scripts inline, and the data as host-safe JSON. The same fragment
#' goes into [taiga_export_html()], [taiga_export_quarto()] and [taiga_shiny_app()].
#'
#' @param root Class of the root element (the CSS namespace, for example `"qs"` or
#'   `"lumen-story"`).
#' @param id Id of the root element.
#' @param mode `"html"`, `"quarto"` or `"shiny"`: written to `data-mode`.
#' @param css,js Paths of CSS and JavaScript files to inline, in order. They are checked with
#'   [taiga_check_assets()].
#' @param data Data for the front end, embedded with [taiga_json_script()] under the id `data_id`.
#' @param data_id Id of the JSON element.
#' @param framework `NULL`, `"lumen"` or `"neue"`: also inline that framework's token sheet
#'   ([taiga_css()]). With `"lumen"`, the root also gets the class `lm`.
#' @param theme Initial theme, written to `data-theme` (requirement DLV-07).
#' @param noscript Text shown when JavaScript is off.
#' @return A character string (class `"html"`).
#' @seealso [taiga_export_html()], [taiga_export_quarto()], [taiga_shiny_app()]
#' @examples
#' ex <- taiga_example()
#' f <- taiga_fragment("hello", css = ex$css, js = ex$js, framework = "lumen", theme = "dark",
#'                     data = list(title = "Hello, Taiga", items = c("Shiny", "Quarto", "HTML")))
#' substr(f, 1, 120)
#' @export
taiga_fragment <- function(root, id = root, mode = c("html", "quarto", "shiny"), css = character(), js = character(),
                           data = NULL, data_id = paste0(id, "-data"), framework = NULL, theme = NULL,
                           noscript = "This page needs JavaScript.") {
  mode <- match.arg(mode)
  chk <- taiga_check_assets(c(css, js))
  if (length(c(css, js)) && !all(chk$ok)) {
    stop("taiga: assets are not host-safe (DLV-06): ", paste(chk$file[!chk$ok], collapse = ", "), call. = FALSE)
  }
  cls <- paste(c(root, if (identical(framework, "lumen")) "lm"), collapse = " ")
  attrs <- sprintf(' data-mode="%s"%s', mode, if (!is.null(theme)) sprintf(' data-theme="%s"', htmltools::htmlEscape(theme, attribute = TRUE)) else "")
  style <- function(paths) if (length(paths)) sprintf('<style id="%s">\n%s\n</style>', paste0(id, "-css-", seq_along(paths)), vapply(paths, read_text, "")) else character()
  script <- function(paths) if (length(paths)) sprintf('<script id="%s">\n%s\n</script>', paste0(id, "-js-", seq_along(paths)), vapply(paths, read_text, "")) else character()
  tokens <- if (!is.null(framework)) sprintf('<style id="%s-tokens">\n%s\n</style>', id, read_text(taiga_css(framework))) else character()
  parts <- c(
    sprintf('<div class="%s" id="%s"%s><noscript><p>%s</p></noscript></div>', htmltools::htmlEscape(cls, attribute = TRUE),
            htmltools::htmlEscape(id, attribute = TRUE), attrs, htmltools::htmlEscape(noscript)),
    tokens, style(css),
    if (!is.null(data)) as.character(taiga_json_script(data, data_id)),
    script(js)
  )
  htmltools::HTML(paste(parts, collapse = "\n"))
}

#' A complete HTML page around a fragment
#'
#' @param fragment A fragment from [taiga_fragment()].
#' @param title Page title.
#' @param lang Page language.
#' @param head Extra HTML for the `<head>` (a character string).
#' @param body_class Class of `<body>`.
#' @param reset Remove the browser's default page margin, so the fragment fills the page?
#' @return A character string (class `"html"`): a full HTML document.
#' @seealso [taiga_export_html()]
#' @examples
#' substr(taiga_html_page("<p>Hi</p>", "Demo"), 1, 80)
#' @export
taiga_html_page <- function(fragment, title = "Taiga", lang = "en", head = NULL, body_class = NULL, reset = TRUE) {
  htmltools::HTML(paste0(
    "<!DOCTYPE html>\n<html lang=\"", lang, "\">\n<head>\n<meta charset=\"utf-8\">\n",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
    "<meta name=\"color-scheme\" content=\"light dark\">\n<title>", htmltools::htmlEscape(title), "</title>\n",
    if (isTRUE(reset)) "<style>html, body { margin: 0; padding: 0; }</style>\n", paste(head, collapse = "\n"), "\n</head>\n<body", if (!is.null(body_class)) sprintf(' class="%s"', htmltools::htmlEscape(body_class, attribute = TRUE)),
    ">\n", fragment, "\n</body>\n</html>\n"))
}

#' Export a standalone HTML file
#'
#' The HTML format of the delivery model (DLV-13): one self-contained file, with no server and no
#' network needed. Build the fragment with `mode = "html"`.
#'
#' @param fragment A fragment from [taiga_fragment()].
#' @param file Output file.
#' @param title Page title.
#' @param ... Further arguments to [taiga_html_page()].
#' @return Invisibly, the path of the written file.
#' @seealso [taiga_export_quarto()], [taiga_shiny_app()]
#' @examples
#' ex <- taiga_example()
#' f <- taiga_fragment("hello", css = ex$css, js = ex$js, framework = "lumen",
#'                     data = list(title = "Hello, Taiga", items = c("Shiny", "Quarto", "HTML")))
#' out <- taiga_export_html(f, file.path(tempdir(), "hello.html"), title = "Hello")
#' file.size(out)
#' @export
taiga_export_html <- function(fragment, file, title = "Taiga", ...) {
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  con <- file(file, open = "w", encoding = "UTF-8"); on.exit(close(con))
  writeLines(taiga_html_page(fragment, title = title, ...), con, useBytes = TRUE)
  invisible(normalizePath(file, winslash = "/"))
}

#' A raw-HTML block for a Quarto or R Markdown document
#'
#' For authors who write their own `.qmd`: print the result in a chunk with `output: asis`, or paste
#' it into the document.
#'
#' @param fragment A fragment from [taiga_fragment()], built with `mode = "quarto"`.
#' @return A character string: a fenced `{=html}` block.
#' @seealso [taiga_export_quarto()]
#' @examples
#' cat(substr(taiga_quarto_block("<div>hi</div>"), 1, 40))
#' @export
taiga_quarto_block <- function(fragment) {
  paste0("```{=html}\n", fragment, "\n```\n")
}

#' Export a Quarto document
#'
#' The Quarto format of the delivery model (DLV-12). Writes a ready-to-render `.qmd`: a YAML header
#' (`embed-resources: true`), the author's Markdown, and the front end as a raw-HTML block. Render it
#' with `quarto render`.
#'
#' @param fragment A fragment from [taiga_fragment()], built with `mode = "quarto"`.
#' @param dir Output folder.
#' @param file Name of the `.qmd` file.
#' @param title Document title.
#' @param before,after Markdown placed before and after the front end (the author's commentary).
#' @param overwrite Overwrite an existing file?
#' @return Invisibly, the path of the `.qmd` file.
#' @seealso [taiga_quarto_block()], [taiga_export_html()]
#' @examples
#' ex <- taiga_example()
#' f <- taiga_fragment("hello", mode = "quarto", css = ex$css, js = ex$js, framework = "lumen",
#'                     data = list(title = "Hello, Taiga", items = c("Shiny", "Quarto", "HTML")))
#' qmd <- taiga_export_quarto(f, tempfile("taiga-quarto-"), title = "Hello",
#'                            before = "The same front end, inside a document.")
#' cat(readLines(qmd, n = 8), sep = "\n")
#' @export
taiga_export_quarto <- function(fragment, dir = ".", file = "index.qmd", title = "Taiga", before = NULL, after = NULL, overwrite = FALSE) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(dir, file)
  if (file.exists(path) && !isTRUE(overwrite)) stop("taiga: ", path, " exists (use overwrite = TRUE)", call. = FALSE)
  yaml <- c("---", paste0("title: \"", gsub("\"", "\\\\\"", title), "\""), "format:", "  html:", "    embed-resources: true",
            "    page-layout: full", "---", "")
  con <- file(path, open = "w", encoding = "UTF-8"); on.exit(close(con))
  writeLines(c(yaml, before, if (length(before)) "", taiga_quarto_block(fragment), after), con, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/"))
}

#' A Shiny app around a fragment
#'
#' The Shiny format of the delivery model (DLV-10). The UI is the fragment (built with
#' `mode = "shiny"`) plus any extra tags. The server is yours: the front end talks to it over one
#' input and one custom message (DLV-11), for example `Shiny.setInputValue("<id>_msg", ...)` and
#' `session$sendCustomMessage("<id>-msg", ...)`.
#'
#' @param fragment A fragment from [taiga_fragment()], built with `mode = "shiny"`.
#' @param server A Shiny server function (default: one that does nothing).
#' @param title Window title.
#' @param ... Extra UI elements (tags, dependencies such as [taiga_dependency()]).
#' @return A `shiny.appobj`.
#' @seealso [taiga_export_html()], [taiga_export_quarto()]
#' @examples
#' \dontrun{
#' ex <- taiga_example()
#' f <- taiga_fragment("hello", mode = "shiny", css = ex$css, js = ex$js, framework = "lumen",
#'                     data = list(title = "Hello, Taiga", items = c("Shiny", "Quarto", "HTML")))
#' shiny::runApp(taiga_shiny_app(f, title = "Hello"))
#' }
#' @export
taiga_shiny_app <- function(fragment, server = NULL, title = "Taiga", ...) {
  if (!requireNamespace("shiny", quietly = TRUE)) stop("taiga: the Shiny format needs the 'shiny' package", call. = FALSE)
  ui <- htmltools::tagList(htmltools::tags$head(htmltools::tags$title(title)), ..., htmltools::HTML(fragment))
  shiny::shinyApp(ui, server %||% function(input, output, session) NULL)
}

#' Capability matrix of the three formats
#'
#' What each delivery format can and cannot do (requirement DLV-21). Copy it into a project's README
#' and adapt it.
#'
#' @return A data frame with `capability`, `shiny`, `quarto` and `html`.
#' @seealso [taiga_apps()]
#' @examples
#' taiga_capabilities()
#' @export
taiga_capabilities <- function() {
  y <- "\u2713"; n <- "\u2013"
  data.frame(
    capability = c("Runs without a server", "Server-side computation / secrets", "Persistence across sessions and devices",
                   "Uploads / reading server folders", "Author commentary around the tool", "Works offline / e-mailable"),
    shiny = c(n, y, paste(y, "(server)"), y, n, n),
    quarto = c(paste(y, "(rendered page)"), n, "browser only", "browser file pickers only", y, "with embed-resources"),
    html = c(y, n, "browser only", "browser file pickers only", n, y),
    stringsAsFactors = FALSE
  )
}

#' A tiny example front end
#'
#' A host-safe front end (`hello.css`, `hello.js`) that renders a card from its embedded JSON and shows
#' which host it runs in. Use it to try [taiga_fragment()] and the three exports.
#'
#' @return A list with the paths `css` and `js`.
#' @examples
#' taiga_example()
#' @export
taiga_example <- function() {
  list(css = taiga_path("examples", "hello", "hello.css"), js = taiga_path("examples", "hello", "hello.js"))
}
