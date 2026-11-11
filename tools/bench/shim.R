# Taiga test bench: a markup stand-in for htmltools / shiny / bslib / jsonlite, in base R.
#
# Why: no R package repository was reachable in the sandbox, so shiny, bslib and htmltools could not
# be installed. webR (base R compiled to WebAssembly, from npm) runs offline. This file lets the
# apps' *unmodified* R UI code (R/ui.R, R/components.R, R/app_ui.R, app.R, ...) run in webR and
# produce HTML that mirrors what the real packages emit (same tags, classes and attributes for the
# functions the apps call). It is used only to render screenshot benches; it is not a Shiny server.
#
# How: the apps call `shiny::uiOutput()`, `bslib::card()`, `htmltools::tags$div()`. `::` is an
# ordinary R function, so defining `::` in the evaluation environment routes those calls to the
# stand-ins below (base-R packages such as tools::, utils::, stats:: still resolve normally).
#
# Fidelity notes (also in tools/bench/README.md): markup follows shiny 1.8 / bslib 0.8 with
# Bootstrap 5; Bootstrap CSS comes from the npm `bootstrap` package; bslib's own component CSS and
# shiny's ionRangeSlider "shiny" skin are approximated in bench.css; `bslib::input_dark_mode()` (a web
# component) is drawn as a plain icon button.

.shim <- new.env()
.shim$ids <- 0L
.shim$deps <- list()
.shim$theme <- NULL
.shim$title <- NULL
.shim$outputs <- new.env()
.shim$observers <- list()
.shim_id <- function(prefix = "bench") { .shim$ids <- .shim$ids + 1L; sprintf("%s-%04d", prefix, .shim$ids) }

# ---------------------------------------------------------------- tag objects
.html_escape <- function(x, attr = FALSE) {
  x <- gsub("&", "&amp;", x, fixed = TRUE); x <- gsub("<", "&lt;", x, fixed = TRUE); x <- gsub(">", "&gt;", x, fixed = TRUE)
  if (attr) { x <- gsub("\"", "&quot;", x, fixed = TRUE) }
  x
}
HTML_ <- function(text, ...) structure(paste(c(text, ...), collapse = ""), class = c("html", "character"))
.void <- c("area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr")

.flatten <- function(x) {
  out <- list()
  for (el in x) {
    if (is.null(el)) next
    if (inherits(el, "shim.tag") || inherits(el, "html") || inherits(el, "shim.dep")) { out[[length(out) + 1]] <- el; next }
    if (is.list(el)) { out <- c(out, .flatten(el)); next }
    if (is.character(el) || is.numeric(el) || is.logical(el) || is.factor(el)) { for (v in as.character(el)) out[[length(out) + 1]] <- v; next }
    out[[length(out) + 1]] <- el
  }
  out
}

tag_ <- function(name, args) {
  nms <- names(args) %||% rep("", length(args))
  attrs <- list(); kids <- list()
  for (i in seq_along(args)) {
    a <- args[[i]]
    if (nzchar(nms[i])) {
      if (nms[i] %in% c(".noWS", ".renderHook")) next          # htmltools rendering directives, not attributes
      if (is.null(a)) next
      if (is.list(a) && !length(a)) next
      attrs[[length(attrs) + 1]] <- list(name = nms[i], value = a)
    } else kids[[length(kids) + 1]] <- a
  }
  structure(list(name = name, attrs = attrs, children = .flatten(kids)), class = "shim.tag")
}

.render_attrs <- function(attrs) {
  if (!length(attrs)) return("")
  keys <- unique(vapply(attrs, `[[`, "", "name"))
  parts <- vapply(keys, function(k) {
    vals <- lapply(Filter(function(a) a$name == k, attrs), `[[`, "value")
    if (any(vapply(vals, function(v) length(v) == 1 && is.na(v) && !is.character(v), TRUE))) return(k)   # boolean attribute
    v <- unlist(lapply(vals, function(v) as.character(v)))
    v <- v[!is.na(v)]
    sep <- if (k == "class") " " else if (k == "style") "" else " "
    if (k == "style") v <- vapply(v, function(s) if (nzchar(s) && !grepl(";\\s*$", s)) paste0(s, ";") else s, "")
    sprintf('%s="%s"', k, .html_escape(trimws(paste(v[nzchar(v)], collapse = sep)), attr = TRUE))
  }, "")
  paste0(" ", paste(parts, collapse = " "))
}

