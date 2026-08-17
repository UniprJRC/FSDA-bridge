"""pyfsda example: interactive Forward-Search *persistent brushing* of residual trajectories.

Idiomatic port of the FSDA MATLAB example
"MR: Forward EDA persistent brushing with other options":

    load('multiple_regression.txt')
    y = multiple_regression(:,4);  X = multiple_regression(:,1:3);
    out = LXS(y, X, 'nsamp', 10000);          % LMS from 10000 subsamples
    out = FSReda(y, X, out.bs);               % Forward Search, monitor residuals
    out1 = out;  out1.RES = out.RES.^2;       % scaled *squared* residuals
    ... build fground / databrush structs ...
    resfwdplot(out1, 'fground', fground, 'databrush', databrush);

Every FSDA routine is called through the pyfsda façade -- ``pyfsda.LXS`` / ``pyfsda.FSReda``
/ ``pyfsda.resfwdplot`` -- with plain Python objects. No MATLAB code is run by hand: FSDA
results come back as dicts and are passed straight back in. A Python ``dict`` marshals to a
MATLAB ``struct`` (numbers/arrays -> double, strings -> char, ``list[str]`` -> cellstr), so:

  * the ``FSReda`` result dict (``out1``, with ``RES`` squared) crosses back as the struct
    ``resfwdplot`` reads, and
  * the ``fground`` / ``databrush`` option structs are ordinary Python dicts.

``resfwdplot`` is interactive graphics, so it runs MATLAB-side (nargout=0) and brushing is
done with the mouse on the live figure.

Run (opens a MATLAB figure; needs the FSDA Add-On):

    python examples/resfwdplot_brush_example.py

Then rubber-band (Rect) select residual trajectories; with ``persist='on'`` you can brush
repeatedly and the selections/labels accumulate. Press a key on the plot to stop brushing,
then close the figure window(s) to finish.
"""
import sys

import numpy as np

import pyfsda

# Start the shared engine quietly (skip the network / Add-On version checks for a clean demo).
eng = pyfsda.start(check_version=False)

# --- 1. data: y = 4th column, X = first three columns of the FSDA dataset --------------
# The dataset ships with FSDA; ask MATLAB where it is, then read it with numpy.
data = np.loadtxt(eng.which("multiple_regression.txt"))
y = data[:, [3]]        # response, kept 2-D (n, 1) so it crosses as a MATLAB column
X = data[:, 0:3]        # the three explanatory variables

# --- 2. robust fit (LMS) + Forward Search, both via the pyfsda façade ------------------
pyfsda.rng(1000, nargout=0)                          # reproducible demo (seed MATLAB's RNG; example sets none)
out_lxs = pyfsda.LXS(y, X, nsamp=10000)              # dict -> use the best subset out.bs
out = pyfsda.FSReda(y, X, out_lxs["bs"])            # dict: RES, Un, y, X, Bols, class, ...

out1 = dict(out)                                     # out1 = out
out1["RES"] = np.asarray(out["RES"]) ** 2            # out1.RES = out.RES.^2 (scaled squared)

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
# resfwdplot WITH databrush runs databrush's own interactive loop and BLOCKS until you press
# a key on the plot to stop brushing (figure/keyboard-driven, so it works with the engine
# embedded). Gate on a TTY so piped / CI runs never hang: with no TTY, plot WITHOUT brushing.
interactive = sys.stdin.isatty()

print("Opening the resfwdplot figure ...")
if interactive:
    print("  * Rect-select residual trajectories to brush; persist='on' lets you brush repeatedly.")
    print("  * Press a keyboard key on the plot to STOP brushing (the call returns).")
    pyfsda.resfwdplot(out1, fground=fground, databrush=databrush, nargout=0)  # blocks while brushing
    eng.render_figures()
    print("Brushing finished. Close the figure window(s) to end the session.")
    eng.wait_for_figures()             # MATLAB-side uiwait; returns when all figures close
else:
    pyfsda.resfwdplot(out1, fground=fground, nargout=0)   # no databrush -> does not block
    eng.render_figures()
    print("Non-interactive run: drew resfwdplot without brushing "
          "(run this in a terminal to brush it).")

pyfsda.stop()
