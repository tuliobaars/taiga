test_that("luminance and contrast follow WCAG 2.x", {
  expect_equal(taiga_luminance(c("#000", "#ffffff")), c(0, 1))
  expect_equal(taiga_contrast("#000000", "#ffffff"), 21)
  expect_equal(taiga_contrast("#fff", "#fff"), 1)
  expect_equal(taiga_luminance("rgb(255, 255, 255)"), 1)
  expect_equal(taiga_luminance("white"), 1)
  expect_equal(round(taiga_contrast("#ffffff", "#0e8f83"), 2), 3.98)   # white on the Neue teal (styleguide 2.5)
  expect_equal(round(taiga_contrast("#1d1d1f", "#fbfbfd"), 2), 16.28)  # Lumen daylight text 1
})

test_that("WCAG levels", {
  expect_equal(taiga_wcag(c(7, 4.5, 3, 2.9)), c("AAA", "AA", "AA large/UI", "fail"))
})

test_that("audits match the styleguides' contrast rules", {
  a <- taiga_contrast_audit("neue", "light")
  ink4 <- a[a$fg == "--tn-ink-4", ]
  expect_true(all(ink4$wcag == "fail"))                                # ink-4 carries no information
  expect_true(all(a$wcag[a$fg == "--tn-ink"] == "AAA"))
  l <- taiga_contrast_audit("lumen", "dark")
  expect_true(all(l$ratio[l$fg == "--lm-text"] >= 15))                 # LUM-V-03: text 1 >= 15:1
  expect_setequal(names(l), c("framework", "theme", "fg", "fg_value", "bg", "bg_value", "ratio", "wcag"))
})
