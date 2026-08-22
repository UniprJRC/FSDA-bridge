
import numpy as np
import pyfsda

pyfsda.start(check_version=False)

data = pyfsda.load("swiss_banknotes")
table = data["swiss_banknotes"]

data = np.column_stack(list(table["data"].values()))

print(f"swiss_banknotes dataset: {data.shape[0]} observations, {data.shape[1]} variables")

pyfsda.rng(42, nargout=0)
out = pyfsda.FSM(data, plots=0, msg=0)

print("Output keys:", list(out.keys()))
outliers = np.asarray(out["outliers"], dtype=int).ravel()
loc = np.asarray(out["loc"]).ravel()
print("Outliers:", outliers)
print("md shape:", np.asarray(out["md"]).shape)
print("mmd shape:", np.asarray(out["mmd"]).shape)
print("cov shape:", np.asarray(out["cov"]).shape)
print("loc:", loc)

pyfsda.stop()
