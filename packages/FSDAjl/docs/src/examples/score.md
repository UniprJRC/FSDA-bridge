# Score

Tests which Box-Cox transformation of the response best fits a regression.
The candidate whose score statistic is closest to zero is the one the data
supports.

## Input arguments

Mandatory:

| Argument | Type | Description |
|---|---|---|
| `y` | `Matrix{Float64}` | `n x 1` response column |
| `X` | `Matrix{Float64}` | `n x (p-1)` predictors |

Optional, passed as name-value keywords:

| Argument | Description |
|---|---|
| `la` | vector of transformation parameters to test; defaults to -1, -0.5, 0, 0.5, 1 |
| `intercept` | whether to include an intercept, true by default |

The response must stay two dimensional, so use `W[:, 4:4]` rather than `W[:, 4]`.

## Output arguments

| Value | Type | Description |
|---|---|---|
| `Score` | `Matrix{Float64}` | the test statistic for each candidate lambda |
| `Lik` | `Matrix{Float64}` | the corresponding likelihood values |

## Example

```julia
using FSDA
using Printf

# wool ships with FSDA, so it is loaded through MATLAB.
W = eval_expr("table2array(getfield(load('wool.mat'),'wool'))")

y  = W[:, 4:4]
X  = W[:, 1:3]
la = [-1.0, -0.5, 0.0, 0.5, 1.0]

out = Score(y, X)

for (lam, s) in zip(la, vec(out["Score"]))
    @printf("  lambda = %+4.1f    score = %9.4f\n", lam, s)
end

stop_engine()
```

## Output

```
  lambda = -1.0    score =   17.7059
  lambda = -0.5    score =    7.4927
  lambda = +0.0    score =   -0.9122
  lambda = +0.5    score =   -9.5511
  lambda = +1.0    score =  -18.5576
```

A `Dict` with `Score`, the test statistic for each candidate lambda, and `Lik`.
The lambda whose statistic is nearest zero is the best supported: here that is
lambda = 0, the log transformation.

## See also

- Score documentation: <https://rosa.unipr.it/FSDA/Score.html>
- FSDA datasets information: <https://rosa.unipr.it/FSDA/datasets_regression.html>
