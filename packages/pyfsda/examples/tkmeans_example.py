"""tkmeans (Trimmed k-Means) on the geyser2 dataset.

tkmeans partitions data into k clusters while trimming a specified proportion
(alpha) of potential outliers.
Input Arguments:
   - Y data matrix
   - K number of groups
   - alpha global trimming level

see also:
tkmeans documentation: https://rosa.unipr.it/FSDA/tkmeans.html
FSDA datasets information: https://rosa.unipr.it/FSDA/datasets_clu.html
"""

import pyfsda

eng = pyfsda.start(check_version=False)

pyfsda.rng(42, nargout=0)

Y = pyfsda.load("geyser2.txt")

# clustering to 3 groups and trimming level of 3 percent
out = pyfsda.tkmeans(Y, 3, 0.03, 'plots', 1)

print("Objective function:")
print(out["obj"])

print("\nCluster sizes:")
print(out["siz"])

print("\nWeights:")
print(out["weights"])

eng.render_figures()
eng.wait_for_figures()

pyfsda.stop()
