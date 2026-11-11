# teal_neue / BlockR bench driver (runs in webR; see run_r.mjs and shim.R).
#
# Real (the apps' own, unmodified R code): the module tree and its labels, the command-bar index,
# the study overview (R/overview.R, base R, computed on the bundled ADaM cache), the header, the
# footer, the TLG Catalog pages (ui_tlg_catalog) and, for BlockR, the canvas UI, its configuration
# (registry + templates), template graphs (blockr_template_graph), compiled R code (blockr_compile),
# SAS code (blockr_sas) and block statuses (blockr_run with base-R stand-ins for the data verbs).
#
# Stand-ins (teal, teal.modules.*, tern, rtables, ggplot2 are not available): teal's module
# constructors keep only the labels (module arguments are never evaluated); the page chrome mirrors
# teal's Bootstrap markup (nav tabs with dropdowns, a sidebar filter panel); plots are drawn with
# base R graphics on the real data.
source("/bench/shim.R")
tags <- htmltools::tags; div <- htmltools::div; tagList <- htmltools::tagList
APP <- readLines("/bench/app.txt")[1]
PKG <- c(teal_neue = "teal.neue", BlockR = "BlockR")[[APP]]
out <- "/bench/out"; dir.create(out, showWarnings = FALSE)

# ---- teal stand-ins: module()/modules() keep labels and the ui function (for pages the bench renders)
module <- function(label = "module", server = NULL, ui = NULL, filters, datanames = "all", server_args = NULL, ui_args = NULL, ...) {
  structure(list(label = label, ui = ui, ui_args = ui_args, datanames = datanames), class = "teal_module")
}
modules <- function(..., label = "root", header = NULL) structure(list(label = label, children = list(...)), class = "teal_modules")
.shim_pkgs$teal <- list(module = module, modules = modules, modify_title = function(x, ...) x, modify_header = function(x, ...) x,
                        modify_footer = function(x, ...) x, init = function(...) list(...))
stub_label <- function(name) function(label = NULL, ...) {
  a <- list(...)
  structure(list(label = if (is.null(label)) gsub("_", " ", sub("^tm_[a-z]_?", "", name)) else label), class = "teal_module")
}
for (f in list.files("/app/R", pattern = "[.]R$", full.names = TRUE)) sys.source(f, envir = globalenv())

# every tm_*() the apps call from teal.modules.* (not defined by the app itself): a label-only module
calls <- unique(unlist(lapply(list.files("/app/R", pattern = "[.]R$", full.names = TRUE), function(f) regmatches(readLines(f), gregexpr("\\btm_[a-z0-9_]+\\b", readLines(f), perl = TRUE)))))
for (nm in calls) if (!exists(nm, envir = globalenv(), inherits = FALSE)) assign(nm, stub_label(nm), envir = globalenv())

# namespaces of packages that are not installed (teal) resolve to an empty environment: lookups such as
# get0(f, envir = asNamespace("teal")) then find nothing, as with a teal version without that function
asNamespace <- function(ns, base.OK = TRUE) if (ns %in% loadedNamespaces() || nzchar(system.file(package = ns))) base::asNamespace(ns, base.OK) else emptyenv()

# the app's package-level helpers that read the installed package
www <- "/app/inst/www"
assign(if (APP == "teal_neue") "teal_neue_www" else "blockr_www", function() www, envir = globalenv())
ver <- sub("^Version:\\s*", "", grep("^Version:", readLines("/app/DESCRIPTION"), value = TRUE))
assign(if (APP == "teal_neue") "teal_neue_version" else "blockr_version", function() ver, envir = globalenv())

# ---- data: the app's own cache of the bundled random.cdisc.data study
cache <- readRDS("/app/cache/lumen_adam.rds")
ds <- lapply(cache$datasets, as.data.frame)
meta_key <- if (APP == "teal_neue") ".teal_neue" else ".blockr"
data <- c(ds, setNames(list(list(source = list(source = "bundled"))), meta_key))
cat("datasets:", paste(sprintf("%s %dx%d", names(ds), vapply(ds, nrow, 1L), vapply(ds, ncol, 1L)), collapse = ", "), "\n")

