# FSMeda - the forward search, recording what happens at every step.
#
#   out = FSMeda(Y, bsb; name = value)
#
#   Y    n x v data matrix
#   bsb  the starting subset, a column of unit numbers to begin from
#   out  Dict; "mmd" is two columns, the subset size and the minimum
#        Mahalanobis distance at that step, and "MAL" is n x steps, the
#        distance of every unit at every step
#
# Full documentation: the FSMeda page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - monitoring the forward search on the Swiss banknotes data.

# FSM answers one question: which units are outliers. FSMeda answers a
# different one: what happened along the way. It runs the same search but
# records diagnostics at every step, so the search can be inspected rather
# than simply trusted.

# 200 notes, 6 measurements. The first 100 are genuine, the last 100 forged.
Y = eval_expr("table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")
@printf("swiss_banknotes: %d observations, %d variables\n\n", size(Y, 1), size(Y, 2))

# The search has to start somewhere clean. unibiv scores every unit, and the
# lowest scoring ones are the most ordinary, so they make a safe starting
# point. Twenty is enough to be stable without assuming too much.
fre = unibiv(Y)
bsb = reshape(fre[sortperm(fre[:, 4])[1:20], 1], :, 1)

println("starting from the 20 most ordinary notes:")
println("  ", Int.(vec(bsb)))
println()

# plots = 0 keeps this a text-only example; FSMeda would otherwise draw the
# distance plot as well.
out = FSMeda(Y, bsb; plots = 0)

mmd = out["mmd"]

@printf("the search ran %d steps, from subset size %d up to %d\n", 
        size(mmd, 1), Int(mmd[1, 1]), Int(mmd[end, 1]))
println("(FSDA begins monitoring from its own minimum subset size, which is")
println("larger than the 20 notes we supplied, so the first reported step is")
println("already well into the search.)")
println()

# At each step, mmd is the distance of the nearest unit not yet included.
# While the search is adding ordinary notes it stays low. When the only notes
# left to add are unlike the rest, it climbs.
println("minimum Mahalanobis distance, first five steps")
for i in 1:5
    @printf("  subset size %3d   mmd = %7.4f\n", Int(mmd[i, 1]), mmd[i, 2])
end

println()
println("and the last five steps")
for i in (size(mmd, 1) - 4):size(mmd, 1)
    @printf("  subset size %3d   mmd = %7.4f\n", Int(mmd[i, 1]), mmd[i, 2])
end

println()
println("The distance is flat near 3.3 through the early steps and climbs to")
println("5.8 by the end. Early on the search is adding notes that sit")
println("comfortably with the ones already in, so the nearest excluded note is")
println("never far away. By the end the only notes left to add are unlike the")
println("rest, and the distance rises to say so.")

stop_engine()
