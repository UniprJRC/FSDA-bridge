# malfwdplot: the forward search monitoring plot for the Swiss banknotes data.
#
# malfwdplot draws one trajectory per unit, showing how its scaled Mahalanobis
# distance evolves as the forward search grows the subset. Well behaved units
# trace flat lines near the bottom. Outliers sit high, or climb sharply once the
# search is forced to admit them.
#
# This example is built differently from the others, and deliberately so.
#
# malfwdplot takes a STRUCT as its input, the output of FSMeda. Structs can be
# returned from MATLAB to Julia, where they arrive as a Dict, but they cannot
# currently be sent back the other way: engine.jl converts arrays to numpy and
# passes everything else through unconverted, so a Dict never becomes a MATLAB
# struct. Passing one back fails with "BufferError: not a buffer" before MATLAB
# ever sees the call.
#
# The way around it is to never move the struct at all. Each step runs inside
# the MATLAB workspace via eval_expr, so the struct is created there, consumed
# there, and only the numeric field is brought back to Julia.
#
# Note: this example opens a figure window, which is the point of it.
#
# Run from the repository root:
#   julia --project=code/fsda_engine packages/FSDAjl/examples/malfwdplot_example.jl

include(joinpath(@__DIR__, "..", "src", "engines", "engine.jl"))

using Printf

h = start_engine()

try
    println("building the search inside the MATLAB workspace\n")

    # Step 1: load the data, MATLAB side.
    eval_expr(h, "Y = table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'));",
              nargout = 0)

    # Step 2: clean starting subset, the documented FSDA way.
    eval_expr(h, "fre = sortrows(unibiv(Y),4); bsb = fre(1:20,1);", nargout = 0)

    # Step 3: run the monitored search. The struct stays in MATLAB.
    eval_expr(h, "outEDA = FSMeda(Y, bsb, 'plots', 0);", nargout = 0)

    # Step 4: plot it. The struct is named, not passed, so nothing crosses.
    eval_expr(h, "malfwdplot(outEDA);", nargout = 0)
    println("malfwdplot drawn, struct never left MATLAB\n")

    # Step 5: bring back only the numeric field, which crosses cleanly.
    MAL = eval_expr(h, "outEDA.MAL")
    @printf("MAL came back as a %s of size %s\n\n", typeof(MAL), size(MAL))

    final = MAL[:, end]
    ord = sortperm(final, rev = true)

    println("ten highest trajectories at the end of the search")
    for i in ord[1:10]
        @printf("  unit %3d   scaled distance = %7.4f\n", i, final[i])
    end

    @printf("\nrange across all units: %.4f to %.4f\n", minimum(final), maximum(final))
finally
    stop_engine(h)
end