render_html <- function(x) {
  if (is.null(x)) return("")
  if (inherits(x, "shim.dep")) { .shim$deps[[length(.shim$deps) + 1]] <- x; return("") }
  if (inherits(x, "html")) return(as.character(x))
  if (inherits(x, "shim.tag")) {
    for (d in attr(x, "deps") %||% list()) .shim$deps[[length(.shim$deps) + 1]] <- d
    open <- paste0("<", x$name, .render_attrs(x$attrs), ">")
    if (x$name %in% .void) return(open)
    return(paste0(open, paste(vapply(x$children, render_html, ""), collapse = ""), "</", x$name, ">"))
  }
  if (is.list(x)) return(paste(vapply(x, render_html, ""), collapse = ""))
  .html_escape(paste(as.character(x), collapse = ""))
}

.tag_names <- c("a", "abbr", "article", "aside", "b", "br", "button", "canvas", "code", "details", "div", "dl", "dt", "dd", "em",
                "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "i", "iframe", "img", "input", "kbd",
                "label", "li", "link", "main", "meta", "nav", "ol", "option", "p", "pre", "script", "section", "select", "small",
                "source", "span", "strong", "style", "sub", "summary", "sup", "svg", "table", "tbody", "td", "textarea", "th", "thead",
                "title", "tr", "u", "ul", "video", "audio", "figure", "figcaption", "time", "mark", "path", "circle", "rect", "g", "output")
tags_ <- new.env()
for (.n in .tag_names) local({ n <- .n; assign(n, function(...) tag_(n, list(...)), envir = tags_) })
tags_ <- as.list(tags_)

# ---------------------------------------------------------------- htmltools
.ht <- list(
  tags = tags_, HTML = HTML_,
  div = function(...) tag_("div", list(...)), span = function(...) tag_("span", list(...)), p = function(...) tag_("p", list(...)),
  strong = function(...) tag_("strong", list(...)), em = function(...) tag_("em", list(...)), a = function(...) tag_("a", list(...)),
  h1 = function(...) tag_("h1", list(...)), h2 = function(...) tag_("h2", list(...)), h3 = function(...) tag_("h3", list(...)),
  h4 = function(...) tag_("h4", list(...)), img = function(...) tag_("img", list(...)), code = function(...) tag_("code", list(...)),
  pre = function(...) tag_("pre", list(...)), br = function(...) tag_("br", list(...)),
  tag = function(`_tag_name`, varArgs) tag_(`_tag_name`, varArgs),
  tagList = function(...) .flatten(list(...)),
  css = function(..., collapse_ = "") {
    a <- list(...); a <- a[!vapply(a, is.null, TRUE)]
    paste0(gsub("([A-Z])", "-\\L\\1", gsub("\\.", "-", names(a)), perl = TRUE), ":", unlist(a), ";", collapse = collapse_)
  },
  htmlDependency = function(name, version, src = NULL, script = NULL, stylesheet = NULL, head = NULL, ...) {
    structure(list(name = name, version = version, src = src, script = script, stylesheet = stylesheet, head = head), class = "shim.dep")
  },
  attachDependencies = function(x, value, append = FALSE) {
    value <- if (inherits(value, "shim.dep")) list(value) else value
    attr(x, "deps") <- c(if (append) attr(x, "deps"), value); x
  },
  validateCssUnit = function(x) if (is.numeric(x)) paste0(x, "px") else x,
  bindFillRole = function(x, ...) x,
  tagAppendAttributes = function(tag, ...) { a <- list(...); for (k in names(a)) tag$attrs[[length(tag$attrs) + 1]] <- list(name = k, value = a[[k]]); tag },
  tagAppendChild = function(tag, child) { tag$children <- c(tag$children, .flatten(list(child))); tag },
  tagAppendChildren = function(tag, ...) { tag$children <- c(tag$children, .flatten(list(...))); tag },
  htmlEscape = function(text, attribute = FALSE) .html_escape(text, attribute),
  renderTags = function(x) list(html = render_html(x)),
  doRenderTags = function(x) render_html(x)
)

# ---------------------------------------------------------------- shiny inputs / outputs
.label <- function(id, label) {
  tag_("label", list(class = "control-label", class = if (is.null(label)) "shiny-label-null", id = paste0(id, "-label"), `for` = id, label))
}
.group <- function(..., width = NULL, class = NULL) tag_("div", list(class = "form-group shiny-input-container", class = class,
                                                                     style = if (!is.null(width)) paste0("width:", width, ";"), ...))