# build the module tree; helpers from teal.transform/teal.picks etc. that the module lists call eagerly
# get a do-nothing stand-in (their results only feed module arguments, which are never evaluated)
build <- function(expr_fun) {
  for (i in 1:60) {
    r <- tryCatch(list(ok = expr_fun()), error = function(e) list(err = conditionMessage(e)))
    if (!is.null(r$ok)) return(r$ok)
    m <- regmatches(r$err, regexec('could not find function "([^"]+)"', r$err))[[1]]
    if (length(m) < 2) m <- regmatches(r$err, regexec("object '([A-Za-z_.][A-Za-z0-9_.]*)' not found", r$err))[[1]]
    if (length(m) < 2) stop(r$err)
    cat("  stand-in for", m[2], "\n")
    assign(m[2], function(...) invisible(structure(list(), class = "bench_stub")), envir = globalenv())
  }
  stop("too many missing functions")
}
mods <- build(function() if (APP == "teal_neue") teal_neue_modules(data) else blockr_modules(data))
labels <- leaf_labels(mods)
cat("modules:", length(labels), "leaves\n")
cat("stand-ins used while building the module list:", paste(.shim$missing, collapse = ", "), "\n")

# ---- overview, index, header, footer: the apps' own functions
n_subj <- nrow(ds$ADSL)
if (APP == "teal_neue") {
  overview <- teal_neue_app_overview(data, mods)
  index <- teal_neue_index(mods, overview = overview)
  label <- teal_neue_data_label(list(source = "bundled"), n_subj)
  header <- teal_neue_header(label, style = TRUE, index = index)
  footer <- teal_neue_footer(style = TRUE)
  head_script <- teal_neue_head_script("light", TRUE)
} else {
  index <- blockr_index(mods)
  label <- blockr_data_label(list(source = "bundled"), n_subj)
  header <- blockr_header(label, style = TRUE, index = index)
  footer <- blockr_footer(style = TRUE)
  head_script <- blockr_head_script("light", TRUE)
}
cat("overview parts:", if (APP == "teal_neue") paste(names(Filter(Negate(is.null), overview)), collapse = ", ") else "-", "\n")

# ---- teal's page chrome: top-level tabs (nested module groups as dropdown menus), one pane per leaf
slug <- function(x) gsub("(^-|-$)", "", gsub("[^a-z0-9]+", "-", tolower(x)))
pane_id <- function(path) paste0("teal-tab-", slug(paste(path, collapse = "-")))
nav_items <- list(); panes <- list()
add_leaf <- function(m, path) panes[[length(panes) + 1]] <<- list(id = pane_id(c(path, m$label)), label = m$label, path = c(path, m$label), mod = m)
for (top in mods$children) {
  if (inherits(top, "teal_modules")) {
    items <- list()
    walk <- function(x, path) {
      if (inherits(x, "teal_modules")) { for (ch in x$children) walk(ch, c(path, x$label)) }
      else { add_leaf(x, path); items[[length(items) + 1]] <<- tags$li(tags$a(class = "dropdown-item", href = paste0("#", pane_id(c(path, x$label))),
                                  `data-bs-toggle` = "tab", `data-value` = x$label, role = "tab", x$label)) }
    }
    for (ch in top$children) walk(ch, top$label)
    nav_items[[length(nav_items) + 1]] <- tags$li(class = "nav-item dropdown",
      tags$a(class = "nav-link dropdown-toggle", href = "#", `data-bs-toggle` = "dropdown", role = "button", `aria-expanded` = "false", top$label),
      tags$ul(class = "dropdown-menu", items))
  } else {
    add_leaf(top, character(0))
    nav_items[[length(nav_items) + 1]] <- tags$li(class = "nav-item", tags$a(class = "nav-link", class = if (!length(nav_items)) "active", href = paste0("#", pane_id(top$label)),
                                                                          `data-bs-toggle` = "tab", `data-value` = top$label, role = "tab", top$label))
  }
}
writeLines(vapply(panes, function(p) paste(p$id, paste(p$path, collapse = " > "), sep = "\t"), ""), file.path(out, "panes.tsv"))

