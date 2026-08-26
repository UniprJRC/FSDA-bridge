"""FSR (Forward Search Regression) on FSDA's stars benchmark dataset by Humpreys (1978),
consists of 47 observations about the light intensity (y2) and the surface temperature (y1)

FSR performs forward search in linear regression to detect outliers.

see also:
    FSR documentation: https://rosa.unipr.it/FSDA/FSR.html
    FSDA datasets information: https://rosa.unipr.it/FSDA/datasets_reg.html
"""

import numpy as np
import pyfsda

eng = pyfsda.start(check_version=False)

raw_data = pyfsda.load("stars")
table = raw_data["stars"]

colnames = table["VariableNames"]
data = np.column_stack([np.asarray(table["data"][c]) for c in colnames])

y = data[:, -1]
X = data[:, :-1]

print(f"stars dataset: {X.shape[0]} observations, {X.shape[1]} predictors\n")

out = pyfsda.FSR(y, X, nsamp=0)

beta = np.asarray(out["beta"]).ravel()
scale = np.asarray(out["scale"]).ravel()
outliers = np.asarray(out["outliers"], dtype=int).ravel()

print("Forward search fit on:")
print(f"  beta = {beta}")
print(f"  scale = {scale}")
print(f"  flagged outliers (indices): {outliers}")

eng.render_figures()
eng.wait_for_figures()

pyfsda.stop()