.choices <- function(choices) {
  if (is.list(choices) && !is.null(names(choices)) && all(vapply(choices, function(x) length(x) > 1, TRUE))) {
    # optgroups are flattened (not used by the apps' benches)
    choices <- unlist(unname(choices))
  }
  v <- as.character(unlist(choices)); n <- names(unlist(choices)) %||% v; n[!nzchar(n)] <- v[!nzchar(n)]
  list(value = v, label = n)
}
.sh <- list(
  NS = function(namespace, id = NULL) { f <- function(id) if (length(namespace) && nzchar(namespace)) paste(namespace, id, sep = "-") else id; if (is.null(id)) f else f(id) },
  tags = tags_, HTML = HTML_, div = .ht$div, span = .ht$span, p = .ht$p, strong = .ht$strong, h3 = .ht$h3, h4 = .ht$h4,
  tagList = .ht$tagList, icon = function(name, class = NULL, lib = "font-awesome", ...) {
    tag_("i", list(class = paste0(if (grepl("^fa[srbl]?-", name)) "" else "fas fa-", name), class = class, role = "presentation", `aria-label` = paste(name, "icon")))
  },
  uiOutput = function(outputId, inline = FALSE, container = if (inline) .ht$span else .ht$div, fill = FALSE, ...) container(id = outputId, class = "shiny-html-output"),
  htmlOutput = function(outputId, inline = FALSE, ...) tag_(if (inline) "span" else "div", list(id = outputId, class = "shiny-html-output")),
  textOutput = function(outputId, container = if (inline) .ht$span else .ht$div, inline = FALSE) container(id = outputId, class = "shiny-text-output"),
  tableOutput = function(outputId) tag_("div", list(id = outputId, class = "shiny-html-output")),
  plotOutput = function(outputId, width = "100%", height = "400px", ...) tag_("div", list(class = "shiny-plot-output html-fill-item", id = outputId,
                                                                                        style = sprintf("width:%s;height:%s;", .ht$validateCssUnit(width), .ht$validateCssUnit(height)))),
  textInput = function(inputId, label, value = "", width = NULL, placeholder = NULL, ...) .group(.label(inputId, label),
      tag_("input", list(id = inputId, type = "text", class = "shiny-input-text form-control", value = value, placeholder = placeholder)), width = width),
  passwordInput = function(inputId, label, value = "", width = NULL, placeholder = NULL) .group(.label(inputId, label),
      tag_("input", list(id = inputId, type = "password", class = "shiny-input-password form-control", value = value, placeholder = placeholder)), width = width),
  textAreaInput = function(inputId, label, value = "", width = NULL, height = NULL, cols = NULL, rows = NULL, placeholder = NULL, resize = NULL, ...)
    .group(.label(inputId, label), tag_("textarea", list(id = inputId, class = "shiny-input-textarea form-control", placeholder = placeholder,
                                                         rows = rows, cols = cols, style = if (!is.null(resize)) paste0("resize:", resize, ";"), value)), width = width),
  numericInput = function(inputId, label, value, min = NA, max = NA, step = NA, width = NULL, ...) .group(.label(inputId, label),
      tag_("input", list(id = inputId, type = "number", class = "shiny-input-number form-control", value = value,
                         min = if (!is.na(min)) min, max = if (!is.na(max)) max, step = if (!is.na(step)) step)), width = width),
  selectInput = function(inputId, label, choices, selected = NULL, multiple = FALSE, selectize = TRUE, width = NULL, size = NULL) {
    ch <- .choices(choices); sel <- selected %||% if (!multiple && length(ch$value)) ch$value[1]
    opts <- lapply(seq_along(ch$value), function(i) tag_("option", list(value = ch$value[i], selected = if (ch$value[i] %in% sel) NA, ch$label[i])))
    .group(.label(inputId, label), tag_("div", list(tag_("select", list(id = inputId, class = "shiny-input-select",
                                                                         class = if (!selectize) "form-control", class = if (selectize) "form-select bench-selectize",
                                                                         multiple = if (multiple) NA, opts)))), width = width)
  },
  selectizeInput = function(inputId, label, choices, selected = NULL, multiple = FALSE, options = NULL, width = NULL, ...)
    .sh$selectInput(inputId, label, choices, selected, multiple, TRUE, width),
  sliderInput = function(inputId, label, min, max, value, step = NULL, round = FALSE, ticks = TRUE, animate = FALSE, width = NULL, sep = ",",
                         pre = NULL, post = NULL, timeFormat = NULL, timezone = NULL, dragRange = TRUE) {
    rng <- length(value) > 1
    .group(.label(inputId, label), tag_("input", list(class = "js-range-slider", id = inputId, `data-skin` = "shiny",
      `data-type` = if (rng) "double", `data-min` = min, `data-max` = max, `data-from` = value[1], `data-to` = if (rng) value[2],
      `data-step` = step %||% signif((max - min) / 100, 2), `data-grid` = tolower(as.character(isTRUE(ticks))), `data-grid-num` = 10,
      `data-grid-snap` = "false", `data-prettify-separator` = sep, `data-prettify-enabled` = "true", `data-prefix` = pre, `data-postfix` = post,
      `data-keyboard` = "true", `data-data-type` = "number")), width = width)
  },
  fileInput = function(inputId, label, multiple = FALSE, accept = NULL, width = NULL, buttonLabel = "Browse...", placeholder = "No file selected", ...) {
    .group(.label(inputId, label),
      tag_("div", list(class = "input-group",
        tag_("label", list(class = "input-group-btn input-group-prepend",
          tag_("span", list(class = "btn btn-default btn-file", buttonLabel,
            tag_("input", list(id = inputId, class = "shiny-input-file", name = inputId, type = "file",
                               style = "position: absolute !important; top: -99999px !important; left: -99999px !important;",
                               multiple = if (multiple) "multiple", accept = if (length(accept)) paste(accept, collapse = ","))))))),
        tag_("input", list(type = "text", class = "form-control", placeholder = placeholder, readonly = "readonly")))),
      tag_("div", list(id = paste0(inputId, "_progress"), class = "progress active shiny-file-input-progress", tag_("div", list(class = "progress-bar")))),
      width = width)
  },
  actionButton = function(inputId, label, icon = NULL, width = NULL, class = NULL, ...) {
    tag_("button", c(list(id = inputId, type = "button", class = "btn btn-default action-button", class = class,
                          style = if (!is.null(width)) paste0("width:", width, ";")), list(...), list(icon, tag_("span", list(class = "action-label", label)))))
  },
  actionLink = function(inputId, label, icon = NULL, ...) tag_("a", c(list(id = inputId, href = "#", class = "action-button"), list(...), list(icon, label))),
  downloadButton = function(outputId, label = "Download", class = NULL, ...) tag_("a", list(id = outputId, class = "btn btn-default shiny-download-link", class = class,
                                                                                            href = "", target = "_blank", download = NA, tag_("i", list(class = "fas fa-download")), label)),
  checkboxInput = function(inputId, label, value = FALSE, width = NULL) .group(tag_("div", list(class = "checkbox", tag_("label", list(
      tag_("input", list(id = inputId, type = "checkbox", class = "shiny-input-checkbox", checked = if (isTRUE(value)) NA)), tag_("span", list(label)))))), width = width),
  radioButtons = function(inputId, label, choices = NULL, selected = NULL, inline = FALSE, width = NULL, choiceNames = NULL, choiceValues = NULL) {
    ch <- if (!is.null(choices)) .choices(choices) else list(value = as.character(choiceValues), label = choiceNames)
    sel <- selected %||% ch$value[1]
    items <- lapply(seq_along(ch$value), function(i) {
      inp <- tag_("input", list(type = "radio", name = inputId, value = ch$value[i], checked = if (ch$value[i] == sel) "checked"))
      if (inline) tag_("label", list(class = "radio-inline", inp, tag_("span", list(ch$label[[i]]))))
      else tag_("div", list(class = "radio", tag_("label", list(inp, tag_("span", list(ch$label[[i]]))))))
    })
    tag_("div", list(id = inputId, class = "form-group shiny-input-radiogroup shiny-input-container", class = if (inline) "shiny-input-container-inline",
                     role = "radiogroup", `aria-labelledby` = paste0(inputId, "-label"), .label(inputId, label), tag_("div", list(class = "shiny-options-group", items))))
  },
  conditionalPanel = function(condition, ..., ns = NS, inline = FALSE) tag_(if (inline) "span" else "div", c(list(`data-display-if` = condition, `data-ns-prefix` = ""), list(...))),
  tabsetPanel = function(..., id = NULL, selected = NULL, type = "tabs", header = NULL, footer = NULL) {
    tabs <- Filter(function(x) inherits(x, "shim.tabpanel"), list(...))
    tsid <- sprintf("%d", 1000 + .shim$ids); .shim$ids <- .shim$ids + 1L
    sel <- selected %||% tabs[[1]]$value
    lis <- lapply(seq_along(tabs), function(i) tag_("li", list(class = if (tabs[[i]]$value == sel) "active",
      tag_("a", list(href = sprintf("#tab-%s-%d", tsid, i), `data-toggle` = "tab", `data-bs-toggle` = "tab", `data-value` = tabs[[i]]$value,
                     class = if (tabs[[i]]$value == sel) "active", tabs[[i]]$title)))))
    panes <- lapply(seq_along(tabs), function(i) tag_("div", c(list(class = "tab-pane", class = if (tabs[[i]]$value == sel) "active",
                                                                 `data-value` = tabs[[i]]$value, id = sprintf("tab-%s-%d", tsid, i)), tabs[[i]]$content)))
    tag_("div", list(class = "tabbable",
                     tag_("ul", list(class = paste0("nav nav-", type), class = "shiny-tab-input", id = id, `data-tabsetid` = tsid, lis)),
                     header, tag_("div", list(class = "tab-content", `data-tabsetid` = tsid, panes)), footer))
  },
  tabPanelBody = function(value, ..., icon = NULL) structure(list(value = value, title = NULL, content = list(...)), class = "shim.tabpanel"),
  tabPanel = function(title, ..., value = title, icon = NULL) structure(list(value = value, title = title, content = list(...)), class = "shim.tabpanel"),
  # server-side functions: only what the benches call while building output HTML
  req = function(...) invisible(list(...)[[1]]), isolate = function(expr) expr, isTruthy = function(x) !is.null(x) && length(x) && !identical(x, FALSE),
  renderUI = function(expr, env = parent.frame(), quoted = FALSE, ...) { force(env); e <- if (quoted) expr else substitute(expr); function() eval(e, env) },
  renderText = function(expr, env = parent.frame(), quoted = FALSE, ...) { force(env); e <- if (quoted) expr else substitute(expr); function() eval(e, env) },
  renderTable = function(expr, ...) function() NULL, renderPlot = function(expr, ...) function() NULL,
  observe = function(...) invisible(NULL), bindEvent = function(x, ...) x,
  observeEvent = function(eventExpr, handlerExpr, ..., event.quoted = FALSE, handler.quoted = FALSE, event.env = parent.frame(), handler.env = parent.frame()) {
    # recorded, not run: a bench driver can fire one (bench_fire()) to render what the app's handler builds
    force(handler.env)
    ev <- if (event.quoted) eventExpr else substitute(eventExpr); h <- if (handler.quoted) handlerExpr else substitute(handlerExpr)
    .shim$observers[[length(.shim$observers) + 1]] <- list(event = paste(deparse(ev), collapse = " "), handler = h, env = handler.env)
    invisible(NULL)
  },
  reactive = function(expr, env = parent.frame(), ...) { force(env); e <- substitute(expr); function() eval(e, env) },
  reactiveVal = function(value = NULL, ...) { v <- value; function(x) if (missing(x)) v else v <<- x },
  reactiveValues = function(...) { e <- new.env(); l <- list(...); for (k in names(l)) assign(k, l[[k]], e); e },
  showNotification = function(...) invisible(NULL), removeNotification = function(...) invisible(NULL),
  updateTextInput = function(...) invisible(NULL), updateSelectInput = function(...) invisible(NULL),
  debounce = function(r, ...) r, invalidateLater = function(...) invisible(NULL), getDefaultReactiveDomain = function() NULL,
  addResourcePath = function(...) invisible(NULL), resourcePaths = function() list(),
  moduleServer = function(id, module, session = NULL) {
    # runs the module's server function once, with value-only input/session; its renderUI outputs are kept
    # under their namespaced ids in .shim$outputs (observers are no-ops)
    ns <- function(x) paste(id, x, sep = "-")
    output <- new.env()
    res <- tryCatch(module(input = list(), output = output, session = list(ns = ns, sendCustomMessage = function(...) NULL, userData = new.env())),
                    error = function(e) { cat("  moduleServer", id, "error:", conditionMessage(e), "\n"); NULL })
    for (k in ls(output)) assign(ns(k), get(k, envir = output), envir = .shim$outputs)
    invisible(res)
  },
  modalDialog = function(..., title = NULL, footer = NULL, size = "m", easyClose = FALSE, fade = TRUE) {
    tag_("div", list(id = "shiny-modal", class = "modal", class = if (fade) "fade", tabindex = "-1", `data-backdrop` = if (!easyClose) "static",
      tag_("div", list(class = "modal-dialog", class = switch(size, s = "modal-sm", l = "modal-lg", xl = "modal-xl", NULL),
        tag_("div", list(class = "modal-content",
          if (!is.null(title)) tag_("div", list(class = "modal-header", tag_("h4", list(class = "modal-title", title)))),
          tag_("div", list(class = "modal-body", ...)),
          if (!is.null(footer)) tag_("div", list(class = "modal-footer", footer))))))))
  },
  showModal = function(ui, ...) { .shim$modal <- ui; invisible(NULL) }, exprToFunction = function(expr, env = parent.frame(), quoted = FALSE) function() NULL,
  createRenderFunction = function(...) function() NULL, runApp = function(...) invisible(NULL), shinyApp = function(ui, server, ...) list(ui = ui, server = server)
)

