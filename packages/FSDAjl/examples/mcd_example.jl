# mcd - Minimum Covariance Determinant: a centre and spread that ignore outliers.
#
#   out = mcd(Y; name = value)
#
#   Y    n x v data matrix
#   out  Dict; "loc" is the robust centre, "cov" the robust covariance,
#        "md" the distance of each unit from that centre, "outliers" the
#        units judged too far away
#
# Full documentation: the mcd page in the FSDAjl docs.

using FSDA
using Random
using Printf


# Example 1 - mcd with all default options.

# The ordinary mean and covariance use every observation, outliers included.
# So a few odd points widen the estimated spread, and once the spread is too
# wide those same points no longer look unusual - they hide behind the mess
# they created. MCD avoids this by looking for the tightest half of the data
# and measuring everything against that.

# 200 points in 3 dimensions, with the first five shifted well away.
Random.seed!(123456)
n, v = 200, 3
Y = randn(n, v)
Ycont = copy(Y)
Ycont[1:5, :] .+= 3

# MCD tries many random subsets, so seed MATLAB for a repeatable answer.
call("rng", 1234, nargout = 0)

out = mcd(Ycont; msg = 0, plots = 0)

flagged = sort(Int.(vec(out["outliers"])))
@printf("units flagged as outliers: %d of %d\n", length(flagged), n)
println("flagged units: ", flagged)
println("(units 1 to 5 are the ones we moved, so those are the ones to look for)")

println()
println("The five planted points sit far outside the rest of the data, and MCD")
println("finds all five. The other flagged units are ordinary points that happen")
println("to fall near the edge of the cloud - with 200 random points, a few")
println("always will.")

stop_engine()
