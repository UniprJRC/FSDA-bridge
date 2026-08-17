"""Integration smoke test -- requires a running MATLAB with the FSDA Add-On.

Run locally with:  pytest -m integration
It is deselected by the default ``-m "not integration"`` and skips itself when MATLAB /
FSDA cannot be started.

If FSDA is not on the runner's default MATLAB path, set ``PYFSDA_FSDA_ROOT`` to the FSDA
install/checkout dir; it is forwarded to ``FsdaEngine.start(fsda_root=...)``.
"""
import os

import numpy as np
import pytest

pytest.importorskip("matlab.engine")
from pyfsda import FsdaEngine


@pytest.mark.integration
def test_mahalfs_matches_numpy():
    """mahalFS(Y, MU, SIGMA) must equal the numpy Mahalanobis oracle to 1e-9."""
    fsda_root = os.environ.get("PYFSDA_FSDA_ROOT") or None
    try:
        eng = FsdaEngine.start("mahalFS", fsda_root=fsda_root, check_version=False)
    except Exception as exc:                      # no MATLAB / FSDA on this machine
        pytest.skip(f"MATLAB with FSDA not available: {exc}")
    try:
        Y = np.array([[1.0, 2.0], [2.0, 0.0], [3.0, 5.0], [0.0, -1.0], [4.0, 4.0]])
        MU = np.array([2.0, 2.0])
        SIGMA = np.array([[2.0, 0.5], [0.5, 1.0]])
        d = np.asarray(eng.call("mahalFS", Y, MU, SIGMA), dtype=float).reshape(-1)
        diff = Y - MU.reshape(1, -1)
        ref = np.sum((diff @ np.linalg.inv(SIGMA)) * diff, axis=1)
        np.testing.assert_allclose(d, ref, rtol=0.0, atol=1e-9)
    finally:
        eng.stop()


@pytest.mark.integration
def test_dataframe_table_roundtrip():
    """DataFrame input -> MATLAB table, and frames=True: table output -> DataFrame.

    Uses base-MATLAB builtins only (istable / sortrows), so it needs no FSDA. A numeric
    DataFrame must arrive MATLAB-side as a table; passing it through sortrows and reading
    it back with frames=True must reproduce the columns and values within 1e-9.
    """
    pd = pytest.importorskip("pandas")
    from pyfsda import is_table_dict, to_dataframe  # noqa: F401  (exported surface)
    from pyfsda.frames import is_dataframe

    fsda_root = os.environ.get("PYFSDA_FSDA_ROOT") or None
    try:
        eng = FsdaEngine.start(fsda_root=fsda_root, check_version=False)
    except Exception as exc:                          # no MATLAB on this machine
        pytest.skip(f"MATLAB not available: {exc}")
    try:
        df_in = pd.DataFrame({"aa": [1.0, 2.0, 3.0], "bb": [4.0, 5.0, 6.0]})

        # input path: the DataFrame must be seen as a MATLAB table, not a numeric matrix
        assert bool(np.asarray(eng.call("istable", df_in)).astype(bool).ravel()[0])

        # output path: sortrows(T) -> table, viewed back as a DataFrame via frames=True
        rt = eng.call("sortrows", df_in, frames=True)
        assert is_dataframe(rt)
        assert list(rt.columns) == ["aa", "bb"]       # VariableNames preserved
        np.testing.assert_allclose(
            rt[["aa", "bb"]].to_numpy(dtype=float),
            df_in.to_numpy(dtype=float), rtol=0.0, atol=1e-9)

        # default (frames omitted) still returns the neutral dict -- contract unchanged
        assert is_table_dict(eng.call("sortrows", df_in))
    finally:
        eng.stop()


@pytest.mark.integration
def test_dict_to_struct_input():
    """A Python dict argument crosses as a MATLAB struct (fields + values + list[str] cell).

    Uses base-MATLAB builtins (fieldnames / getfield) so it needs no FSDA. Proves the input
    marshalling that lets an FSReda result dict be passed back into a struct-consuming plot.
    """
    try:
        eng = FsdaEngine.start(check_version=False)
    except Exception as exc:                          # no MATLAB on this machine
        pytest.skip(f"MATLAB not available: {exc}")
    try:
        d = {"mat": np.array([[1.0, 2.0], [3.0, 4.0]]),
             "name": "FSReda",
             "styles": ["--", "-.", ":"]}
        names = eng.call("fieldnames", d)             # dict -> struct -> fieldnames -> list
        assert set(names) == {"mat", "name", "styles"}
        mat = np.asarray(eng.call("getfield", d, "mat"), dtype=float)
        np.testing.assert_allclose(mat, [[1.0, 2.0], [3.0, 4.0]], rtol=0.0, atol=1e-9)
        assert eng.call("getfield", d, "name") == "FSReda"
        # the list[str] field is a cellstr; iscellstr confirms it crossed as a cell of char
        assert bool(np.asarray(eng.call("iscellstr", eng.call("getfield", d, "styles"))
                               ).astype(bool).ravel()[0]) or \
            eng.call("getfield", d, "styles") == ["--", "-.", ":"]
    finally:
        eng.stop()


