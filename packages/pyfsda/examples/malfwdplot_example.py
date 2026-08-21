#!/usr/bin/env python3
"""malfwdplot example: FSMeda on swiss banknotes data."""
import numpy as np
from pyfsda import FsdaEngine

eng = FsdaEngine.start(check_version=False)

data = eng.eval("load('swiss_banknotes.txt')")

if isinstance(data, dict):
    table = data['swiss_banknotes']
    colnames = table["VariableNames"]
    arr = np.column_stack([np.asarray(table["data"][c]) for c in colnames])
else:
    arr = np.asarray(data)

fre = eng.call('unibiv', arr)
m0 = 20
bs = fre[:m0, 0].reshape(-1, 1)
out = eng.call('FSMeda', arr, bs)
print("MMD shape:", np.asarray(out['mmd']).shape)

eng.call("malfwdplot", out, nargout=0)

eng.render_figures()
print("Plot window open. Close it to exit.")
eng.wait_for_figures()

eng.stop()
print("Engine stopped.")