# ---- a teal analysis module, as a bench stand-in: teal.modules.clinical's layout (encodings | output | filter panel)
# around a Kaplan-Meier plot of the real ADTTE overall survival, drawn with base R graphics (ggplot2 and
# nestcolor are not available; arm colours are the app's own --tn-arm-* tokens)
km_standin <- function() {
  a <- ds$ADTTE; a <- a[a$PARAMCD == "OS", , drop = FALSE]
  arm <- if ("ARM" %in% names(a)) a$ARM else a$ACTARM
  arms <- if (is.factor(arm)) levels(droplevels(arm)) else sort(unique(arm))
  cols <- c("#0e8f83", "#d98b0b", "#4a67b0", "#a34f8f")
  ink <- "#0F1720"; ink2 <- "#3A4651"; ink3 <- "#66737F"; grid <- "#E2E7EA"
  dir.create(file.path(out, "plots"), showWarnings = FALSE)
  svg(file.path(out, "plots", "km.svg"), width = 9.2, height = 5.4, family = "sans")
  par(mar = c(4.2, 4.6, 3.6, 14.5), mgp = c(2.6, .7, 0), tcl = -.25, col.axis = ink3, col.lab = ink2, fg = grid, las = 1, cex.axis = .9, xpd = FALSE)
  tmax <- max(a$AVAL, na.rm = TRUE)
  plot(NA, xlim = c(0, tmax), ylim = c(0, 1), xlab = paste0("Time (", if (!is.null(a$AVALU)) tolower(as.character(a$AVALU[1])) else "days", ")"),
       ylab = "Survival probability", bty = "n", xaxs = "i", yaxs = "i", axes = FALSE)
  abline(h = seq(0, 1, .25), col = grid, lwd = 1); axis(1, col = grid, col.ticks = grid); axis(2, at = seq(0, 1, .25), labels = paste0(seq(0, 100, 25), "%"), col = NA)
  med <- c()
  for (i in seq_along(arms)) {
    sel <- arm == arms[i]; t <- a$AVAL[sel]; e <- 1 - a$CNSR[sel]
    o <- order(t); t <- t[o]; e <- e[o]; ut <- unique(t[e == 1]); S <- 1; tt <- 0; ss <- 1
    for (u in ut) { S <- S * (1 - sum(t == u & e == 1) / sum(t >= u)); tt <- c(tt, u); ss <- c(ss, S) }
    tt <- c(tt, max(t)); ss <- c(ss, S)
    lines(tt, ss, type = "s", col = cols[i], lwd = 2.2)
    cz <- t[e == 0]; sv <- vapply(cz, function(x) ss[max(which(tt <= x))], 1); points(cz, sv, pch = "|", col = cols[i], cex = .55)
    m <- tt[which(ss <= .5)[1]]; med <- c(med, if (is.na(m)) "NR" else format(round(m)))
  }
  par(xpd = NA)
  legend(tmax * 1.03, .98, legend = paste0(arms, "\nn = ", as.vector(table(arm)[arms]), " \u00b7 median ", med), col = cols[seq_along(arms)], lwd = 2.2,
         bty = "n", cex = .82, text.col = ink2, title = "ARM", title.col = ink2, title.font = 2, y.intersp = 2.1, seg.len = 1.6)
  title(main = "Kaplan-Meier: overall survival", adj = 0, line = 2, col.main = ink, cex.main = 1.2, font.main = 2)
  mtext(sprintf("Intent-to-treat population, %d subjects", length(unique(a$USUBJID))), side = 3, adj = 0, line = .7, col = ink3, cex = .9)
  dev.off()
  enc <- div(class = "well bench-encodings", tags$h6(class = "bench-enc-title", "Encodings"),
             shiny::selectInput("km-endpoint", "Endpoint", c("Overall Survival" = "OS", "Progression-Free Survival" = "PFS", "Event-Free Survival" = "EFS"), "OS"),
             shiny::selectInput("km-arm", "Arm variable", c("ARM", "ACTARM", "ARMCD"), "ARM"),
             shiny::selectInput("km-ref", "Reference group", arms, arms[1]),
             shiny::selectInput("km-strata", "Strata variables", c("None" = "", "SEX", "STRATA1", "BMRKR2"), ""),
             bslib::input_switch("km-ci", "Confidence intervals", FALSE), bslib::input_switch("km-table", "Numbers at risk", TRUE))
  plot_card <- div(class = "card bench-output", div(class = "card-body", div(class = "shiny-plot-output", id = "km-plot", tags$img(src = "plots/km.svg", alt = "Kaplan-Meier plot", style = "width:100%;height:auto;display:block"))))
  filt <- tags$aside(class = "sidebar bench-filter", div(class = "sidebar-content",
    tags$header(class = "sidebar-title", "Filter panel"),
    div(class = "card bench-filter-card", div(class = "card-body", tags$div(class = "bench-filter-var", tags$code("ADSL"), " \u00b7 AGE"),
        shiny::sliderInput("f-age", NULL, min = min(ds$ADSL$AGE), max = max(ds$ADSL$AGE), value = c(min(ds$ADSL$AGE), max(ds$ADSL$AGE)), step = 1, ticks = FALSE))),
    div(class = "card bench-filter-card", div(class = "card-body", tags$div(class = "bench-filter-var", tags$code("ADTTE"), " \u00b7 PARAMCD"),
        shiny::checkboxInput("f-os", paste0("OS (", sum(ds$ADTTE$PARAMCD == "OS"), ")"), TRUE)))))
  div(class = "bench-module-layout", div(class = "bench-enc-col", enc), div(class = "bench-out-col", plot_card), filt)
}

