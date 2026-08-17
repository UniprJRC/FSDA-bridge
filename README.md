# FSDA-bridge — call FSDA from Python (and Julia · R)

Call routines from **[FSDA](https://github.com/UniprJRC/FSDA)** (a MATLAB robust-statistics toolbox)
from **Python**, keeping the original MATLAB FSDA code as the unmodified computational backend. This
repo holds two things:

- **`pyfsda`** (`packages/pyfsda/`) — an **installable Python package**: `import pyfsda` and call any
  FSDA routine as `pyfsda.Score(y, X, ...)`. It has its own build, tests, examples, and CI, and is
  published to PyPI. **Start here if you just want to use FSDA from Python.**
- **The research prototype** (`code/`, `specs/`) it was distilled from — a spec-driven study of the
  Python↔MATLAB bridge, including thin **Julia** (PythonCall) and **R** (reticulate) surfaces over the
  same engine. This is **no build / no CI** by design (see §1–10 below for the internals). Work here is
  spec-driven: `CONSTITUTION.md` fixes the rules, `AGENTS.md` says how to contribute, one file per task
  under `specs/`.

---

## Using `pyfsda`

**Requirements:** MATLAB with the FSDA Add-On on the path, and `matlabengine` **matching your MATLAB
release** (e.g. `pip install "matlabengine==26.1.*"` for R2026a; a different MATLAB needs its paired
version). Python 3.9–3.13.

**Install**:

```bash
pip install pyfsda
# with the optional pandas view:
pip install pyfsda[pandas]
```

**Call any FSDA routine as a Python function** — the MATLAB session starts on first use and is reused:

```python
import pyfsda

d   = pyfsda.mahalFS(Y, MU, SIGMA)               # numeric array -> numpy ndarray
out = pyfsda.Score(y, X, la=la, intercept=True)  # struct        -> dict (MATLAB-style options)
RAW, REW = pyfsda.mcd(Y, nargout=2)             # two outputs   -> tuple
pyfsda.stop()                                     # optional; also runs at exit
```

`pyfsda.<name>` works for **any** FSDA routine (and `from pyfsda import Score` too). Prefer managing the
session yourself? Use the explicit engine: `from pyfsda import FsdaEngine; eng = FsdaEngine.start(...)`.

**New in 0.5.0 — optional pandas view** (`pip install pyfsda[pandas]`): pass `frames=True` to get
`table`/`timetable` outputs back as a `pandas.DataFrame` (row/column labels preserved as the index and
columns), and pass a `pandas.DataFrame` argument to send a MATLAB `table` in — e.g. a labeled
contingency table straight into `corrNominal` or a table containing summary statistics into `grpstatsFS`. 
Output stuctures containing tables are also converted to Pandas' dataframes. Max nesting of tables is 2 
levels. Pandas is optional and lazily imported; the default
return is still the neutral dict, so the shared engine and the R/Julia surfaces are unchanged.

**Learn more:** runnable [`examples/`](packages/pyfsda/examples/) (`score_example_simple.py`,
`score_example.py`, `corrnominal_pandas_example.py`, `grpstatsFS_pandas_example.py`,
`resfwdplot_brush_example.py`, `smoke_test.py`), the package
[README](packages/pyfsda/README.md), and [`CONTRIBUTING.md`](packages/pyfsda/CONTRIBUTING.md)
(dev, self-hosted CI, release flow).

---

The rest of this document describes **how the bridge works internally** — the shared engine, the
marshalling rules, the Julia/R surfaces, and the agreement gates that back all three.

## 1. Architecture at a glance

```text
Layer 0   MATLAB + FSDA                     (never edited — we only call it)
             ▲
Layer 1   Python  FsdaEngine  ── matlab.engine ──►      code/fsda_engine/engine.py
             ▲            ▲
Layer 2   Julia          R
          PythonCall      reticulate
          engine.jl       engine.R
```

**The one idea to take away:** *all* data marshalling lives in **one place** — the Python
`FsdaEngine` (`code/fsda_engine/engine.py`). The Julia and R surfaces are **thin adapters** that call
straight into that Python engine and only convert the result into native Julia/R values. They
re-implement **no** marshalling, so they inherit every engine change for free. (For example: the
2-D-cell decode added for `/clustering` landed a day after the adapters were written, yet the Julia
and R gates exercise it with zero adapter edits.)

---

## 2. The generic engine (`code/fsda_engine/engine.py`)

This is the heart of the project.

### Lifecycle

MATLAB engine startup is slow, so one session is started and reused:

```python
from engine import FsdaEngine

eng = FsdaEngine.start("mahalFS")                      # boots MATLAB, verifies the routine is on the path
d   = eng.call("mahalFS", Y, MU, SIGMA)                # numeric array  -> numpy ndarray
out = eng.call("Score", y, X, la=la, intercept=True)  # struct         -> dict
eng.stop()                                             # always shut the session down explicitly
```

### The call surface

```python
call(name, *args, nargout=1, echo_output=False, options=None, **kwargs)
eval(expr, nargout=1)
```

- **Positional `args`** are marshalled with `to_matlab` and passed to the FSDA function in order.
- **Keyword args** (and any `options` dict) become MATLAB **name/value pairs**, in order:
  `call("Score", y, X, la=la, intercept=True)` → `Score(y, X, 'la', la, 'intercept', true)`.
- **Reserved keywords** — only `nargout`, `echo_output`, `options` are consumed by the bridge.
  Everything else is forwarded to MATLAB. In particular FSDA's own `msg` option passes straight
  through (`call("FSR", y, X, msg=0)`); `echo_output` is the bridge's *own* stdout/stderr tee, named so
  it can never collide with an FSDA option. If an FSDA option name ever clashes with a reserved word,
  route it via `options={...}`.
- `nargout=2` returns a **tuple** (e.g. `[RAW, REW] = mcd(Y)` → `(dict, dict)`).

### Why it runs through the MATLAB *workspace*

A MATLAB `table`/`timetable`, or a 2-D (`M×N`) `cell`, **cannot be returned to Python by the engine at
all**. So `call`/`eval` do not `feval` directly — they assign inputs to workspace temporaries, run the
statement in the MATLAB **workspace**, and decode the outputs *MATLAB-side* into Python-friendly
structures. Function and option names interpolated into that statement are validated against
`_IDENT_RE` first (an injection guard).

### Marshalling map

| MATLAB value | crosses as | notes |
|---|---|---|
| numeric / logical array | `numpy.ndarray` | natural shape preserved, `NaN`/`Inf` kept |
| `struct` | `dict` | recursed |
| nested struct of arrays | `dict` of `dict`s of ndarrays | recursed |
| `char` / `string` scalar | `str` | |
| `cell` (row/col) | `list` | |
| `table` / `timetable` | `dict` `{VariableNames, RowNames`/`RowTimes, data, height}` | decoded in the workspace (`_table_to_dict`); columns read by **index**, never by name |
| 2-D `cell` (`M×N`) | nested `list` | decoded element-by-element (`_marshal_cell2d`) |
| `struct` *holding* any of the above | `dict`, field-by-field | fallback path (`_marshal_struct`) |
| graphics handle (`matlab.graphics.*`) | **not marshalled** | see the contract below |

> The **`pyfsda` package** (0.4.0+) layers an optional, Python-only pandas view on top of this map
> (`pip install pyfsda[pandas]`): `frames=True` returns a `table`/`timetable` as a `pandas.DataFrame`,
> and a `pandas.DataFrame` argument is marshalled to a MATLAB `table`. It is a pyfsda-only convenience —
> the shared engine here (and the R/Julia surfaces) still exchange the neutral dict above.

### Boundary conventions (where ports silently break)

- **1-D input → MATLAB row** (`1×n`). Pass an `(n, 1)` array when a routine wants a column (e.g. a
  response `y`). This is the single documented input convention.
- **No silent reshape** on output — values come back in MATLAB's natural shape; the caller squeezes if
  it wants `(n,)`.
- MATLAB is **column-major** and **1-based**. An index returned from MATLAB stays 1-based until the
  language surface converts it — never hand it to Python as if it were 0-based.

### Fallback decode

`_marshal_var` tries the **fast whole-value read** first (`eng.workspace[var]`), so ordinary
numeric/struct outputs are untouched. Only if that read fails does it fall back to decomposing a
`struct` field-by-field or a 2-D `cell` element-by-element. This fallback was built from evidence — a
real Python-side `ValueError` when `tclustIC` returned a 2-D cell — not speculation.

### Graphics-handle contract

Graphics handle objects are **never marshalled, because they are never requested**. Plotting routines
(the whole `toolbox/graphics` folder) are called with `nargout=0` for their side effect, or with
`nargout` tuned to return only their **data** outputs (e.g. `distribspec` → take `p`, drop the handle
`h`; `histFS` → take counts `ng`, drop the bar handles `hb`). A handle riding *inside* a returned
struct (e.g. `boxplotb.handles`) crosses harmlessly as an empty array. See `CONSTITUTION.md` §4.

---

## 3. The Julia and R surfaces

Both are adapters over the Python engine — the actual MATLAB/FSDA call always stays in `engine.py`.

- **Julia** (`engine.jl`, spec 017): uses **PythonCall**. Because PythonCall never auto-converts, it
  carries a recursive `_py2jl` (Python dict/array/list/str/bool → Julia) and `_to_py` (Julia arrays →
  numpy). PythonCall binds its interpreter once at `using PythonCall`, so the engine pins it to the
  resolved venv *before* that point — switch interpreters by starting a fresh `julia`.
- **R** (`engine.R`, spec 018): uses **reticulate** with `convert = TRUE`, which auto-converts both
  directions, so no recursive converter is needed. The call surface is `fsda_call` (not `call`, which
  would mask `base::call`) and `eval_m`; cleanup uses `on.exit` (avoid `<<-` onto the locked
  `base::diag`).

---

## 4. Agreement gate and the check suites

**Definition of done:** for fixed inputs, a surface must reproduce the genuine FSDA output to a stated
tolerance (default **`1e-9`**) — same values, same flagged units, same structure. Randomized FSDA
steps (subsampling) are seed-controlled across the bridge. A port not checked against the oracle is
**not done**.

The generic engine is exercised by `check_engine.py`, `check_engine.jl`, and `check_engine.R` — the
same **25 cases** in all three languages, currently **25/25 PASS everywhere**. The suite is the living
specification of exactly what crosses the boundary:

| Cases | Marshalling path proven |
|---|---|
| 1 · mahalFS | numeric array → ndarray |
| 2–3 · Score, constructed | struct → dict; nested struct of arrays |
| 4 (+) · FSR, FSRaddt | char scalar + struct; committed forward-search gold |
| 5–7 · array2table, univariatems, corrNominal | `table`/`timetable` → dict; struct carrying table fields |
| 8–11 · FSM, mcd, pcaFS, CressieRead | struct tail vs bootstrapped gold; `nargout=2` tuples |
| 12–14 · logfactorial, tabulateFS, TBwei | scalar / matrix / vector oracles (`utilities_stat`) |
| 15–16 · GowerIndex, tclustIC | matrix + table (nargout=2); **2-D cell → nested list** |
| 17–21 · removeExtraSpacesLF … lexunrank | string I/O; `utilities` / `combinatorial` numerics |
| 22 · publishFS | struct with a 2-D-cell arg table + empty `MException` |
| 23–25 · distribspec, histFS, boxplotb | **graphics, data outputs only** (handles never requested) |

Oracles are one of: an **inline numpy/stdlib** computation, a **committed / bootstrapped gold** CSV
(for routines with no cheap independent oracle, e.g. forward searches), or a **structural** check (for
stochastic routines, assert shape/labels not exact values). Golds live under each target's
`reference/` folder and are read read-only.

Run the three generic gates (each boots MATLAB once, calls real FSDA, prints per-case `PASS`/`FAIL`):

```bash
python  code/fsda_engine/check_engine.py
julia --project=code/fsda_engine code/fsda_engine/check_engine.jl
Rscript code/fsda_engine/check_engine.R
```

---

## 5. Per-routine prototypes (legacy / bespoke)

Before the generic engine, each routine had its own `code/<target>/bridge.{py,jl,R}` +
`check_<target>{.py,_jl.jl,_r.R}`. They are kept for history and for routines that need bespoke
handling; **new work should prefer the generic engine.**

| Folder | FSDA routine | Why it exists |
|---|---|---|
| `code/mahalFS/` | `mahalFS` | first worked example — Mahalanobis distances (specs 001–003) |
| `code/Score/` | `Score` | Box-Cox score-test struct (specs 004–006) |
| `code/FSR/` | `FSR` | Forward Search Regression (specs 007–009) |
| `code/FSRaddt/` | `FSRaddt` | added-variable deletion t-test (specs 010–012) |
| `code/getYahoo/` | `getYahoo` | **bespoke** — struct-array / timetable return over live market data; checked with fixed inputs and a fixed historical window (specs 013–015) |

`getYahoo` is the one return shape the generic engine deliberately does **not** cover (struct-arrays /
datetime scalars), so it keeps its own bridge.

---

## 6. How coverage grew — the folder-sweep method

Recent iterations added coverage by sweeping whole FSDA toolbox folders with a repeatable loop:

1. **Bucket** every function in a folder by output type (numeric / struct / table / cell / graphics …).
2. **Probe** the representative shapes empirically through `FsdaEngine.call` in a throwaway script.
3. **Classify failures by origin.** A `MatlabExecutionError` is MATLAB rejecting inputs — *not* a
   marshalling gap. Only a Python-side conversion error / opaque return is a real gap.
4. **Change the engine only on a confirmed gap.** Across `/regression`, `/multivariate`,
   `/utilities_stat`, `/clustering`, `/utilities`, `/combinatorial`, `/utilities_help`, `/graphics`,
   exactly one real gap surfaced (the 2-D cell) — everything else already crossed.
5. **Add a few deterministic committed checks**, then **mirror them** into the Julia and R gates.

---

## 7. Requirements & toolchain

The specific version numbers below are **not** mandatory — they are what this repo was developed
against (`CONSTITUTION.md §2` pins them for reproducibility). The **one real constraint** is that the
pieces be **version-matched**:

- **`matlab.engine` must match your installed MATLAB release.** This is the actual lock: install the
  `matlabengine` PyPI version that pairs with your MATLAB (R2026a → `matlabengine==26.1.*`; a different
  MATLAB release just needs its matching engine package).
- **Python must be within the range your MATLAB release supports** — for R2026a that is **3.9–3.13**,
  so the pinned `3.12.10` is only the exact patch the dev box uses, not a requirement.
- **MATLAB** needs the **FSDA Add-On** on the path, see next section. Any release recent enough
  for FSDA and a matching engine works; R2026a is the reference, not a floor.

| Component | Developed against | What actually matters |
|---|---|---|
| MATLAB | R2026a + FSDA Add-On | any FSDA-capable release, engine package paired to it |
| Python | 3.12.10 + `numpy` + `matlabengine==26.1.*` | any Python in the release's supported range; engine version paired to MATLAB |
| Julia | PythonCall (`code/fsda_engine/Project.toml`) | any recent Julia |
| R | reticulate | any recent R |

The bridge resolves the Python interpreter in this order, so nothing machine-specific is committed:
**(a)** an activated venv, **(b)** the `FSDA_DEV_VENV` env var (point it at the venv's *python
executable*), **(c)** `python` / `python3` on `PATH`.

### Is FSDA installed and up to date?

`FsdaEngine.start()` runs a **best-effort version check** right after the engine boots (disable with
`start(check_version=False)`). It drives FSDA's own `tuna` utility in a quiet, no-GUI mode
(`tuna('FSDA','uniprJRC','FSDA','gui',false)`):

- **`exist('tuna','file') == 0`** → FSDA is not on the MATLAB path *or* is too old to self-check
  (`tuna` is a recent addition) → a one-line notice is printed.
- **otherwise** `tuna` compares the installed version (from the Add-On manager) against the latest
  GitHub release and emits a Command-Window notice **only when an update is available** — so a current
  FSDA produces **no output**. No modal dialog appears, and any failure (offline, GitHub unreachable)
  is non-fatal.

Because the Julia and R surfaces call this same Python `start`, they inherit the check unchanged. Note
that `tuna` reads the installed version via `matlab.addons.installedAddons`, which only lists FSDA when
it is a registered **Add-On** — a raw source checkout on the path is seen as present but its version
cannot be read (so the check reports it as not-an-Add-On rather than comparing versions). The
`'gui', false` option this relies on lives in FSDA's `tuna.m` (`toolbox/utilities/tuna.m`).

---

## 8. Setup

```bash
# macOS / Linux — from the repo root
python3 -m venv .venv && source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install numpy "matlabengine==26.1.*"   # 26.1.* pairs with MATLAB R2026a — match yours
```

```powershell
# Windows PowerShell
python -m venv .venv; .venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install numpy "matlabengine==26.1.*"   # 26.1.* pairs with MATLAB R2026a — match yours
```

For the Julia and R gates, point `FSDA_DEV_VENV` at that same interpreter so PythonCall / reticulate
bind to the venv the MATLAB Engine API uses, and instantiate the surface deps once:

```bash
export FSDA_DEV_VENV="$(command -v python)"
julia --project=code/fsda_engine -e 'import Pkg; Pkg.instantiate()'   # PythonCall, once
Rscript -e 'install.packages("reticulate")'                          # once, if missing
```

Then run the three gates from §4. Per-routine checks (appendix):

```bash
python  code/mahalFS/check_mahalFS.py          # or Score / FSR / FSRaddt / getYahoo
julia --project=code/mahalFS code/mahalFS/check_mahalFS_jl.jl
Rscript code/mahalFS/check_mahalFS_r.R
```

---

## 9. Repository layout

```text
.
├── README.md          ← this file
├── CONSTITUTION.md    ← binding contract: toolchain, architecture, marshalling, agreement gate
├── AGENTS.md          ← how any AI/human contributor works in this repo
├── packages/
│   └── pyfsda/                 ← the installable Python package (start here to USE FSDA)
│       ├── src/pyfsda/         ← __init__.py (functional façade) + engine.py + py.typed
│       ├── tests/  examples/   ← pytest suite; runnable examples (smoke_test, score_example…)
│       ├── pyproject.toml  CHANGELOG.md  CONTRIBUTING.md
│       └── .github/workflows/  ← build + tests (self-hosted MATLAB) + PyPI trusted publishing
├── specs/
│   ├── TEMPLATE.md
│   └── 001-*.md … 018-*.md      ← one spec per unit of work (Contract + Design + Tasks)
└── code/                        ← the research prototype (how the bridge is built)
    ├── fsda_engine/            ← the generic engine (the pyfsda engine was distilled from here)
    │   ├── engine.py / engine.jl / engine.R
    │   ├── check_engine.py / check_engine.jl / check_engine.R
    │   └── reference/          ← golds + shared fixtures (e.g. FSM_Y.csv)
    ├── mahalFS/  Score/  FSR/  FSRaddt/          ← per-routine prototypes
    └── getYahoo/                                 ← bespoke (struct-array / timetable)
```

---

## 10. Governance & working model

1. Read **`CONSTITUTION.md`** (the contract) and **`AGENTS.md`** (how to work) before changing bridge
   behaviour. The contract wins; a spec may add detail but must not contradict it.
2. Work inside a spec under `specs/`, or copy `specs/TEMPLATE.md` to `specs/NNN-<slug>.md` and write
   its `Contract` / `Design` / `Tasks` first.
3. Put code under `code/fsda_engine/` (generic work) or the relevant `code/<target>/`.
4. **The agreement gate is the definition of done** — a change that does not pass its check is not
   finished. Commit in scoped chunks that reference the spec number; record what was learned in the
   spec.
5. Keep the repo machine-neutral: never commit venv paths, MATLAB install paths, or other absolute
   paths.
