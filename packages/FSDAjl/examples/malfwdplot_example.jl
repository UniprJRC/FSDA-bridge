# malfwdplot - one trajectory per unit, monitored along the forward search.
#
#   malfwdplot(out; nargout = 0)
#
#   out  the Dict returned by FSMeda
#
# malfwdplot draws nothing back to Julia; it is called for the plot. Note that
# the whole struct is passed straight through, which the bridge handles.
#
# Full documentation: the malfwdplot page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - monitoring the Swiss banknotes search.

# malfwdplot draws one line per unit, showing how far that unit sits from the
# centre at every step of the search. Ordinary units trace flat lines near the
# bottom. A unit that is unlike the rest sits high, or climbs sharply once the
# search is forced to admit it.

# The same data and starting subset as the FSMeda example.
Y = eval_expr("table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")
fre = unibiv(Y)
bsb = reshape(fre[sortperm(fre[:, 4])[1:20], 1], :, 1)

out = FSMeda(Y, bsb; plots = 0)

# FSMeda returns a struct, which arrives in Julia as a Dict. It can be handed
# straight back to MATLAB.
malfwdplot(out; nargout = 0)
render_figures()

MAL   = out["MAL"]
final = MAL[:, end]
ord   = sortperm(final, rev = true)

println("the ten highest trajectories at the end of the search")
for i in ord[1:10]
    @printf("  unit %3d   scaled distance = %7.4f\n", i, final[i])
end

@printf("\nacross all units the final distances run from %.4f to %.4f\n",
        minimum(final), maximum(final))

println()
println("The top five here are 40, 171, 167, 1 and 161, which are exactly the")
println("five notes the mahalFS example finds most distant, in nearly the same")
println("order. One is a single distance calculation and the other a search")
println("monitored over eighty steps, so agreeing on the same five is worth")
println("something.")
println()
println("Note that these are not the forgeries. Five of the ten highest are")
println("genuine notes and five are forged. Distance from the centre is not the")
println("same question as which notes were faked.")

stop_engine()
