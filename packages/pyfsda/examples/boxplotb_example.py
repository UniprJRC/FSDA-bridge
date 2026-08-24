"""boxplotb example: Bivariate boxplot on stars dataset.

Computes and visualizes bivariate boxplots to identify robust location,
scatter, and bivariate outliers.

see also:
boxplotb documentation: https://rosa.unipr.it/FSDA/boxplotb.html
FSDA datasets information: https://rosa.unipr.it/FSDA/datasets_reg.html
"""

import numpy as np
import pyfsda

eng = pyfsda.start(check_version=False)

data = pyfsda.load("stars.txt")

out = pyfsda.boxplotb(data)
pyfsda.xlabel('Log effective surface temperature')
pyfsda.ylabel('Log light intensity')

outliers = np.asarray(out['outliers']).ravel().astype(int)
print("Outliers:", outliers.tolist())

eng.render_figures()
eng.wait_for_figures()

pyfsda.stop()