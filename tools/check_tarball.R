# Used by tools/check.sh after R CMD build: does the tarball hold what R CMD check needs?
# Usage: Rscript check_tarball.R <tarball> <package source dir> [R CMD build options]
args <- commandArgs(TRUE); tarball <- args[1]; src <- args[2]; no_vignettes <- "--no-build-vignettes" %in% args
files <- sub("^taiga/", "", utils::untar(tarball, list = TRUE))
need <- c("DESCRIPTION", "NAMESPACE", "inst/guides/DELIVERY_MODEL.md", "inst/css/lumen-tokens.css")
if (!no_vignettes) need <- c(need, "build/vignette.rds", "inst/doc/taiga.html", "inst/doc/taiga.Rmd")
imgs <- list.files(file.path(src, "inst", "guides", "img"), recursive = TRUE)
need <- c(need, file.path("inst/guides/img", imgs))
miss <- setdiff(need, files)
cat(sprintf("== tarball: %d files; %d pictures; vignette %s\n", length(files), sum(startsWith(files, "inst/guides/img/") & grepl("[.]jpg$", files)),
            if (no_vignettes) "not built" else if ("inst/doc/taiga.html" %in% files) "built" else "MISSING"))
if (!length(miss)) quit(status = 0)
cat("   R CMD build left out", length(miss), "file(s) the check needs, e.g.\n    ", paste(utils::head(miss, 5), collapse = "\n     "), "\n")
# why? the patterns R CMD build excludes by: its defaults and the source's .Rbuildignore
pats <- c(tools:::get_exclude_patterns(),
          if (file.exists(f <- file.path(src, ".Rbuildignore"))) readLines(f, warn = FALSE))
pats <- pats[nzchar(pats)]
for (m in utils::head(miss, 5)) {
  hit <- pats[vapply(pats, function(p) grepl(p, m, perl = TRUE, ignore.case = TRUE), TRUE)]
  cat("   ", m, ": ", if (length(hit)) paste0("excluded by the pattern ", paste(sQuote(hit, FALSE), collapse = ", "),
                                              " (", file.path(src, ".Rbuildignore"), " or R's defaults)")
                      else "not excluded by any .Rbuildignore pattern", "\n", sep = "")
}
if (any(startsWith(miss, "inst/doc/")))
  cat("   .Rbuildignore in the source folder:\n", paste0("      ", readLines(file.path(src, ".Rbuildignore"), warn = FALSE), collapse = "\n"), "\n")
quit(status = 1)
