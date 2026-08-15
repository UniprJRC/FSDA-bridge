module FSDA

const _ENGINE_DIR = joinpath(@__DIR__, "engines")# absolute path to the engine directory

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

# Re-export the mandatory API
export start_engine, call, eval_expr, stop_engine

end
