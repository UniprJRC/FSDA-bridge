"""malfwdplot example: Forward Search Monitoring of Mahalanobis Distances on Swiss Banknotes Dataset.

This example Computes Forward Search multivariate exploratory data analysis (FSMeda) starting from
an initial subset chosen via unibiv, and visualizes the forward trajectories of
Mahalanobis distances.

see also:
malfwdplot documentation: https://rosa.unipr.it/FSDA/malfwdplot.html
FSMeda documentation: https://rosa.unipr.it/FSDA/FSMeda.html
FSDA datasets information: https://rosa.unipr.it/FSDA/datasets_mv.html
"""

import pyfsda

eng = pyfsda.start(check_version=False)

data = pyfsda.load("swiss_banknotes.txt")

fre = pyfsda.unibiv(data)
m0 = 20
bs = fre[:m0, 0].reshape(-1, 1)
out = pyfsda.FSMeda(data, bs)

pyfsda.malfwdplot(out, nargout=0)

eng.render_figures()
eng.wait_for_figures()

pyfsda.stop()