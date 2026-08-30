"""pyfsda example: FSDA ``corrNominal`` on a *labeled* pandas contingency table.

This exercises the pandas support added in pyfsda 0.4.0 (spec 019):

* **Input** -- a ``pandas.DataFrame`` with row and column names is marshalled to a MATLAB
  ``table``. ``corrNominal`` takes a contingency table and, when it is a table, reads its
  labels directly (``Lr = N.Properties.RowNames``, ``Lc = N.Properties.VariableNames``),
  so the DataFrame's index/columns become the category labels with no extra options.
* **Output** -- ``frames=True`` returns any table-typed output field (e.g. ``Ntable``) as a
  ``pandas.DataFrame`` carrying those same labels.

To keep it honest, chi-square and Cramer's V are also checked against a small numpy oracle,
so the counts are proven to cross intact -- not just executed.

Run (boots a MATLAB engine; needs the FSDA Add-On and ``pip install pyfsda[pandas]``):

    python examples/corrnominal_pandas_example.py
"""
import numpy as np
import pandas as pd

import pyfsda

# Start the shared engine quietly (skip the network / Add-On version checks for a clean demo).
pyfsda.start(check_version=False)

# --- a 3x4 contingency table: highest education level x preferred news medium ----------
counts = np.array([
    [58, 24, 12, 20],
    [42, 38, 63, 17],
    [15, 20, 88,  9],
], dtype=float)
rows = ["Primary", "Secondary", "Tertiary"]
cols = ["TV", "Newspaper", "Online", "Radio"]

N = pd.DataFrame(counts, index=rows, columns=cols)
print("Contingency table (pandas DataFrame):")
print(N, "\n")

# --- one call: DataFrame -> MATLAB table; corrNominal uses RowNames/VariableNames -------
# dispresults + echo_output surface FSDA's own labeled results table -- visual proof that
# the row/column names crossed the bridge.
out = pyfsda.corrNominal(N, dispresults=True, echo_output=True)

chi2   = float(np.asarray(out["Chi2"]).reshape(-1)[0])
pval   = float(np.asarray(out["Chi2pval"]).reshape(-1)[0])
phi    = float(np.asarray(out["Phi"]).reshape(-1)[0])
cramer = float(np.asarray(out["CramerV"]).reshape(-1)[0])   # CramerV is a 1x4 [index, ...]

print("\nAssociation measures returned by corrNominal:")
print(f"  Chi-square  = {chi2:.4f}   (p = {pval:.3g})")
print(f"  Phi         = {phi:.4f}")
print(f"  Cramer's V  = {cramer:.4f}")

# --- prove the counts crossed intact: numpy oracle (same as the engine agreement gate) --
rt = counts.sum(1, keepdims=True)
ct = counts.sum(0, keepdims=True)
tot = counts.sum()
E = rt @ ct / tot
chi2_ref = float(((counts - E) ** 2 / E).sum())
I, J = counts.shape
cramer_ref = float(np.sqrt(chi2_ref / (tot * (min(I, J) - 1))))
assert abs(chi2 - chi2_ref) < 1e-9, (chi2, chi2_ref)
assert abs(cramer - cramer_ref) < 1e-9, (cramer, cramer_ref)
print(f"\nnumpy oracle agrees within 1e-9  (chi2={chi2_ref:.4f}, V={cramer_ref:.4f}).  PASS")

# --- output-side pandas view --------------------------------------------------------------
# corrNominal returns a *struct*; several of its fields are MATLAB tables (Ntable,
# ConfLimtable, ...). With frames=True those *nested* table fields come back as pandas
# DataFrames with their labels preserved (not bare arrays).
out_f = pyfsda.corrNominal(N, dispresults=False, frames=True)

frame_fields = [k for k, v in out_f.items() if hasattr(v, "columns")]   # the DataFrame fields
print("\nStruct fields returned as pandas DataFrames (frames=True):")
print("  " + ", ".join(frame_fields))

ntable = out_f["Ntable"]        # the contingency table echoed back -- now a labeled DataFrame
print("\nout['Ntable'] as a DataFrame -- same row/column labels as the input:")
print(ntable)

# round-trip check: Ntable is the input contingency table, so it must equal `counts`.
assert set(rows).issubset(ntable.index) and set(cols).issubset(ntable.columns)
assert np.allclose(ntable.loc[rows, cols].to_numpy(dtype=float), counts, atol=1e-9)
print("\nNtable matches the input counts and labels within 1e-9.  PASS")

pyfsda.stop()
