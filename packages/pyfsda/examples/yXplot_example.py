#!/usr/bin/env python3
"""Minimal pyfsda example — FSDA's FSR (robust regression) + yXplot on stack-loss data."""
import numpy as np
import pyfsda as FS

# Stack-loss data (Brownlee, 1965): 21 observations
# Columns: air flow, water temp, acid conc, stack loss
STACK = np.array([
    [80, 27, 89, 42], [80, 27, 88, 37], [75, 25, 90, 37],
    [62, 24, 87, 28], [62, 22, 87, 18], [62, 23, 87, 18],
    [62, 24, 93, 19], [62, 24, 93, 20], [58, 23, 87, 15],
    [58, 18, 80, 14], [58, 18, 89, 14], [58, 17, 88, 13],
    [58, 18, 82, 11], [58, 19, 93, 12], [50, 18, 89,  8],
    [50, 18, 86,  7], [50, 19, 72,  8], [50, 19, 79,  8],
    [50, 20, 80,  9], [56, 20, 82, 15], [70, 20, 91, 15],
], dtype=float)

y = STACK[:, -1].reshape(-1, 1)   # response as (n, 1) column
X = STACK[:, :3]                   # three predictors

# One call to FSDA's FSR — the MATLAB engine starts on first use
out = FS.FSR(y, X, plots=0, msg=0)

# `out` is a dict (MATLAB struct -> Python dict)
print("out is a", type(out).__name__, "with keys", list(out.keys()))

outliers = np.asarray(out["outliers"]).reshape(-1)
beta = np.asarray(out["beta"]).reshape(-1)
print("outliers:", outliers.astype(int).tolist())
print("beta:    ", beta.round(6).tolist())

# Agreement gate: compare to local MATLAB reference (1e-9)
# Run the MATLAB snippet below first to create the ref files
import os
ref_dir = os.path.join(os.path.dirname(__file__), "..", "..", "references")
try:
    ref_out = np.loadtxt(os.path.join(ref_dir, "fsr_stackloss_outliers_ref.csv"), delimiter=",")
    ref_beta = np.loadtxt(os.path.join(ref_dir, "fsr_stackloss_beta_ref.csv"), delimiter=",")
    np.testing.assert_allclose(outliers, ref_out, rtol=0.0, atol=1e-9)
    np.testing.assert_allclose(beta, ref_beta, rtol=0.0, atol=1e-9)
    print("Agreement gate: PASS")
except FileNotFoundError:
    print("Note: run the MATLAB reference snippet to enable 1e-9 gate")
except AssertionError as e:
    print("Agreement gate: FAIL —", e)

# Plot
FS.yXplot(y, X)
FS.engine().render_figures()
print("Plot open. Close it to continue.")
FS.engine().wait_for_figures()
FS.stop()
