# Minimal testthat stand-in for the webR fallback of tools/check.sh (webR has no CRAN packages).
# Covers only what tests/testthat uses; with a real R installation check.sh runs the real testthat.
.tt <- new.env()
.tt$pass <- 0L; .tt$fail <- 0L; .tt$skip <- 0L; .tt$err <- 0L; .tt$test <- ""
test_path <- function(...) file.path("tests", "testthat", ...)
.tt_fail <- function(msg) {
  .tt$fail <- .tt$fail + 1L
  if (.tt$fail < 40) cat("    FAIL [", .tt$test, "] ", msg, "\n", sep = "")
}
.tt_ok <- function(cond, msg) if (isTRUE(cond)) .tt$pass <- .tt$pass + 1L else .tt_fail(msg)
.tt_lbl <- function(x) paste(deparse(x, width.cutoff = 60L)[1], collapse = "")
.tt_fmt <- function(x) paste(utils::head(format(x), 3), collapse = ",")
expect_equal <- function(object, expected, tolerance = 1.5e-8, ...) {
  ok <- isTRUE(all.equal(object, expected, tolerance = tolerance))  # attributes and names count, as in testthat edition 3
  .tt_ok(ok, paste0(.tt_lbl(substitute(object)), ": got ", .tt_fmt(object), " expected ", .tt_fmt(expected)))
}
expect_identical <- function(object, expected, ...) .tt_ok(identical(object, expected), paste(.tt_lbl(substitute(object)), "not identical"))
expect_true <- function(object, ...) .tt_ok(isTRUE(object), paste(.tt_lbl(substitute(object)), "is not TRUE"))
expect_false <- function(object, ...) .tt_ok(isFALSE(object), paste(.tt_lbl(substitute(object)), "is not FALSE"))
expect_null <- function(object, ...) .tt_ok(is.null(object), paste(.tt_lbl(substitute(object)), "is not NULL"))
expect_length <- function(object, n) .tt_ok(length(object) == n, paste0(.tt_lbl(substitute(object)), " has length ", length(object), " not ", n))
expect_match <- function(object, regexp, fixed = FALSE, ...) .tt_ok(length(object) > 0 && all(grepl(regexp, object, fixed = fixed)), paste(.tt_lbl(substitute(object)), "does not match", regexp))
expect_setequal <- function(object, expected) .tt_ok(setequal(object, expected), paste(.tt_lbl(substitute(object)), "sets differ"))
expect_gt <- function(object, expected) .tt_ok(isTRUE(object > expected), paste(.tt_lbl(substitute(object)), "not >", expected))
expect_error <- function(object, regexp = NULL, ...) {
  e <- tryCatch({ object; NULL }, error = function(e) e)
  .tt_ok(inherits(e, "error") && (is.null(regexp) || grepl(regexp, conditionMessage(e))), "no (matching) error")
}
skip_if_not_installed <- function(pkg, ...) {
  if (!requireNamespace(pkg, quietly = TRUE)) stop(structure(class = c("skip", "condition"), list(message = paste(pkg, "not installed"), call = NULL)))
}
test_that <- function(desc, code) {
  .tt$test <- desc; f0 <- .tt$fail
  r <- tryCatch({ eval(substitute(code), new.env(parent = globalenv())); "ok" },
                skip = function(e) { .tt$skip <- .tt$skip + 1L; paste("SKIP:", conditionMessage(e)) },
                error = function(e) { .tt$err <- .tt$err + 1L; paste("ERROR:", conditionMessage(e)) })
  if (r == "ok" && .tt$fail > f0) r <- sprintf("FAIL: %d expectation(s)", .tt$fail - f0)
  cat(sprintf("  %-4s %s%s\n", if (r == "ok") "ok" else substr(r, 1, 4), desc,
              if (r == "ok") "" else paste0("  (", sub("^[A-Z]+: ", "", r), ")")))
}
expect <- function(ok, failure_message, ...) .tt_ok(ok, failure_message)
skip_on_cran <- function() invisible()
skip_if_not <- function(condition, message = "condition not met") {
  if (!isTRUE(condition)) stop(structure(class = c("skip", "condition"), list(message = message, call = NULL)))
}
