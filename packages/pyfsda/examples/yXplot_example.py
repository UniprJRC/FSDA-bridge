"""yXplot example: Forward Search Regression (FSR) on stack-loss data.

This example demonstrates running Forward Search for outlier detection on the stack-loss dataset
and visualizing variable y against predictors X using yXplot.

see also:
yXplot documentation: https://rosa.unipr.it/FSDA/yXplot.html
FSR documentation: https://rosa.unipr.it/FSDA/FSR.html
FSDA datasets information: https://rosa.unipr.it/FSDA/datasets_reg.html
"""

import numpy as np
import pyfsda

eng = pyfsda.start(check_version=False)

data = pyfsda.load("stack_loss.mat")

table = data['stack_loss']
arr = np.column_stack(list(table["data"].values()))


y = arr[:, -1].reshape(-1, 1)
X = arr[:, :-1]

out = pyfsda.FSR(y, X, 'plots', 0)
print("Outliers:", np.asarray(out['outliers']).ravel())
print("Beta:", np.asarray(out['beta']).ravel())

pyfsda.yXplot(y, X)

eng.render_figures()
eng.wait_for_figures()

pyfsda.stop()