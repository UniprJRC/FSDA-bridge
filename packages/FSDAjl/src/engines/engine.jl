# Julia interface that handles Python <-> Julia exchange of information through
# PythonCall. Starts the engine, passes calls to it, handles the conversion to
# Python (_to_py) and marshals the results back to Julia (_py2jl). 

using PythonCall

const _PYTHONCALL_VERSION = try
    string(pkgversion(PythonCall))
catch
    "n/a"
end

const _np = PythonCall.pynew()
const _builtins = PythonCall.pynew()
const _ENGINE_PY = PythonCall.pynew()
const _PY_READY = Ref(false)

# Controls state of py modules import, and lazy loads on the first use
# Fills the handles the converters use. Only needs numpy.
function _ensure_python!()
    _PY_READY[] && return nothing
    np = pyimport("numpy")
    builtins = pyimport("builtins")
    PythonCall.pycopy!(_np, np)
    PythonCall.pycopy!(_builtins, builtins)
    _PY_READY[] = true
    return nothing
end

# Load vendored engine.py with a unique module name
# Needs matlabengine
function _engine_py()
    if PythonCall.pyisnull(_ENGINE_PY)
        util = pyimport("importlib.util")
        name = "fsdabridge_engine"
        spec = util.spec_from_file_location(name, joinpath(_ENGINE_DIR, "engine.py"))
        mod = util.module_from_spec(spec)
        pyimport("sys").modules[name] = mod
        spec.loader.exec_module(mod)
        PythonCall.pycopy!(_ENGINE_PY, mod)
    end
    return _ENGINE_PY
end

# --- Opaque handle -----------------------------------------------------------
struct FsdaEngineHandle
    engine::Py      # live FsdaEngine instance (wraps a matlab.engine session)
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
    engine_mod = try
        _ensure_python!()
        _engine_py()
    catch err
        if err isa PyException
            exe = pyconvert(String, pyimport("sys").executable)
            error("""
            Cannot load the Python components required by FSDABridge using:
                $exe

            Verify that PythonCall is configured to use the correct interpreter
            and that NumPy and a matlabengine compatible with your MATLAB version
            are installed for it.
            See 'Configure PythonCall' in the readme for more information.""")
        else
            rethrow()
        end
    end

    rt = routine === nothing ? nothing : String(routine)
    fr = (fsda_root === nothing || isempty(String(fsda_root))) ? nothing : String(fsda_root)
    engine = engine_mod.FsdaEngine.start(rt, fr)
    return FsdaEngineHandle(engine)
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
        engine_dir = _ENGINE_DIR,
    )
end
