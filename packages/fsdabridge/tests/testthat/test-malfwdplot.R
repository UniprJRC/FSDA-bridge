test_that("malfwdplot is exported", {
  expect_true(exists("malfwdplot", envir = asNamespace("fsdabridge"), inherits = FALSE))

  fn = get("malfwdplot", envir = asNamespace("fsdabridge"))

  expect_true(is.function(fn))
  expect_true(all(c("handle", "out", "...") %in% names(formals(fn))))
})
