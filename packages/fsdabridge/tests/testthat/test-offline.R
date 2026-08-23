# Offline layer: everything here must pass WITHOUT MATLAB, FSDA or Python —
# this is the layer CRAN's build farm actually runs.

test_that("the bundled Python engine ships with the package", {
  path = system.file("python", "engine.py", package = "fsdabridge")
  expect_true(nzchar(path))
  expect_true(file.exists(path))
})

test_that("the exported surface is complete", {
  for (fn in c("start_engine", "fsda_call", "eval_m", "render_figures",
               "wait_for_figures", "stop_engine", "diagnostics")) {
    expect_true(is.function(get(fn, envir = asNamespace("fsdabridge"))),
                info = fn)
  }
})

test_that("fsda_call rejects a non-handle without touching Python", {
  expect_error(fsda_call(list(), "mahalFS"), "start_engine")
  expect_error(fsda_call(NULL, "FSR"), "start_engine")
  expect_error(stop_engine(42), "start_engine")
})
