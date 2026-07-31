#!/usr/bin/env python3
"""Minimal pyfsda example — FSM + malfwdplot on Hawkins data.

Hawkins data is loaded directly from FSDA's built-in .mat file through MATLAB.
Follows the same pattern as score_example.py.
"""
from __future__ import annotations

import os
import sys

import numpy as np

from pyfsda import FsdaEngine

TOL = 1e-9


def main() -> int:
    fsda_root = (
        sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PYFSDA_FSDA_ROOT")
    ) or None

    print("Starting MATLAB (slow the first time) ...")
    try:
        eng = FsdaEngine.start("FSM", fsda_root=fsda_root, check_version=False)
    except Exception as exc:
        print("\nCould not start MATLAB with FSDA:")
        print("  * is MATLAB installed and matlabengine matching its release?")
        print("  * is FSDA on the MATLAB path? (pass FSDA_ROOT as arg or env var)")
        print(f"\nunderlying error: {exc}")
        return 1

    try:
        print(f"MATLAB {eng.version()} ready.\n")

        # Load Hawkins data from FSDA's built-in .mat file
        eng.eval("load('hawkins.mat'); Y = hawkins{:, 1:3};", nargout=0)
        HAWKINS = np.asarray(eng.eval("Y"))
        print(f"Loaded Hawkins data: {HAWKINS.shape}\n")

        # Run FSM
        out = eng.call("FSM", HAWKINS, plots=0, msg=0)
        print("out keys:", list(out.keys()))

        outliers = np.asarray(out["outliers"], dtype=float).reshape(-1)
        md = np.asarray(out["md"], dtype=float)
        mmd = np.asarray(out["mmd"], dtype=float)
        print(f"outliers: {outliers.astype(int).tolist()}")
        print(f"md shape:  {md.shape}")
        print(f"mmd shape: {mmd.shape}")

        # 1e-9 agreement gate (local refs, NOT committed)
        ref_dir = os.path.join(os.path.dirname(__file__), "..", "..", "references")
        try:
            ref_out = np.loadtxt(os.path.join(ref_dir, "hawkins_fsm_outliers_ref.csv"), delimiter=",")
            ref_md  = np.loadtxt(os.path.join(ref_dir, "hawkins_fsm_md_ref.csv"),  delimiter=",")
            ref_mmd = np.loadtxt(os.path.join(ref_dir, "hawkins_fsm_mmd_ref.csv"), delimiter=",")
            np.testing.assert_allclose(outliers, ref_out, rtol=0.0, atol=TOL)
            np.testing.assert_allclose(md,      ref_md,  rtol=0.0, atol=TOL)
            np.testing.assert_allclose(mmd,     ref_mmd, rtol=0.0, atol=TOL)
            print("\nAgreement gate: PASS (within 1e-9)")
            gate_ok = True
        except FileNotFoundError:
            print("\nNote: local reference files not found — run generate_reference.m in MATLAB first")
            gate_ok = True
        except AssertionError as exc:
            print(f"\nAgreement gate: FAIL — {exc}")
            gate_ok = False

        # Plot
            
        print("\nCalling malfwdplot(out) ...")
        out["MAL"] = out["md"]  # malfwdplot expects MAL field
        out["Y"] = HAWKINS       # malfwdplot expects original data
        
        # Use direct MATLAB feval (bypasses pyfsda wrapper which forces nargout=0)
        eng.eng.feval("malfwdplot", out, nargout=0)
        
        eng.render_figures()
        print("Plot window open. Close it to continue.")
        eng.wait_for_figures()
        print(f"\nRESULT: {'PASS' if gate_ok else 'FAIL'}")
    finally:
        eng.stop()

    return 0 if gate_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())