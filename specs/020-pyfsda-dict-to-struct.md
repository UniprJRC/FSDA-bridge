# Spec 020 — Python dict → MATLAB struct input marshalling (pyfsda)

> Read `CONSTITUTION.md` first. This spec adds the input counterpart to the engine's existing
> struct → dict *output* marshalling, so struct-consuming FSDA routines can be called from
> Python with plain objects. Scoped to the **pyfsda package** engine (see Isolation).

## Contract

- **Deliverable:** in the pyfsda package engine, a Python `dict` passed as a positional
  argument or option value is marshalled to a MATLAB `struct` (recursively), enabling
  idiomatic calls like `pyfsda.resfwdplot(out1, fground=fground, databrush=databrush)` where
  `out1` is an `FSReda` result dict and `fground`/`databrush` are Python dicts. Companion:
  a fully idiomatic example, `examples/resfwdplot_brush_example.py` (LXS → FSReda →
  resfwdplot persistent brushing) that runs **no** MATLAB by hand.
- **Done when:**
  - `eng.call("fieldnames", {...})` returns the dict's keys; a numeric field round-trips
    within `1e-9`; a `list[str]` field crosses as a cellstr (test `test_dict_to_struct_input`).
  - `eng.call("resfwdplot", out1, fground=fground)` (dict inputs) draws without error and
    returns its `plotopt` cell (test `test_resfwdplot_dict_struct_pipeline`).
  - `examples/resfwdplot_brush_example.py` runs end-to-end via `pyfsda.LXS`/`FSReda`/
    `resfwdplot`; non-interactive (no TTY) runs draw without `databrush` and never block.
  - Existing unit tests still pass (the arg/option loops were refactored through one
    `_set_input_var` dispatcher).
- **Out of scope:** struct **arrays** (a `list[dict]` becomes a cell of structs, not a
  1×n struct array); `datetime`/`duration`; timetable inputs; mirroring this into the
  shared `code/fsda_engine/engine.py` and the R/Julia surfaces (follow-up).

## Design

- **Files (all under `packages/pyfsda/`):**
  - `src/pyfsda/engine.py` — new `_set_input_var` dispatcher (routes every positional/option
    value: dict→struct, DataFrame→table, list[str]→cellstr, list[num]→row double, other
    list→cell, else `to_matlab`); new `_dict_to_struct_var` and `_list_to_cell_var`;
    `_cellstr_to_var` gained a `column` flag. The two `call` loops now call `_set_input_var`.
  - `src/pyfsda/__init__.py` — `start()` sets the GitHub-notice gate only when it actually
    creates the engine, so `start(check_version=False)` is no longer re-enabled by a later
    `engine()` / `pyfsda.<name>()` call (bug found while writing the example).
  - `examples/resfwdplot_brush_example.py` — rewritten to the idiomatic façade.
  - `tests/test_integration.py`, `README.md`, `CHANGELOG.md`.
- **Marshalling notes:**
  - Field names validated against `_IDENT_RE`; only bridge temp names are interpolated into
    `eval`, never dict keys or string **values** (injection-safe, as for `_table_to_dict`).
  - **Cell orientation matters.** FSDA graphics structs consume style cells via
    `set(H,{'Color'},...)` / `set(H,{'LineStyle'},...)`, which require an **n×1 column** cell
    (a row raises *"Size mismatch in Param/Value Cell pair"*). So `list[str]` inside a struct
    builds a **column** cell (`_cellstr_to_var(column=True)`), while the table path keeps the
    **row** cell that `array2table 'VariableNames'` wants.
- **Isolation:** R/Julia import the shared `code/fsda_engine/engine.py`; pyfsda uses its own
  copy, so this capability lives only in the package copy (the copies already diverge for the
  pandas view, spec 019). The shared-engine mirror is a follow-up.

## Tasks

- [ ] #p3 Mirror dict→struct into the shared `code/fsda_engine/engine.py` (gives R named-list
      / Julia dict → struct for free); unify the two `engine.py` copies.
- [ ] #p3 Optional: `list[dict]` → MATLAB struct **array** (currently a cell of structs).

### Done  (2026-07-31)

- [x] #p1 `_set_input_var` / `_dict_to_struct_var` / `_list_to_cell_var` + `column` cell flag.
- [x] #p1 `start()` check_version gate fix.
- [x] #p1 Idiomatic `examples/resfwdplot_brush_example.py`.
- [x] #p2 Integration tests `test_dict_to_struct_input` + `test_resfwdplot_dict_struct_pipeline`;
      README input-marshalling note; CHANGELOG entry.

### Verification (2026-07-31)

- `pytest -m "not integration"` (frames + marshalling + functional) → **24 passed**, no MATLAB.
- `pytest -m integration test_dict_to_struct_input` → **passed** (fieldnames/getfield/cellstr).
- `examples/resfwdplot_brush_example.py` end-to-end on a live engine → LMS + FSReda + dict→
  struct `out1` + `fground` column cells + `resfwdplot` draw, clean exit (no stray notice).
- MATLAB MCP confirmed the `set(H,{'Color'},...)` column-cell requirement (the `1e...`
  size-mismatch that drove the column-orientation fix).
