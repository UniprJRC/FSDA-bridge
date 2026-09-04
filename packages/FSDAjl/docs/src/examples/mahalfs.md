# mahalFS

Computes Mahalanobis distances, in squared units, for each row of a matrix.
You supply the centre and the covariance yourself, so the result is only as
robust as the values you pass in.

## Input arguments

Mandatory:

| Argument | Type | Description |
|---|---|---|
| `Y` | `Matrix{Float64}` | `n x v` data matrix: `n` observations, `v` variables |
| `μ` | `Matrix{Float64}` | `1 x v` row vector, the centroid to measure from |
| `Σ` | `Matrix{Float64}` | `v x v` covariance matrix |

Optional: none. `mahalFS` takes no name-value arguments.

In the code below these are written as the Julia symbols μ and Σ. They
are `MU` and `SIGMA` in the FSDA MATLAB documentation.

## Output arguments

| Value | Type | Description |
|---|---|---|
| `d` | `Matrix{Float64}` | `n x 1` squared distances, in the row order of `Y` |

## Example

```julia
using FSDA
using Statistics

Y = [ 0.52 -1.10;  1.83  0.14; -0.09  1.53;  0.32 -0.77;  1.10  0.37;
     -0.86  0.26;  0.15 -1.44;  0.79  0.33; -1.21  0.71;  0.46 -0.05]

# Compute MD using as centroid the medians and shape matrix Σ
μ = median(Y, dims = 1)
Σ = [0.3 0.4; 0.4 1.0]

d = mahalFS(Y, μ, Σ)

println(round.(vec(d)[1:3], digits = 4))

stop_engine()
```

## Output

```
[4.7079, 15.3129, 9.0842]
```

Because the distances are squared, they compare directly against chi-square
quantiles with `v` degrees of freedom.

## See also

- mahalFS documentation: <https://rosa.unipr.it/FSDA/mahalFS.html>
- FSDA datasets information: <https://rosa.unipr.it/FSDA/datasets_mv.html>
