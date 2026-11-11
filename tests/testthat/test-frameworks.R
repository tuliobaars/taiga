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
