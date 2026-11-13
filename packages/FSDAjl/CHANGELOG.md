# Changelog

All notable changes to `FSDABridge` are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-13

First release. FSDABridge.jl calls routines of the MATLAB FSDA toolbox from Julia,
through PythonCall and MATLAB’s Engine API for Python.

### Added
- `call(name, args...; kwargs...)` runs any FSDA or MATLAB function by name.
  Positional arguments are passed in order; keyword arguments become MATLAB
  name-value pairs. the option `nargout` sets the number of outputs returned by the called function.
- Wrapper functions for 16 FSDA routines, each equivalent to `call()` with the
  routine's name: `mahalFS`, `Score`, `FSR`, `FSRaddt`, `FSRfan`, `LXS`, `MMreg`,
  `FSM`, `FSMeda`, `mcd`, `unibiv`, `tclust`, `tkmeans`, `yXplot`, `malfwdplot`,
  `boxplotb`.
- The MATLAB engine starts automatically on the first call; `stop_engine()` shuts
  it down.
- `start_engine()` starts the engine and returns an engine handle;
  `call(handle, name, ...)` and `stop_engine(handle)` use it.
- `eval_expr(expr)` evaluates a MATLAB expression.
- `render_figures()` and `wait_for_figures()` for routines that draw MATLAB figures.
- `diagnostics(handle)` reports the Julia, PythonCall, Python, MATLAB and
  matlabengine versions in use.
- Documentation with examples for 13 FSDA routines, and 16 example scripts in `examples/`.

[0.1.0]: https://github.com/UniprJRC/FSDA-bridge/releases/tag/FSDABridge-v0.1.0
