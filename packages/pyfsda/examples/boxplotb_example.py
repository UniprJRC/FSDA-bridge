#!/usr/bin/env python3
"""boxplotb example with FSDA stars data."""
import numpy as np
from pyfsda import FsdaEngine

eng = FsdaEngine.start(check_version=False)

data = eng.eval("load('stars.txt')")
arr = np.asarray(data)

out = eng.call('boxplotb', arr)
print("Output keys:", list(out.keys()))
print("Cent shape:", np.asarray(out['cent']).shape)
outliers = np.asarray(out['outliers']).ravel().astype(int)
print("Outliers:", outliers.tolist())
print("Spl shape:", np.asarray(out['Spl']).shape)

eng.render_figures()
print("Plot opened. Close it to exit.")
eng.wait_for_figures()

eng.stop()
print("Engine stopped.")