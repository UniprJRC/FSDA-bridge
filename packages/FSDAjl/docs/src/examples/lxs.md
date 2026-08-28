# LXS

Fits a regression to the majority of the data and lets outliers fall outside
it. Up to half the observations can be arbitrarily wrong without moving the
estimate.

## Input arguments

Mandatory:

| Argument | Type | Description |
|---|---|---|
| `y` | `Matrix{Float64}` | `n x 1` response column |
| `X` | `Matrix{Float64}` | `n x (p-1)` predictors; the intercept is added by default |

Optional, passed as name-value keywords:

| Argument | Description |
|---|---|
| `rew` | set to 1 to refit using only the units that passed the first pass |
| `msg` | set to 0 to silence progress messages |
| `nsamp` | how many subsamples to draw |

## Example

```julia
using FSDA
using Random
using Printf

# The same data as the FSR example.
Random.seed!(123456)
n, p = 200, 3
X = randn(n, p)
y = randn(n, 1)
ycont = copy(y)
ycont[1:5] .+= 6

# LXS draws random subsamples, so seed MATLAB for a repeatable answer.
call("rng", 1234, nargout = 0)

out = LXS(ycont, X; msg = 0)
println("flagged units: ", sort(Int.(vec(out["outliers"]))))

# Reweighting refits using only the units that passed.
call("rng", 1234, nargout = 0)
out2 = LXS(ycont, X; rew = 1, msg = 0)
println("after reweighting: ", sort(Int.(vec(out2["outliers"]))))

stop_engine()
```

## Output

A `Dict` with `beta`, the coefficients, `residuals`, one per unit,
`outliers`, the units flagged, and `scale`, the robust spread estimate.

y was pure noise before the first five were shifted, so a fit that has not
been dragged by them has coefficients close to zero. Reweighting moves the
intercept closer to zero and flags one further unit.

One caveat: FSR uses LXS internally to choose where its search begins, so
agreement between the two is not independent confirmation.

```
flagged units: [1, 2, 3, 4, 5, 40, 146]
after reweighting: [1, 2, 3, 4, 5, 40, 54, 146]
```

## See also

- LXS documentation: <https://rosa.unipr.it/FSDA/LXS.html>
- FSDA datasets information: <https://rosa.unipr.it/FSDA/datasets_regression.html>