# ---------------------------------------------------------------- bslib
.card_body <- function(...) tag_("div", c(list(class = "card-body bslib-gap-spacing html-fill-item html-fill-container",
                                               style = "margin-top:auto;margin-bottom:auto;flex:1 1 auto;"), list(...)))
.bs <- list(
  bs_theme = function(...) { .shim$theme <- list(...); invisible(.shim$theme) },
  font_collection = function(...) paste(c(...), collapse = ", "),
  font_google = function(family, ...) family,
  page = function(..., title = NULL, theme = NULL, lang = NULL) { .shim$title <- title; .flatten(list(...)) },
  page_fillable = function(..., padding = NULL, gap = NULL, title = NULL, theme = NULL) { .shim$title <- title; .flatten(list(...)) },
  sidebar = function(..., width = 250, position = "left", open = "desktop", id = NULL, title = NULL, bg = NULL, fg = NULL, class = NULL) {
    structure(list(content = list(...), width = width, class = class, title = title, id = id %||% .shim_id("bslib-sidebar")), class = "shim.sidebar")
  },
  layout_sidebar = function(..., sidebar = NULL, fillable = TRUE, border = NULL, border_radius = NULL) .layout_sidebar(sidebar, list(...)),
  page_sidebar = function(..., sidebar = NULL, title = NULL, fillable = TRUE, theme = NULL, window_title = NA) {
    .shim$title <- if (!is.na(window_title)) window_title else if (is.character(title)) title
    if (is.character(title)) title <- tag_("h1", list(class = "bslib-page-title", title))
    nav <- if (!is.null(title)) tag_("div", list(class = "navbar navbar-static-top", tag_("div", list(class = "container-fluid", tag_("div", list(class = "navbar-brand", title))))))
    .shim$body_class <- "bslib-page-fill bslib-gap-spacing bslib-page-sidebar html-fill-container"
    .flatten(list(nav, .layout_sidebar(sidebar, list(...))))
  },
  card = function(..., full_screen = FALSE, height = NULL, class = NULL, id = NULL) {
    kids <- list(...)
    body <- lapply(kids, function(k) if (inherits(k, "shim.tag") && grepl("card-(body|header|footer)", paste(unlist(lapply(k$attrs, `[[`, "value")), collapse = " "))) k else k)
    plain <- Filter(function(k) !inherits(k, "shim.dep"), body)
    tag_("div", list(class = "card bslib-card bslib-mb-spacing html-fill-item html-fill-container", class = class, id = id,
                     `data-bslib-card-init` = NA, `data-full-screen` = "false", `data-require-bs-version` = "5", `data-require-bs-caller` = "card()",
                     style = if (!is.null(height)) paste0("height:", .ht$validateCssUnit(height), ";"),
                     if (length(plain) && !(inherits(plain[[1]], "shim.tag") && any(grepl("card-body", vapply(plain[[1]]$attrs, function(a) paste(a$value, collapse = " "), ""))))) .card_body(plain) else plain,
                     Filter(function(k) inherits(k, "shim.dep"), kids)))
  },
  card_body = function(..., fillable = TRUE, class = NULL, padding = NULL) { b <- .card_body(...); if (!is.null(class)) b$attrs[[length(b$attrs) + 1]] <- list(name = "class", value = class); b },
  card_header = function(..., class = NULL) tag_("div", list(class = "card-header", class = class, ...)),
  accordion = function(..., id = NULL, open = NULL, multiple = TRUE, class = NULL) {
    id <- id %||% .shim_id("bslib-accordion")
    panels <- Filter(function(x) inherits(x, "shim.panel"), list(...))
    if (is.null(open)) open <- if (length(panels)) panels[[1]]$value
    items <- lapply(panels, function(pn) {
      is_open <- isTRUE(open) || pn$value %in% open
      pid <- .shim_id("bslib-accordion-panel")
      tag_("div", list(class = "accordion-item", `data-value` = pn$value,
        tag_("div", list(class = "accordion-header",
          tag_("button", list(class = "accordion-button", class = if (!is_open) "collapsed", type = "button", `data-bs-toggle` = "collapse",
                              `data-bs-target` = paste0("#", pid), `aria-expanded` = tolower(as.character(is_open)), `aria-controls` = pid,
                              tag_("div", list(class = "accordion-icon", pn$icon)), tag_("div", list(class = "accordion-title", pn$title)))))),
        tag_("div", list(id = pid, class = "accordion-collapse collapse", class = if (is_open) "show", `data-bs-parent` = if (!multiple) paste0("#", id),
                         tag_("div", list(class = "accordion-body", pn$content))))))
    })
    tag_("div", list(class = "accordion", class = class, id = id, `data-require-bs-version` = "5", `data-require-bs-caller` = "accordion()", items))
  },
  accordion_panel = function(title, ..., value = title, icon = NULL) structure(list(title = title, value = value, icon = icon, content = list(...)), class = "shim.panel"),
  input_switch = function(id, label, value = FALSE, width = NULL) .group(tag_("div", list(class = "bslib-input-switch form-switch form-check",
      tag_("input", list(id = id, class = "form-check-input", type = "checkbox", role = "switch", checked = if (isTRUE(value)) NA)),
      tag_("label", list(class = "form-check-label", `for` = id, tag_("span", list(label)))))), width = width),
  input_dark_mode = function(id = NULL, mode = NULL, ...) tag_("button", list(id = id, type = "button", class = "bench-dark-mode",
      title = "Toggle light/dark", `aria-label` = "Toggle light/dark mode",
      HTML_('<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="12" r="4.2"/><path d="M12 2.5v2.2M12 19.3v2.2M4.6 4.6l1.6 1.6M17.8 17.8l1.6 1.6M2.5 12h2.2M19.3 12h2.2M4.6 19.4l1.6-1.6M17.8 6.2l1.6-1.6"/></svg>'))),
  tooltip = function(trigger, ...) trigger, popover = function(trigger, ...) trigger,
  update_switch = function(...) invisible(NULL), accordion_panel_open = function(...) invisible(NULL)
)
.layout_sidebar <- function(sidebar, main) {
  sb <- sidebar
  aside <- if (!is.null(sb)) tag_("aside", list(id = sb$id, class = "sidebar", class = sb$class,
    tag_("div", list(class = "sidebar-content bslib-gap-spacing", if (!is.null(sb$title)) tag_("header", list(class = "sidebar-title", sb$title)), sb$content))))
  tag_("div", list(class = "bslib-sidebar-layout bslib-mb-spacing html-fill-item", `data-bslib-sidebar-init` = "TRUE", `data-open` = "desktop",
                   `data-collapsible-mobile` = "true", `data-collapsible-desktop` = "true", `data-bslib-sidebar-border` = "false",
                   `data-bslib-sidebar-border-radius` = "false", style = sprintf("--_sidebar-width:%s;", .ht$validateCssUnit(sb$width %||% 250)),
                   tag_("div", list(class = "main bslib-gap-spacing html-fill-container", role = "main", main)), aside,
                   tag_("button", list(class = "collapse-toggle", type = "button", title = "Toggle sidebar", `aria-expanded` = "true", `aria-controls` = sb$id,
                                       HTML_('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" class="bi bi-chevron-left collapse-icon" style="fill:currentColor;height:;width:;" aria-hidden="true" role="img"><path fill-rule="evenodd" d="M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0z"></path></svg>')))))
}

