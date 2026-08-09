# FSM - multivariate outlier detection by the forward search.
#
#   out = FSM(Y; name = value)
#
#   Y    n x v data matrix
#   out  Dict; "outliers" is the units flagged, "loc" the centre computed
#        from the clean units only, "mmd" the minimum Mahalanobis distance
#        at each step of the search
#
# Full documentation: the FSM page in the FSDAjl docs.

using FSDA
using Random
using Printf


# Example 1 - FSM with all default options.

# The forward search starts from a small subset that looks clean and adds
# observations one at a time, always taking whichever fits best. At each step
# it records how far away the nearest excluded point is. While the search is
# adding ordinary points that distance stays small; when it is finally forced
# to admit an outlier the distance jumps, and that jump is the signal.

# The same data as the mcd example: 200 points in 3 dimensions with the first
# five moved well away, so the two methods can be compared on equal terms.
Random.seed!(123456)
n, v = 200, 3
Y = randn(n, v)
Ycont = copy(Y)
Ycont[1:5, :] .+= 3

call("rng", 1234, nargout = 0)

out = FSM(Ycont; msg = 0, plots = 0)

flagged = sort(Int.(vec(out["outliers"])))
@printf("the search ran %d monitored steps\n", size(out["mmd"], 1))
@printf("units flagged as outliers: %d of %d\n", length(flagged), n)
println("flagged units: ", flagged)

println()
println("Units 1 to 5 are the ones we moved. FSM finds four of them and")
println("misses unit 4, while mcd on the same data finds all five. Neither is")
println("wrong: they judge outlyingness differently, so on a borderline point")
println("they can disagree. Running both and comparing is often more telling")
println("than trusting either one alone.")

stop_engine()
