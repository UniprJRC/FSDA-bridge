"""Optional pandas view over FSDA table/timetable results -- Python codepath only.

The generic engine returns a MATLAB ``table``/``timetable`` as a neutral dict
``{VariableNames, RowNames/RowTimes, data, height}`` (see ``engine._table_to_dict``). That
dict is the cross-language interchange format (R / Julia rely on it) and stays the default.
This module layers an *opt-in* pandas view on the Python side:

    * ``to_dataframe(table_dict)`` -- build a ``pandas.DataFrame`` from the dict.
    * ``apply_frames(obj)``       -- recurse through a result, converting every table-dict.
    * ``is_table_dict(obj)``      -- recognise the dict shape.
    * ``is_dataframe(x)``         -- recognise a pandas DataFrame WITHOUT importing pandas.

pandas is an optional dependency: it is imported lazily, only when a table actually crosses
(``to_dataframe``). ``is_dataframe`` is duck-typed so the input path never imports pandas.
Install the extra with ``pip install pyfsda[pandas]``.
"""
from __future__ import annotations

_PANDAS_HINT = (
    "pandas is required for this feature; install it with `pip install pyfsda[pandas]` "
    "(or `pip install pandas`)."
)


def _require_pandas():
    """Import pandas lazily, raising a clear, actionable error if it is missing."""
    try:
        import pandas as pd
    except ImportError as exc:                      # pragma: no cover - trivial guard
        raise ImportError(_PANDAS_HINT) from exc
    return pd


def is_table_dict(obj) -> bool:
    """True if ``obj`` is a table/timetable dict emitted by ``engine._table_to_dict``."""
    return (
        isinstance(obj, dict)
        and "VariableNames" in obj
        and "data" in obj
        and ("RowNames" in obj or "RowTimes" in obj)
    )


def is_dataframe(x) -> bool:
    """True if ``x`` is a pandas DataFrame -- duck-typed, so pandas is never imported here."""
    cls = type(x)
    return cls.__name__ == "DataFrame" and cls.__module__.split(".", 1)[0] == "pandas"


def to_dataframe(table_dict):
    """Build a ``pandas.DataFrame`` from a table/timetable dict.

    Columns follow ``VariableNames`` order; the index comes from ``RowTimes`` (parsed to a
    DatetimeIndex when possible, else kept as strings) for a timetable, or from non-empty
    ``RowNames`` for a table; otherwise the default RangeIndex is used.
    """
    if not is_table_dict(table_dict):
        raise TypeError("to_dataframe expects a table/timetable dict "
                        "{VariableNames, data, RowNames/RowTimes, ...}.")
    pd = _require_pandas()
    names = list(table_dict["VariableNames"])
    data = table_dict["data"]
    df = pd.DataFrame({col: data[col] for col in names}, columns=names)

    row_times = table_dict.get("RowTimes")
    row_names = table_dict.get("RowNames")
    if row_times:
        try:
            df.index = pd.to_datetime(list(row_times))
        except (ValueError, TypeError):
            df.index = list(row_times)
    elif row_names:
        df.index = list(row_names)
    return df


def dataframe_to_table_dict(df) -> dict:
    """Convert a ``pandas.DataFrame`` to the neutral table-dict shape (inverse of
    ``to_dataframe``): ``{VariableNames, RowNames, data, height}``.

    Used when a table arrives already as a DataFrame -- e.g. ``matlab.engine`` natively
    converts a table nested inside a returned struct to a DataFrame. Normalising it to the
    table-dict keeps a nested table on the same footing as a top-level one (dict by default,
    ``pandas.DataFrame`` under ``frames=True``), so labels are never silently dropped. Reads
    only the DataFrame's own attributes -- no ``import pandas`` needed here.

    A default ``RangeIndex(0..n-1)`` becomes an empty ``RowNames`` (unlabelled table);
    any other index is kept as string row labels.
    """
    columns = [str(c) for c in df.columns]
    data = {str(c): df[c].to_numpy() for c in df.columns}
    index = list(df.index)
    default = index == list(range(len(df)))
    return {
        "VariableNames": columns,
        "RowNames": [] if default else [str(i) for i in index],
        "data": data,
        "height": len(df),
    }


def apply_frames(obj):
    """Recurse through a marshalled result, converting every table-dict to a DataFrame.

    Handles a bare table-dict, a ``nargout > 1`` tuple/list, and a struct dict that holds
    table-dict fields. Non-table values are returned unchanged.
    """
    if is_table_dict(obj):
        return to_dataframe(obj)
    if isinstance(obj, dict):
        return {k: apply_frames(v) for k, v in obj.items()}
    if isinstance(obj, tuple):
        return tuple(apply_frames(v) for v in obj)
    if isinstance(obj, list):
        return [apply_frames(v) for v in obj]
    return obj