# ---------------------------------------------------------------- jsonlite (minimal, for inline JSON)
.json <- function(x, auto_unbox = FALSE, null = "null", na = "null", ...) {
  esc <- function(s) paste0('"', gsub("[\u0001-\u001f]", "", gsub("\n", "\\\\n", gsub('"', '\\\\"', gsub("\\\\", "\\\\\\\\", s)))), '"')
  val <- function(v) {
    if (is.null(v)) return(if (identical(null, "null")) "null" else "{}")
    if (inherits(v, "json")) return(as.character(v))
    if (is.data.frame(v)) return(val(lapply(as.list(v), function(col) if (is.factor(col)) as.character(col) else col)))   # shiny: dataframe = "columns"
    if (is.list(v)) {
      if (!length(v)) return(if (!is.null(names(v))) "{}" else "[]")
      if (!is.null(names(v)) && all(nzchar(names(v)))) return(paste0("{", paste(esc(names(v)), vapply(v, val, ""), sep = ":", collapse = ","), "}"))
      return(paste0("[", paste(vapply(v, val, ""), collapse = ","), "]"))
    }
    one <- function(e) if (is.na(e)) "null" else if (is.character(e) || is.factor(e)) esc(as.character(e)) else if (is.logical(e)) tolower(as.character(e)) else format(e, scientific = FALSE, trim = TRUE, digits = 15)
    s <- vapply(as.list(v), one, "")
    if (auto_unbox && length(v) == 1 && !inherits(v, "AsIs")) s else paste0("[", paste(s, collapse = ","), "]")
  }
  structure(val(x), class = "json")
}
# read side: jsonlite::read_json / fromJSON with simplifyVector = FALSE semantics
# (objects -> named lists, arrays -> unnamed lists, scalars -> length-1 vectors, null -> NULL)
.json_parse <- function(txt) {
  txt <- paste(txt, collapse = "\n")
  rx <- '"(?:[^"\\\\]|\\\\.)*"|-?[0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|true|false|null|[][{}:,]'
  tok <- regmatches(txt, gregexpr(rx, txt, perl = TRUE))[[1]]
  st <- new.env(); st$i <- 1L
  unesc <- function(s) {
    s <- substr(s, 2L, nchar(s) - 1L)
    if (!grepl("\\", s, fixed = TRUE)) return(s)
    m <- gregexpr("\\\\u[0-9a-fA-F]{4}", s)
    if (m[[1]][1] > 0) regmatches(s, m) <- list(vapply(regmatches(s, m)[[1]], function(u) intToUtf8(strtoi(substr(u, 3, 6), 16L)), ""))
    s <- gsub("\\\\n", "\n", s); s <- gsub("\\\\t", "\t", s); s <- gsub("\\\\r", "\r", s)
    s <- gsub("\\\\/", "/", s); s <- gsub('\\\\"', '"', s); gsub("\\\\\\\\", "\\\\", s)
  }
  val <- function() {
    t <- tok[st$i]; st$i <- st$i + 1L
    if (t == "{") {
      out <- list(); nm <- character()
      if (tok[st$i] == "}") { st$i <- st$i + 1L; return(structure(list(), names = character())) }
      repeat {
        k <- unesc(tok[st$i]); st$i <- st$i + 2L
        v <- val(); out[length(out) + 1L] <- list(v); nm <- c(nm, k)
        t2 <- tok[st$i]; st$i <- st$i + 1L
        if (t2 == "}") break
      }
      names(out) <- nm; return(out)
    }
    if (t == "[") {
      out <- list()
      if (tok[st$i] == "]") { st$i <- st$i + 1L; return(out) }
      repeat { v <- val(); out[length(out) + 1L] <- list(v); t2 <- tok[st$i]; st$i <- st$i + 1L; if (t2 == "]") break }
      return(out)
    }
    if (t == "true") return(TRUE); if (t == "false") return(FALSE); if (t == "null") return(NULL)
    if (substr(t, 1, 1) == '"') return(unesc(t))
    n <- as.numeric(t); if (!grepl("[.eE]", t) && abs(n) < .Machine$integer.max) as.integer(n) else n
  }
  if (!length(tok)) stop("empty JSON")
  val()
}
.js <- list(toJSON = .json, unbox = function(x) x, base64_enc = function(x) "",
            read_json = function(path, simplifyVector = FALSE, ...) .json_parse(readLines(path, warn = FALSE, encoding = "UTF-8")),
            fromJSON = function(txt, simplifyVector = FALSE, ...) .json_parse(if (length(txt) == 1 && file.exists(txt)) readLines(txt, warn = FALSE) else txt),
            write_json = function(...) invisible(NULL))

