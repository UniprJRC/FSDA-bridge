"""FSRaddt (forward search added-variable t tests) on FSDA's wool dataset
(3^3 factorial, 27 observations, 3 factors + response).
FSRaddt monitors a deletion t statistic for each explanatory variable at every step of the forward search.

see also:
    FSRaddt documentation: https://rosa.unipr.it/FSDA/FSRaddt.html
    FSDA datasets information: https://rosa.unipr.it/FSDA/datasets_reg.html
"""
import numpy as np
import pyfsda

eng = pyfsda.start(check_version=False)

raw_data = pyfsda.load("wool", frames=True) # To run this example with frames=True, pandas is required
df = raw_data["wool"]

data = df.to_numpy()

y = data[:, -1]
X = data[:, :-1]

print(f"wool dataset: {X.shape[0]} observations, {X.shape[1]} predictors\n")

# Run FSRaddt (nsamp=0 for exhaustive search on small dataset)
out = pyfsda.FSRaddt(y, X, nsamp=0, intercept=True, plots=1)

Tdel = np.asarray(out["Tdel"])
print("\nDeletion t-statistics along the forward search (first 3 and last 3 steps):")
header_terms = "  ".join(f"t{j + 1}".rjust(9) for j in range(Tdel.shape[1] - 1))
print(f"  {'step':>5}  {header_terms}")

rows = list(range(3)) + list(range(len(Tdel) - 3, len(Tdel)))
for row in rows:
    step = int(Tdel[row, 0])
    ts = Tdel[row, 1:]
    formatted_ts = "  ".join(f"{t:9.4f}" for t in ts)
    print(f"  {step:5d}  {formatted_ts}")

eng.render_figures()
eng.wait_for_figures()

pyfsda.stop()