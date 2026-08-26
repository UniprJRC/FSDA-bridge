"""tclust (Trimmed Clustering) on the geyser2 dataset.

tclust partitions data into k clusters while trimming a specified proportion
(alpha) of potential outliers.

see also:
    tclust documentation: https://rosa.unipr.it/FSDA/tclust.html
    FSDA datasets information: https://rosa.unipr.it/FSDA/datasets_clu.html
"""

import pyfsda

eng = pyfsda.start(check_version=False)

Y = pyfsda.load( "geyser2.txt")

pyfsda.rng(1, nargout=0)

# Run trimmed clustering with k=3 groups, 10% global trimming (alpha=0.1),
# and restriction factor = 10000
k = 3
alpha = 0.1
restrfactor = 10000

out = pyfsda.tclust(Y, k, alpha, restrfactor, plots=1)

print("\nObjective function:")
print(out["obj"])

print("\nCluster sizes:")
print(out["siz"])

eng.render_figures()
eng.wait_for_figures()

pyfsda.stop()
