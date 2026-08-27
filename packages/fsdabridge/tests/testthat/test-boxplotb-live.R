test_that("boxplotb matches MATLAB", {
  skip_if_not(
    identical(Sys.getenv("FSDA_LIVE"), "1"),
    "set FSDA_LIVE=1 to run the live MATLAB/FSDA test"
  )

  fsda_root = Sys.getenv("FSDA_ROOT")
  if (!nzchar(fsda_root)) {
    fsda_root = NULL
  }

  h = start_engine("boxplotb", fsda_root = fsda_root)
  on.exit(stop_engine(h), add = TRUE)

  ref_dir = system.file("extdata", "boxplotb", package = "fsdabridge")
  y_path = file.path(ref_dir, "stars.csv")
  cent_path = file.path(ref_dir, "cent.csv")
  spl_path = file.path(ref_dir, "Spl.csv")
  outliers_path = file.path(ref_dir, "outliers.csv")

  expect_true(nzchar(ref_dir))
  expect_true(file.exists(y_path))
  expect_true(file.exists(cent_path))
  expect_true(file.exists(spl_path))
  expect_true(file.exists(outliers_path))

  Y = as.matrix(read.csv(y_path, stringsAsFactors = FALSE))
  expected_cent = as.numeric(read.csv(cent_path, stringsAsFactors = FALSE)$cent)
  expected_spl = as.matrix(read.csv(spl_path, stringsAsFactors = FALSE))
  expected_outliers = as.numeric(read.csv(outliers_path, stringsAsFactors = FALSE)$outliers)

  out = boxplotb(h, Y)
  try(eval_m(h, "close all;", nargout = 0), silent = TRUE)

  cent = as.numeric(out$cent)
  spl = as.matrix(out$Spl)
  outliers = as.numeric(out$outliers)

  expect_equal(length(cent), length(expected_cent))
  expect_lte(max(abs(cent - expected_cent)), 1e-9)

  expect_equal(dim(spl), dim(expected_spl))
  expect_lte(max(abs(spl - expected_spl)), 1e-9)

  expect_equal(sort(outliers), sort(expected_outliers))
})
