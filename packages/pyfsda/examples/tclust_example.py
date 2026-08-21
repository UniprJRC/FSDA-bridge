#!/usr/bin/env python3

import pyfsda

print("Starting MATLAB...")

eng = pyfsda.FsdaEngine.start(
    "tclust", check_version=False
)

eng.call("rng", 1,nargout=0)

Y = eng.call("load", "geyser2.txt")

out = eng.call(
    "tclust",
    Y,
    3,
    0.1,
    10000
)

print("\nReturned fields:")
print(out.keys())

print("\nObjective function:")
print(out["obj"])

print("\nCluster sizes:")
print(out["siz"])

eng.stop()