module FSDABridge

const _ENGINE_DIR = joinpath(@__DIR__, "engines") # absolute path to the engine directory

# Load the engine module
include(joinpath(_ENGINE_DIR, "engine.jl"))

const _GLOBAL_ENGINE = Ref{Any}(nothing)

# Zero-argument stop_engine to cleanly shut down the auto-started global engine
"""
    stop_engine()

Shut down the MATLAB session that the routine functions, `call(name, ...)` and
`eval_expr(expr)` start automatically.
If that session is not running, it only prints a message.

To shut down a session started with [`start_engine`](@ref), pass its handle:
`stop_engine(handle)`.
"""
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
"""
    call(name, args...; nargout = 1, echo_output = false, kwargs...)

Call the FSDA or MATLAB function `name`, starting the MATLAB session on first use.
Positional arguments are passed in order; keyword arguments become MATLAB
name-value pairs. Pass a response `y` as an `n x 1` matrix (`y[:, 1:1]`, not
`y[:, 1]`) when a routine expects a column: a Julia vector reaches MATLAB as a row.

# Keywords
- `nargout`: how many outputs to request. With more than one, the outputs come back
  as a vector; with `nargout = 0`, `nothing` is returned.
- `echo_output`: if `true`, MATLAB's console output is printed.

# Examples
```julia
out = call("FSR", y, X; plots = 0, msg = 0)
call("rng", 1234; nargout = 0)
```

Structs come back as `Dict{String,Any}`, numeric arrays as Julia arrays.
To use a session started with [`start_engine`](@ref), pass its handle first:
`call(handle, name, ...)`.
"""
call(name::AbstractString, args...; kwargs...) =
    call(_engine(), name, args...; kwargs...)

"""
    eval_expr(expr; nargout = 1)

Evaluate the MATLAB expression `expr` and return its result, starting the MATLAB
session on first use. With the default `nargout = 1`, a MATLAB table comes back
as a `Dict`. Useful when [`call`](@ref) is not enough. 

# Examples
```julia
Y = eval_expr("table2array(getfield(load('geyser2.mat'),'geyser2'))")
```

To use a session started with [`start_engine`](@ref), pass its handle first:
`eval_expr(handle, expr)`.
"""
eval_expr(expr::AbstractString; nargout::Integer = 1) =
    eval_expr(_engine(), expr; nargout = nargout)

"""
    render_figures()

Update open MATLAB figures and process pending callbacks (using MATLAB's `drawnow`),
so that plots appear while the script keeps running.

A session started with [`start_engine`](@ref) takes its handle:
`render_figures(handle)`.
"""
render_figures() = render_figures(_engine())

"""
    wait_for_figures()

Draw any open MATLAB figures, then wait until the user has closed all of them.
Returns immediately if no figures are open. Use it at the end of a script that
plots, so the figures stay on screen until you close them.

A session started with [`start_engine`](@ref) takes its handle:
`wait_for_figures(handle)`.
"""
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
    name = string(routine)
    doc = """
            $name(args...; kwargs...)

        Call the FSDA routine `$name`; the same as `call("$name", args...; kwargs...)`.
        Arguments and name-value options are those of the MATLAB function, documented
        at https://rosa.unipr.it/FSDA/$name.html
        """
    @eval begin
        @doc $doc function $routine(args...; kwargs...)
            return call(_engine(), $name, args...; kwargs...)
        end
        export $routine
    end
end

end

