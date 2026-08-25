"""pyfsda — a generic Python bridge for calling FSDA routines via the MATLAB Engine.

Python -> matlab.engine -> MATLAB + FSDA

Every per-routine `code/<target>/bridge.py` repeats the same engine/plumbing:
start the engine, check the routine is on the path, marshal numpy <-> matlab.double,
route MATLAB messages, handle figures, shut down. This module factors that plumbing
into ONE place so a new FSDA routine usually needs no wrapper at all -- you call

    eng = FsdaEngine.start("mahalFS")
    d   = eng.call("mahalFS", Y, MU, SIGMA)            # numeric array  -> ndarray
    out = eng.call("Score", y, X, la=la, intercept=True)  # struct      -> dict

and the generic converters handle the crossing. It covers these MATLAB return
shapes (see spec 016):

    numeric array            matlab.double      -> ndarray
    struct                   dict               -> dict (recursed)
    nested struct of arrays  dict of dicts      -> dict of dicts of ndarrays
    char/string scalar       char               -> str
    table / timetable        (cannot return)    -> dict {VariableNames, RowNames
                                                  / RowTimes, data}  (decomposed
                                                  MATLAB-side; see _table_to_dict)
    2-D cell (M x N)         (cannot return)    -> nested list (see _marshal_cell2d)
    struct holding any of    (cannot return)    -> dict, decomposed field-by-field
    the above                                     (see _marshal_struct)

A table/timetable, a 2-D cell, or a struct *containing* one cannot be returned to Python
by the engine at all, so `call` runs through the MATLAB workspace and decomposes them
there (the approach `code/getYahoo/bridge.py` uses for its timetable). The struct/cell
field-by-field path is a *fallback*: the fast whole-value read is tried first, so ordinary
structs/numerics are untouched. STILL OUT OF SCOPE: struct-ARRAYS and datetime/duration
scalars (getYahoo keeps its own bespoke bridge for those).

Marshalling rules (CONSTITUTION sec 4):
  * Output is returned in MATLAB's natural shape -- NO silent reshape. A column
    vector stays (n, 1); callers squeeze if they want (n,).
  * Input has ONE documented convention: a 1-D ndarray/list crosses as a MATLAB
    *row* (1 x n). Pass an (n, 1) array when a routine wants a column (e.g. y).
  * NaN / Inf are preserved; MATLAB indices stay 1-based -- interpretation is the
    caller's.

Dependencies: numpy + matlab + matlab.engine + stdlib only.

See the pyfsda README for the full marshalling rules and usage.
"""
from __future__ import annotations

import io
import re
import sys

import numpy as np
import matlab
import matlab.engine

from .frames import apply_frames, dataframe_to_table_dict, is_dataframe

# call() reserves these keyword names for its own control; every OTHER keyword is
# forwarded to MATLAB as a name/value pair. Notably `msg` is NOT reserved -- it
# passes straight through to FSDA (FSR/FSRaddt/getYahoo each have their own `msg`
# option). The bridge's stdout/stderr tee is `echo_output`, deliberately named so
# it cannot collide with an FSDA option. `frames` is the opt-in pandas view (see
# call()). The rare case where an FSDA option's name does collide with one of these
# reserved words is handled via the `options` dict:
#     eng.call("FSR", y, X, options={"nargout": ...})
_RESERVED_CALL_KWARGS = ("nargout", "echo_output", "options", "frames", "store")

# call()/eval() execute through the MATLAB workspace (so table/timetable outputs --
# which the engine cannot return directly -- can be decomposed MATLAB-side). The
# function name and option names are interpolated into an eval command, so they are
# validated against this allow-list first (an injection guard, like getYahoo).
_IDENT_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
_REF_RE   = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)*$")

class WorkspaceRef:
    """minimal token referencing a MATLAB workspace variable."""
    __slots__ = ("name",)

    def __init__(self, name: str):
        if not _REF_RE.match(name):
            raise ValueError(f"invalid workspace variable name: {name!r}")
        self.name = name

    def __repr__(self):
        return f"WorkspaceRef({self.name!r})"

    def field(self, name: str) -> "WorkspaceRef":
        """Access a struct field: WorkspaceRef('out').field('x') → WorkspaceRef('out.x')."""
        if not _IDENT_RE.match(name):
            raise ValueError(f"invalid field name: {name!r}")
        return WorkspaceRef(f"{self.name}.{name}")

