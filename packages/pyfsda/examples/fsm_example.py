"""FSM (Forward Search Multivariate) on the swiss banknotes dataset by
Flury and Riedwyl (1988), which contains 100 genuine, and 100 forged banknotes.

FSM monitors Mahalanobis distances along the forward search to detect
multivariate outliers.

see also:
    FSM documentation: https://rosa.unipr.it/FSDA/FSM.html
    FSDA datasets information: https://rosa.unipr.it/FSDA/datasets_mv.html
"""

import numpy as np

import pyfsda

eng = pyfsda.start(check_version=False)

raw = pyfsda.load(
    "swiss_banknotes", frames=True
)  # To run this example with frames=True, pandas is required
df = raw["swiss_banknotes"]

# FSM expects a numeric matrix, not a table.
# We select to analyse only the 100 forged banknotes
Y = df.iloc[100:].to_numpy()

pyfsda.rng(42, nargout=0)

# Passing plots as a dictionary (struct), lets us name the variable labels in the scatterplot matrix
plots = {"nameY": list(df.columns)}
out = pyfsda.FSM(Y, plots=plots)

outliers = np.asarray(out["outliers"], dtype=int).ravel()

print(f"FSM flagged {len(outliers)} outliers out of {Y.shape[0]} forged banknotes.")
print(f"  indices (within the subset): {outliers.tolist()}\n")

# Monitoring plot: d_min at each forward search step; the spike marks the signal.
# Scatter matrix: outliers (red) vs clean (blue) across all variable pairs.
# See https://rosa.unipr.it/FSDA/FSM.html for details.

eng.render_figures()
eng.wait_for_figures()

pyfsda.stop()
