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

# global eval expr
function eval_expr(expr; nargout::Integer = 1)
    if _GLOBAL_ENGINE[] === nothing
        @info "Auto-starting FSDA engine..."
        _GLOBAL_ENGINE[] = start_engine()
    end
    return eval_expr(_GLOBAL_ENGINE[], expr; nargout = nargout)
end


# Re-export the mandatory API
export start_engine, call, eval_expr, stop_engine

const FSDA_ROUTINES = [
    :mahalFS,
    :Score,
    :FSR,
    :FSRaddt,
    :tclust,
    :getYahoo
]

# Generate the facade functions dynamically at compile time
for routine in FSDA_ROUTINES
    @eval begin
        function $routine(args...; kwargs...)
            if _GLOBAL_ENGINE[] === nothing
                @info "Auto-starting FSDA engine..."
                _GLOBAL_ENGINE[] = start_engine()
            end
            return call(_GLOBAL_ENGINE[], $(string(routine)), args...; kwargs...)
        end
        export $routine
    end
end

end

