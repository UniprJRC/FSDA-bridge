"""pyfsda — call FSDA (MATLAB robust-statistics toolbox) routines from Python.

Two ways to call, over the same generic engine and numpy <-> MATLAB marshalling.

Functional (MATLAB-like) — call any FSDA routine as ``pyfsda.<name>(...)``; the shared
MATLAB session starts on first use and is reused::

    import pyfsda

    d   = pyfsda.mahalFS(Y, MU, SIGMA)               # numeric array -> ndarray
    out = pyfsda.Score(y, X, la=la, intercept=True)  # struct        -> dict
    RAW, REW = pyfsda.mcd(Y, nargout=2)              # two outputs   -> tuple
    pyfsda.stop()                                     # optional; also runs at exit

Explicit session (advanced) — manage the engine yourself::

    from pyfsda import FsdaEngine
    eng = FsdaEngine.start("mahalFS")
    d   = eng.call("mahalFS", Y, MU, SIGMA)
    eng.stop()

Requires MATLAB with the FSDA Add-On and a ``matlabengine`` release matching that
MATLAB (see the README).

On the first call, pyfsda prints (once, best-effort) the latest FSDA release available
on GitHub, so you can check your install is current. Silence it with
``pyfsda.start(check_version=False)`` before the first call.

Optional pandas view (``pip install pyfsda[pandas]``): pass ``frames=True`` to receive
table/timetable outputs as a ``pandas.DataFrame`` (``out = pyfsda.univariatems(y, X,
frames=True)``), and pass a ``pandas.DataFrame`` argument to send a MATLAB ``table`` in.
The default return is still the neutral dict -- the cross-language contract is unchanged.
"""
from __future__ import annotations

import atexit
import sys

from .engine import FsdaEngine, from_matlab, to_matlab, WorkspaceRef
from .frames import is_table_dict, to_dataframe

__version__ = "0.5.0"

__all__ = [
    "FsdaEngine", "to_matlab", "from_matlab",
    "to_dataframe", "is_table_dict",
    "start", "stop", "engine", "__version__",
    "WorkspaceRef", "fetch", "clear",
]

# --- shared lazily-started engine (backs the functional pyfsda.<name>(...) surface) ----
_ENGINE: FsdaEngine | None = None
_WRAPPERS: dict = {}
_VALIDATED: set = set()          # FSDA names confirmed on-path for the current engine
_CHECK_VERSION: bool = True      # set by start(); gates the first-call GitHub version notice
_LATEST_CHECKED: bool = False    # run-once latch for _notify_latest_fsda

_FSDA_RELEASES_API = "https://api.github.com/repos/UniprJRC/FSDA/releases/latest"

# A few common FSDA routines advertised by __dir__ for REPL discoverability. The
# __getattr__ mechanism accepts ANY FSDA function name, not just these.
_COMMON = (
    "mahalFS", "Score", "FSR", "FSRaddt", "FSM", "mcd", "pcaFS",
    "corrNominal", "tabulateFS", "TBwei", "bc", "combsFS",
)


def start(routine: str | None = None, fsda_root: str | None = None,
          check_version: bool = True) -> FsdaEngine:
    """Start (once) and return the shared FSDA engine used by ``pyfsda.<name>(...)``.

    Idempotent: returns the already-running engine on later calls. Call this before the
    first routine only if you need to set ``fsda_root`` or disable ``check_version``.
    """
    global _ENGINE, _CHECK_VERSION
    if _ENGINE is None:
        # Set the GitHub-notice gate only when we actually create the engine, so a later
        # bare engine() / pyfsda.<name>() call (which routes through start()) cannot silently
        # re-enable a notice the caller disabled with start(check_version=False).
        _CHECK_VERSION = check_version
        _ENGINE = FsdaEngine.start(routine=routine, fsda_root=fsda_root,
                                   check_version=check_version)
    return _ENGINE


def engine() -> FsdaEngine:
    """Return the shared engine, starting it with defaults if needed."""
    return start()


def stop() -> None:
    """Shut the shared engine down (safe to call when it was never started)."""
    global _ENGINE, _LATEST_CHECKED
    if _ENGINE is not None:
        try:
            _ENGINE.stop()
        finally:
            _ENGINE = None
            _VALIDATED.clear()
            _LATEST_CHECKED = False        # a fresh session re-checks the latest release


atexit.register(stop)

def fetch(ref, *, frames=False):
    """Pull a stored workspace variable to Python."""
    return engine().fetch(ref, frames=frames)

def clear(*refs):
    """Remove stored workspace variables."""
    engine().clear(*refs)


def _notify_latest_fsda() -> None:
    """Once per session, print the latest FSDA release available on GitHub (stderr).

    Purely informational and best-effort: it reports the latest `tag_name` from the FSDA
    GitHub releases API using only the standard library, and stays silent on any failure
    (offline, rate-limited, blocked). It does NOT compare against the installed version.
    Runs on the first `pyfsda.<name>(...)` call and is gated by `check_version` (disable
    with `pyfsda.start(check_version=False)`). Separate from `engine.py`'s `tuna` check.
    """
    global _LATEST_CHECKED
    if _LATEST_CHECKED or not _CHECK_VERSION:
        return
    _LATEST_CHECKED = True                  # latch up front: never retry on failure
    try:
        import json
        import urllib.request

        with urllib.request.urlopen(_FSDA_RELEASES_API, timeout=4.0) as resp:
            tag = json.load(resp).get("tag_name")
        if tag:
            sys.stderr.write(
                f"pyfsda: latest FSDA release on GitHub is {tag} "
                f"(https://github.com/UniprJRC/FSDA/releases/tag/{tag}). "
                f"Ensure your installed FSDA is current.\n"
            )
            sys.stderr.flush()
    except Exception:
        pass                                # never let a courtesy check break a call


def _make_wrapper(name: str):
    """Build (and cache) a callable that runs FSDA `name` on the shared engine."""
    def _fsda_call(*args, **kwargs):
        eng = engine()
        _notify_latest_fsda()                          # once: latest FSDA release on GitHub
        if name not in _VALIDATED:                     # verify once per name (typo guard)
            if not eng.which(name):
                raise AttributeError(
                    f"FSDA function {name!r} not found on the MATLAB path."
                )
            _VALIDATED.add(name)
        return eng.call(name, *args, **kwargs)
    _fsda_call.__name__ = name
    _fsda_call.__qualname__ = name
    _fsda_call.__doc__ = (f"Call FSDA `{name}` on the shared pyfsda engine: "
                          f"pyfsda.{name}(*args, **name_value_options).")
    return _fsda_call


def __getattr__(name: str):                            # PEP 562 module-level hook
    """Expose any FSDA routine as ``pyfsda.<name>`` (e.g. ``pyfsda.Score``)."""
    if name.startswith("_"):                            # don't hijack dunders/privates
        raise AttributeError(f"module 'pyfsda' has no attribute {name!r}")
    wrapper = _WRAPPERS.get(name)
    if wrapper is None:
        wrapper = _WRAPPERS[name] = _make_wrapper(name)
    return wrapper


def __dir__() -> list:
    return sorted(set(__all__) | set(_COMMON))
