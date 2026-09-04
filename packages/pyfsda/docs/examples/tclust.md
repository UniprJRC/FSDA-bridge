# tclust

`tclust` computes robust trimmed clustering with scatter restrictions on multivariate data.

The algorithm partitions observations into $k$ clusters while trimming a fraction $\alpha$ of extreme values or outliers. This partition minimizes the trimmed sum, over all clusters, of the within-cluster sums of point-to-cluster-centroid distances.
## Input arguments

### Mandatory

| Argument | Type | Description                                                                                                                                                                                                                                                 |
|---|---|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Y` | `ndarray`, `n x v` | Data matrix with $n$ observations and $v$ variables. Missing values (`NaN`) are excluded automatically.                                                                                                                                                     |
| `k` | `int` | Number of target clusters.                                                                                                                                                                                                                                  |
| `alpha` | `float` or `int` | Global trimming level. If `0 <= alpha < 0.5`, specifies the fraction of trimmed observations. If `alpha` is an integer specifying the number of observations which have to be trimmed. `alpha = 0` reduces to standard Gaussian mixture/k-means clustering. |
| `restrfactor` | `float` or `dict` | Restriction factor ($\ge 1$) constraining relative differences among cluster scatters. `1` forces equal eigenvalues/determinants across clusters. Can also be supplied as a parameter dictionary for Gaussian Parsimonious Clustering Models (GPCM).        |

### Optional (Keyword Arguments)

| Argument | Default | Description |
|---|---|---|
| `restrtype` | `'eigen'` | Constraint type applied to scatter matrices: `'eigen'` constrains eigenvalues; `'deter'` constrains determinants. |
| `cshape` | `1e10` | Shape matrix constraint value ($\ge 1$). Effective when `restrtype='deter'`. |
| `equalweights` | `False` | `True` assumes equal cluster sizes during concentration steps; `False` allows estimated cluster proportions. |
| `mixt` | `0` | `0` performs crisp cluster assignment. `1` or `2` performs mixture modeling (soft/likelihood-based allocation). |
| `nsamp` | `300` | Number of random subsamples to draw. Set to `0` to extract all possible combinations. |
| `refsteps` | `15` | Number of concentration refining steps per subsample. |
| `reftol` | `1e-14` | Convergence tolerance for refining iterations. |
| `startv1` | `True` | `True` initializes cluster centers using $v+1$ randomly selected units; `False` uses single units and identity covariances. |
| `plots` | `0` | Controls visualization output: `0` (none), `1` (scatterplot matrix/bivariate plot), `'ellipse'` (confidence ellipses), `'contour'` / `'contourf'` (density contours). |
| `msg` | `1` | Verbosity level: `0` (silent), `1` (standard progress), `2` (detailed iteration logs). |
| `nocheck` | `0` | Set to `1` to skip input verification checks on `Y`. |
| `Ysave` | `False` | Set to `True` to store the raw input matrix `Y` in the returned structure. |

---

## Example

Trimmed clustering executed on the geyser2 dataset ($k=3$, $\alpha=0.10$, $\text{restrfactor}=10000$):
```python
import numpy as np
import pyfsda

# Load geyser data
Y = pyfsda.load( "geyser2.txt")

# Run tclust: 3 clusters, 10% trimming, restriction factor of 10000
pyfsda.rng(1234, nargout=0)
out = pyfsda.tclust(Y, k=3, alpha=0.10, restrfactor=10000)

pyfsda.stop()
```

---

## Output

A `dict` keyed by FSDA structure field names:

| Field | Description |
| --- | --- |
| `idx` | `n x 1` vector containing cluster assignments ($1, \dots, k$). $0$ denotes trimmed observations. |
| `muopt` | `k x v` matrix of final cluster centroid locations. |
| `sigmaopt` | `v x v x k` array of estimated constrained covariance matrices for each cluster. |
| `siz` | `(k+1) x 3` matrix summarizing observation counts and percentages per cluster (row `0` corresponds to trimmed units). |
| `postprob` | `n x k` matrix of posterior probabilities (0 for trimmed units). |
| `obj` | Value of the maximized objective function. |
| `CLACLA` | Classification Likelihood Information Criterion (available when `mixt=0`). |
| `MIXMIX` | Mixture BIC criterion (available when `mixt > 0`). |
| `MIXCLA` | Integrated Complete Likelihood (ICL) criterion (available when `mixt > 0`). |
| `bs` | Units forming the initial subset associated with the optimal solution. |
| `notconver` | Number of subsamples that failed to converge within `refsteps`. |

---

## See also

* tclust documentation: [https://rosa.unipr.it/FSDA/tclust.html](https://rosa.unipr.it/FSDA/tclust.html)
- FSDA datasets information: <https://rosa.unipr.it/FSDA/datasets_clu.html>
