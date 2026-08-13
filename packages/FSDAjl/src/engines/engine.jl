# Generic Layer-2 Julia surface for the shared FSDA engine (spec 017).
#
# The actual MATLAB/FSDA call stays in the Python engine (code/fsda_engine/engine.py,
# class FsdaEngine); this file owns PythonCall setup and delegates a *routine-agnostic*
# `call(handle, name, args...; kwargs...)` straight to the Python `FsdaEngine.call`.
# Unlike the per-target bridge.jl files (one wrapper per routine), this works for ANY
# FSDA function. PythonCall does NOT auto-convert, so it adds the one genuinely new
# piece: a recursive `_py2jl` converter for arbitrary nested dict / array / list / str /
# table results.
#
# CRITICAL: PythonCall binds its interpreter at load time (`using PythonCall`), so the
# interpreter is resolved and exported via ENV *before* that line.

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

# --- Interpreter resolution (no machine-specific path committed) -------------
function _resolve_python(python::AbstractString)
    p = String(python)
    if isempty(p)
        found = Sys.which("python")
        found === nothing && (found = Sys.which("python3"))
        found === nothing && error(
            "No Python interpreter found. Set FSDA_DEV_VENV to your venv's python " *
            "executable (bin/python on macOS) that has matlabengine installed.")
        return abspath(found)
    end
    isfile(p) && return abspath(p)
    if isdir(p)
        nested = [
            joinpath(p, "python.exe"),
            joinpath(p, "Scripts", "python.exe"),
            joinpath(p, "bin", "python"),
            joinpath(p, "bin", "python3"),
        ]
        idx = findfirst(isfile, nested)
        idx !== nothing && return abspath(nested[idx])
    end
    error("Python venv or executable not found: ", p,
          ". Set FSDA_DEV_VENV to the project venv or a Python executable with matlabengine.")
end

# Resolve the interpreter and pin PythonCall to it BEFORE `using PythonCall`.
const _PYTHON_EXE = _resolve_python(get(ENV, "FSDA_DEV_VENV", ""))
ENV["JULIA_CONDAPKG_BACKEND"] = "Null"
ENV["JULIA_PYTHONCALL_EXE"] = _PYTHON_EXE

using PythonCall

const _PYTHONCALL_VERSION = try
    string(pkgversion(PythonCall))
catch
    "n/a"
end

const _np = PythonCall.pynew()
const _builtins = PythonCall.pynew()

# --- Opaque handle -----------------------------------------------------------
struct FsdaEngineHandle
    module_::Py     # imported Python `engine` module
    engine::Py      # live FsdaEngine instance (wraps a matlab.engine session)
    python::String
    engine_dir::String
end

# --- Converters --------------------------------------------------------------
# Julia -> Python input: arrays become numpy (so engine.to_matlab marshals them);
# scalars / strings / bools cross via PythonCall's own conversion.
_to_py(a) = a isa AbstractArray ? _np.asarray(Py(a)) : Py(a)

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
    start_engine(; routine=nothing, python=ENV["FSDA_DEV_VENV"], fsda_root=nothing)

Import the shared Python `engine` and start a reusable MATLAB engine session, returning
an opaque `FsdaEngineHandle`. PythonCall is already bound to the interpreter resolved at
load time.
"""
function start_engine(; routine = nothing,
                       python::AbstractString = get(ENV, "FSDA_DEV_VENV", ""),
                       fsda_root = nothing)
    requested = isempty(String(python)) ? _PYTHON_EXE : _resolve_python(python)
    if requested != _PYTHON_EXE
        @warn("PythonCall is already bound to a different interpreter; start a fresh " *
              "`julia` process to switch interpreters.", bound = _PYTHON_EXE, requested = requested)
    end

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
    return FsdaEngineHandle(module_, engine, _PYTHON_EXE, _ENGINE_DIR)
end

"""
    call(handle, name, args...; nargout=1, echo_output=false, options=nothing, kwargs...)

Routine-agnostic call: positional `args` -> MATLAB positionals (in order), `kwargs` ->
MATLAB name/value pairs. e.g. `call(h, "mahalFS", Y, MU, SIGMA)` or
`call(h, "Score", y, X; la=la, intercept=true)`. Pass `y` as an (n, 1) matrix when a
routine wants a column. Arbitrary nested dict / array / table results are converted to
Julia by `_py2jl`.
"""
function call(handle, name, args...; nargout::Integer = 1, echo_output::Bool = false,
              options = nothing, kwargs...)
    _validate_handle(handle)
    pyargs = Py[_to_py(a) for a in args]
    conv = (; (k => _to_py(v) for (k, v) in kwargs)...)   # convert kwarg values to py
    res = handle.engine.call(name, pyargs...;
                             nargout = nargout, echo_output = echo_output,
                             options = options, conv...)
    return _py2jl(res)
end

"""
    eval_expr(handle, expr; nargout=1)

Evaluate a MATLAB expression through the engine (table/timetable aware).
"""
function eval_expr(handle, expr; nargout::Integer = 1)
    _validate_handle(handle)
    return _py2jl(handle.engine.eval(expr; nargout = nargout))
end

render_figures(handle) = (_validate_handle(handle); handle.engine.render_figures(); nothing)
wait_for_figures(handle) = (_validate_handle(handle); handle.engine.wait_for_figures(); nothing)
stop_engine(handle) = (_validate_handle(handle); handle.engine.stop(); nothing)

"""
    diagnostics(handle) -> NamedTuple

Julia / PythonCall / Python / MATLAB / matlabengine details.
"""
function diagnostics(handle)
    _validate_handle(handle)
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
        requested_python = handle.python,
    )
end
