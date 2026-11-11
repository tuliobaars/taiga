# Package checks that run without an R installation, in webR (base R 4.6 in WebAssembly); see tools/check.sh.
# Not a substitute for R CMD check (no install, no codetools): run `devtools::check()` where R is available.
# htmltools / jsonlite are the bench stand-ins (tools/bench/shim.R); testthat is QuantSkill's stand-in
# (QuantSkill/dev/tests/testthat_shim.R), both read-only.
source("/bench/shim.R")
source("/qs/testthat_shim.R")
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
cat(if (length(problems)) sprintf("\nCHECK: %d problem(s)\n", length(problems)) else "\nCHECK: OK\n")
