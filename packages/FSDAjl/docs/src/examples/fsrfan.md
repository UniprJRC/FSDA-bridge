# FSRfan

Recomputes the Box-Cox score statistic at every step of the forward search.
A transformation supported only at the end is one resting on a handful of
observations.

## Input arguments

Mandatory:

| Argument | Type | Description |
|---|---|---|
| `y` | `Matrix{Float64}` | `n x 1` response column |
| `X` | `Matrix{Float64}` | `n x (p-1)` predictors; the intercept is added by default |

Optional, passed as name-value keywords:

| Argument | Description |
|---|---|
| `la` | vector of transformation parameters to test |
| `msg` | set to 0 to silence progress messages |
| `plots` | set to 0 for no plot |
| `nsamp` | how many subsamples to draw |

FSDA draws the fan plot with a separate function, fanplotFS, so FSRfan itself
returns the statistics and nothing is plotted here.

## Example

```julia
using FSDA
using Printf

W = eval_expr("table2array(getfield(load('wool.mat'),'wool'))")

y = W[:, 4:4]
X = W[:, 1:3]

# The default candidates, the same five the Score example used.
la = [-1.0, -0.5, 0.0, 0.5, 1.0]

out = FSRfan(y, X; msg = 0, plots = 0)

Sc = out["Score"]

for i in 1:4:size(Sc, 1)
    @printf("  subset %3d", Int(Sc[i, 1]))
    for j in 2:size(Sc, 2)
        @printf("%10.3f", Sc[i, j])
    end
    println()
end

stop_engine()
```

## Output

A `Dict` whose `Score` field is `steps x (1 + number of lambdas)`: the subset
size followed by the score statistic for each candidate.

Read the table down each column. The first row is all zeros, since five
observations cannot support a test with three predictors. After that the
lambda = 1 column marches steadily away from zero, so leaving the response
untransformed becomes less tenable as more data enters, while lambda = 0 stays
close to zero throughout.

The full sample row is exactly what the Score example produces on the same
data. Score answers the question once; FSRfan shows how the answer held up.

```
  subset   5    -0.000    -0.000     0.000     0.000    -0.000
  subset   9     0.195     0.268    -1.572    -1.157     0.547
  subset  13     0.323     1.952    -0.175    -1.065    -1.828
  subset  17     1.283     2.277     0.015    -2.384    -4.207
  subset  21     3.135     1.620     0.822    -2.753    -8.272
  subset  25     9.358     3.747    -0.134    -5.967   -12.110
```

## See also

- FSRfan documentation: <https://rosa.unipr.it/FSDA/FSRfan.html>
- FSDA datasets information: <https://rosa.unipr.it/FSDA/datasets_regression.html>
