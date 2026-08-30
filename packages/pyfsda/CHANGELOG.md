# Changelog

All notable changes to `pyfsda` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and the project uses
[Semantic Versioning](https://semver.org/).

## [0.5.0] — 2026-08-03

### Added
- **Python dict → MATLAB struct input marshalling** (spec 020). A `dict` argument (or option value) now
  crosses as a MATLAB `struct` — recursively: nested `dict` → struct, `list[str]` → cellstr, other lists
  → cell, numbers/arrays/strings via the usual rules. This makes struct-consuming FSDA routines callable
  with plain Python objects: an FSDA result `dict` (e.g. from `FSReda`) can be handed straight back into a
  plot, and option structs like `fground` / `databrush` are ordinary dicts. New example
  `examples/resfwdplot_brush_example.py` (interactive Forward-Search persistent brushing) uses it.
- New example `examples/grpstatsFS_pandas_example.py` — a full **table in → table out** pandas round trip
  (`grpstatsFS`: a numeric DataFrame of observations → a labelled DataFrame of per-variable statistics).

### Fixed
- **Nested tables now honor the pandas view** (spec 021). A MATLAB `table` nested inside a returned
  `struct` (e.g. `corrNominal`'s `Ntable` / `ConfLimtable` / …) is no longer flattened to a bare
  `ndarray` with its labels dropped. It now marshals to the neutral table-dict by default — like a
  top-level table — and to a `pandas.DataFrame` (labels preserved) under `frames=True`.

## [0.4.0] — 2026-07-27

### Added
- **Optional pandas view at the Python boundary** (`pip install pyfsda[pandas]`, spec 019). pandas stays
  optional and lazily imported — `import pyfsda` works without it, and the neutral
  `dict {VariableNames, RowNames/RowTimes, data, height}` remains the default and the cross-language
  contract (R and Julia surfaces are untouched).
  - **Output:** `frames=True` returns `table`/`timetable` outputs as a `pandas.DataFrame`
    (`pyfsda.<name>(..., frames=True)`); new public helper `pyfsda.to_dataframe(table_dict)` and
    predicate `pyfsda.is_table_dict(obj)`.
  - **Input:** a `pandas.DataFrame` argument is marshalled to a MATLAB `table` (`array2table`, names and
    non-default index preserved). v1 supports numeric/logical columns; other column types raise
    `NotImplementedError`.

## [0.3.0] — unreleased

### Added
- On the **first `pyfsda.<name>(...)` call**, print (once, best-effort) the **latest FSDA release
  available on GitHub** so you can check your install is current — a stdlib-only query of the FSDA
  releases API, silent on any failure (offline / rate-limited), and gated by `check_version` (disable
  with `pyfsda.start(check_version=False)`). This is separate from, and runs alongside, the existing
  MATLAB-side `tuna` check at engine start.

## [0.2.0] — unreleased

### Added
- **Functional façade:** call any FSDA routine as a top-level function, e.g.
  `pyfsda.Score(y, X, la=..., intercept=True)` or `pyfsda.mahalFS(Y, MU, SIGMA)` — the shared MATLAB
  session starts lazily on first use and is reused. Backed by a module-level `__getattr__`, so it
  covers every FSDA routine with no per-function code; `from pyfsda import Score` works too.
- Session helpers `pyfsda.start(...)`, `pyfsda.stop()`, `pyfsda.engine()`; the engine is also stopped
  at interpreter exit. Unknown routine names raise a clear `AttributeError` (typo guard).

## [0.1.0] — unreleased

### Added
- First packaged release of the generic FSDA ↔ Python bridge (`FsdaEngine`, `to_matlab`,
  `from_matlab`), extracted from the `fsda_python_porting_test` prototype.
- Routine-agnostic `call` / `eval` surface with generic marshalling
  (numeric ↔ ndarray, struct ↔ dict, cell ↔ list, char ↔ str, table/timetable → dict,
  2-D cell → nested list) via a MATLAB-workspace round-trip.
- Best-effort FSDA up-to-date check at `start()` (FSDA `tuna`, quiet unless outdated;
  disable with `check_version=False`).

### Publishing note
Releases are published to PyPI via GitHub Actions **trusted publishing** (OIDC) on a `v*` tag.
One-time setup: register `pyfsda` as a Trusted Publisher on PyPI
(project → *Publishing* → add the GitHub repo + `publish.yml` workflow).
