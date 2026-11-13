# Tests the converters on julia side
# require python and numpy
using PythonCall

const B = FSDABridge
B._ensure_python!()
const np = pyimport("numpy")

isnd(p) = pyisinstance(p, np.ndarray)
pyshape(p) = pyconvert(Tuple, p.shape)

@testset "Julia converters" begin
    @testset "_to_py: ndarray order and values" begin
        A = [1.0 2.0 3.0; 4.0 5.0 6.0]
        cases = (
            "Matrix" => (A, [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]),
            "adjoint" => (A', [[1.0, 4.0], [2.0, 5.0], [3.0, 6.0]]),
            "strided view" => (view(A, :, 1:2:3), [[1.0, 3.0], [4.0, 6.0]]),
        )
        @testset "$label" for (label, (x, rows)) in cases
            p = B._to_py(x)
            @test isnd(p)
            @test pyconvert(Vector{Vector{Float64}}, p.tolist()) == rows
        end

        T = [1.0 3.0 5.0; 7.0 9.0 11.0;;; 2.0 4.0 6.0; 8.0 10.0 12.0]   # 2 x 3 x 2
        p3 = B._to_py(T)
        @test isnd(p3)
        @test pyconvert(Vector{Vector{Vector{Float64}}}, p3.tolist()) ==
              [[[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]],
            [[7.0, 8.0], [9.0, 10.0], [11.0, 12.0]]]

        mask = B._to_py(BitVector([1, 0]))
        @test isnd(mask)
        @test pyconvert(String, mask.dtype.name) == "bool"
        @test pyconvert(Vector{Bool}, mask.tolist()) == [true, false]
    end

    @testset "_to_py: array shape" begin
        @test pyshape(B._to_py([1.0, 2.0, 3.0])) == (3,)
        m = [1.0 2.0; 3.0 4.0; 5.0 6.0]
        @test pyshape(B._to_py(m[:, 1:1])) == (3, 1)
        @test pyshape(B._to_py([1.0 2.0 3.0])) == (1, 3)
    end

    @testset "_to_py: non numeric arrays" begin
        p = B._to_py(["a", "b"])
        @test pyisinstance(p, pybuiltins.list)
        @test pyconvert(Vector{String}, p) == ["a", "b"]

        # Broken: an array whose eltype is not <: Number is flattened to a 1-D list.
        col = Union{Missing,Float64}[1.0; 2.0; 3.0;;]
        @test_broken isnd(B._to_py(col)) && pyshape(B._to_py(col)) == (3, 1)
        @test_broken pyconvert(Vector{Vector{String}}, B._to_py(["a" "b"; "c" "d"])) == [["a", "b"], ["c", "d"]]
    end

    @testset "_to_py: Dicts" begin
        p = B._to_py(Dict(:opt => 1.0, :sub => Dict("w" => [1.0, 2.0], "name" => "x")))
        @test pyisinstance(p, pybuiltins.dict)
        @test all(k -> pyisinstance(k, pybuiltins.str), p)
        sub = p["sub"]
        @test pyisinstance(sub, pybuiltins.dict)
        @test isnd(sub["w"])
        @test pyconvert(Vector{Float64}, sub["w"].tolist()) == [1.0, 2.0]
        @test pyisinstance(sub["name"], pybuiltins.str)
    end

    @testset "_to_py: nothing warns, becomes None" begin
        p = @test_logs (:warn, r"nothing.*not supported") B._to_py(nothing)
        @test pyis(p, pybuiltins.None)
    end

    @testset "_py2jl: numeric arrays" begin
        ns = pydict()
        pyexec("""
        import numpy as np
        m = np.array([[1.0, 2.0, 3.0], [4.0, float('nan'), float('inf')]])
        m_f = np.asfortranarray(m)
        col = np.array([[1.0], [2.0], [3.0]])
        mask = np.array([[True, False]])
        c3 = np.arange(1.0, 13.0).reshape(2, 3, 2)
        f3 = np.asfortranarray(c3)
        empty = np.zeros((0, 3))
        """, ns)
        expected = [1.0 2.0 3.0; 4.0 NaN Inf]
        @test isequal(B._py2jl(ns["m"]), expected)
        @test isequal(B._py2jl(ns["m_f"]), expected)
        c = B._py2jl(ns["col"])
        @test c isa Matrix{Float64}
        @test size(c) == (3, 1)
        @test B._py2jl(ns["mask"]) isa Matrix{Bool}

        @test size(B._py2jl(ns["empty"])) == (0, 3)

        T = [1.0 3.0 5.0; 7.0 9.0 11.0;;; 2.0 4.0 6.0; 8.0 10.0 12.0]
        @test B._py2jl(ns["c3"]) == T
        @test B._py2jl(ns["f3"]) == T
    end

    @testset "_py2jl: nested structs and tables" begin
        ns = pydict()
        pyexec("""
        import numpy as np
        table = {"VariableNames": ["x", "s"], "height": 2, "RowNames": [],
                 "data": {"x": np.array([1.0, 2.0]), "s": ["a", "b"]}}
        struct = {"beta": np.array([[0.5], [1.5]]), "tab": table, "msg": "ok", "flag": True}
        multi = (np.array([[1.0]]), struct)
        """, ns)
        out = B._py2jl(ns["multi"])
        @test out isa Vector
        @test length(out) == 2

        s = out[2]
        @test s isa Dict{String,Any}
        @test s["beta"] isa Matrix{Float64}
        @test size(s["beta"]) == (2, 1)
        @test s["msg"] isa String
        @test s["msg"] == "ok"
        @test s["flag"] === true

        t = s["tab"]
        @test t isa Dict{String,Any}
        @test t["data"] isa Dict{String,Any}
        @test t["VariableNames"] == ["x", "s"]
        @test t["data"]["x"] == [1.0, 2.0]
        @test t["data"]["s"] == ["a", "b"]

        @test B._py2jl(pybuiltins.None) === nothing
    end

    @testset "call(handle, ...) converts and forwards" begin
        ns = pydict()
        pyexec("""
        class Recorder:
            def call(self, name, *args, **kwargs):
                self.name, self.args, self.kwargs = name, args, kwargs
                return args
        rec = Recorder()
        """, ns)
        rec = ns["rec"]
        out = call(B.FsdaEngineHandle(rec), "f", [1.0 2.0; 3.0 4.0], "txt";
            nargout=2, la=[0.5, 1.0], intercept=true)
        @test pyconvert(String, rec.name) == "f"
        @test isnd(rec.args[0])
        @test pyshape(rec.args[0]) == (2, 2)
        @test pyisinstance(rec.args[1], pybuiltins.str)
        @test isnd(rec.kwargs["la"])
        @test pyisinstance(rec.kwargs["intercept"], pybuiltins.bool)
        @test pyconvert(Int, rec.kwargs["nargout"]) == 2
        @test out isa Vector
        @test out[1] isa Matrix{Float64}
        @test out[2] == "txt"
    end
end
