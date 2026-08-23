# Generic Layer-2 R surface for the shared FSDA engine (spec 018).
#
# The actual MATLAB/FSDA call stays in the Python engine (code/fsda_engine/engine.py,
# class FsdaEngine); this file owns reticulate setup and delegates a *routine-agnostic*
# `fsda_call(handle, name, ...)` straight to the Python `FsdaEngine.call`. Unlike the
# per-target bridge.R files (one wrapper per routine), this works for ANY FSDA function.
#
# reticulate with convert = TRUE auto-converts both directions (R matrix <-> numpy,
# dict <-> named list, str <-> character), so no manual recursive converter is needed.
# The function is named `fsda_call` (not `call`, which would mask base::call).

.engine_dir = local({
  # Prefer source(".../engine.R") metadata, then fall back to common working dirs.
  frames = sys.frames()
  for (i in rev(seq_along(frames))) {
    ofile = frames[[i]]$ofile
    if (!is.null(ofile) && nzchar(ofile) && basename(ofile) == "engine.R") {
      return(normalizePath(dirname(ofile), winslash = "/", mustWork = TRUE))
    }
  }
  here = normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  candidates = c(here, file.path(here, "code", "fsda_engine"))
  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "engine.py"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Cannot locate code/fsda_engine/engine.py; source engine.R from the repo or its directory.")
})

.require_reticulate = function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("R package 'reticulate' is required for spec 018.")
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

start_engine = function(routine = NULL, python = Sys.getenv("FSDA_DEV_VENV"), fsda_root = NULL) {
  # Import the shared Python engine and start a reusable MATLAB engine session.
  reticulate = .require_reticulate()
  python = .resolve_python(python)
  .configure_python(reticulate, python)

  # engine.py has a unique module name (not the per-target 'bridge'), so no cache
  # eviction is needed; still force this dir to the front so the right file loads.
  module = reticulate$import_from_path("engine", path = .engine_dir, convert = TRUE)
  engine = module$FsdaEngine$start(routine, fsda_root)

  handle = list(module = module, engine = engine, python = python, engine_dir = .engine_dir)
  class(handle) = "fsda_engine"
  handle
}

fsda_call = function(handle, name, ..., nargout = 1, echo_output = FALSE, options = NULL) {
  # Routine-agnostic call: positional `...` -> MATLAB positionals (in order), named
  # `...` -> MATLAB name/value pairs. e.g.
  #   fsda_call(h, "mahalFS", Y, MU, SIGMA)
  #   fsda_call(h, "Score", y, X, la = la, intercept = TRUE)
  # Pass y as an (n, 1) matrix when a routine wants a column. reticulate converts R
  # matrices <-> numpy and the returned dict <-> named list automatically.
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

eval_m = function(handle, expr, nargout = 1) {
  # Evaluate a MATLAB expression through the engine (table/timetable aware).
  .validate_handle(handle)
  handle$engine$eval(expr, nargout = as.integer(nargout))
}

render_figures = function(handle) {
  .validate_handle(handle)
  handle$engine$render_figures()
  invisible(NULL)
}

wait_for_figures = function(handle) {
  # Block until the user closes all open MATLAB figures (driven MATLAB-side via uiwait).
  .validate_handle(handle)
  handle$engine$wait_for_figures()
  invisible(NULL)
}

stop_engine = function(handle) {
  # MATLAB engine startup is expensive, so callers control shutdown explicitly.
  .validate_handle(handle)
  handle$engine$stop()
  invisible(NULL)
}

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
