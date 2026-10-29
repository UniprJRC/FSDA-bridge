# Generic Layer-2 Julia surface for the shared FSDA engine (spec 017).
#
# The actual MATLAB/FSDA call stays in the Python engine (code/fsda_engine/engine.py,
# class FsdaEngine); this file owns PythonCall setup and delegates a *routine-agnostic*
# `call(handle, name, args...; kwargs...)` straight to the Python `FsdaEngine.call`.
# Unlike the per-target bridge.jl files (one wrapper per routine), this works for ANY
# FSDA function. PythonCall does NOT auto-convert, so it adds the one genuinely new
# piece: a recursive `_py2jl` converter for arbitrary nested dict / array / list / str /
# table results.

# --- Locate this file's directory (engine.py must sit next to it) ------------
const _ENGINE_DIR = let
    here = @__DIR__
    if isfile(joinpath(here, "engine.py"))
        abspath(here)
    else
        wd = pwd()
        candidates = [wd, joinpath(wd, "code", "fsda_engine")]
        idx = findfirst(c -> isfile(joinpath(c, "engine.py")), candidates)
        idx === nothing && error(
            "Cannot locate code/fsda_engine/engine.py next to engine.jl or under the " *
            "working directory; run from the repo or the engine directory.")
        abspath(candidates[idx])
    end
end


using PythonCall

const _PYTHONCALL_VERSION = try
    string(pkgversion(PythonCall))
catch
    "n/a"
end

const _np = PythonCall.pynew()
const _builtins = PythonCall.pynew()
const _PY_READY = Ref(false)

# Controls state of py modules import, and lazy loads on  on the first use
function _ensure_python!()
    _PY_READY[] && return nothing
    np = pyimport("numpy")
    builtins = pyimport("builtins")
    PythonCall.pycopy!(_np, np)
    PythonCall.pycopy!(_builtins, builtins)
    _PY_READY[] = true
    return nothing
end

# --- Opaque handle -----------------------------------------------------------
struct FsdaEngineHandle
    module_::Py     # imported Python `engine` module
    engine::Py      # live FsdaEngine instance (wraps a matlab.engine session)
    engine_dir::String
end

# --- Converters --------------------------------------------------------------
# Julia -> Python input: the inverse of _py2jl below. Numeric arrays become numpy
# (so engine.to_matlab marshals them); Dicts become Python dicts, which the MATLAB
# engine accepts as structs; non-numeric or mixed arrays become Python lists, which
# it accepts as cell arrays; scalars / strings / bools cross via PythonCall.
function _to_py(a)
    if a === nothing
        # No silent conversion: nothing and [] mean different things, so let
        # matlabengine raise its own error rather than guessing an empty array.
        @warn "passing `nothing` to MATLAB is not supported; matlabengine will reject it"
        return Py(a)
    elseif a isa AbstractDict
        # A Python dict reaches the workspace without engine.py's to_matlab
        # touching it: to_matlab has no dict branch, so it falls through, and
        # matlabengine accepts a plain dict as a struct. Worth knowing if an
        # incompatibility ever needs tracing back.
        d = _builtins.dict()
        for (k, v) in a
            d[string(k)] = _to_py(v)
        end
        return d
    elseif a isa AbstractArray
        if eltype(a) <: Number
            return _np.asarray(Py(a))
        end
        lst = _builtins.list()
        for el in a
            lst.append(_to_py(el))
        end
        return lst
    elseif a isa Tuple
        lst = _builtins.list()
        for el in a
            lst.append(_to_py(el))
        end
        return lst
    else
        return Py(a)
    end
end

# Python -> Julia output: recurse through the generic shapes engine.py returns.
function _py2jl(x)
    x isa Py || return x
    if pyisinstance(x, _builtins.dict)
        d = Dict{String,Any}()
        for k in x
            d[pyconvert(String, k)] = _py2jl(x[k])
        end
        return d
    elseif pyisinstance(x, _np.ndarray)
        return pyconvert(Array, x)
    elseif pyisinstance(x, _builtins.list) || pyisinstance(x, _builtins.tuple)
        return Any[_py2jl(el) for el in x]
    elseif pyisinstance(x, _builtins.str)
        return pyconvert(String, x)
    elseif pyisinstance(x, _builtins.bool)
        return pyconvert(Bool, x)
    else
        return pyconvert(Any, x)
    end