def _cellstr_list(raw) -> list:
    """MATLAB cellstr -> Python list[str]. The engine returns a 1-element cell as a
    bare str and a multi-element cell as a list; an empty cell as an empty value.
    Collapse all of these to a list[str]."""
    if raw is None:
        return []
    if isinstance(raw, str):
        return [raw]
    try:
        return [str(x) for x in raw]
    except TypeError:
        return [str(raw)]


def to_matlab(x):
    """Marshal a Python value to a MATLAB-engine input type.

    ndarray : 0-D -> float; 1-D -> MATLAB row (1 x n); 2-D -> matlab.double as-is.
              (1-D -> row is a *convention*; pass an (n, 1) array for a column.)
    bool    -> bool (MATLAB logical) -- checked before int (bool is an int subclass).
    int/float -> float.   str -> str (char).   list/tuple of numbers -> row matlab.double.
    Anything else is passed through untouched (already a matlab.* type, etc.).
    """
    if is_dataframe(x):
        raise TypeError(
            "pandas.DataFrame inputs are marshalled to a MATLAB table by call() -- "
            "pass a DataFrame as a positional/option argument to call(), not to to_matlab().")
    if isinstance(x, np.ndarray):
        a = np.asarray(x, dtype=float)
        if a.ndim == 0:
            return float(a)
        if a.ndim == 1:
            a = a.reshape(1, -1)            # documented: 1-D -> MATLAB row
        return matlab.double(a.tolist())
    if isinstance(x, bool):
        return x
    if isinstance(x, (int, float)):
        return float(x)
    if isinstance(x, str):
        return x
    if isinstance(x, (list, tuple)):
        return matlab.double([float(v) for v in x])
    return x


def from_matlab(x):
    """Marshal a MATLAB-engine return value to plain Python, recursively.

    None        -> None (e.g. an nargout=0 call).
    dict        -> {k: from_matlab(v)}                 (struct / nested struct).
    str/bool/int/float -> passed through                (char scalar, logical scalar).
    list/tuple  -> [from_matlab(v) ...]                 (cell array / nargout > 1).
    DataFrame   -> neutral table-dict                   (a table nested in a struct that
                  the engine natively converted to pandas; keeps it on the same footing
                  as a top-level table -- dict here, DataFrame under frames=True).
    matlab.*    -> np.asarray(x)  (numeric/logical array; shape & NaN/Inf preserved,
                  NO reshape).
    """
    if x is None:
        return None
    if isinstance(x, dict):
        return {k: from_matlab(v) for k, v in x.items()}
    if isinstance(x, str):
        return x
    if isinstance(x, (bool, int, float)):
        return x
    if isinstance(x, (list, tuple)):
        return [from_matlab(v) for v in x]
    if is_dataframe(x):
        # matlab.engine (with pandas) converts a table nested in a returned struct straight
        # to a DataFrame; normalise it to the table-dict so labels survive and frames=True
        # can view it -- otherwise np.asarray below would flatten it to a bare ndarray.
        return dataframe_to_table_dict(x)
    # matlab.double / matlab.logical / matlab.int* and anything array-like.
    try:
        return np.asarray(x)
    except Exception:
        return x


