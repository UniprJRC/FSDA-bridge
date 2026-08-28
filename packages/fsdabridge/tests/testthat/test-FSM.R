test_that("FSM wrapper is exported and callable", {
  expect_true(exists("FSM"))
  expect_type(FSM, "closure")
  expect_equal(names(formals(FSM)), c("handle", "Y", "..."))
})
