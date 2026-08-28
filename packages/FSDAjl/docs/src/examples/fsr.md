# FSR

Runs the forward search on a regression model and reports which observations
are outliers. The search grows a clean subset one observation at a time and
watches for the jump that signals contamination.

## Input arguments

Mandatory:

| Argument | Type | Description |
|---|---|---|
| `y` | `Matrix{Float64}` | `n x 1` response column |
| `X` | `Matrix{Float64}` | `n x (p-1)` predictors; the intercept is added by default |

Optional, passed as name-value keywords:

| Argument | Description |
|---|---|
| `init` | subset size at which monitoring starts |
| `msg` | set to 0 to silence progress messages |
| `plots` | set to 0 for no plot |

The response must stay two dimensional. A one dimensional Julia vector crosses
to MATLAB as a row, and FSR expects an `n x 1` column.

## Example

```julia
using FSDA
using Random
using Printf

Random.seed!(123456)

n = 200
p = 3
X = randn(n, p)
y = randn(n, 1)

# Contaminate the first five responses so there is something to find.
ycont = copy(y)
ycont[1:5] .+= 6

# FSR subsamples internally, so seed MATLAB for a repeatable answer.
call("rng", 1234, nargout = 0)

out = FSR(ycont, X; msg = 0, plots = 0)

flagged = sort(Int.(vec(out["ListOut"])))
@printf("units flagged as outliers: %d of %d\n", length(flagged), n)
println("flagged units: ", flagged)

stop_engine()
```

## Output

A `Dict` keyed by the FSDA field names. `ListOut` holds the units flagged as
outliers, `beta` the estimated coefficients, and `mdr` the minimum deletion
residual at each step of the search.

```
units flagged as outliers: 5 of 200
flagged units: [1, 2, 3, 4, 5]
```

## See also

- FSR documentation: <https://rosa.unipr.it/FSDA/FSR.html>
- FSDA datasets information: <https://rosa.unipr.it/FSDA/datasets_regression.html>
