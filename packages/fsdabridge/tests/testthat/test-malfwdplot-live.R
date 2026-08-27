test_that("malfwdplot matches MATLAB", {
  skip_if_not(
    identical(Sys.getenv("FSDA_LIVE"), "1"),
    "set FSDA_LIVE=1 to run the live MATLAB/FSDA test"
  )

  fsda_root = Sys.getenv("FSDA_ROOT")
  if (!nzchar(fsda_root)) {
    fsda_root = NULL
  }

  h = start_engine("malfwdplot", fsda_root = fsda_root)
  on.exit(stop_engine(h), add = TRUE)

  ref_dir = system.file("extdata", "malfwdplot", package = "fsdabridge")
  y_path = file.path(ref_dir, "hawkins.csv")
  mal_path = file.path(ref_dir, "MAL.csv")
  nfig_path = file.path(ref_dir, "nfig.csv")
  nax_path = file.path(ref_dir, "nax.csv")

  expect_true(nzchar(ref_dir))
  expect_true(file.exists(y_path))
  expect_true(file.exists(mal_path))
  expect_true(file.exists(nfig_path))
  expect_true(file.exists(nax_path))

  Y = as.matrix(read.csv(y_path, stringsAsFactors = FALSE))
  bs = matrix(1:20, ncol = 1)
  expected_mal = as.matrix(read.csv(mal_path, stringsAsFactors = FALSE))
  expected_nfig = as.numeric(read.csv(nfig_path, stringsAsFactors = FALSE)$nfig)
  expected_nax = as.numeric(read.csv(nax_path, stringsAsFactors = FALSE)$nax)

  out = fsda_call(h, "FSMeda", Y, bs, init = 30, msg = 0, plots = 0)
  mal = as.matrix(out$MAL)

  expect_equal(dim(mal), dim(expected_mal))
  expect_lte(max(abs(mal - expected_mal)), 1e-9)

  malfwdplot(h, out)

  nfig = as.numeric(eval_m(h, "double(numel(findobj(0,'type','figure')))"))[1]
  nax = as.numeric(eval_m(h, "double(numel(findobj(0,'type','axes')))"))[1]
  try(eval_m(h, "close all;", nargout = 0), silent = TRUE)

  expect_equal(nfig, expected_nfig)
  expect_equal(nax, expected_nax)
})
