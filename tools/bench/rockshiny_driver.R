# RockShiny bench driver (runs in webR; see run_r.mjs and shim.R).
# Sources R/*.R unmodified and evaluates the UI part of app.R (rs_theme, app_dependency, brand, shortcuts,
# ui), skipping its server-side start-up (resource paths, audio pre-warm). The library selector is
# filled with the labels library_choices() makes from each song's manifest (read here by RockShiny's
# Python reference implementation, since openssl is not available in webR), for songs_all/.
source("/bench/shim.R")
for (f in list.files("/app/R", pattern = "[.]R$", full.names = TRUE)) sys.source(f, envir = globalenv())
options(rockshiny.root = "/app", rockshiny.library_dir = "/app/songs_all")
lib <- jsonlite::read_json("/bench/library.json")
library_choices <- function(...) stats::setNames(paste0("/app/songs_all/", names(lib)), vapply(lib, `[[`, "", "label"))
exprs <- parse("/app/app.R")
keep <- c("rs_theme", "app_dependency", "brand", "shortcuts", "ui")
for (e in exprs) if (is.call(e) && identical(e[[1]], as.name("<-")) && as.character(e[[2]]) %in% keep) eval(e, globalenv())
page <- ui(NULL)
bench_render(page, "/bench/out/ui.html")
writeLines(.shim$body_class %||% "", "/bench/out/body_class.txt")
deps <- unique(Filter(Negate(is.null), lapply(.shim$deps, function(d) list(name = d$name, src = d$src[["file"]] %||% d$src, script = d$script, stylesheet = d$stylesheet))))
writeLines(as.character(jsonlite::toJSON(deps, auto_unbox = TRUE)), "/bench/out/deps.json")
cat("theme:", paste(names(.shim$theme), unlist(.shim$theme), sep = "=", collapse = "; "), "\n")
cat("deps:", paste(vapply(deps, `[[`, "", "name"), collapse = ", "), "\n")
