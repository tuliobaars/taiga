# Package checks that run without an R installation, in webR (base R 4.6 in WebAssembly); see tools/check.sh.
# Not a substitute for R CMD check (no install, no codetools): run `devtools::check()` where R is available.
# htmltools / jsonlite are the bench stand-ins (tools/bench/shim.R); testthat is tools/testthat_shim.R.
# Everything it needs ships inside this package folder (nothing from the Taiga workspace).
source("/bench/shim.R")
source("/bench/testthat_shim.R")
P <- "/pkg"; options(taiga.inst = file.path(P, "inst"), warn = 1)
problems <- character()
note <- function(...) { m <- paste0(...); problems <<- c(problems, m); cat("  PROBLEM:", m, "\n") }

cat("== DESCRIPTION\n")
d <- read.dcf(file.path(P, "DESCRIPTION"))
for (f in c("Package", "Title", "Version", "Description", "License", "Imports")) if (!f %in% colnames(d)) note("DESCRIPTION lacks ", f)
cat("  ", d[, "Package"], d[, "Version"], "\n")

cat("== R code: parse, ASCII\n")
rfiles <- list.files(file.path(P, "R"), pattern = "[.]R$", full.names = TRUE)
for (f in rfiles) {
  r <- tryCatch({ parse(f); "ok" }, error = function(e) conditionMessage(e)); if (r != "ok") note(basename(f), ": ", r)
  bytes <- readBin(f, "raw", file.info(f)$size); if (any(as.integer(bytes) > 127L)) note(basename(f), ": non-ASCII characters")
}
cat("  ", length(rfiles), "files\n")

cat("== Rd: checkRd\n")
rd <- list.files(file.path(P, "man"), pattern = "[.]Rd$", full.names = TRUE)
for (f in rd) {
  msgs <- tryCatch(tools::checkRd(f), error = function(e) paste("ERROR", conditionMessage(e)))
  if (length(msgs)) note(basename(f), ": ", paste(msgs, collapse = " | "))
}
cat("  ", length(rd), "files\n")

cat("== NAMESPACE exports exist and are documented\n")
ex <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", readLines(file.path(P, "NAMESPACE")), value = TRUE))
for (f in rfiles) sys.source(f, envir = globalenv())
aliases <- unlist(lapply(rd, function(f) { x <- tools::parse_Rd(f); unlist(lapply(x[vapply(x, function(e) attr(e, "Rd_tag") == "\\alias", TRUE)], as.character)) }))
for (e in ex) { if (!exists(e, mode = "function")) note("export without a function: ", e); if (!e %in% aliases) note("export not documented: ", e) }
cat("  ", length(ex), "exports\n")

cat("== codoc: \\usage matches the functions, every argument is documented\n")
rd_text <- function(x) paste(unlist(lapply(x, function(e) if (is.list(e)) rd_text(e) else as.character(e))), collapse = "")
ncodoc <- 0
for (f in rd) {
  x <- tools::parse_Rd(f); tags <- vapply(x, function(e) attr(e, "Rd_tag"), "")
  if (!"\\usage" %in% tags) next
  calls <- as.list(parse(text = rd_text(x[[which(tags == "\\usage")]])))
  items <- if (!"\\arguments" %in% tags) character() else unlist(lapply(x[[which(tags == "\\arguments")]], function(e)
    if (identical(attr(e, "Rd_tag"), "\\item")) trimws(strsplit(rd_text(e[[1]]), ",")[[1]])))
  for (cl in calls) {
    fn <- as.character(cl[[1]]); ncodoc <- ncodoc + 1
    if (!exists(fn, mode = "function")) { note(basename(f), ": usage of unknown function ", fn); next }
    fm <- formals(get(fn, mode = "function")); us <- as.list(cl)[-1]
    un <- ifelse(nzchar(names(us) %||% rep("", length(us))), names(us), vapply(us, deparse, ""))
    if (!identical(as.character(un), as.character(names(fm)))) { note(basename(f), ": usage arguments of ", fn, " differ from the function"); next }
    for (a in names(fm)) {
      d_fun <- if (identical(fm[[a]], quote(expr = ))) "" else paste(deparse(fm[[a]]), collapse = "")
      d_use <- if (nzchar(names(us)[match(a, un)] %||% "")) paste(deparse(us[[match(a, un)]]), collapse = "") else ""
      if (!identical(d_fun, d_use)) note(basename(f), ": default of ", fn, "(", a, ") is ", d_fun, " in the code, ", d_use, " in the usage")
    }
    miss <- setdiff(names(fm), items); if (length(miss)) note(basename(f), ": undocumented arguments ", paste(miss, collapse = ", "))
  }
}
cat("  ", ncodoc, "usages\n")

