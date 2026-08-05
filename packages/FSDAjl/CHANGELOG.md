# Changelog

All notable changes to `FSDA` are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/) and the project uses [Semantic Versioning](https://semver.org/).

## [0.1.0] — unreleased

### Added
- Package skeleton and core files: initial package layout under `packages/FSDAjl/` including `Project.toml` (version 0.1.0), `README.md`, `LICENSE`, a minimal test harness (`test/runtests.jl`), `src/FSDA.jl` (package entry), and `src/engines/engine.jl` (generic Layer-2 Julia surface placeholder to call the shared Python `FsdaEngine`). This commit establishes CI/test defaults and basic documentation so the package can be exercised locally.
- CondaPkg / PythonCall guard: set `JULIA_CONDAPKG_BACKEND=Null` (and document `FSDA_DEV_VENV`) to prevent `CondaPkg`/`PythonCall` from provisioning a Conda-managed Python automatically; this ensures users point PythonCall at an existing Python environment that has `matlabengine` installed.

### Publishing note
This project is a local prototype. Publishing a Julia package to the General registry requires following the registry rules (package naming, CI, tests, and acceptance process). For now `FSDAjl` remains an unregistered local package; to publish you would update `Project.toml` as needed and submit to the General registry via the standard registrator workflow.

---
