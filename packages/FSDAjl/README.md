# FSDA.jl

A Julia package for calling [FSDA](https://github.com/UniprJRC/FSDA) (the MATLAB robust-statistics toolbox) from Julia, via a thin wrapper over [FSDA-bridge](https://github.com/UniprJRC/FSDA-bridge)'s generic Python engine.

## The package requires MATLAB. Read this before installing.

- **MATLAB R2026a with the FSDA Add-On** must be installed and licensed on
  the machine that will _run_ FSDA calls.
- A **Python environment** with a `matlabengine` release matching your
  MATLAB version (e.g. `matlabengine==26.1.*` for R2026a) is also required.
- **FSDA.jl is a bridge, not a re-implementation.** FSDA itself runs inside
  MATLAB at call time; this package only marshals data to and from it.
- The package **installs fine without MATLAB** (e.g. via
  `Pkg.add("FSDA")` in CI), but any call into FSDA will fail until the
  above is configured. See [Install matrix](#install-matrix) below.

## Install matrix

| MATLAB release | Required `matlabengine` |
| -------------- | ----------------------- |
| R2026a         | `matlabengine==26.1.*`  |

## Installation

```julia
using Pkg
Pkg.add("FSDA")   # once registered in General
```

### Required environment configuration

FSDA.jl calls into an existing Python environment via
[PythonCall.jl](https://github.com/JuliaPy/PythonCall.jl). You must tell PythonCall to use that environment rather than provisioning its own via Conda. Conda cannot install MATLAB's `matlabengine` for you, and letting PythonCall try will produce confusing errors.

```bash
export JULIA_CONDAPKG_BACKEND=Null
export FSDA_DEV_VENV=/path/to/your/venv/bin/python

# or, alternatively:
export JULIA_PYTHONCALL_EXE=/path/to/your/venv/bin/python
```

Set these **before** starting Julia / loading the package. FSDA.jl checks `JULIA_CONDAPKG_BACKEND` at load time and will warn loudly if it isn't set to `"Null"`.

## Quick start

```julia
using FSDA

FSDA.start_engine()

result = FSDA.call("mahalFS", Y, mu, Sigma)

FSDA.stop_engine()
```

## Licence

[EUPL-1.2](LICENSE) — consistent with FSDA's own licensing.
