# Runs only from the package sources (devtools::test(), RStudio's Build > Test): the installed package used by
# R CMD check has no .Rbuildignore. R CMD build deletes every file that a .Rbuildignore pattern matches,
# after it has built the vignette; if the built vignette in inst/doc is deleted, installing the package
# fails with "installing vignettes failed ... doc/index.html".
test_that(".Rbuildignore keeps what the package needs", {
  rbi <- test_path("..", "..", ".Rbuildignore")
  skip_if_not(file.exists(rbi), "not run from the package sources")
  pats <- readLines(rbi, warn = FALSE)
  pats <- pats[nzchar(trimws(pats))]
  keep <- c("DESCRIPTION", "NAMESPACE", "R/delivery.R", "man/taiga_css.Rd", "vignettes/taiga.Rmd",
            "inst/doc/taiga.html", "inst/doc/taiga.Rmd", "inst/doc/taiga.R", "build/vignette.rds",
            "inst/guides/DELIVERY_MODEL.md", "inst/guides/img/full/format-qs-html.jpg",
            "inst/css/lumen-tokens.css", "tests/testthat/test-build.R")
  for (p in pats) {
    hit <- keep[vapply(keep, function(f) isTRUE(grepl(p, f, perl = TRUE, ignore.case = TRUE)), TRUE)]
    expect(length(hit) == 0L, sprintf(
      "The .Rbuildignore line '%s' makes R CMD build drop %s. Remove it (the package ships with: %s).",
      p, paste(hit, collapse = ", "), "^.*\\.Rproj$ ^\\.Rproj\\.user$ ^\\.gitignore$ ^LICENSE\\.md$ ^README\\.md$ ^VERIFICATION\\.md$ ^tools$ ^doc$ ^Meta$ ^renv$ ^renv\\.lock$"))
  }
  expect_true(any(grepl("^\\^tools\\$?$", pats)))                       # development tools stay out
})

# Files dated in the future (for example, unzipped in a time zone behind the one they were zipped in) make
# R CMD build delete the vignette source: tools::buildVignettes() removes every file in vignettes/ that is
# newer than the start of the build. The build then has no vignette ("Removed empty directory
# 'taiga/inst/doc'") and installing the package fails ("installing vignettes failed ... doc/index.html").
test_that("no package file is dated in the future", {
  root <- test_path("..", "..")
  skip_if_not(file.exists(file.path(root, "DESCRIPTION")) && dir.exists(file.path(root, "vignettes")), "not run from the package sources")
  files <- c(file.path(root, c("DESCRIPTION", "NAMESPACE")),
             list.files(file.path(root, c("R", "man", "vignettes", "inst", "tests")), recursive = TRUE, full.names = TRUE))
  future <- files[file.mtime(files) > Sys.time() + 60]
  expect(length(future) == 0L, paste0(
    length(future), " files have modification times in the future, e.g. ", paste(utils::head(basename(future), 3), collapse = ", "),
    ". R CMD build would delete vignettes/taiga.Rmd. Fix: in R, from the package folder, run ",
    "Sys.setFileTime(list.files(recursive = TRUE, all.files = TRUE), Sys.time())"))
})
