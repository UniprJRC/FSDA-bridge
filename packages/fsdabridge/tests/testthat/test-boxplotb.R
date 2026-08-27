test_that("boxplotb is exported", {
  expect_true(exists("boxplotb", envir = asNamespace("fsdabridge"), inherits = FALSE))

  fn = get("boxplotb", envir = asNamespace("fsdabridge"))

  expect_true(is.function(fn))
  expect_true(all(c("handle", "Y", "...") %in% names(formals(fn))))
})