# ---------------------------------------------------------------- the `::` router
.rl <- list(hash = function(x) { f <- tempfile(); saveRDS(x, f, compress = FALSE); h <- unname(tools::md5sum(f)); unlink(f); h },
            `%||%` = function(x, y) if (is.null(x)) y else x, .data = NULL)
.shim_pkgs <- list(htmltools = .ht, shiny = .sh, bslib = .bs, jsonlite = .js, rlang = .rl)
`::` <- function(pkg, name) {
  pkg <- as.character(substitute(pkg)); name <- as.character(substitute(name))
  if (!is.null(.shim_pkgs[[pkg]])) {
    f <- .shim_pkgs[[pkg]][[name]]
    if (is.null(f)) stop(sprintf("bench shim: %s::%s is not implemented", pkg, name), call. = FALSE)
    return(f)
  }
  if (pkg %in% loadedNamespaces() || nzchar(system.file(package = pkg))) return(getExportedValue(pkg, name))
  # a package that is not installed in the bench: a recorded, do-nothing stand-in (only reached where
  # the apps build argument lists for modules the bench never runs)
  .shim$missing <- unique(c(.shim$missing, paste0(pkg, "::", name)))
  function(...) invisible(structure(list(), class = "bench_stub"))
}
`:::` <- function(pkg, name) { pkg <- as.character(substitute(pkg)); name <- as.character(substitute(name)); get(name, envir = asNamespace(pkg), inherits = FALSE) }

# helpers the bench drivers use
bench_fire <- function(pattern) {
  hits <- Filter(function(o) grepl(pattern, o$event), .shim$observers)
  for (o in hits) eval(o$handler, o$env)
  length(hits)
}
bench_deps <- function() unique(vapply(.shim$deps, function(d) d$name, ""))
bench_render <- function(x, file) { .shim$deps <- list(); h <- render_html(x); writeLines(h, file, useBytes = TRUE); invisible(nchar(h)) }
