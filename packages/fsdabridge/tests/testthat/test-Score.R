test_that("Score wrapper is exported and has the expected interface", {
  expect_true(exists("Score", envir = asNamespace("fsdabridge"), inherits = FALSE))

  fn = get("Score", envir = asNamespace("fsdabridge"))

  expect_true(is.function(fn))
  expect_true(all(c("handle", "y", "X", "...") %in% names(formals(fn))))
})