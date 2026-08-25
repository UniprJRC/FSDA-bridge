"""pyfsda example: interactive Forward-Search *persistent brushing* of residual trajectories.

This example showcases the possibility of leaving the data inside the running
MATLAB session, and fetching only when it's needed, avoiding multiple unnecessary
marshalling trips when the data doesn't need to leave MATLAB.
"""
import sys

import numpy as np

import pyfsda

eng = pyfsda.start(check_version=False)

# --- 1. data: y = 4th column, X = first three columns of the FSDA dataset --------------
# The dataset ships with FSDA; ask MATLAB where it is, then read it with numpy.
data = np.loadtxt(eng.which("multiple_regression.txt"))
y = data[:, [3]]        # response, kept 2-D (n, 1) so it crosses as a MATLAB column
X = data[:, 0:3]        # the three explanatory variables

# --- 2. robust fit (LMS) + Forward Search, both via the pyfsda façade ------------------
pyfsda.rng(1000, nargout=0)                          # reproducible demo

# by using the WorkspaceRefs with store="name" the data never leaves MATLAB
ref_lxs = pyfsda.LXS(y, X, nsamp=10000, store="lxs_out")
ref_eda = pyfsda.FSReda(y, X, ref_lxs.field("bs"), store="eda_out")

# Square RES directly in MATLAB
eng.eval("eda_out.RES = eda_out.RES.^2;", nargout=0)

# --- 3. foreground trajectory styling (a plain Python dict -> MATLAB struct) ------------
fground = {
    "fthresh":   3.1 ** 2,                 # highlight trajectories above 3.1^2
    "LineStyle": ["--", "-.", ":"],        # different line styles in foreground
    "Color":     ["b", "g", "c", "m", "y", "k"],   # different colors in foreground
}

# --- 4. persistent rectangular brushing (a plain Python dict -> MATLAB struct) ----------
databrush = {
    "bivarfit":      "",
    "selectionmode": "Rect",               # rubber-band rectangle selection
    "persist":       "on",                 # keep brushing across repeated selections
    "Label":         "on",                 # write trajectory labels while selecting
    "RemoveLabels":  "off",                # keep the labels after each selection
}

# --- 5. the interactive plot, called as pyfsda.resfwdplot(...) --------------------------
interactive = sys.stdin.isatty()

print("Opening the resfwdplot figure ...")
if interactive:
    print("  * Rect-select residual trajectories to brush; persist='on' lets you brush repeatedly.")
    print("  * Press a keyboard key on the plot to STOP brushing (the call returns).")
    pyfsda.resfwdplot(ref_eda, fground=fground, databrush=databrush, nargout=0)
    eng.render_figures()
    print("Brushing finished. Close the figure window(s) to end the session.")
    eng.wait_for_figures()
else:
    pyfsda.resfwdplot(ref_eda, fground=fground, nargout=0)
    eng.render_figures()
    print("Non-interactive run: drew resfwdplot without brushing "
          "(run this in a terminal to brush it).")

# --- 6. Fetch the data only when necessary
res = pyfsda.fetch(ref_eda.field("RES"))
print(f"Fetched RES to Python: {type(res).__name__} {res.shape}")
print(f"First 3 obs, first 5 steps:\n{res[:3, :5]}")

mdr = pyfsda.fetch(ref_eda.field("mdr"))
print(f"Fetched mdr: {type(mdr).__name__} {mdr.shape}")
print(f"First 5 rows:\n{mdr[:5]}")

pyfsda.clear(ref_lxs, ref_eda)
pyfsda.stop()
