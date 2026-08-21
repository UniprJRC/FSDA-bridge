#!/usr/bin/env python3

import pyfsda

eng = pyfsda.FsdaEngine.start(
    "tkmeans",check_version=False
)

eng.call("rng", 1, nargout=0)

Y = eng.call("load", "geyser2.txt")

out = eng.call("tkmeans", Y, 3, 0.03)

print("Objective function:")
print(out["obj"])

print("\nCluster sizes:")
print(out["siz"])

print("\nWeights:")
print(out["weights"])

eng.stop()