cat("== globals: no undefined variables in the package functions (like R CMD check's 'no visible binding')\n")
pkg_env <- new.env(); for (f in rfiles) sys.source(f, envir = pkg_env)
.syms <- character(); .asg <- character(); .qual <- character()
.walk <- function(e) {
  if (is.symbol(e)) { s <- as.character(e); if (nzchar(s)) .syms <<- c(.syms, s); return(invisible()) }
  if (!is.call(e)) return(invisible())
  h <- if (is.symbol(e[[1]])) as.character(e[[1]]) else ""
  if (h %in% c("$", "@")) return(.walk(e[[2]]))
  if (h %in% c("::", ":::")) { .qual <<- c(.qual, paste(as.character(e[[2]]), as.character(e[[3]]), sep = "::")); return(invisible()) }
  if (h %in% c("<-", "=", "<<-", "for")) { l <- e[[2]]; while (is.call(l)) l <- l[[2]]; .asg <<- c(.asg, as.character(l)) }
  if (h == "function") {
    .asg <<- c(.asg, names(e[[2]]))
    for (i in seq_along(e[[2]])) if (!identical(e[[2]][[i]], quote(expr = ))) .walk(e[[2]][[i]])
    return(.walk(e[[3]]))
  }
  for (i in seq_along(e)) if (!identical(e[[i]], quote(expr = ))) .walk(e[[i]])
}
.known <- function(x) isTRUE(tryCatch(exists(x, envir = baseenv()) || any(vapply(c("utils", "grDevices", "stats", "methods"),
  function(p) exists(x, envir = asNamespace(p)), TRUE)), error = function(e) NA))
for (n in ls(pkg_env)) {
  f <- get(n, pkg_env); if (!is.function(f)) next
  .syms <- character(); .asg <- names(formals(f)); fm <- formals(f)
  for (i in seq_along(fm)) if (!identical(fm[[i]], quote(expr = ))) .walk(fm[[i]])
  .walk(body(f))
  g <- setdiff(unique(.syms), c(.asg, ls(pkg_env))); g <- g[!vapply(g, .known, TRUE)]
  if (length(g)) note(n, ": undefined global(s) ", paste(g, collapse = ", "))
}
for (q in unique(.qual)) {            # pkg::fun must be exported (R CMD check: 'Missing or unexported object')
  pf <- strsplit(q, "::", fixed = TRUE)[[1]]
  if (requireNamespace(pf[1], quietly = TRUE) && !pf[2] %in% getNamespaceExports(pf[1])) note("missing or unexported object: ", q)
}
cat("  ", length(ls(pkg_env)), "objects,", length(unique(.qual)), "pkg::fun references\n")

cat("== examples\n")
nex <- 0
for (f in rd) {
  out <- tempfile(fileext = ".R"); tools::Rd2ex(f, out, commentDontrun = TRUE)
  if (!file.exists(out)) next
  nex <- nex + 1
  r <- tryCatch({ capture.output(source(out, local = new.env())); "ok" }, error = function(e) conditionMessage(e))
  if (r != "ok") note("example ", basename(f), ": ", r)
}
cat("  ", nex, "example files run\n")

cat("== vignettes (R chunks; knitr is not available here)\n")
for (v in list.files(file.path(P, "vignettes"), pattern = "[.]Rmd$", full.names = TRUE)) {
  L <- readLines(v); starts <- grep("^```\\{r", L); ends <- grep("^```\\s*$", L); n <- 0
  env <- new.env()
  for (st in starts) {
    en <- ends[ends > st][1]; head <- L[st]
    if (grepl("eval\\s*=\\s*FALSE|include\\s*=\\s*FALSE", head)) next
    code <- L[(st + 1):(en - 1)]; code <- code[!grepl("^library\\(taiga\\)", code)]
    r <- tryCatch({ capture.output(eval(parse(text = code), envir = env)); "ok" }, error = function(e) conditionMessage(e))
    if (r != "ok") note(basename(v), " chunk at line ", st, ": ", r); n <- n + 1
  }
  cat("  ", basename(v), n, "chunks run\n")
}

cat("== tests\n")
for (f in list.files(file.path(P, "tests", "testthat"), pattern = "^test-.*[.]R$", full.names = TRUE)) { cat(" ", basename(f), "\n"); sys.source(f, envir = globalenv()) }
cat(sprintf("  %d expectations passed, %d failed, %d errors, %d skipped\n", .tt$pass, .tt$fail, .tt$err, .tt$skip))
if (.tt$fail || .tt$err) note("tests failed")
if (length(problems)) stop(structure(class = c("quiet_error", "error", "condition"),
  list(message = sprintf("CHECK: %d problem(s)", length(problems)), call = NULL)))
cat("\nCHECK: OK\n")
