
import numpy as np
import pandas as pd
import pyfsda

pyfsda.start(check_version=False)

data = pyfsda.load("swiss_banknotes")
table = data["swiss_banknotes"]

df = pd.DataFrame(table["data"])[table["VariableNames"]]
data = df.to_numpy()

print(f"swiss_banknotes dataset: {data.shape[0]} observations, {data.shape[1]} variables")

fre = np.asarray(pyfsda.unibiv(data))
fre = fre[fre[:, 3].argsort()]
bs = fre[:20, 0].reshape(-1, 1)

out = pyfsda.FSMeda(data, bs, plots=0)

mmd = np.asarray(out["mmd"])
gap = np.asarray(out["gap"])

print("Output keys:", list(out.keys()))

print("\nMMD (Min Mahalanobis Distance) Preview (First 3 & Last 3 Steps)")
print("Step | Min MD  | (m+1)th Ordered MD")
for row in mmd[:3]:
    print(f"{int(row[0]):4d} | {row[1]:16.4f} | {row[2]:16.4f}")

for row in mmd[-3:]:
    print(f"{int(row[0]):4d} | {row[1]:16.4f} | {row[2]:16.4f}")

print("\nGap (Last 3 Steps)")
print("Step | Min MD Outside - Max MD Inside | (m+1)th - mth Ordered MD")
for row in gap[-3:]:
    print(f"{int(row[0]):4d} | {row[1]:16.4f} | {row[2]:16.4f}")

pyfsda.stop()
