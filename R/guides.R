# Guides ---------------------------------------------------------------------------------------

#' The Taiga guides
#'
#' The styleguides, the requirements for new projects and the delivery model, installed as Markdown.
#' The image links in the guides point at the six application folders of the Taiga workspace, next to
#' the package sources.
#'
#' @return A data frame with `topic`, `title` and `path`.
#' @seealso [taiga_guide()]
#' @examples
#' taiga_guides()[, c("topic", "title")]
#' @export
taiga_guides <- function() {
  topics <- data.frame(
    topic = c("lumen-styleguide", "lumen-requirements", "neue-styleguide", "neue-requirements", "delivery"),
    title = c("Lumen: styleguide", "Lumen: requirements for new projects", "Neue: styleguide",
              "Neue: requirements for new projects", "Triple-format delivery model: Shiny, Quarto, HTML"),
    file = c("lumen/STYLEGUIDE.md", "lumen/REQUIREMENTS.md", "neue/STYLEGUIDE.md", "neue/REQUIREMENTS.md", "DELIVERY_MODEL.md"),
    stringsAsFactors = FALSE
  )
  topics$path <- vapply(topics$file, function(f) taiga_path("guides", f), "", USE.NAMES = FALSE)
  topics$file <- NULL
  topics
}

#' Open or locate a Taiga guide
#'
#' @param topic One of the topics of [taiga_guides()]: `"lumen-styleguide"`,
#'   `"lumen-requirements"`, `"neue-styleguide"`, `"neue-requirements"` or `"delivery"`.
#' @param open Show the guide ([utils::file.show()])? The default shows it in interactive sessions.
#' @return Invisibly, the path of the Markdown file.
#' @examples
#' p <- taiga_guide("delivery", open = FALSE)
#' readLines(p, n = 1)
#' @export
taiga_guide <- function(topic = c("lumen-styleguide", "lumen-requirements", "neue-styleguide", "neue-requirements", "delivery"),
                        open = interactive()) {
  topic <- match.arg(topic)
  g <- taiga_guides()
  path <- g$path[g$topic == topic]
  if (isTRUE(open)) utils::file.show(path, title = g$title[g$topic == topic])
  invisible(path)
}