# pages the bench renders with the app's own module UI: TLG Catalog pages (+ BlockR's canvas)
render_pane <- function(p) {
  m <- p$mod
  if (is.function(m$ui) && (identical(m$ui, ui_tlg_catalog) || (APP == "BlockR" && exists("ui_blockr_canvas") && identical(m$ui, ui_blockr_canvas)))) {
    args <- c(list(id = paste0("mod-", slug(p$label))), m$ui_args %||% list())
    return(do.call(m$ui, args))
  }
  if (APP == "teal_neue" && grepl("^kaplan", tolower(p$label))) return(km_standin())
  div(class = "bench-module", `data-module` = p$label)
}
first <- panes[[1]]$id
body <- div(class = "container-fluid teal-page",           # teal's page is a fluid Bootstrap container
  header,
  div(class = "teal-modules-wrapper",
      tags$ul(class = "nav nav-underline teal-nav", id = "teal-modules", role = "tablist", nav_items),
      div(class = "tab-content", lapply(panes, function(p) div(class = "tab-pane", class = if (p$id == first) "active show", id = p$id,
                                                               `data-value` = p$label, role = "tabpanel", render_pane(p))))),
  footer)
bench_render(body, file.path(out, "body.html"))
writeLines(head_script, file.path(out, "head_script.html"))
writeLines(as.character(jsonlite::toJSON(index, auto_unbox = TRUE)), file.path(out, "index.json"))
cat("body.html written (", length(panes), "panes )\n")

# ---- server-rendered outputs of the pages the bench shows, from the apps' own server functions
odir <- file.path(out, "outputs", "default"); dir.create(odir, recursive = TRUE, showWarnings = FALSE)
.shim_pkgs$teal.code <- list(get_code = function(...) character(0))   # data-prep prefix of "Show R code": not available here
for (p in panes) {
  m <- p$mod
  if (is.function(m$ui) && identical(m$ui, ui_tlg_catalog)) local({           # local(): the entries are bound now, not lazily
    ents <- m$ui_args$entries; id <- paste0("mod-", slug(p$label))
    srv_tlg_catalog(id, data = function() data, entries = ents)
  })
}
for (k in ls(.shim$outputs)) if (grepl("-header$", k)) tryCatch(writeLines(render_html(get(k, envir = .shim$outputs)()), file.path(odir, paste0(k, ".html"))), error = function(e) cat("  ", k, ":", conditionMessage(e), "in", deparse(conditionCall(e))[1], "\n"))
# the "Show R code" dialog of the first TLG page, built by the page's own handler
.shim$observers <- Filter(function(o) TRUE, .shim$observers)
ae <- Filter(function(o) grepl("show_code", o$event), .shim$observers)
if (length(ae)) { eval(ae[[1]]$handler, ae[[1]]$env); writeLines(render_html(.shim$modal), file.path(out, "modal_tlg.html")) }
cat("outputs:", length(list.files(odir)), "rendered; code dialog:", file.exists(file.path(out, "modal_tlg.html")), "\n")

