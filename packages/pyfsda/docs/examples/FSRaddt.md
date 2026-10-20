# FSRaddt

FSRaddt produces t deletion tests for each explanatory variable.

## Input arguments

Mandatory:

| Argument | Type | Description |
|---|---|---|
| `y` | `ndarray`, length `n` | response variable, either a row or a column vector. `NaN`/`Inf` rows are excluded automatically. |
| `X` | `ndarray`, `n x (p-1)` | explanatory variables (regressors). Rows are observations, columns are variables. `NaN`/`Inf` rows are excluded automatically. |

Optional, passed as keyword arguments (the most commonly used ones -- see the
full list on RoSA, linked below, for the rest):

| Argument | Default | Description |
|---|---|---|
| `DataVars` | not stated on the FSDA page | variables for which the t deletion tests have to be computed (vector of positive integers, or empty) |
| `h` | not stated on the FSDA page | number of observations that have determined the least trimmed squares estimator |
| `intercept` | `True` | indicator for the constant term |
| `init` | not stated on the FSDA page | search initialization, e.g. `init=100` starts monitoring from step `m=100` |
| `lms` | not stated on the FSDA page | criterion used to find the initial subset that initializes the search |
| `nsamp` | not stated on the FSDA page | number of subsamples extracted to find the robust estimator |
| `plots` | not stated on the FSDA page | plot on the screen |
| `nameX` | not stated on the FSDA page | variable labels in the plot (list of strings) |
| `msg` | not stated on the FSDA page | level of output to display (boolean) |
| `quant` | not stated on the FSDA page | confidence quantiles for the envelopes, e.g. `[0.025, 0.975]` |

## Example


FSRaddt with all default options.

```python
import numpy as np
import pyfsda

eng = pyfsda.start(check_version=False)

np.random.seed(123456)
n = 200
p = 3
X = np.random.randn(n, p)
y = np.random.randn(n, 1)

out = pyfsda.FSRaddt(y, X)

pyfsda.stop()
```

![FSRaddt Deletion t Plot](../assets/images/fsraddt_plot.png)

## Output

A `dict` keyed by the FSDA field names:

| Field | Description |
|---|---|
| `Tdel` | `(n-init+1) x (p+1)` matrix with the monitoring of the deletion t statistic at each step of the forward search. 1st column = forward search index (from `init` to `n`); 2nd column = deletion t statistic for the first explanatory variable; 3rd column = for the second explanatory variable; ...; `(p+1)`th column = for the `p`th explanatory variable |
| `S2del` | `(n-init+1) x (p+1)` matrix with the monitoring of the deletion S2 statistic at each step of the forward search. 1st column = forward search index; the other columns = estimate of sigma^2 when the ordering of the units entering the search is found excluding the first, second, ..., last explanatory variable |
| `bs` | `p x length(DataVars)` matrix with the units forming the initial subset of length `p` for the searches associated with the deletion t statistics |
| `Un` | cell of length `length(DataVars)` (a `list` in Python). `Un[i]` is an `(n-init) x 11` matrix with the unit(s) included in the subset at each step of the search which excludes the `i`th explanatory variable. At every step the new subset is compared with the old one: `Un` contains the unit(s) present in the new subset but not in the old one |
| `y` | vector with the response variable that has been used |
| `X` | matrix of explanatory variables that has been used (it also contains the column of ones if the option `intercept` was missing or equal to `True`) |
| `la` | vector with the numbers of the columns of `out["X"]` for which the deletion t statistics have been computed. For example, if the intercept is present and `DataVars` was `[1, 3]`, then `la = [2, 4]` |
| `class` | `'FSRaddt'` |

## See also

- FSRaddt documentation: <https://rosa.unipr.it/FSDA/FSR.html>
- FSDA datasets information: <https://rosa.unipr.it/FSDA/datasets_reg.html>