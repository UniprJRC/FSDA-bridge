module FSDA

const _ENGINE_DIR = joinpath(@__DIR__, "engines") # absolute path to the engine directory

# Load the engine module
include(joinpath(_ENGINE_DIR, "engine.jl"))

# CondaPkg guard
function __init__()
    conda_backend = get(ENV, "JULIA_CONDAPKG_BACKEND", "unset")
    if conda_backend != "Null"
        @warn """
        JULIA_CONDAPKG_BACKEND is set to '$(conda_backend)' (expected 'Null').
        PythonCall has likely already provisioned its own Python via Conda, 
        which will NOT include the matlabengine.
        
        To prevent this on your next run, set the environment variable before starting Julia:
        - Mac/Linux:        export JULIA_CONDAPKG_BACKEND=Null
        - Windows (CMD):    set JULIA_CONDAPKG_BACKEND=Null
        - Windows (PS):     \$env:JULIA_CONDAPKG_BACKEND="Null"
        """
    end
end


const _GLOBAL_ENGINE = Ref{Any}(nothing)

# Zero-argument stop_engine to cleanly shut down the auto-started global engine
function stop_engine()
    if _GLOBAL_ENGINE[] !== nothing
        stop_engine(_GLOBAL_ENGINE[]) # Calls the 1-arg method from engine.jl
        _GLOBAL_ENGINE[] = nothing
        @info "Global FSDA engine stopped."
    else
        @info "No global engine is currently running."
    end
end

# Return the global engine, starting it if it is not running yet.
function _engine()
    if _GLOBAL_ENGINE[] === nothing
        @info "Auto-starting FSDA engine..."
        _GLOBAL_ENGINE[] = start_engine()
    end
    return _GLOBAL_ENGINE[]
end

# Global forms: reach MATLAB through the auto-started engine, so scripts do not
# have to manage a handle alongside the facade functions.
call(name::AbstractString, args...; kwargs...) =
    call(_engine(), name, args...; kwargs...)

eval_expr(expr::AbstractString; nargout::Integer = 1) =
    eval_expr(_engine(), expr; nargout = nargout)

render_figures() = render_figures(_engine())

wait_for_figures() = wait_for_figures(_engine())


# Re-export the mandatory API
export start_engine, call, eval_expr, render_figures, wait_for_figures, diagnostics, stop_engine

const FSDA_ROUTINES = [
    :mahalFS,
    :Score,
    :FSR,
    :FSRaddt,
    :tclust,
    :getYahoo,
    :unibiv,
    :LXS,
    :MMreg,
    :FSM,
    :FSMeda,
    :mcd,
    :FSRfan,
    :tkmeans,
    :yXplot,
    :malfwdplot,
    :boxplotb
]

# Generate the facade functions dynamically at compile time

for routine in FSDA_ROUTINES
    @eval begin
        function $routine(args...; kwargs...)
            return call(_engine(), $(string(routine)), args...; kwargs...)
        end
        export $routine
    end
end

end

