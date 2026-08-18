"""
pyfsda example: FSDA FSRaddt -- deletion t-statistics along the forward search.

Dataset: FSDA 'wool' dataset (3^3 factorial, 27 observations, 3 factors + response).
"""

import numpy as np
import pyfsda

pyfsda.start(check_version=False)

# Load wool benchmark dataset
raw_data = pyfsda.load("wool")

# Check if raw_data is a dictionary (MATLAB table) or a direct NumPy array
if isinstance(raw_data, dict):
    # Extract table object
    table = raw_data["wool"]

    # Reconstruct array using VariableNames order
    colnames = table["VariableNames"]
    data = np.column_stack([
        np.asarray(table["data"][col], dtype=float) for col in colnames
    ])
else:
    # It's already a NumPy array (e.g. loaded via 'wool.txt')
    data = np.asarray(raw_data, dtype=float)

y = data[:, -1]
X = data[:, :-1]

print(f"wool dataset: {X.shape[0]} observations, {X.shape[1]} predictors\n")

# Run FSRaddt (nsamp=0 for exhaustive search on small dataset)
out = pyfsda.FSRaddt(y, X, nsamp=0, intercept=True, plots=0, msg=0)

print("Output keys:", list(out.keys()))

if "Tdel" in out:
    Tdel = np.asarray(out["Tdel"], dtype=float)

    print("\nDeletion t-statistics along the forward search (first 3 and last 3 steps):")
    header_terms = "  ".join(f"t{j + 1}".rjust(9) for j in range(Tdel.shape[1] - 1))
    print(f"  {'step':>5}  {header_terms}")

    rows = list(range(3)) + list(range(len(Tdel) - 3, len(Tdel)))
    for row in rows:
        step = int(Tdel[row, 0])
        ts = Tdel[row, 1:]
        formatted_ts = "  ".join(f"{t:9.4f}" for t in ts)
        print(f"  {step:5d}  {formatted_ts}")

pyfsda.stop()