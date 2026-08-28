test_that("FSM matches MATLAB", {
  skip_if_not(
    identical(Sys.getenv("FSDA_LIVE"), "1"),
    "set FSDA_LIVE=1 to run the live MATLAB/FSDA test"
  )

  fsda_root = Sys.getenv("FSDA_ROOT")
  if (!nzchar(fsda_root)) {
    fsda_root = NULL
  }

  h = start_engine("FSM", fsda_root = fsda_root)
  on.exit(stop_engine(h), add = TRUE)

  ref_dir = system.file("extdata", "FSM", package = "fsdabridge")
  y_path = file.path(ref_dir, "FSM_Y.csv")
  mmd_path = file.path(ref_dir, "FSM_mmd.csv")

  expect_true(nzchar(ref_dir))
  expect_true(file.exists(y_path))
  expect_true(file.exists(mmd_path))

  Y = as.matrix(read.csv(y_path))
  expected_mmd = as.matrix(read.csv(mmd_path))

  eval_m(h, "rng(0)", nargout = 0)  # fixes FSM's random initial subset
  out = FSM(h, Y, plots = 0, msg = 0)

  expect_equal(as.character(out$class), "FSM")

  mmd = as.matrix(out$mmd)
  tail_n = nrow(mmd)
  tail_g = nrow(expected_mmd)
  tail = mmd[(tail_n - 4):tail_n, ]
  expected_tail = expected_mmd[(tail_g - 4):tail_g, ]

  expect_lte(max(abs(tail - expected_tail)), 1e-9)
})
