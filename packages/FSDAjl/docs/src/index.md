# FSDAjl

FSDAjl lets you call the MATLAB [FSDA toolbox](https://github.com/UniprJRC/FSDA)
from Julia. It does not reimplement the statistics: it starts MATLAB in the
background, passes your data to FSDA, and returns the results as ordinary Julia
arrays.

## Requirements

- MATLAB, with the FSDA Add-On installed
- A working MATLAB licence
- Python with the matlabengine package, and `JULIA_CONDAPKG_BACKEND` set to `Null`

## Installation

```julia
using Pkg
Pkg.add("FSDA")
```

## A first call

The engine starts by itself on the first call, so there is no setup step. Call
`stop_engine()` when you are finished to shut MATLAB down.

```julia
using FSDA
using Statistics

Y = [ 0.52 -1.10;  1.83  0.14; -0.09  1.53;  0.32 -0.77;  1.10  0.37;
     -0.86  0.26;  0.15 -1.44;  0.79  0.33; -1.21  0.71;  0.46 -0.05]

μ = median(Y, dims = 1)
Σ = [0.3 0.4; 0.4 1.0]

d = mahalFS(Y, μ, Σ)

stop_engine()
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
