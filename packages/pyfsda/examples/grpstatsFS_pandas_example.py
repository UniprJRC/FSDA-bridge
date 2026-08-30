"""pyfsda example: a *table in -> table out* FSDA routine, round-tripped through pandas.

Exercises the pandas view added in pyfsda 0.4.0 in both directions with a single call:

    * INPUT  -- a numeric ``pandas.DataFrame`` (rows = observations, columns = variables)
      is marshalled to a MATLAB ``table``.
    * OUTPUT -- with ``frames=True`` the returned MATLAB ``table`` comes back as a
      ``pandas.DataFrame``, labels preserved.

The routine is ``grpstatsFS`` (FSDA summary statistics): it takes a table of observations
and returns a table with **one row per variable** and **one column per statistic**
(classical *and* robust: mean, median, std, scaled MAD, skewness, medcouple). So the input
DataFrame's *column* names reappear as the output DataFrame's *row* labels -- a clean
demonstration of labels surviving the Python <-> MATLAB round trip.

Run (needs the FSDA Add-On and ``pip install pyfsda[pandas]``):

    python examples/grpstatsFS_pandas_example.py
"""
import numpy as np
import pandas as pd

import pyfsda

# Start the shared engine quietly (skip the network / Add-On version checks for a clean demo).
pyfsda.start(check_version=False)

# --- a small numeric table: 12 subjects x 3 measurements ------------------------------
# One deliberate outlier in `weight_kg` (row 0) so the robust statistics (median, MAD)
# visibly resist it while the classical ones (mean, std) are pulled toward it.
df = pd.DataFrame({
    "height_cm": [170.0, 168.0, 175.0, 172.0, 169.0, 174.0,
                  171.0, 173.0, 167.0, 176.0, 170.0, 172.0],
    "weight_kg": [180.0,  68.0,  72.0,  70.0,  66.0,  75.0,   # 180.0 is the outlier
                   69.0,  73.0,  64.0,  77.0,  71.0,  70.0],
    "age_yrs":   [34.0,  28.0,  41.0,  37.0,  25.0,  45.0,
                  31.0,  39.0,  22.0,  50.0,  33.0,  36.0],
})
print("Input DataFrame (observations x variables):")
print(df, "\n")

# --- one call: DataFrame -> MATLAB table -> grpstatsFS -> table -> DataFrame -----------
# groupvars = [] : no grouping variable, statistics over the whole sample. (A grouping
# variable would be categorical; the v1 DataFrame->table input marshaller handles numeric
# columns, so this example keeps all columns numeric.)
stats = pyfsda.grpstatsFS(df, [], frames=True)

print("Output DataFrame (variables x statistics) -- from a MATLAB table via frames=True:")
print(stats, "\n")
print("index (= input variable names):", list(stats.index))
print("columns (= statistics)        :", list(stats.columns))

# --- honest check: the values crossed intact, not merely executed ---------------------
# FSDA's `mean` must equal pandas' own mean for every variable, to 1e-9.
for col in df.columns:
    fsda_mean = float(stats.loc[col, "mean"])
    pandas_mean = float(df[col].mean())
    assert abs(fsda_mean - pandas_mean) < 1e-9, (col, fsda_mean, pandas_mean)
print("FSDA mean == pandas mean for every variable (within 1e-9).  PASS\n")

# The outlier's fingerprint: for weight_kg the classical mean/std are inflated relative to
# the robust median / scaled MAD -- exactly what robust statistics are meant to reveal.
w = stats.loc["weight_kg"]
print(f"weight_kg: mean={w['mean']:.2f} vs median={w['median']:.2f} | "
      f"std={w['std']:.2f} vs MAD={w['MAD']:.2f}  (robust ones resist the 180 kg outlier)")

# --- opt-in reminder: without frames=True the same call returns the neutral dict -------
raw = pyfsda.grpstatsFS(df, [])
print("\nWithout frames=True the result is the neutral dict, keys:", sorted(raw.keys()))

pyfsda.stop()
