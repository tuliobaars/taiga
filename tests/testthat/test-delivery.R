test_that("JSON is host-safe (DLV-05)", {
  s <- taiga_json_script(list(a = "</script><!-- x"), "d")
  body <- sub('^<script type="application/json" id="d">(.*)</script>$', "\\1", s)
  expect_false(grepl("<", body, fixed = TRUE))                       # no markup left in the data
  expect_match(body, "\\u003c", fixed = TRUE)
  expect_equal(jsonlite::fromJSON(body)$a, "</script><!-- x")         # and the value round-trips
  expect_match(s, '^<script type="application/json" id="d">')
})

test_that("asset checks (DLV-06)", {
  ex <- taiga_example()
  expect_true(all(taiga_check_assets(c(ex$css, ex$js))$ok))
  bad <- tempfile(fileext = ".js"); writeLines("var s = '<script>';", bad)
  expect_false(taiga_check_assets(bad)$ok)
  expect_error(taiga_fragment("x", js = bad))
  expect_equal(nrow(taiga_check_assets(character())), 0)
})

test_that("one fragment, three hosts", {
  ex <- taiga_example()
  data <- list(title = "Hello, Taiga", items = c("Shiny", "Quarto", "HTML"))
  for (mode in c("html", "quarto", "shiny")) {
    f <- taiga_fragment("hello", mode = mode, css = ex$css, js = ex$js, data = data, framework = "lumen", theme = "dark")
    expect_match(f, sprintf('data-mode="%s"', mode), fixed = TRUE)
    expect_match(f, 'class="hello lm"', fixed = TRUE)
    expect_match(f, 'data-theme="dark"', fixed = TRUE)
    expect_match(f, "--lm-bg", fixed = TRUE)                          # tokens inlined
    expect_match(f, 'id="hello-data"', fixed = TRUE)
  }
  f <- taiga_fragment("hello", css = ex$css, js = ex$js, data = data, framework = "lumen")
  html <- taiga_export_html(f, file.path(tempdir(), "taiga-test.html"), title = "Hello")
  page <- paste(readLines(html, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  expect_match(page, "^<!DOCTYPE html>")
  expect_match(page, "<title>Hello</title>", fixed = TRUE)
  json <- regmatches(page, regexpr('(?<=id="hello-data">).*?(?=</script>)', page, perl = TRUE))
  expect_equal(unlist(jsonlite::fromJSON(json)$items), data$items)   # the data round-trips
  qdir <- tempfile("taiga-q-")
  qmd <- taiga_export_quarto(taiga_fragment("hello", mode = "quarto", css = ex$css, js = ex$js, data = data), qdir,
                             title = "Hello", before = "Commentary.")
  q <- readLines(qmd)
  expect_equal(q[1], "---")
  expect_true("    embed-resources: true" %in% q)
  expect_true("```{=html}" %in% q)
  expect_true("Commentary." %in% q)
  expect_error(taiga_export_quarto("<div></div>", qdir))              # no silent overwrite
})

test_that("capability matrix and app registry", {
  cap <- taiga_capabilities()
  expect_equal(names(cap), c("capability", "shiny", "quarto", "html"))
  apps <- taiga_apps()
  expect_equal(nrow(apps), 6)
  expect_true(all(apps$shiny == "shipped"))
  expect_setequal(apps$app[apps$quarto == "shipped" & apps$html == "shipped"], c("QuantSkill", "lumenJourney"))
})

test_that("dependency", {
  dep <- taiga_dependency("neue")
  expect_equal(dep$name, "taiga-neue")
  expect_equal(dep$stylesheet, "neue-tokens.css")
})

test_that("the Shiny format builds an app", {
  skip_if_not_installed("shiny")
  ex <- taiga_example()
  f <- taiga_fragment("hello", mode = "shiny", css = ex$css, js = ex$js, framework = "lumen", data = list(a = 1))
  app <- taiga_shiny_app(f, taiga_dependency("lumen"), title = "Hello")
  expect_true(inherits(app, "shiny.appobj"))
  expect_error(taiga_shiny_app(f, server = "not a function"))
})

test_that("bslib themes compile for every theme", {
  skip_if_not_installed("bslib")
  skip_on_cran()                                                       # compiling Sass takes a few seconds
  th <- taiga_themes()
  for (i in seq_len(nrow(th))) {
    t <- taiga_bs_theme(th$framework[i], th$theme[i])
    expect_true(bslib::is_bs_theme(t))
    expect_true(length(bslib::bs_theme_dependencies(t)) > 0)
  }
})
