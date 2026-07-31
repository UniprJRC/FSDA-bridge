#!/usr/bin/env python3
"""Minimal pyfsda example — boxplotb (bivariate boxplot) on 2-D data.

Follows the same pattern as score_example.py.
"""
from __future__ import annotations

import os
import sys

import numpy as np

from pyfsda import FsdaEngine

TOL = 1e-9

# --- Bivariate dataset (20 observations, 2 variables) ------------------------
# 18 inliers from N([0,0], [[1,0.5],[0.5,1]]) + 2 outliers at [5,5] and [-5,-5]
# Generated with rng(42) in MATLAB for reproducibility.
BIVARIATE_2D = np.array([
    [ 0.4967,  0.1383], [ 0.6477,  1.1530], [-0.2342, -0.4634],
    [ 1.5792,  1.4963], [ 0.7674, -0.1508], [-0.4695,  0.6981],
    [ 0.5426, -0.1018], [-0.4634,  0.2340], [-0.4657,  1.5232],
    [ 0.2410, -0.5434], [-1.9133, -1.5708], [-1.7249, -1.0222],
    [-0.5623, -0.3226], [-1.0128,  0.4320], [ 0.3142,  1.1394],
    [-0.9080,  0.2957], [-1.4123, -0.6295], [ 1.4656,  1.2259],
    [ 5.0000,  5.0000], [-5.0000, -5.0000],
], dtype=float)


def main() -> int:
    fsda_root = (
        sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PYFSDA_FSDA_ROOT")
    ) or None

    print("Starting MATLAB (slow the first time) ...")
    try:
        eng = FsdaEngine.start("boxplotb", fsda_root=fsda_root, check_version=False)
    except Exception as exc:
        print("\nCould not start MATLAB with FSDA:")
        print("  * is MATLAB installed and matlabengine matching its release?")
        print("  * is FSDA on the MATLAB path? (pass FSDA_ROOT as arg or env var)")
        print(f"\nunderlying error: {exc}")
        return 1

    try:
        print(f"MATLAB {eng.version()} ready.\n")

        # Run boxplotb
        out = eng.call("boxplotb", BIVARIATE_2D)
        print("out keys:", list(out.keys()))

        fence = np.asarray(out.get("fence", []), dtype=float)
        data = np.asarray(out.get("data", []), dtype=float)
        print(f"fence shape: {fence.shape}")
        print(f"data shape:  {data.shape}")

        # 1e-9 agreement gate (local refs, NOT committed)
        ref_dir = os.path.join(os.path.dirname(__file__), "..", "..", "references")
        try:
            ref_fence = np.loadtxt(os.path.join(ref_dir, "boxplotb_fence_ref.csv"), delimiter=",")
            ref_data = np.loadtxt(os.path.join(ref_dir, "boxplotb_data_ref.csv"), delimiter=",")
            np.testing.assert_allclose(fence, ref_fence, rtol=0.0, atol=TOL)
            np.testing.assert_allclose(data, ref_data, rtol=0.0, atol=TOL)
            print("\nAgreement gate: PASS (within 1e-9)")
            gate_ok = True
        except FileNotFoundError:
            print("\nNote: local reference files not found — run generate_reference.m in MATLAB first")
            gate_ok = True
        except AssertionError as exc:
            print(f"\nAgreement gate: FAIL — {exc}")
            gate_ok = False

        # Plot
        print("\nCalling boxplotb(Y) ...")
        eng.call("boxplotb", BIVARIATE_2D)
        eng.render_figures()
        print("Plot window open. Close it to continue.")
        eng.wait_for_figures()

        print(f"\nRESULT: {'PASS' if gate_ok else 'FAIL'}")
    finally:
        eng.stop()

    return 0 if gate_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