class FsdaEngine:
    """A reusable MATLAB engine session with a generic, routine-agnostic `call`."""

    def __init__(self, eng):
        self.eng = eng

    # --- lifecycle -----------------------------------------------------------
    @classmethod
    def start(cls, routine: str | None = None, fsda_root: str | None = None,
              check_version: bool = True) -> "FsdaEngine":
        """Start a MATLAB engine; optionally verify one FSDA `routine` resolves.

        FSDA is normally a MATLAB Add-On (already on the path), so `fsda_root` can
        be None; pass the FSDA install dir only as a fallback (added with
        addpath(genpath(...))). When `routine` is given and cannot be found, the
        engine is closed and RuntimeError is raised.

        When `check_version` is True (default), a one-off, non-fatal FSDA
        up-to-date check runs once the session is up (see `_check_fsda_version`):
        it is silent when FSDA is current and prints a notice otherwise. Pass
        `check_version=False` for a network-free / hermetic session.
        """
        eng = matlab.engine.start_matlab()
        if fsda_root:
            eng.addpath(eng.genpath(fsda_root), nargout=0)
        if routine and not eng.which(routine):
            eng.quit()
            raise RuntimeError(
                f"FSDA `{routine}` not found on the MATLAB path. Install the FSDA "
                f"Add-On in MATLAB, or pass fsda_root=<FSDA install dir>."
            )
        self = cls(eng)
        if check_version:
            self._check_fsda_version()
        return self

    def stop(self) -> None:
        """Shut the engine session down (startup is slow -- callers control this)."""
        self.eng.quit()

    def _check_fsda_version(self) -> None:
        """Notify, once at session start, if the installed FSDA is not the latest.

        Uses FSDA's own `tuna` utility in its quiet, no-GUI mode
        (`tuna('FSDA','uniprJRC','FSDA','gui',false)`): tuna compares the installed
        version (from the Add-On manager) against the latest GitHub release and
        writes a message to the MATLAB Command Window ONLY when an update is
        available -- so this prints nothing when FSDA is current. No modal dialog
        is shown; a failure to reach GitHub is non-fatal MATLAB-side.

        `tuna` is a recent FSDA utility, so `exist('tuna','file')==0` means FSDA is
        either not installed or too old to self-check -- reported as such. The whole
        check is best-effort: any Python-side failure is swallowed so it can never
        break a session (disable it entirely with `start(check_version=False)`).
        """
        try:
            has_tuna = int(self.eng.eval("double(exist('tuna','file')>0)", nargout=1))
        except Exception:
            return
        if not has_tuna:
            sys.stderr.write("FSDA not found on the MATLAB path, or too old to include "
                             "'tuna' -- FSDA version check skipped.\n")
            sys.stderr.flush()
            return
        out, err = io.StringIO(), io.StringIO()
        try:
            self.eng.eval("tuna('FSDA','uniprJRC','FSDA','gui',false)",
                          nargout=0, stdout=out, stderr=err)
        except Exception:
            return                                    # tuna raised -> stay silent
        msg = out.getvalue() + err.getvalue()
        if msg.strip():                               # current FSDA -> tuna is silent
            sys.stderr.write(msg)
            sys.stderr.flush()

    # --- the generic call ----------------------------------------------------
    def call(self, name: str, *args, nargout: int = 1, echo_output: bool = False,
             options: dict | None = None, frames: bool = False,
             store: str | None = None, **kwargs):
        """Call FSDA function `name` generically and return plain Python.

        Positional `args` are marshalled with `to_matlab` and passed in order.
        Keyword args (and any `options` dict) become MATLAB name/value pairs, in
        the given order -- e.g. ``call("Score", y, X, la=la, intercept=True)``
        sends ``Score(y, X, 'la', la, 'intercept', true)``. FSDA's own ``msg``
        option is just such a kwarg -- ``call("FSR", y, X, msg=0)`` forwards it to
        MATLAB (it is NOT consumed by the bridge).

        nargout     : number of outputs to request (default 1).
        echo_output : when True, route MATLAB's stdout/stderr to this terminal (the
                      engine needs io.StringIO buffers, so capture then echo). This
                      is the bridge's OWN tee, named so it cannot clash with an FSDA
                      option; it does not change what FSDA prints, only whether an
                      embedded host (reticulate / PythonCall) surfaces it.
        frames      : when True, table/timetable outputs (the dict returned by
                      `_table_to_dict`) are returned as a `pandas.DataFrame` instead
                      -- an opt-in Python-only view; the dict is still the default and
                      the cross-language contract (needs `pip install pyfsda[pandas]`).

        A `pandas.DataFrame` passed as a positional/option argument is marshalled to a
        MATLAB `table` (see `_df_to_table_var`), independent of the `frames` flag.

        Execution runs through the MATLAB workspace so outputs the engine cannot
        return directly -- a **table / timetable** -- can be decomposed MATLAB-side
        into a Python dict (see `_table_to_dict`); numeric/struct/char outputs cross
        exactly as before. A returned table -> dict has keys ``VariableNames``,
        ``RowNames`` (or ISO ``RowTimes`` for a timetable), and ``data`` (column ->
        ndarray / list[str]).
        """
        if not _IDENT_RE.match(name):
            raise ValueError(f"unsafe / malformed function name: {name!r}")
        pairs = dict(options or {})
        pairs.update(kwargs)
        for key in pairs:
            if not _IDENT_RE.match(str(key)):
                raise ValueError(f"unsafe / malformed option name: {key!r}")

        in_names, opt_tokens, temp = [], [], []
        for i, a in enumerate(args):
            if isinstance(a, WorkspaceRef):
                in_names.append(a.name)    # Already in MATLAB workspace
            else:
                vn = f"fe_in{i}"
                self._set_input_var(a, vn)            # dict->struct / DataFrame->table / array / ...
                in_names.append(vn)
                temp.append(vn)
        for key, value in pairs.items():
            if isinstance(value, WorkspaceRef):
                opt_tokens.append(f"'{key}',{value.name}")
            else:
                vn = f"fe_opt_{key}"
                self._set_input_var(value, vn)        # option value (may itself be a struct/table)
                opt_tokens.append(f"'{key}',{vn}")   # 'name', tempvar
                temp.append(vn)

        if store is not None:
            if not _IDENT_RE.match(store):
                raise ValueError(f"unsafe / malformed store name: {store!r}")
            out_names = [store if j == 0 else f"{store}_{j}" for j in range(nargout)]
            # refs should not be added to temp, to prevent automatic cleanup
        else:
            out_names = [f"fe_out{j}" for j in range(nargout)]
            temp.extend(out_names)

        rhs = ",".join(in_names + opt_tokens)
        if nargout == 0:
            cmd = f"{name}({rhs});"
        elif nargout == 1:
            cmd = f"{out_names[0]} = {name}({rhs});"
        else:
            cmd = f"[{','.join(out_names)}] = {name}({rhs});"

        try:
            self._eval_cmd(cmd, echo_output)
            if nargout == 0:
                return None
            if store is not None:
                refs = [WorkspaceRef(vn) for vn in out_names]
                return refs[0] if nargout == 1 else tuple(refs)
            results = [self._marshal_var(vn) for vn in out_names]
        finally:
            self._clear(temp)
        if frames:                                # opt-in: table-dicts -> DataFrames
            results = [apply_frames(r) for r in results]
        return results[0] if nargout == 1 else tuple(results)

    def eval(self, expr: str, nargout: int = 1):
        """Evaluate a MATLAB expression and marshal the result back generically.

        Handy for building/reading values the function `call` surface does not cover
        (e.g. a constructed nested struct, or a table). nargout=0 returns None. For
        nargout==1 the value is bound to a workspace temp first, so a table/timetable
        expression decomposes through the same path as `call`.
        """
        if nargout == 0:
            self.eng.eval(expr, nargout=0)
            return None
        if nargout == 1:
            vn = "fe_eval0"
            try:
                self.eng.eval(f"{vn} = ({expr});", nargout=0)
                return self._marshal_var(vn)
            finally:
                self._clear([vn])
        return from_matlab(self.eng.eval(expr, nargout=nargout))

    # --- workspace execution helpers -----------------------------------------
    def _eval_cmd(self, cmd: str, echo_output: bool = False) -> None:
        """Run a MATLAB statement, optionally tee-ing its stdout/stderr (see call())."""
        if echo_output:
            out_buf, err_buf = io.StringIO(), io.StringIO()
            self.eng.eval(cmd, nargout=0, stdout=out_buf, stderr=err_buf)
            if out_buf.getvalue():
                sys.stdout.write(out_buf.getvalue())
                sys.stdout.flush()          # surface under reticulate / PythonCall too
            if err_buf.getvalue():
                sys.stderr.write(err_buf.getvalue())
                sys.stderr.flush()
        else:
            self.eng.eval(cmd, nargout=0)

    def _clear(self, names: list) -> None:
        """Remove the bridge's `fe_*` temp variables from the MATLAB workspace."""
        if names:
            self.eng.eval("clear " + " ".join(names), nargout=0)

    def _marshal_var(self, vn: str):
        """Marshal one workspace variable. table/timetable -> dict (decomposed
        MATLAB-side); a 2-D cell -> nested list (the engine only returns 1-D cells);
        otherwise read it out and pass through `from_matlab`. If that direct read
        fails (e.g. a struct containing a field the engine cannot convert), fall back
        to decomposing the struct/cell field-by-field MATLAB-side."""
        if int(self.eng.eval(f"double(istable({vn})||istimetable({vn}))", nargout=1)):
            return self._table_to_dict(vn)
        if int(self.eng.eval(
                f"double(iscell({vn}) && ~isrow({vn}) && ~iscolumn({vn}))", nargout=1)):
            return self._marshal_cell2d(vn)        # M x N cell: engine can't return it
        try:
            return from_matlab(self.eng.workspace[vn])
        except Exception:
            if int(self.eng.eval(f"double(isstruct({vn}))", nargout=1)):
                return self._marshal_struct(vn)
            if int(self.eng.eval(f"double(iscell({vn}))", nargout=1)):
                return self._marshal_cell2d(vn)
            raise

    def _marshal_struct(self, vn: str) -> dict:
        """Decompose a struct field-by-field MATLAB-side (used when the engine cannot
        eagerly convert the whole struct -- e.g. it holds a 2-D cell or table field).
        Each field is routed back through `_marshal_var`, so tables/2-D cells/nested
        structs are handled recursively. The function ran once already; this only
        re-reads its result carefully."""
        fields = _cellstr_list(self.eng.eval(f"fieldnames({vn})", nargout=1))
        out = {}
        for f in fields:
            if not _IDENT_RE.match(f):             # fieldnames are valid idents; guard anyway
                raise ValueError(f"unsafe struct field name: {f!r}")
            self.eng.eval(f"fe_fld = {vn}.{f};", nargout=0)
            try:
                out[f] = self._marshal_var("fe_fld")
            finally:
                self._clear(["fe_fld"])
        return out

    def _marshal_cell2d(self, vn: str) -> list:
        """Decompose an M x N MATLAB cell into a nested Python list (the engine only
        returns 1-by-N / M-by-1 cells). Each element is read by index and routed
        through `_marshal_var`, so cells of matrices / structs / tables all cross."""
        m = int(self.eng.eval(f"double(size({vn},1))", nargout=1))
        n = int(self.eng.eval(f"double(size({vn},2))", nargout=1))
        rows = []
        for i in range(1, m + 1):
            row = []
            for j in range(1, n + 1):
                self.eng.eval(f"fe_cel = {vn}{{{i},{j}}};", nargout=0)
                try:
                    row.append(self._marshal_var("fe_cel"))
                finally:
                    self._clear(["fe_cel"])
            rows.append(row)
        return rows

    def _table_to_dict(self, vn: str) -> dict:
        """Decompose a MATLAB table/timetable workspace var into a Python dict.

        Columns are read by **index** (`T{:,j}`), never by interpolating their names,
        so a column name can be anything without risk. Numeric/logical columns become
        ndarrays (single columns flattened to 1-D); other columns (categorical /
        string / cellstr) become list[str].
        """
        is_tt = int(self.eng.eval(f"double(istimetable({vn}))", nargout=1))
        varnames = _cellstr_list(self.eng.eval(f"{vn}.Properties.VariableNames", nargout=1))
        height = int(self.eng.eval(f"double(height({vn}))", nargout=1))

        data = {}
        for j, col in enumerate(varnames, start=1):
            is_num = int(self.eng.eval(
                f"double(isnumeric({vn}{{:,{j}}})||islogical({vn}{{:,{j}}}))", nargout=1))
            if is_num:
                arr = np.asarray(self.eng.eval(f"{vn}{{:,{j}}}", nargout=1), dtype=float)
                data[col] = arr.reshape(-1) if (arr.ndim == 1 or arr.shape[1] == 1) else arr
            else:
                data[col] = _cellstr_list(
                    self.eng.eval(f"cellstr(string({vn}{{:,{j}}}))", nargout=1))

        result = {"VariableNames": varnames, "data": data, "height": height}
        if is_tt:
            result["RowTimes"] = _cellstr_list(
                self.eng.eval(f"cellstr(string({vn}.Properties.RowTimes))", nargout=1))
        else:
            result["RowNames"] = _cellstr_list(
                self.eng.eval(f"{vn}.Properties.RowNames", nargout=1))
        return result

    def _cellstr_to_var(self, values, vn: str, column: bool = False) -> None:
        """Build a MATLAB cellstr in workspace var `vn` from a Python list[str].

        Each element crosses as a char scalar (a supported engine input); the cell is then
        assembled MATLAB-side. Only the bridge's own temp names (`{vn}_e0`, ...) are ever
        interpolated -- never the string CONTENTS -- so column/row labels are injection-safe.

        `column=False` builds a 1 x n **row** cell (what `array2table 'VariableNames'` wants);
        `column=True` builds an n x 1 **column** cell -- the orientation FSDA graphics structs
        use for style fields, e.g. `fground.Color={'b';'g';...}` consumed via
        `set(H,{'Color'},...)` (a row there raises "Size mismatch in Param/Value Cell pair").
        """
        ws = self.eng.workspace
        sep = ";" if column else ","
        elem_vars = []
        try:
            for k, v in enumerate(values):
                ev = f"{vn}_e{k}"
                ws[ev] = str(v)
                elem_vars.append(ev)
            self.eng.eval(f"{vn} = {{{sep.join(elem_vars)}}};", nargout=0)
        finally:
            self._clear(elem_vars)

    def _df_to_table_var(self, df, vn: str) -> None:
        """Assemble a MATLAB `table` in workspace variable `vn` from a pandas DataFrame.

        The inverse of `_table_to_dict`. Column names cross as a MATLAB cell (`fe_varnames`,
        built by `_cellstr_to_var`) and feed `array2table(...,'VariableNames',fe_varnames)`
        -- never string-interpolated. Explicit `VariableNames` are used verbatim (modern
        MATLAB tables allow arbitrary variable-name text). A non-default row index becomes
        the table's `RowNames`.

        v1 supports **numeric / logical** columns only (the common FSDA design-matrix case);
        string / categorical / datetime columns and a MultiIndex raise NotImplementedError,
        consistent with the engine's existing struct-array / datetime limits.
        """
        raw = np.asarray(df.to_numpy())
        if raw.dtype != bool and not np.issubdtype(raw.dtype, np.number):
            raise NotImplementedError(
                "pyfsda: DataFrame -> MATLAB table supports numeric/logical columns only in "
                "v1; string / categorical / datetime columns are not yet marshalled.")
        block = np.asarray(raw, dtype=float)
        if block.ndim != 2:
            block = block.reshape(len(df), -1)

        ws = self.eng.workspace
        ws["fe_block"] = matlab.double(block.tolist())
        temp = ["fe_block", "fe_varnames"]
        try:
            self._cellstr_to_var([str(c) for c in df.columns], "fe_varnames")
            self.eng.eval(
                f"{vn} = array2table(fe_block,'VariableNames',fe_varnames);", nargout=0)
            index = list(df.index)
            if index != list(range(len(df))):        # non-default index -> RowNames
                self._cellstr_to_var([str(i) for i in index], "fe_rownames")
                temp.append("fe_rownames")
                self.eng.eval(f"{vn}.Properties.RowNames = fe_rownames;", nargout=0)
        finally:
            self._clear(temp)

    def _set_input_var(self, value, vn: str) -> None:
        """Marshal one Python value into workspace variable `vn` for use as a MATLAB input.

        Handles the container cases the scalar/array `to_matlab` path cannot express, so a
        struct-consuming FSDA routine can be called with plain Python objects:

            dict            -> struct   (recursed; e.g. an FSReda result, or a `databrush`
                                         / `fground` option struct)
            pandas.DataFrame-> table    (see `_df_to_table_var`)
            list/tuple[str] -> cellstr  ({'--','-.',':'})
            list/tuple[num] -> 1 x n double row
            other list/tuple-> cell     (mixed / nested, recursed)
            everything else -> `to_matlab` (ndarray, number, str, bool, matlab.* passthrough)
        """
        if isinstance(value, dict):
            self._dict_to_struct_var(value, vn)
        elif is_dataframe(value):
            self._df_to_table_var(value, vn)
        elif isinstance(value, (list, tuple)):
            seq = list(value)
            if seq and all(isinstance(e, str) for e in seq):
                self._cellstr_to_var(seq, vn, column=True)          # n x 1 cell of char (FSDA style)
            elif all(isinstance(e, (int, float)) and not isinstance(e, bool) for e in seq):
                self.eng.workspace[vn] = to_matlab(seq)             # numeric row (or [] if empty)
            else:
                self._list_to_cell_var(seq, vn)                     # general cell
        else:
            self.eng.workspace[vn] = to_matlab(value)

    def _list_to_cell_var(self, seq, vn: str) -> None:
        """Build a MATLAB row cell in `vn` from a Python list of arbitrary values (recursed)."""
        elem_vars = []
        try:
            for k, v in enumerate(seq):
                ev = f"{vn}_c{k}"
                self._set_input_var(v, ev)
                elem_vars.append(ev)
            self.eng.eval(f"{vn} = {{{','.join(elem_vars)}}};", nargout=0)
        finally:
            self._clear(elem_vars)

    def _dict_to_struct_var(self, d: dict, vn: str) -> None:
        """Assemble a MATLAB struct in workspace variable `vn` from a Python dict.

        The inverse of the struct -> dict output path: each field value is marshalled with
        `_set_input_var` (nested dict -> struct, list[str] -> cellstr, ndarray -> double,
        ...), then assigned by field name. Field names are validated against `_IDENT_RE` and
        only the bridge's own temp names are interpolated -- field VALUES never are. This is
        what lets an FSReda result dict cross back as a struct that e.g. `resfwdplot` accepts.
        """
        self.eng.eval(f"{vn} = struct();", nargout=0)
        for field, value in d.items():
            if not _IDENT_RE.match(str(field)):
                raise ValueError(f"unsafe / malformed struct field name: {field!r}")
            fv = f"{vn}_f"
            try:
                self._set_input_var(value, fv)
                self.eng.eval(f"{vn}.{field} = {fv};", nargout=0)
            finally:
                self._clear([fv])

    # --- diagnostics ---------------------------------------------------------
    def which(self, name: str) -> str:
        """Resolved path of FSDA function `name` (empty str if not found)."""
        return str(self.eng.which(name))

    def version(self) -> str:
        """MATLAB version string."""
        return str(self.eng.version())

    # --- figures (parity with the per-routine bridges) -----------------------
    def render_figures(self) -> None:
        """Force any open MATLAB figures to paint."""
        self.eng.eval("drawnow", nargout=0)

    def wait_for_figures(self) -> None:
        """Block until the user closes all open MATLAB figures.

        Driven entirely MATLAB-side (uiwait), so it is immune to the terminal-stdin
        interference seen when the engine is embedded via reticulate / PythonCall.
        Returns immediately if no figures are open.
        """
        self.eng.eval(
            "drawnow; "
            "fh = findall(groot, 'Type', 'figure'); "
            "while ~isempty(fh); uiwait(fh(1)); "
            "fh = findall(groot, 'Type', 'figure'); end",
            nargout=0,
        )

    def fetch(self, ref, *, frames=False):
        name = ref.name if isinstance(ref, WorkspaceRef) else ref
        if not _REF_RE.match(name):
            raise ValueError(f"unsafe / malformed variable name: {name!r}")
        if "." in name:
            tmp = "fe_fetch_tmp"
            self.eng.eval(f"{tmp} = {name};", nargout=0)
            try:
                result = self._marshal_var(tmp)
            finally:
                self._clear([tmp])
        else:
            result = self._marshal_var(name)
        if frames:
            result = apply_frames(result)
        return result

    def clear(self, *refs):
        """Remove stored workspace variables.

        Public wrapper around private _clear() method. Adds injection validation
        and accepts both WorkspaceRef or plain strings
        """
        names = [r.name if isinstance(r, WorkspaceRef) else r for r in refs]
        for n in names:
            if not _IDENT_RE.match(n):
                raise ValueError(f"unsafe / malformed variable name: {n!r}")
        self._clear(names)
