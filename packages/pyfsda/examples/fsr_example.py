
import numpy as np
import pyfsda

pyfsda.start(check_version=False)

# stars dataset: x = temperature, y = light intensity
data = pyfsda.load("stars")
table = data["stars"]

colnames = table["VariableNames"]
data = np.column_stack([np.asarray(table["data"][c], dtype=float) for c in colnames])

y = data[:, -1]
X = data[:, :-1]

print(f" dataset: {X.shape[0]} observations, {X.shape[1]} predictors\n")

out = pyfsda.FSR(y, X, nsamp=0, plots=0, msg=0)

beta = np.asarray(out["beta"], dtype=float).reshape(-1)
scale = float(np.asarray(out["scale"]).reshape(-1)[0])
outliers = sorted(int(v) for v in np.asarray(out["outliers"]).reshape(-1) if not np.isnan(v))

print("Forward search fit on:")
print(f"  beta = {beta}")
print(f"  scale = {scale:.6f}")
print(f"  flagged outliers (indices): {outliers}")

pyfsda.stop()
