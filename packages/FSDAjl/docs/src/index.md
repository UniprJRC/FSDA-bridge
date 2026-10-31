# FSDABridge.jl

FSDABridge.jl lets you call the MATLAB [FSDA toolbox](https://github.com/UniprJRC/FSDA) from Julia through a thin wrapper over [FSDA-bridge](https://github.com/UniprJRC/FSDA-bridge)'s generic Python engine.

FSDA itself runs inside MATLAB at call time. FSDABridge.jl does not reimplement the statistical routines; it passes data to FSDA and returns the results as Julia values.

## Requirements

Before installing, make sure you have:

- MATLAB installed and licensed, with the FSDA Add-On installed and available on the MATLAB path.
- A Python environment with `numpy` and a `matlabengine` release matching your MATLAB version (for example, `matlabengine==26.1.*` for MATLAB R2026a).
- Julia 1.10 or later.

**FSDABridge.jl can be installed without MATLAB**, but calls into FSDA will fail until MATLAB, FSDA, and the matching MATLAB Engine API for Python are configured.

Match `matlabengine` to your installed MATLAB release; do not assume the example version applies to every MATLAB release.

MATLAB and the MATLAB Engine API for Python are proprietary MathWorks software and are not distributed with this package; see [THIRD_PARTY_NOTICE.md](https://github.com/UniprJRC/FSDA-bridge/blob/main/packages/FSDAjl/THIRD_PARTY_NOTICE.md).

## Installation

```julia
using Pkg
Pkg.add("FSDABridge")
```

## Configure PythonCall

FSDABridge.jl uses [PythonCall.jl](https://github.com/JuliaPy/PythonCall.jl) to call the existing Python environment. PythonCall normally uses CondaPkg to supply dependencies,
matlabengine, however has to be built against your MATLAB, and Conda can't do that. This
means that you have to setup your own Python environment and point PythonCall at it.

### 1. Create a Python environment
Install numpy and the matlabengine matching your MATLAB version. See 
[Install MATLAB Engine API for Python](https://www.mathworks.com/help/matlab/matlab_external/install-the-matlab-engine-for-python.html) for a guide on installing matlabengine. Your Python version must also be compatible with your MATLAB and matlabengine's version, you can check compatibility at: [Versions of Python Compatible with MATLAB Products](https://www.mathworks.com/support/requirements/python-compatibility.html).

### 2. Point PythonCall at it
Tell CondaPkg not to install anything, and tell PythonCall which Python it should use.
This can be achieved in 2 main ways.

Adding them as preferences:
```julia
# Go to the default environment, install PreferenceTools there, then go back:
pkg> activate
pkg> add PreferenceTools
pkg> activate /path/to/your/project/

# In the project where you use FSDABridge:
# preferences only apply for packages in your project, so add these explicitly
pkg> add PythonCall CondaPkg
julia> using PreferenceTools
pkg> preference add CondaPkg backend=Null
pkg> preference add PythonCall exe=/path/to/your/venv/bin/python
```

or by setting them as environment variables before starting Julia:
```bash
export JULIA_CONDAPKG_BACKEND=Null
export JULIA_PYTHONCALL_EXE=/Path/to/your/venv/bin/python
```

### 3. Restart Julia, check, and try a first call
After restarting Julia, you can run our diagnostics function to make sure everything
is working as it should:

```julia
using FSDABridge

h = start_engine()
diagnostics(h)
stop_engine(h)
```

If something is misconfigured, `start_engine()` will error at runtime, the error will
show which Python PythonCall is using: if its path contains `.CondaPkg`, then step 2
hasn't taken effect.

Otherwise, if everything works correctly, you can proceed to try a first call.

## A first call

The first call starts the MATLAB engine automatically. Call `stop_engine()` when you are finished to shut it down.

```julia
using FSDABridge
using Statistics

Y = [ 0.52 -1.10;  1.83  0.14; -0.09  1.53;  0.32 -0.77;  1.10  0.37;
     -0.86  0.26;  0.15 -1.44;  0.79  0.33; -1.21  0.71;  0.46 -0.05]

μ = median(Y, dims = 1)
Σ = [0.3 0.4; 0.4 1.0]

d = mahalFS(Y, μ, Σ)

stop_engine()
```

## Quick start: explicit engine

You can also manage the MATLAB engine explicitly and reuse it across calls:

```julia
using FSDABridge
using Statistics

h = FSDABridge.start_engine()

Y = randn(10, 2)
MU = median(Y, dims = 1)
SIGMA = [0.3 0.4; 0.4 1.0]

d = FSDABridge.call(h, "mahalFS", Y, MU, SIGMA)

FSDABridge.stop_engine(h)
```

## Reaching MATLAB directly

FSDA routines are called by name, as above. For anything else in MATLAB, such
as loading a dataset or seeding the random number generator, use `eval_expr`
and `call`. Both use the same engine, so nothing extra needs starting.

```julia
Y = eval_expr("table2array(getfield(load('geyser2.mat'),'geyser2'))")
call("rng", 1234, nargout = 0)
```

## Examples

Every function has a page of its own, listed in the sidebar. Each gives the
input arguments, a worked example with its output, and links to the
corresponding page of the FSDA documentation.

## License

[EUPL-1.2](https://github.com/UniprJRC/FSDA-bridge/blob/main/packages/FSDAjl/LICENSE), consistent with FSDA's own licensing.
