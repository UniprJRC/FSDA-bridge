# Welcome to pyfsda

pyfsda lets you call the MATLAB [FSDA toolbox](https://github.com/UniprJRC/FSDA)
from Python. It does not reimplement the statistics: it starts MATLAB in the
background, passes your data to FSDA, and returns the results as ordinary
Python objects (dicts, numpy arrays, and pandas DataFrames).

## Requirements

- MATLAB, with the FSDA Add-On installed
- A working MATLAB licence
- The `matlabengine` package matching your MATLAB release
- `numpy`

## Installation

```bash
pip install pyfsda
```

To get results back as pandas DataFrames (`frames=True`, see below), install
the `pandas` extra instead:

```bash
pip install "pyfsda[pandas]"
```

## A first call

The engine starts by itself on the first call, so there is no setup step.
Call `pyfsda.stop()` when you are finished to shut MATLAB down.

```python
import numpy as np
import pyfsda

Y = np.array([[1.0, 2.0], [2.0, 0.0], [3.0, 5.0], [0.0, -1.0], [4.0, 4.0]])
mu = np.array([2.0, 2.0])
sigma = np.array([[2.0, 0.5], [0.5, 1.0]])

d = pyfsda.mahalFS(Y, mu, sigma)
print(d)

pyfsda.stop()
```


## DataFrames

Any function that returns a MATLAB table can hand it back as a pandas
DataFrame instead of a plain dict, by passing `frames=True` (requires the
`pandas` extra above):

```python
raw = pyfsda.load("swiss_banknotes", frames=True)
df = raw["swiss_banknotes"]   # a real pandas DataFrame, labels preserved
```

## Examples

Every function below has a page of its own, listed in the sidebar. Each gives
the input arguments, a worked example with its real output, and a link to the
corresponding page of the FSDA documentation. Every FSDA function not listed
here can still be called the same way -- see its entry in FSDA's own
documentation for the arguments it expects: <https://rosa.unipr.it/FSDA/function-cate.html>