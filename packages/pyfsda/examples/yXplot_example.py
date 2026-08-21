#!/usr/bin/env python3
"""yXplot example: FSR on stack-loss data."""
import numpy as np
from pyfsda import FsdaEngine

eng = FsdaEngine.start(check_version=False)

data = eng.eval("load('stack_loss.mat')")

if isinstance(data, dict):
    table = data['stack_loss']
    colnames = table["VariableNames"]
    arr = np.column_stack([np.asarray(table["data"][c]) for c in colnames])
else:
    arr = np.asarray(data)

y = arr[:, -1].reshape(-1, 1)
X = arr[:, :-1]
print(f"Loaded stack-loss data: y={y.shape}, X={X.shape}")

out = eng.call('FSR', y, X, 'plots', 0)
print("Outliers:", np.asarray(out['outliers']).ravel())
print("Beta:", np.asarray(out['beta']).ravel())

eng.call('yXplot', y, X)
eng.render_figures()
print("Plot opened. Close it to exit.")
eng.wait_for_figures()

eng.stop()
print("Engine stopped.")