@pytest.mark.integration
def test_resfwdplot_dict_struct_pipeline():
    """End-to-end: LXS -> FSReda (dicts) -> out1 dict -> resfwdplot accepts it as a struct.

    Exercises the whole idiomatic path of examples/resfwdplot_brush_example.py without the
    interactive databrush (so it does not block): the FSReda result dict crosses back as a
    struct and the `fground` dict (with column cellstr Color/LineStyle) is consumed by
    resfwdplot's `set(H,{'Color'},...)` idiom. Figures are kept hidden.
    """
    fsda_root = os.environ.get("PYFSDA_FSDA_ROOT") or None
    try:
        eng = FsdaEngine.start(fsda_root=fsda_root, check_version=False)
    except Exception as exc:                          # no MATLAB / FSDA on this machine
        pytest.skip(f"MATLAB with FSDA not available: {exc}")
    try:
        eng.eval("set(0,'DefaultFigureVisible','off');", nargout=0)
        data = np.loadtxt(eng.which("multiple_regression.txt"))
        y, X = data[:, [3]], data[:, 0:3]
        eng.call("rng", 1000, nargout=0)
        bs = eng.call("LXS", y, X, nsamp=10000)["bs"]
        out = eng.call("FSReda", y, X, bs)
        out1 = dict(out)
        out1["RES"] = np.asarray(out["RES"]) ** 2
        fground = {"fthresh": 3.1 ** 2,
                   "LineStyle": ["--", "-.", ":"],
                   "Color": ["b", "g", "c", "m", "y", "k"]}
        plotopt = eng.call("resfwdplot", out1, fground=fground)   # dict->struct in; cell out
        assert isinstance(plotopt, list) and len(plotopt) > 0
    finally:
        try:
            eng.eval("close all force; set(0,'DefaultFigureVisible','on');", nargout=0)
        except Exception:
            pass
        eng.stop()


@pytest.mark.integration
def test_grpstatsfs_frames_roundtrip():
    """table in -> table out: a numeric DataFrame through grpstatsFS and back via frames=True.

    Mirrors examples/grpstatsFS_pandas_example.py: input column names become the output
    DataFrame's row index, columns are the statistic names, and FSDA's `mean` matches pandas'.
    """
    pd = pytest.importorskip("pandas")
    from pyfsda.frames import is_dataframe

    fsda_root = os.environ.get("PYFSDA_FSDA_ROOT") or None
    try:
        eng = FsdaEngine.start(fsda_root=fsda_root, check_version=False)
    except Exception as exc:                          # no MATLAB / FSDA on this machine
        pytest.skip(f"MATLAB with FSDA not available: {exc}")
    try:
        df = pd.DataFrame({"a": [1.0, 2.0, 3.0, 4.0, 5.0],
                           "b": [10.0, 12.0, 9.0, 11.0, 100.0]})   # 100 = outlier in b
        stats = eng.call("grpstatsFS", df, [], frames=True)        # DataFrame in and out
        assert is_dataframe(stats)
        assert list(stats.index) == ["a", "b"]                     # input columns -> row labels
        assert "mean" in stats.columns and "median" in stats.columns
        for col in df.columns:
            np.testing.assert_allclose(float(stats.loc[col, "mean"]),
                                       float(df[col].mean()), rtol=0.0, atol=1e-9)
        # robust median resists the outlier: b's median far below its (inflated) mean
        assert float(stats.loc["b", "median"]) < float(stats.loc["b", "mean"])
    finally:
        eng.stop()


@pytest.mark.integration
def test_corrnominal_nested_table_frames():
    """A table nested in a returned struct honors frames=True (corrNominal's Ntable).

    Guards the fix where matlab.engine natively converts a struct's table field to a
    DataFrame and from_matlab used to flatten it to a bare ndarray. Default -> neutral
    table-dict (labels kept); frames=True -> pandas DataFrame with those labels.
    """
    pd = pytest.importorskip("pandas")
    from pyfsda.frames import is_dataframe, is_table_dict

    fsda_root = os.environ.get("PYFSDA_FSDA_ROOT") or None
    try:
        eng = FsdaEngine.start(fsda_root=fsda_root, check_version=False)
    except Exception as exc:                          # no MATLAB / FSDA on this machine
        pytest.skip(f"MATLAB with FSDA not available: {exc}")
    try:
        counts = np.array([[10.0, 20.0, 30.0], [40.0, 50.0, 60.0], [70.0, 80.0, 90.0]])
        N = pd.DataFrame(counts, index=["r1", "r2", "r3"], columns=["c1", "c2", "c3"])

        # default: the nested table field is the neutral table-dict, labels preserved
        raw = eng.call("corrNominal", N, dispresults=False)
        nt = raw["Ntable"]
        assert is_table_dict(nt)
        assert list(nt["VariableNames"]) == ["c1", "c2", "c3"]
        assert list(nt["RowNames"]) == ["r1", "r2", "r3"]

        # frames=True: the nested table field is a DataFrame with those labels + values
        out = eng.call("corrNominal", N, dispresults=False, frames=True)
        ntf = out["Ntable"]
        assert is_dataframe(ntf)
        assert list(ntf.index) == ["r1", "r2", "r3"]
        assert list(ntf.columns) == ["c1", "c2", "c3"]
        np.testing.assert_allclose(ntf.loc[["r1", "r2", "r3"], ["c1", "c2", "c3"]]
                                   .to_numpy(dtype=float), counts, rtol=0.0, atol=1e-9)
    finally:
        eng.stop()
