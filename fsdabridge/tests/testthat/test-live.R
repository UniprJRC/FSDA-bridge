# Live layer: exercises MATLAB/FSDA through the bridge. Opt-in only — skipped
# everywhere by default (CRAN has no MATLAB; the engine start costs ~30 s).
# Run locally with:  FSDA_LIVE=1 Rscript -e 'testthat::test_dir("tests/testthat")'

test_that("live smoke test: mahalFS agrees with stats::mahalanobis", {
  skip_if(!nzchar(Sys.getenv("FSDA_LIVE")),
          "set FSDA_LIVE=1 (with FSDA_DEV_VENV / FSDA_ROOT) to run the live test")

  fsda_root = Sys.getenv("FSDA_ROOT")
  if (!nzchar(fsda_root)) fsda_root = NULL

  h = start_engine("mahalFS", fsda_root = fsda_root)
  on.exit(stop_engine(h), add = TRUE)

  set.seed(42)
  Y = matrix(rnorm(60), ncol = 3)
  MU = matrix(colMeans(Y), nrow = 1)
  SIGMA = cov(Y)

  d_fsda = as.numeric(fsda_call(h, "mahalFS", Y, MU, SIGMA))
  d_r = as.numeric(stats::mahalanobis(Y, colMeans(Y), SIGMA))
  expect_lt(max(abs(d_fsda - d_r)), 1e-9)
})
