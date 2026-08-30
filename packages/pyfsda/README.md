# pyfsda

Call [**FSDA**](https://github.com/UniprJRC/FSDA) — the MATLAB *Flexible Statistics and Data
Analysis* toolbox for robust statistics — from **Python**, using the MATLAB Engine as the
computational backend. FSDA runs unmodified in MATLAB; `pyfsda` is a thin, routine-agnostic bridge
that marshals data across the boundary.

Call any FSDA routine as a plain Python function — the MATLAB session starts on first use and is
reused:

```python
import pyfsda

d   = pyfsda.mahalFS(Y, MU, SIGMA)                # numeric array -> numpy ndarray
out = pyfsda.Score(y, X, la=la, intercept=True)  # struct        -> dict  (MATLAB-style options)
RAW, REW = pyfsda.mcd(Y, nargout=2)             # two outputs   -> tuple
pyfsda.stop()                                     # optional; also runs automatically at exit
```

`pyfsda.<name>` works for **any** FSDA function (`from pyfsda import Score` works too). Prefer managing
the session yourself? Use the explicit engine:

```python
from pyfsda import FsdaEngine

eng = FsdaEngine.start("mahalFS")
d   = eng.call("mahalFS", Y, MU, SIGMA)
eng.stop()
```

## Requirements

`pyfsda` does not bundle MATLAB or FSDA — it drives your local install. You need:

1. **MATLAB** with the **FSDA Add-On** installed and on the MATLAB path (verify `which mahalFS`
   inside MATLAB).
2. **`matlabengine`** matching your MATLAB release. This is the one version constraint that matters:
   the `matlabengine` package on PyPI is release-locked, so install the one that pairs with your
   MATLAB — e.g. `pip install "matlabengine==26.1.*"` for **R2026a**. `pyfsda` lists `matlabengine`
   as a dependency but deliberately does **not** pin it, so it will not clobber a matching version you
   already have.
3. **Python 3.9–3.13** (whatever your MATLAB release's engine supports).

## Install

```bash
pip install pyfsda
# then, if not already present, the matlabengine that matches YOUR MATLAB:
pip install "matlabengine==26.1.*"     # example: MATLAB R2026a
```

## Verify your install

Run [`examples/smoke_test.py`](examples/smoke_test.py) — it starts MATLAB and checks a few real FSDA
routines against numpy oracles, printing `RESULT: PASS` when your MATLAB + FSDA + `matlabengine` setup
is good:

```bash
python smoke_test.py                 # or:  python smoke_test.py /path/to/FSDA
```

For a worked, MATLAB-style example, see [`examples/score_example.py`](examples/score_example.py) — the
Box-Cox `Score` test on the wool dataset, calling `Score(y, X, 'la', ..., 'intercept', true)` the same
way you would in MATLAB.

## What crosses the boundary

`call(name, *args, nargout=1, echo_output=False, options=None, **kwargs)` marshals positional
arguments in order and keyword arguments (and any `options` dict) as MATLAB name/value pairs. It runs
through the MATLAB workspace so outputs the engine cannot return directly (tables, 2-D cells) are
decoded MATLAB-side.

| MATLAB value | crosses as |
|---|---|
| numeric / logical array | `numpy.ndarray` (natural shape, `NaN`/`Inf` preserved) |
| `struct` | `dict` (recursed) |
| `char` / `string` scalar | `str` |
| `cell` | `list` |
| `table` / `timetable` | `dict` `{VariableNames, RowNames`/`RowTimes, data, height}` |
| 2-D `cell` | nested `list` |
| `nargout > 1` | `tuple` of the above |
| graphics handle (`matlab.graphics.*`) | **not marshalled** — request only data outputs |

Conventions: a 1-D input crosses as a MATLAB **row** (pass an `(n, 1)` array for a column); outputs
keep MATLAB's natural shape (no silent reshape); MATLAB indices stay **1-based**.

**Passing structures in** — the boundary also marshals the other way, so a struct-consuming FSDA
routine can be called with plain Python objects: a `dict` → MATLAB `struct` (recursively), a `list[str]`
→ cellstr, other `list`s → cell, and numbers/arrays/strings via the usual rules. This makes results
round-trip: an FSDA result `dict` (e.g. from `FSReda`) can be handed straight back to a plot, and option
structs like `fground` / `databrush` are just Python dicts — see
[`examples/resfwdplot_brush_example.py`](examples/resfwdplot_brush_example.py).

Reserved keywords consumed by the bridge are only `nargout`, `echo_output`, `options`, and `frames`;
every other keyword is forwarded to MATLAB (so FSDA's own `msg` option passes straight through).
`echo_output=True` tees MATLAB's stdout/stderr to your terminal.

### Optional pandas view (`pip install pyfsda[pandas]`)

pandas is an **optional** dependency — `import pyfsda` works without it. When it is installed you get a
DataFrame view over MATLAB tables, on the Python side only (the neutral dict stays the default and
remains the cross-language contract):

- **Output:** pass `frames=True` to receive `table`/`timetable` outputs as a `pandas.DataFrame`
  (index from `RowNames`/`RowTimes`) — e.g. `out = pyfsda.univariatems(y, X, frames=True)`. The public
  helper `pyfsda.to_dataframe(table_dict)` converts a dict you already have.
- **Input:** pass a `pandas.DataFrame` argument and it is marshalled to a MATLAB `table`
  (`array2table`, column names and any non-default index preserved). v1 covers numeric/logical columns;
  string/categorical/datetime columns raise a clear `NotImplementedError`.

Requesting `frames=True` (or passing a DataFrame) without pandas installed raises a clear
`pip install pyfsda[pandas]` error.

For a full **table in → table out** round trip in one call, see
[`examples/grpstatsFS_pandas_example.py`](examples/grpstatsFS_pandas_example.py): a numeric DataFrame
goes into `grpstatsFS` and a labelled DataFrame of per-variable statistics (mean, median, std, MAD,
skewness, medcouple) comes back via `frames=True`.

On the **first `pyfsda.<name>(...)` call**, pyfsda also prints (once, best-effort) the **latest FSDA
release available on GitHub**, so you can check your install is current. `FsdaEngine.start()`
additionally runs a MATLAB-side FSDA up-to-date check via FSDA's `tuna` utility (quiet unless an update
is available). Both are gated by `check_version` — silence them with
`pyfsda.start(check_version=False)` (or `FsdaEngine.start(check_version=False)`) before the first call.

## Notes

- **MATLAB engine startup is slow** — start one `FsdaEngine` and reuse it; always `stop()` explicitly.
- Struct-arrays and `datetime`/`duration` scalars are out of scope for the generic converters.

## License

[EUPL-1.2](LICENSE) — consistent with FSDA's own licensing.