end

function _validate_handle(h)
    (h isa FsdaEngineHandle) || error("handle must be the object returned by start_engine().")
end

# --- Lifecycle ---------------------------------------------------------------
"""
    start_engine(; fsda_root = nothing, routine = nothing)

Start a MATLAB session with FSDA and return a handle to it, for use with
`call(handle, name, ...)`, `eval_expr(handle, expr)`, [`diagnostics`](@ref) and
`stop_engine(handle)`.

This session is separate from the one the routine functions start automatically:
`stop_engine()` does not stop it, and `call(name, ...)` does not use it.

# Keywords
- `fsda_root`: FSDA's install folder, needed only if FSDA is not installed as a
  MATLAB Add-On.
- `routine`: an FSDA function name to look up at start; if MATLAB cannot find it,
  the session is closed and an error is raised.

On start, a notice is printed if a newer FSDA release is available.
"""
function start_engine(; routine = nothing, fsda_root = nothing)
    _ensure_python!()

    sys = pyimport("sys")
    while pyconvert(Bool, sys.path.__contains__(_ENGINE_DIR))
        sys.path.remove(_ENGINE_DIR)
    end
    sys.path.insert(0, _ENGINE_DIR)
    sys.modules.pop("engine", nothing)     # fresh import of this dir's engine.py
    module_ = pyimport("engine")

    rt = routine === nothing ? nothing : String(routine)
    fr = (fsda_root === nothing || isempty(String(fsda_root))) ? nothing : String(fsda_root)
    engine = module_.FsdaEngine.start(rt, fr)
    return FsdaEngineHandle(module_, engine, _ENGINE_DIR)
end

# Arguments and return values are documented on call(name, ...) in FSDABridge.jl;
# update that docstring if this method's behaviour changes.
"""
    call(handle, name, args...; kwargs...)

Same as `call(name, ...)`, but runs in the session `handle` returned by
[`start_engine`](@ref).
Arguments, keywords and return values are as documented there.
"""
function call(handle, name, args...; nargout::Integer = 1, echo_output::Bool = false,
              options = nothing, kwargs...)
    _validate_handle(handle)
    _ensure_python!()
    pyargs = Py[_to_py(a) for a in args]
    conv = (; (k => _to_py(v) for (k, v) in kwargs)...)   # convert kwarg values to py
    res = handle.engine.call(name, pyargs...;
                             nargout = nargout, echo_output = echo_output,
                             options = options, conv...)
    return _py2jl(res)
end

# Arguments and return values are documented on eval_expr(expr) in FSDABridge.jl;
# update that docstring if this method's behaviour changes.
"""
    eval_expr(handle, expr; nargout = 1)

Same as `eval_expr(expr)`, but runs in the session `handle` returned by
[`start_engine`](@ref).
"""
function eval_expr(handle, expr; nargout::Integer = 1)
    _validate_handle(handle)
    _ensure_python!()
    return _py2jl(handle.engine.eval(expr; nargout = nargout))
end

render_figures(handle) = (_validate_handle(handle); handle.engine.render_figures(); nothing)
wait_for_figures(handle) = (_validate_handle(handle); handle.engine.wait_for_figures(); nothing)
stop_engine(handle) = (_validate_handle(handle); handle.engine.stop(); nothing)

"""
    diagnostics(handle) -> NamedTuple

Report the versions in use for the session `handle` returned by
[`start_engine`](@ref): Julia, PythonCall, the Python interpreter and its version,
MATLAB, and `matlabengine`. Useful when reporting a problem.
"""
function diagnostics(handle)
    _validate_handle(handle)
    _ensure_python!()
    sys = pyimport("sys")
    metadata = pyimport("importlib.metadata")
    engine_pkg = try
        pyconvert(String, metadata.version("matlabengine"))
    catch
        "n/a"
    end
    return (
        julia = string(VERSION),
        pythoncall = _PYTHONCALL_VERSION,
        python = pyconvert(String, sys.executable),
        python_version = pyconvert(String, pyimport("platform").python_version()),
        matlab = pyconvert(String, handle.engine.version()),
        matlabengine = engine_pkg,
        engine_dir = handle.engine_dir,
    )
end
