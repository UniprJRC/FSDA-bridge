test_that("yXplot is exported", {
  expect_true(exists("yXplot", envir = asNamespace("fsdabridge"), inherits = FALSE))

  fn = get("yXplot", envir = asNamespace("fsdabridge"))

  expect_true(is.function(fn))
  expect_true(all(c("handle", "y", "X", "...") %in% names(formals(fn))))
})
