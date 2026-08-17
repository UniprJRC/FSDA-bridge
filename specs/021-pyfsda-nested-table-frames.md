# Spec 021 — Nested tables honor the pandas view (pyfsda)

> Read `CONSTITUTION.md` first. A fix so a MATLAB `table` nested inside a returned `struct`
> behaves like a top-level table: neutral table-dict by default, `pandas.DataFrame` under
> `frames=True`. Scoped to the **pyfsda package** engine.

## Contract

- **Deliverable:** in the pyfsda package engine, a MATLAB `table`/`timetable` that appears as
  a **field of a returned struct** (or element of a cell) marshals to the neutral table-dict
  `{VariableNames, RowNames/RowTimes, data, height}` by default and to a `pandas.DataFrame`
  under `frames=True`, with row/column labels preserved — identical to a top-level table
  output. Fixes all of `corrNominal`'s table fields (`Ntable`, `ConfLimtable`, `TestIndtable`,
  `Contrib2Chi2table`, `Contrib2Hyxtable`, `Contrib2tauyxtable`).
- **Done when:**
  - `corrNominal(N, frames=False)["Ntable"]` is a table-dict with the input's
    `VariableNames`/`RowNames`; `frames=True` → a `DataFrame` with those labels and values
    matching `N` within `1e-9` (test `test_corrnominal_nested_table_frames`).
  - `examples/corrnominal_pandas_example.py` prints `Ntable` as a labeled DataFrame (no
    "plain array" fallback).
  - Top-level table paths unchanged (`grpstatsFS` example/test still pass); no-MATLAB unit
    tests green.
- **Out of scope:** shared `code/fsda_engine/engine.py`, R, Julia; the no-pandas case (a
  nested table then arrives as a `matlab.object`); version bump.

## Design

- **Root cause:** `_marshal_var` on a returned struct takes the fast path
  `from_matlab(self.eng.workspace[vn])`. With pandas installed, `matlab.engine` natively
  converts the struct's table fields to `pandas.DataFrame`s during that read; `from_matlab`
  then hit its `np.asarray(x)` fallback on each DataFrame, **flattening it to a bare ndarray
  and dropping the labels**. `_table_to_dict` (top-level path) never ran for the nested
  tables, so `frames=True`/`apply_frames` had no table-dict to convert. (Verified via the
  MathWorks docs — native table→DataFrame conversion — and a live diagnostic on R2026a +
  matlabengine 26.1.)
- **Fix:** `from_matlab` normalises any `pandas.DataFrame` it meets to the table-dict via a
  new `frames.dataframe_to_table_dict(df)` (inverse of `to_dataframe`), *before* the
  `np.asarray` fallback. A nested table is then on the same footing as a top-level one.
- **Files:** `src/pyfsda/frames.py` (`dataframe_to_table_dict`), `src/pyfsda/engine.py`
  (`from_matlab` branch + import), `examples/corrnominal_pandas_example.py`,
  `tests/test_integration.py`, `CHANGELOG.md`.
- **Isolation:** package engine only; the shared engine + R/Julia gates are untouched (their
  Python env need not have pandas, so their `from_matlab` never sees a DataFrame). The two
  `engine.py` copies already diverge for pandas (spec 019/020).

## Tasks

- [ ] #p3 Consider mirroring into the shared engine once the two `engine.py` copies are unified.

### Done  (2026-08-03)

- [x] #p1 `dataframe_to_table_dict` + `from_matlab` DataFrame branch.
- [x] #p1 corrNominal example rewritten to show nested tables as DataFrames.
- [x] #p2 `test_corrnominal_nested_table_frames`; CHANGELOG entry.

### Verification (2026-08-03)

- Live diagnostic: `corrNominal(N, frames=False)["Ntable"]` → table-dict
  (VarNames `c1,c2,c3`, RowNames `r1,r2,r3`); `frames=True` → DataFrame, index/columns match,
  values == `N` within `1e-9`; all six table fields convert.
- `pytest -m "not integration"` → 24 passed (no MATLAB).
