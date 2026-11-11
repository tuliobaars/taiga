# DirectoR bench driver (runs in webR; see run_r.mjs and shim.R).
# Sources DirectoR's own R files unmodified, renders app_ui(), then evaluates every renderUI output
# of the real srv_* functions against real DirectoR engine projects (made by `python -m director
# scout/plan/capture/timeline` in /tmp/taiga-dr/home, see tools/bench/build_director_projects.sh).
source("/bench/shim.R")
for (f in list.files("/app/R", pattern = "[.]R$", full.names = TRUE)) sys.source(f, envir = globalenv())
set.seed(11)
out <- "/bench/out"
home <- "/tmp/taiga-dr/home"
dir.create(out, showWarnings = FALSE)

bench_render(app_ui(), file.path(out, "ui.html"))
cat("ui.html written; theme:", paste(names(.shim$theme), unlist(.shim$theme), sep = "=", collapse = "; "), "\n")

# ---- a minimal session/reactive context (values, not reactivity: the bench renders one state)
session <- list(sendCustomMessage = function(...) NULL, onFlushed = function(...) NULL, onSessionEnded = function(...) NULL,
                allowReconnect = function(...) NULL, userData = new.env(), ns = function(x) x)
input <- list()
doctor <- jsonlite::read_json(file.path(home, "doctor.json"))
render_project <- function(slug, tag) {
  d <- if (is.null(slug)) NULL else file.path(home, "projects", slug)
  rv <- new.env()
  for (k in c("dir", "cfg", "facts", "scout", "sb", "tl", "clips", "man")) assign(k, NULL, envir = rv)
  rv$page <- "lib"; rv$tl_v <- 0; rv$lib_v <- 0; rv$sb_v <- 0; rv$shots_v <- 0; rv$lines_v <- 0
  rv$doctor <- doctor; rv$secrets <- list(); rv$log_open <- FALSE; rv$queue <- list(); rv$player_key <- ""
  if (!is.null(d)) {
    rv$dir <- d; rv$cfg <- dr_cfg(d); rv$facts <- dr_doc(d, "facts"); rv$scout <- dr_doc(d, "scout"); rv$sb <- dr_doc(d, "storyboard")
    rv$tl <- dr_doc(d, "timeline"); rv$clips <- dr_read_json(file.path(d, "vo", "clips.json")); rv$man <- dr_read_json(file.path(d, "out", "manifest.json"))
  }
  ctx <- new.env()
  ctx$home <- home
  ctx$toast <- function(...) NULL
  ctx$url <- function(rel, v = NULL) if (is.null(rv$dir)) "" else paste0("drp/", basename(rv$dir), "/", rel, if (!is.null(v)) paste0("?v=", v) else "")
  ctx$media <- function(rel, v = NULL) if (is.null(rv$dir)) "" else paste0("drp/", basename(rv$dir), "/", rel)
  ctx$set <- function(...) FALSE; ctx$rebuild <- function(...) NULL; ctx$start <- function(...) FALSE; ctx$go <- function(...) NULL
  ctx$load <- function(...) NULL; ctx$env <- function() character()
  output <- new.env()
  for (fn in c("srv_library", "srv_source", "srv_story", "srv_shots", "srv_sound", "srv_look", "srv_export")) {
    r <- tryCatch({ get(fn)(input, output, session, rv, ctx); "ok" }, error = function(e) conditionMessage(e))
    if (!identical(r, "ok")) cat("  ", fn, "setup error:", r, "\n")
  }
  # top bar chips (defined inside app_server(); same expression, evaluated here for the open film)
  if (!is.null(d)) output$top_chips <- function() htmltools::tagList(
    dr_chip(tools::toTitleCase(dr_get(rv$cfg, c("film", "template"), "launch")), "accent", "film"),
    dr_chip(dr_get(rv$cfg, c("format", "aspect"), "16:9"), "", "monitor"),
    if (!is.null(rv$tl$duration)) dr_chip(sprintf("%.1fs", rv$tl$duration), if (rv$tl$duration > 60) "warn" else "", "clock"))
  dir.create(file.path(out, tag), showWarnings = FALSE)
  ok <- 0; bad <- character()
  for (nm in ls(output)) {
    f <- get(nm, envir = output)
    if (!is.function(f)) next
    h <- tryCatch(render_html(f()), error = function(e) { bad <<- c(bad, sprintf("%s (%s)", nm, conditionMessage(e))); NULL })
    if (!is.null(h)) { writeLines(h, file.path(out, tag, paste0(nm, ".html")), useBytes = TRUE); ok <- ok + 1 }
  }
  cat(sprintf("  [%s] %d outputs rendered%s\n", tag, ok, if (length(bad)) paste0("; failed: ", paste(bad, collapse = "; ")) else ""))
}
render_project(NULL, "library")
for (slug in list.dirs(file.path(home, "projects"), full.names = FALSE, recursive = FALSE)) render_project(slug, slug)
# the chip the server pushes (dr-detect) when a link is typed in the Library, as srv_library builds it
for (k in c("url", "git", "zip", "dir")) {
  lab <- c(url = "Website", git = "Git repo", zip = "Zip", dir = "Folder")[[k]]; ic <- c(url = "globe", git = "git", zip = "zip", dir = "folder")[[k]]
  writeLines(render_html(dr_chip(lab, "accent", ic)), file.path(out, paste0("detect_", k, ".html")))
}
