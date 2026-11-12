test_that("frameworks and the decision table", {
  fw <- taiga_frameworks()
  expect_equal(fw$framework, c("lumen", "neue"))
  expect_equal(as.character(taiga_choose_framework("stakeholders", "guided", "low")), "lumen")
  expect_equal(as.character(taiga_choose_framework("analysts", "self-directed", "high")), "neue")
  expect_equal(attr(taiga_choose_framework("stakeholders", "self-directed", "high"), "score"), 2)
  expect_true(all(taiga_apps()$framework %in% fw$framework))
})

test_that("guides are installed", {
  g <- taiga_guides()
  expect_equal(nrow(g), 5)
  expect_true(all(file.exists(g$path)))
  expect_match(readLines(taiga_guide("delivery", open = FALSE), n = 1), "Triple-format")
  expect_match(readLines(taiga_guide("neue-styleguide", open = FALSE), n = 1), "Neue")
})

test_that("the guides' pictures are installed, as thumbnails that link to the full image", {
  for (p in taiga_guides()$path) {
    txt <- paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    refs <- regmatches(txt, gregexpr("\\]\\(([^)#]+\\.(jpg|png))\\)", txt))[[1]]
    refs <- sub("^\\]\\(", "", sub("\\)$", "", refs))
    expect_false(any(grepl("^\\.\\./\\.\\./\\.\\.", refs)))                    # nothing outside the package
    missing <- refs[!file.exists(file.path(dirname(p), refs))]
    expect(length(missing) == 0L, paste0(
      basename(p), ": ", length(missing), " of ", length(refs), " pictures are missing (paths relative to ",
      dirname(p), "), for example ", paste(utils::head(missing, 3), collapse = ", "),
      ". Is inst/guides/img/ complete in this copy of the package?"))
    thumbs <- regmatches(txt, gregexpr("\\[!\\[[^]]*\\]\\([^)]*img/thumb/[^)]+\\)\\]\\([^)]*img/full/[^)]+\\)", txt))[[1]]
    expect_equal(length(thumbs), length(grep("img/thumb/", refs)))             # every thumbnail is clickable
  }
})
