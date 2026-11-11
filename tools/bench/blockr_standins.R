# Base-R stand-ins for the functions BlockR's blocks call, so that BlockR's own blockr_run() can run the
# canvas in webR (dplyr, tern, rtables, formatters, ggplot2 are not available offline).
#
# Data verbs have real semantics: the row and column counts the canvas shows for data blocks are true
# counts on the bundled ADaM data. Layout, table and plot functions return correctly classed objects
# without content, so those blocks report their kind ("layout", "table", "plot") but no table
# dimensions are invented. Anything not implemented here fails on its block, in words, as in the app.

.mask <- function(df, env) { e <- list2env(as.list(df), parent = env); e }
.dots <- function(...) as.list(substitute(list(...)))[-1]

`%>%` <- function(lhs, rhs) {
  rhs <- substitute(rhs); env <- parent.frame()
  e <- new.env(parent = env); assign(".bench_lhs", lhs, envir = e)
  call <- if (is.call(rhs)) as.call(c(rhs[[1]], quote(.bench_lhs), as.list(rhs)[-1])) else as.call(list(rhs, quote(.bench_lhs)))
  eval(call, e)
}
filter <- function(.data, ..., .preserve = FALSE) {
  ex <- eval(substitute(alist(...))); env <- parent.frame()
  keep <- rep(TRUE, nrow(.data))
  for (x in ex) { v <- eval(x, .mask(.data, env)); v[is.na(v)] <- FALSE; keep <- keep & rep_len(v, nrow(.data)) }
  out <- .data[keep, , drop = FALSE]; rownames(out) <- NULL; out
}
mutate <- function(.data, ...) {
  ex <- eval(substitute(alist(...))); env <- parent.frame()
  for (nm in names(ex)) .data[[nm]] <- rep_len(eval(ex[[nm]], .mask(.data, env)), nrow(.data))
  .data
}
if_else <- function(condition, true, false, missing = NULL) { out <- ifelse(condition, true, false); if (!is.null(missing)) out[is.na(condition)] <- missing; out }
case_when <- function(...) {
  fs <- list(...); n <- max(vapply(fs, function(f) length(eval(f[[2]], environment(f))), 1L)); out <- rep(NA, n); done <- rep(FALSE, n)
  for (f in fs) { cond <- rep_len(eval(f[[2]], environment(f)), n); val <- rep_len(eval(f[[3]], environment(f)), n); hit <- !done & !is.na(cond) & cond
    out[hit] <- val[hit]; done <- done | hit }
  out
}
.select_idx <- function(df, ex, env) {
  nms <- names(df); pos <- integer(); neg <- integer()
  helpers <- list(starts_with = function(x) which(startsWith(nms, x)), ends_with = function(x) which(endsWith(nms, x)),
                  contains = function(x) grep(x, nms, fixed = TRUE), everything = function() seq_along(nms), all_of = function(x) match(x, nms),
                  any_of = function(x) stats::na.omit(match(x, nms)))
  one <- function(x) {
    if (is.name(x)) return(match(as.character(x), nms))
    if (is.character(x)) return(match(x, nms))
    if (is.call(x) && identical(x[[1]], as.name("c"))) return(unlist(lapply(as.list(x)[-1], one)))
    if (is.call(x) && identical(x[[1]], as.name(":"))) return(seq(one(x[[2]]), one(x[[3]])))
    eval(x, list2env(helpers, parent = env))
  }
  for (x in ex) { if (is.call(x) && identical(x[[1]], as.name("-"))) neg <- c(neg, one(x[[2]])) else pos <- c(pos, one(x)) }
  if (!length(pos)) pos <- seq_along(nms)
  setdiff(unique(pos), neg)
}
select <- function(.data, ...) { ex <- eval(substitute(alist(...))); .data[, .select_idx(.data, ex, parent.frame()), drop = FALSE] }
arrange <- function(.data, ...) {
  ex <- eval(substitute(alist(...))); if (!length(ex)) return(.data); env <- parent.frame(); m <- .mask(.data, env)
  keys <- lapply(ex, function(x) { if (is.call(x) && identical(x[[1]], as.name("desc"))) -xtfrm(eval(x[[2]], m)) else xtfrm(eval(x, m)) })
  .data[do.call(order, keys), , drop = FALSE]
}
desc <- function(x) -xtfrm(x)
distinct <- function(.data, ..., .keep_all = FALSE) {
  ex <- eval(substitute(alist(...)))
  if (!length(ex)) return(unique(.data))
  idx <- .select_idx(.data, ex, parent.frame()); d <- !duplicated(.data[, idx, drop = FALSE])
  if (.keep_all) .data[d, , drop = FALSE] else .data[d, idx, drop = FALSE]
}
count <- function(x, ..., name = "n", sort = FALSE) {
  ex <- eval(substitute(alist(...))); if (!length(ex)) return(stats::setNames(data.frame(nrow(x)), name))
  g <- x[, .select_idx(x, ex, parent.frame()), drop = FALSE]
  out <- stats::aggregate(rep(1L, nrow(g)), by = as.list(g), FUN = length); names(out)[ncol(out)] <- name
  if (sort) out <- out[order(-out[[name]]), , drop = FALSE]
  out
}
left_join <- function(x, y, by = NULL, ...) merge(x, y, by = by %||% intersect(names(x), names(y)), all.x = TRUE, sort = FALSE)
n <- function() stop("n() is only available inside summarise() in the app (dplyr)")
df_explicit_na <- function(data, omit_columns = NULL, char_as_factor = TRUE, logical_as_factor = FALSE, na_level = "<Missing>") {
  for (nm in setdiff(names(data), omit_columns)) {
    x <- data[[nm]]; lab <- attr(x, "label")
    if (is.character(x) || is.factor(x)) {
      v <- as.character(x); v[is.na(v) | v == ""] <- na_level
      lv <- if (is.factor(x)) unique(c(setdiff(levels(x), ""), if (any(v == na_level)) na_level)) else sort(unique(v))
      x <- if (char_as_factor || is.factor(data[[nm]])) factor(v, levels = unique(c(lv, unique(v)))) else v
      attr(x, "label") <- lab; data[[nm]] <- x
    }
  }
  data
}
var_relabel <- function(x, ...) { l <- list(...); for (k in names(l)) if (k %in% names(x)) attr(x[[k]], "label") <- l[[k]]; x }
as_listing <- function(df, key_cols = NULL, disp_cols = NULL, ...) {
  cols <- unique(c(key_cols, disp_cols)); out <- if (length(cols)) df[, intersect(cols, names(df)), drop = FALSE] else df
  class(out) <- c("listing_df", class(out)); out
}
day2month <- function(x) x / 30.4375

