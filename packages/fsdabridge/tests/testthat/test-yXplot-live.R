test_that("yXplot matches MATLAB", {
  skip_if_not(
    identical(Sys.getenv("FSDA_LIVE"), "1"),
    "set FSDA_LIVE=1 to run the live MATLAB/FSDA test"
  )

  fsda_root = Sys.getenv("FSDA_ROOT")
  if (!nzchar(fsda_root)) {
    fsda_root = NULL
  }

  h = start_engine("yXplot", fsda_root = fsda_root)
  on.exit(stop_engine(h), add = TRUE)

  ref_dir = system.file("extdata", "yXplot", package = "fsdabridge")
  wool_path = file.path(ref_dir, "wool.csv")
  nfig_path = file.path(ref_dir, "nfig.csv")
  nax_path = file.path(ref_dir, "nax.csv")

  expect_true(nzchar(ref_dir))
  expect_true(file.exists(wool_path))
  expect_true(file.exists(nfig_path))
  expect_true(file.exists(nax_path))

  wool = as.matrix(read.csv(wool_path, stringsAsFactors = FALSE))
  y = matrix(wool[, ncol(wool)], ncol = 1)
  X = wool[, seq_len(ncol(wool) - 1), drop = FALSE]

  expected_nfig = as.numeric(read.csv(nfig_path, stringsAsFactors = FALSE)$nfig)
  expected_nax = as.numeric(read.csv(nax_path, stringsAsFactors = FALSE)$nax)

  yXplot(h, y, X)

  nfig = as.numeric(eval_m(h, "double(numel(findobj(0,'type','figure')))"))[1]
  nax = as.numeric(eval_m(h, "double(numel(findobj(0,'type','axes')))"))[1]
  try(eval_m(h, "close all;", nargout = 0), silent = TRUE)

  expect_equal(nfig, expected_nfig)
  expect_equal(nax, expected_nax)
})
