library(testthat)

test_that("FSM wrapper functions correctly", {
  expect_true(exists("FSM"))
  expect_type(FSM, "closure")
})