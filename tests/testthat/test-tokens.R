test_that("token sheets are installed and parse", {
  for (fw in c("lumen", "neue")) {
    expect_true(file.exists(taiga_css(fw)))
    v <- taiga_css_vars(taiga_css(fw))
    expect_gt(nrow(v), 50)
    expect_true(all(startsWith(v$name, "--")))
  }
})

test_that("taiga_css_vars reads selectors, at-rules and plain declarations", {
  css <- "/* c */ .a { --x: 1px; color: red } @media (max-width: 10px) { .b { --y: #fff; } }"
  v <- taiga_css_vars(css)
  expect_equal(v$name, c("--x", "--y"))
  expect_equal(v$selector, c(".a", ".b"))
  expect_true(is.na(v$at_rule[1]))
  expect_match(v$at_rule[2], "@media")
  expect_equal(nrow(taiga_css_vars(css, all = TRUE)), 3)
})

test_that("themes resolve in order (later selectors override)", {
  day <- taiga_tokens("lumen")
  dark <- taiga_tokens("lumen", "dark")
  expect_equal(unname(day["--lm-bg"]), "#fbfbfd")
  expect_equal(unname(dark["--lm-bg"]), "#000")
  expect_equal(unname(dark["--lm-r-l"]), unname(day["--lm-r-l"]))        # inherited from .lm
  expect_equal(unname(taiga_tokens("lumen", "studio")["--lm-accent"]), "#a855f7")
  expect_equal(unname(taiga_tokens("neue", "light")["--tn-accent"]), "#0e8f83")
  expect_equal(unname(taiga_tokens("neue", "dark")["--tn-panel"]), "#10161b")
  expect_equal(unname(taiga_tokens("neue", "slate")["--tn-panel"]), "#1e262e")
  expect_true(all(startsWith(names(taiga_tokens("neue", prefix = "--tn-ink")), "--tn-ink")))
  expect_error(taiga_tokens("lumen", "nope"))
})

test_that("every theme of taiga_themes() has tokens", {
  th <- taiga_themes()
  for (i in seq_len(nrow(th))) expect_gt(length(taiga_tokens(th$framework[i], th$theme[i])), 20)
})

test_that("extracted application values are installed", {
  apps <- taiga_extracted()
  expect_setequal(apps, taiga_apps()$app)
  x <- taiga_extracted("BlockR")
  expect_equal(x$framework, "neue")
  expect_gt(x$n_custom_properties, 600)
  expect_error(taiga_extracted("nope"))
})

test_that("multi-line comments before a rule are not part of its selector", {
  v <- taiga_css_vars("/* line 1\n line 2 */\n.a { --x: 1 }\n/* another\n */ .b { --y: 2 }")
  expect_equal(v$selector, c(".a", ".b"))
})
