# FSR

FSR computes the forward search estimator in linear regression. The search
grows a clean subset of observations step by step, monitoring the minimum
deletion residual at every step; a unit that only enters late, with an
unusually large residual, is flagged as an outlier.

## Input arguments

Mandatory:

| Argument | Type | Description |
|---|---|---|
| `y` | `ndarray`, length `n` | response variable. `NaN`/`Inf` rows are excluded automatically. |
| `X` | `ndarray`, `n x (p-1)` | explanatory variables. Do **not** include a column of 1s -- the intercept is added automatically unless `intercept=False`. |

Optional, passed as keyword arguments (the most commonly used ones -- see the
full list on RoSA, linked below, for the rest):

| Argument | Default | Description |
|---|---|---|
| `intercept` | `True` | include a constant term in the fit |
| `init` | `p+1` if `n<40`, else `min(3p+1, floor(0.5(n+p+1)))` | subset size at which monitoring of the deletion residual starts |
| `nsamp` | auto (exhaustive if <1000 possible subsets, else 1000) | number of subsamples to extract; `0` forces an exhaustive search over every `(n choose p)` subset -- only safe for very small datasets, see the note below |
| `h` | `floor(0.5*(n+p+1))` | size of the subset used to compute the initial LTS/LMS estimator |
| `msg` | `True` | set to `False` to silence the signal-detection messages printed during the search |
| `plots` | `1` | `1` draws the mdr/envelope plot and the yXplot with outliers highlighted; `2` also shows intermediate envelope-superimposition plots; any other value suppresses plotting |
| `weak` | `False` | use a weaker decision rule that also separates VIOM (vertical) from MSOM (bad leverage) outliers -- adds `VIOMout`/`ListCl` to the output |


## Example

```python
import numpy as np
import pyfsda

# Generate data (n=200, p=3)
np.random.seed(123456)
n = 200
p = 3
X = np.random.randn(n, p)
y = np.random.randn(n, 1)

# Contaminate the first 5 observations
ycont = y.copy()
ycont[0:5] = ycont[0:5] + 6.0

# FSR subsamples internally, so seed MATLAB for a repeatable answer
pyfsda.rng(1234, nargout=0)

# Run Forward Search Regression
out = pyfsda.FSR(ycont, X, plots=0)

outliers = np.asarray(out["outliers"], dtype=int).ravel()
beta = np.asarray(out["beta"], dtype=float).ravel()

print("Flagged outlier indices:", outliers.tolist())
print("Fitted beta coefficients:", beta)

pyfsda.stop()
```

## Output

A `dict` keyed by the FSDA field names:

| Field | Description |
|---|---|
| `ListOut` | row vector of units declared as outliers, empty if the sample is homogeneous |
| `outliers` | alias for `ListOut`, kept for consistency with the other robust estimators |
| `beta` | `p x 1` estimated regression coefficients |
| `scale` | estimated scale (sigma) |
| `residuals` | `n x 1` robust scaled residuals |
| `fittedvalues` | `n x 1` fitted values |
| `mdr` | `(n-init) x 2`: search step, minimum deletion residual at that step |
| `Un` | `(n-init) x 11`: which unit(s) entered the subset at each step |
| `nout` | `2 x 5`: how many times `mdr` exceeded the 1/99/99.9/99.99/99.999 percentile quantiles |
| `class` | `'FSR'` |
| `VIOMout` | present only if `weak=True`: units declared as VIOM outliers |
| `ListCl` | present only if `weak=True`: non-outlying units |


## See also

- FSR documentation: <https://rosa.unipr.it/FSDA/FSR.html>
- FSDA datasets information: <https://rosa.unipr.it/FSDA/datasets_reg.html>