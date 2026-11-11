# Internal helpers ---------------------------------------------------------------------------

`%||%` <- function(x, y) if (is.null(x)) y else x

#' Path to a file installed with taiga
#'
#' Uses [system.file()]. During development without an installed package, the option
#' `taiga.inst` can point at the source `inst/` folder.
#' @noRd
taiga_path <- function(...) {
  p <- system.file(..., package = "taiga")
  if (nzchar(p)) return(p)
  root <- getOption("taiga.inst")
  if (!is.null(root)) {
    p <- file.path(root, ...)
    if (file.exists(p)) return(normalizePath(p, winslash = "/"))
  }
  stop("taiga: file not found: ", paste(c(...), collapse = "/"), call. = FALSE)
}

#' @noRd
taiga_version <- function() {
  tryCatch(as.character(utils::packageVersion("taiga")), error = function(e) "0.1.0")
}

#' Read a text file as one UTF-8 string
#' @noRd
read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}
