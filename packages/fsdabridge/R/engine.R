# Package surface for the shared FSDA engine (copied from code/fsda_engine/engine.R).
#
# The actual MATLAB/FSDA call stays in the bundled Python engine
# (inst/python/engine.py, class FsdaEngine); this file owns reticulate setup and
# delegates a *routine-agnostic* `fsda_call(handle, name, ...)` straight to the
# Python `FsdaEngine.call`, so it works for ANY FSDA function.
#
# reticulate with convert = TRUE auto-converts both directions (R matrix <-> numpy,
# dict <-> named list, str <-> character), so no manual recursive converter is needed.
#
# Difference from the repo script: the engine directory is resolved lazily via
# system.file() (the script's source()-location walk would error at install time,
# when no frame carries an ofile and the working directory is the build sandbox).

.engine_dir = function() {
  dir = system.file("python", package = "fsdabridge")
  if (!nzchar(dir) || !file.exists(file.path(dir, "engine.py"))) {
    stop("bundled engine.py not found; please reinstall the 'fsdabridge' package.")
  }
  normalizePath(dir, winslash = "/", mustWork = TRUE)
}

.require_reticulate = function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("R package 'reticulate' is required by fsdabridge.")
  }
  asNamespace("reticulate")
}

.resolve_python = function(python) {
  # No machine-specific default: prefer FSDA_DEV_VENV (passed in as `python`), then the
  # active interpreter on PATH (python or python3), else stop with guidance.
  if (is.null(python) || !nzchar(python)) {
    found = Sys.which(c("python", "python3"))
    found = found[nzchar(found)]
    python = if (length(found) > 0) unname(found[[1]]) else ""
  }
  if (!nzchar(python)) {
    stop(
      "No Python interpreter found. Set FSDA_DEV_VENV to your venv's python ",
      "executable (Scripts\\python.exe on Windows, bin/python on macOS) that ",
      "has matlabengine installed."
    )
  }
  normalizePath(python, winslash = "/", mustWork = FALSE)
}

.configure_python = function(reticulate, python) {
  # Accept a direct executable, a virtualenv root, or a conda-style root. Must run
  # before any Python import because reticulate locks the interpreter.
  root_python = file.path(python, "python.exe")
  scripts_python = file.path(python, "Scripts", "python.exe")
  bin_python = file.path(python, "bin", "python")
  pyvenv_cfg = file.path(python, "pyvenv.cfg")

  if (file.exists(python)) {
    reticulate$use_python(python, required = TRUE)
  } else if (dir.exists(python) && file.exists(pyvenv_cfg)) {
    reticulate$use_virtualenv(python, required = TRUE)
  } else if (file.exists(root_python)) {
    reticulate$use_python(root_python, required = TRUE)
  } else if (file.exists(scripts_python)) {
    reticulate$use_python(scripts_python, required = TRUE)
  } else if (file.exists(bin_python)) {
    reticulate$use_python(bin_python, required = TRUE)
  } else {
    stop(paste0(
      "Python venv or executable not found: ", python,
      ". Set FSDA_DEV_VENV to the project venv or a Python executable with matlabengine."
    ))
  }
}

.validate_handle = function(handle) {
  if (!inherits(handle, "fsda_engine") || is.null(handle$module) || is.null(handle$engine)) {
    stop("handle must be the object returned by start_engine().")
  }
}

.scalar_string = function(x) {
  paste(as.character(unlist(x, recursive = TRUE, use.names = FALSE)), collapse = " ")
}

#' Start a reusable MATLAB/FSDA engine session
#'
#' Imports the bundled Python engine (`inst/python/engine.py`) through
#' reticulate and starts a MATLAB engine session with the FSDA toolbox on its
#' path. Starting MATLAB is expensive (tens of seconds); keep the returned
#' handle and reuse it for many [fsda_call()] invocations, then release it
#' with [stop_engine()].
#'
#' @param routine Optional name of an FSDA routine whose availability is
#'   verified at startup (e.g. `"FSR"`). `NULL` skips the check.
#' @param python Path to the Python interpreter (or virtualenv root) that has
#'   `matlabengine` installed. Defaults to the `FSDA_DEV_VENV` environment
#'   variable, then to `python`/`python3` on the `PATH`.
#' @param fsda_root Path to the FSDA toolbox folder to add to the MATLAB path.
#'   `NULL` assumes FSDA is already on the MATLAB path (e.g. an installed
#'   Add-On).
#' @return An object of class `"fsda_engine"` to pass to [fsda_call()],
#'   [eval_m()], [diagnostics()] and [stop_engine()].
#' @examples
#' \dontrun{
#' h = start_engine("FSR", fsda_root = "~/FSDA")
#' out = fsda_call(h, "FSR", y, X, nsamp = 0, intercept = TRUE, plots = 0)
#' stop_engine(h)
#' }
#' @export
start_engine = function(routine = NULL, python = Sys.getenv("FSDA_DEV_VENV"), fsda_root = NULL) {
  reticulate = .require_reticulate()
  python = .resolve_python(python)
  .configure_python(reticulate, python)

  engine_dir = .engine_dir()
  module = reticulate$import_from_path("engine", path = engine_dir, convert = TRUE)
  engine = module$FsdaEngine$start(routine, fsda_root)

  handle = list(module = module, engine = engine, python = python, engine_dir = engine_dir)
  class(handle) = "fsda_engine"
  handle
}

