using FSDABridge
using Test
using LinearAlgebra

@testset "FSDABridge.jl" begin
    @testset "API is exported" begin
        for f in (:start_engine, :stop_engine, :call, :eval_expr, :diagnostics,
                  :render_figures, :wait_for_figures, :mahalFS, :FSR, :tclust)
            @test f in names(FSDABridge)
        end
    end

    @testset "no method ambiguities" begin
        @test isempty(Test.detect_ambiguities(FSDABridge))
    end

    # Needs MATLAB + FSDA + matlabengine: FSDA_INTEGRATION=true to run
    if get(ENV, "FSDA_INTEGRATION", "false") == "true"
        @testset "MATLAB integration" begin

            # Test that a function call reaches MATLAB, and that the values
            # come back correctly. The test is based on the mahalFS FSDA function
            Y = [0.52 -1.10; 1.83 0.14; -0.09 1.53; 0.32 -0.77; 1.10 0.37]
            mu = sum(Y; dims = 1) ./ size(Y, 1)
            sigma = [0.3 0.4; 0.4 1.0]
            ref = [dot(r, sigma \ r) for r in eachrow(Y .- mu)]
            @test isapprox(vec(mahalFS(Y, mu, sigma)), ref; atol = 1e-9)

            # Test return Types of call / eval_expr
            # nargout = 0 gives nothing, several outputs give a Vector,
            # structs and tables give a Dict
            @test call("rng", 1; nargout = 0) === nothing
            sz = call("size", ones(3, 2); nargout = 2)
            @test sz isa Vector && sz == [3.0, 2.0]
            @test eval_expr("struct('a', 1)") isa Dict{String,Any}
            @test eval_expr("table([1;2], 'VariableNames', {'x'})") isa Dict{String,Any}

            # Input shapes, as documented in call: a Julia vector reaches
            # MATLAB as a 1 x n row, an n x 1 matrix stays a column
            @test call("size", [1.0, 2.0, 3.0]; nargout = 2) == [1.0, 3.0]
            @test call("size", reshape([1.0, 2.0, 3.0], :, 1); nargout = 2) == [3.0, 1.0]

            stop_engine()
        end
    else
        @info "MATLAB integration tests skipped: set FSDA_INTEGRATION=true to run them"
    end
end

# test _to_py, _py2jl
include("converters.jl")