# layouts, tables, plots: classed objects without content (no invented numbers)
.layout <- function(...) structure(list(), class = "PreDataTableLayouts")
.lyt_fun <- function(name) { force(name); function(lyt, ...) {
  if (missing(lyt) || !inherits(lyt, "PreDataTableLayouts")) stop(sprintf("%s() needs a table layout (bench stand-in for rtables/tern)", name))
  lyt } }
basic_table <- .layout
for (.f in c("split_cols_by", "split_rows_by", "add_overall_col", "summarize_num_patients", "count_occurrences", "count_patients_with_flags",
             "analyze_vars", "append_topleft", "split_cols_by_multivar", "summarize_colvars", "analyze_num_patients", "count_patients_with_event",
             "analyze", "add_colcounts", "count_occurrences_by_grade", "summarize_row_groups")) assign(.f, .lyt_fun(.f))
build_table <- function(lyt, df, alt_counts_df = NULL, ...) {
  if (!inherits(lyt, "PreDataTableLayouts")) stop("build_table() needs a table layout")
  if (!is.data.frame(df)) stop("build_table() needs a data frame")
  structure(list(), class = c("TableTree", "VTableTree"))
}
.tbl_fun <- function(name) { force(name); function(tt, ...) { if (!inherits(tt, "VTableTree")) stop(sprintf("%s() needs a table", name)); tt } }
for (.f in c("prune_table", "sort_at_path", "keep_rows", "trim_rows")) assign(.f, .tbl_fun(.f))
has_fraction_in_any_col <- function(...) function(tr) TRUE
cont_n_allcols <- function(...) 0; score_occurrences <- function(...) 0; drop_split_levels <- function(...) NULL
ggplot <- function(data = NULL, mapping = NULL, ...) structure(list(data = data), class = c("gg", "ggplot"))
`+.gg` <- function(e1, e2) e1
aes <- function(...) structure(list(), class = "uneval")
for (.f in c("geom_col", "geom_bar", "geom_point", "geom_line", "labs", "theme_minimal", "theme_bw", "theme", "facet_wrap", "coord_flip",
             "scale_fill_manual", "scale_colour_manual", "geom_errorbar")) assign(.f, function(...) structure(list(), class = "gg_layer"))
position_dodge <- function(...) list()
g_km <- function(df, ...) { if (!is.data.frame(df)) stop("g_km() needs a data frame"); structure(list(), class = c("gTree", "grob")) }
# packages: attaching is a no-op; every package counts as available for the run
requireNamespace <- function(package, ..., quietly = TRUE) TRUE
library <- function(package, ...) invisible(NULL)