#' Call any FSDA routine through the engine
#'
#' Routine-agnostic call: positional `...` become MATLAB positional arguments
#' (in order), named `...` become MATLAB name/value option pairs. Pass `y` as
#' an `(n, 1)` matrix when a routine expects a column vector. reticulate
#' converts R matrices to numpy arrays and the returned MATLAB struct/table to
#' a named list automatically.
#'
#' @param handle Engine handle from [start_engine()].
#' @param name Name of the FSDA function to call (e.g. `"FSR"`, `"LXS"`,
#'   `"mahalFS"`).
#' @param ... Positional arguments, then name/value options for the routine.
#' @param nargout Number of MATLAB outputs to request (default 1).
#' @param echo_output If `TRUE`, echo MATLAB console output.
#' @param options Optional named list merged into the name/value options.
#' @return The routine's output converted to R (named list for structs/tables,
#'   matrix/vector for numeric arrays); a list of outputs when `nargout > 1`.
#' @examples
#' \dontrun{
#' out = fsda_call(h, "FSR", y, X, nsamp = 0, intercept = TRUE, plots = 0)
#' lxs = fsda_call(h, "LXS", y, X, intercept = TRUE, plots = 0, msg = 0)
#' }
#' @export
fsda_call = function(handle, name, ..., nargout = 1, echo_output = FALSE, options = NULL) {
  .validate_handle(handle)
  dots = list(...)
  nm = names(dots)
  if (is.null(nm)) nm = rep("", length(dots))
  positional = dots[nm == ""]
  kwargs = dots[nm != ""]
  args = c(
    list(handle$engine$call, name),
    positional,
    list(nargout = as.integer(nargout), echo_output = echo_output, options = options),
    kwargs
  )
  do.call(args[[1]], args[-1])
}

#' Evaluate a raw MATLAB expression
#'
#' Evaluates `expr` in the engine's MATLAB workspace (table/timetable aware)
#' and returns the converted result.
#'
#' @inheritParams fsda_call
#' @param expr A MATLAB expression as a string.
#' @return The expression's value converted to R.
#' @examples
#' \dontrun{
#' eval_m(h, "1+1")
#' }
#' @export
eval_m = function(handle, expr, nargout = 1) {
  .validate_handle(handle)
  handle$engine$eval(expr, nargout = as.integer(nargout))
}

#' Render pending MATLAB figures
#'
#' @inheritParams fsda_call
#' @return Invisibly `NULL`.
#' @export
render_figures = function(handle) {
  .validate_handle(handle)
  handle$engine$render_figures()
  invisible(NULL)
}

#' Block until all open MATLAB figures are closed
#'
#' Driven MATLAB-side via `uiwait`; useful after a plotting routine so the
#' user can inspect forward-search plots before the script continues.
#'
#' @inheritParams fsda_call
#' @return Invisibly `NULL`.
#' @export
wait_for_figures = function(handle) {
  .validate_handle(handle)
  handle$engine$wait_for_figures()
  invisible(NULL)
}

#' Stop the MATLAB engine session
#'
#' MATLAB engine startup is expensive, so callers control shutdown explicitly.
#'
#' @inheritParams fsda_call
#' @return Invisibly `NULL`.
#' @export
stop_engine = function(handle) {
  .validate_handle(handle)
  handle$engine$stop()
  invisible(NULL)
}

#' Diagnostics for the running engine session
#'
#' @inheritParams fsda_call
#' @return A named list with the R, reticulate, Python, MATLAB and
#'   matlabengine versions plus the resolved engine paths.
#' @export
diagnostics = function(handle) {
  .validate_handle(handle)
  reticulate = .require_reticulate()
  py_config = reticulate$py_config()
  metadata = reticulate$import("importlib.metadata", convert = TRUE)
  engine_pkg = tryCatch(metadata$version("matlabengine"), error = function(e) "n/a")
  list(
    r = as.character(getRversion()),
    reticulate = as.character(utils::packageVersion("reticulate")),
    python = .scalar_string(py_config$python),
    python_version = .scalar_string(py_config$version_string),
    matlab = handle$engine$version(),
    matlabengine = engine_pkg,
    engine_dir = handle$engine_dir,
    requested_python = handle$python
  )
}
