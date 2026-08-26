test_that("Score wrapper agrees with MATLAB/FSDA", {
  skip_if_not(
    identical(Sys.getenv("FSDA_LIVE"), "1"),
    "set FSDA_LIVE=1 to run the live MATLAB/FSDA test"
  )

  python = Sys.getenv("FSDA_DEV_VENV")
  if (!nzchar(python)) {
    python = "C:/Users/hp/FSDA-bridge/fsda-venv/Scripts/python.exe"
  }

  fsda_root = Sys.getenv("FSDA_ROOT")
  if (!nzchar(fsda_root)) {
    fsda_root = NULL
  }

  h = start_engine("Score", python = python, fsda_root = fsda_root)
  on.exit(stop_engine(h), add = TRUE)

  find_repo_root = function() {
    current = normalizePath(getwd(), winslash = "/", mustWork = TRUE)

    repeat {
      candidate = file.path(
        current,
        "code",
        "Score",
        "reference",
        "wool.csv"
      )

      if (file.exists(candidate)) {
        return(current)
      }

      parent = dirname(current)

      if (identical(parent, current)) {
        stop("Could not locate repository root containing code/Score/reference/wool.csv")
      }

      current = parent
    }
  }

  repo_root = find_repo_root()

  wool_path = file.path(
    repo_root,
    "code",
    "Score",
    "reference",
    "wool.csv"
  )

  oracle_path = file.path(
    repo_root,
    "code",
    "Score",
    "reference",
    "Score_check.csv"
  )

  expect_true(file.exists(wool_path))
  expect_true(file.exists(oracle_path))

  wool = read.csv(
    wool_path,
    stringsAsFactors = FALSE
  )

  X = as.matrix(
    wool[, seq_len(ncol(wool) - 1), drop = FALSE]
  )

  y = wool[, ncol(wool)]

  oracle = read.csv(
    oracle_path,
    stringsAsFactors = FALSE
  )

  la = as.numeric(oracle$la)
  expected = as.numeric(oracle$Score_fsda)

  result = Score(
  h,
  y,
  X,
  la = la,
  intercept = TRUE
)

result = result$Score
result = as.numeric(result)

  expect_equal(length(result), length(expected))
  expect_lte(max(abs(result - expected)), 1e-9)
})