# ---- BlockR: the canvas messages, from BlockR's own functions
if (APP == "BlockR") {
  source("/bench/blockr_standins.R", local = globalenv())
  mdir <- file.path(out, "messages"); dir.create(mdir, showWarnings = FALSE)
  msg <- function(name, x) writeLines(as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null")), file.path(mdir, paste0(name, ".json")))
  ns_main <- "mod-canvas-main-"
  labels_ds <- blockr_dataset_labels()
  msg("data", list(ns = ns_main, datasets = unname(lapply(names(ds), function(n) list(name = n, label = if (n %in% names(labels_ds)) unname(labels_ds[[n]]) else n, rows = nrow(ds[[n]]), cols = ncol(ds[[n]]))))))
  catalog <- tlg_catalog()
  for (id in c("AET02", "AET01", "DMT01", "AEL02")) {
    g <- blockr_template_graph(catalog[[id]])
    msg(paste0("graph_", id), list(ns = ns_main, graph = g, implicit = blockr_implicit_deps(g)))
    cache_env <- new.env(parent = emptyenv())
    r <- tryCatch(blockr_run(g, ds, cache_env), error = function(e) list(status = list(), result = NULL, env = new.env(), order = character(0), error = conditionMessage(e)))
    clean <- tryCatch(blockr_compile(g, registry = blockr_registry()), error = function(e) NULL)
    r$code <- if (is.null(clean)) "# The code could not be written." else clean$code
    for (bid in intersect(names(clean$vars), names(r$status))) if (!is.null(clean$vars[[bid]])) r$status[[bid]]$var <- clean$vars[[bid]]
    payload <- blockr_status_payload(r, g, new.env(parent = emptyenv()))
    payload$ns <- ns_main
    msg(paste0("status_", id), payload)
    # data previews (the app shows them with DT, not available here): a plain table of the real first rows
    pdir <- file.path(out, "previews"); dir.create(pdir, showWarnings = FALSE)
    for (nid in names(r$status)) {
      stt <- r$status[[nid]]
      if (!identical(stt$state, "ok") || !isTRUE(stt$kind %in% c("data", "listing"))) next
      v <- tryCatch(blockr_value(r, g, nid), error = function(e) NULL)
      if (!is.data.frame(v)) next
      h <- utils::head(as.data.frame(v), 12); h <- h[, seq_len(min(ncol(h), 8)), drop = FALSE]
      cells <- function(x) vapply(x, function(z) if (is.na(z)) "" else as.character(z), "")
      tb <- tags$div(class = "bench-dt", tags$table(class = "table table-sm table-hover",
        tags$thead(tags$tr(lapply(names(h), function(n) tags$th(n)))),
        tags$tbody(lapply(seq_len(nrow(h)), function(i) tags$tr(lapply(h[i, , drop = FALSE], function(z) tags$td(cells(z))))))),
        tags$div(class = "bench-dt-foot", sprintf("Showing 1 to %d of %s rows", nrow(h), format(nrow(v), big.mark = ","))))
      writeLines(render_html(tb), file.path(pdir, sprintf("%s_%s.html", id, nid)))
    }
    sas <- tryCatch(blockr_sas(g, status = r$status), error = function(e) paste("/* SAS:", conditionMessage(e), "*/"))
    if (FALSE) NULL
    msg(paste0("sas_", id), list(ns = ns_main, rev = 0, code = sas))
    if (!is.null(r$error)) cat("    run error:", r$error, "\n")
    st <- vapply(r$status, function(s) paste0(s$state %||% "?", if (!is.null(s$kind)) paste0(":", s$kind), if (!is.null(s$rows)) paste0(":", s$rows)), "")
    cat(sprintf("  %s: %d blocks; %s\n", id, length(g$nodes), paste(names(table(sub(":.*", "", st))), table(sub(":.*", "", st)), sep = "=", collapse = " ")))
    errs <- Filter(function(s) identical(s$state, "error"), r$status)
    if (length(errs)) cat("    errors:", paste(unique(vapply(errs, `[[`, "", "error")), collapse = " | "), "\n")
  }
  # one dataset block alone (the Tutorial's and "Start from a dataset"'s first canvas): its status, with the
  # column schema the pickers use; the bench maps node "n1" to the id the canvas gives the block
  for (dsn in c("ADSL", "ADAE")) {
    g <- list(version = 1L, nodes = list(list(id = "n1", type = "dataset", dataset = dsn, order = 1L)), result = NULL)
    r <- blockr_run(g, ds, new.env(parent = emptyenv()))
    clean <- tryCatch(blockr_compile(g, registry = blockr_registry()), error = function(e) NULL)
    r$code <- if (is.null(clean)) "" else clean$code
    payload <- blockr_status_payload(r, g, new.env(parent = emptyenv()))
    msg(paste0("status_ds_", dsn), payload)
  }
  cat("  dataset statuses: ADSL, ADAE\n")
}
