"""FSMeda (Forward Search Multivariate Exploratory Data Analysis) on the
swiss banknotes dataset by Flury and Riedwyl (1988).

FSMeda performs forward search in multivariate analysis with exploratory data analysis purposes
Input Arguments:
   - Y data matrix
   - bsb List of units forming the initial subset

see also:
FSMeda documentation: https://rosa.unipr.it/FSDA/FSMeda.html
FSDA datasets information: https://rosa.unipr.it/FSDA/datasets_mv.html
"""

import numpy as np
import pyfsda

eng = pyfsda.start(check_version=False)

raw_data = pyfsda.load("swiss_banknotes", frames=True) # To run this example with frames=True, pandas is required
data = raw_data["swiss_banknotes"]
Y = data.to_numpy()

print(f"swiss_banknotes dataset: {Y.shape[0]} observations, {Y.shape[1]} variables")

fre = np.asarray(pyfsda.unibiv(Y))
fre = fre[fre[:, 3].argsort()]
bs = fre[:20, 0].reshape(-1, 1)

out = pyfsda.FSMeda(Y, bs, plots=1)

mmd = np.asarray(out["mmd"])
gap = np.asarray(out["gap"])

print("\nMMD (Min Mahalanobis Distance) Preview (First 3 & Last 3 Steps)")
print("Step | Min MD  | (m+1)th Ordered MD")
for row in mmd[:3]:
    print(f"{int(row[0]):4d} | {row[1]:16.4f} | {row[2]:16.4f}")

for row in mmd[-3:]:
    print(f"{int(row[0]):4d} | {row[1]:16.4f} | {row[2]:16.4f}")

print("\nGap (Last 3 Steps)")
print("Step | Min MD Outside - Max MD Inside | (m+1)th - mth Ordered MD")
for row in gap[-3:]:
    print(f"{int(row[0]):4d} | {row[1]:16.4f} | {row[2]:16.4f}")

eng.render_figures()
eng.wait_for_figures()

pyfsda.stop()
