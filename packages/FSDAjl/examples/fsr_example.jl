# FSR - forward search estimator in linear regression.
#
#   out = FSR(y, X)
#   out = FSR(y, X; name = value)
#
#   y    n x 1 response column (NOT a 1-D vector: see the note below)
#   X    n x (p-1) predictors; do not add a column of 1s, the intercept
#        is included by default
#   out  Dict of results, keyed by the FSDA field names. Useful keys:
#          "ListOut"   units flagged as outliers
#          "beta"      estimated regression coefficients
#          "mdr"       minimum deletion residual at each step
#
# Full documentation: the FSR page in the FSDAjl docs.

using FSDA
using Random
using Printf


# Example 1 - FSR with all default options.

# The forward search starts from a small subset that looks clean, then adds
# observations one at a time, always taking the ones that fit best. At each
# step it watches the minimum deletion residual. When that jumps above its
# confidence envelope, the search has been forced to admit an outlier.

Random.seed!(123456)

n = 200
p = 3
X = randn(n, p)
y = randn(n, 1)

# Contaminate the first five responses so there is something to find.
ycont = copy(y)
ycont[1:5] .+= 6

# FSR subsamples internally, so fix MATLAB's generator too, or the flagged
# units will differ from run to run.
call("rng", 1234, nargout = 0)

out = FSR(ycont, X; msg = 0, plots = 0)

flagged = sort(Int.(vec(out["ListOut"])))
@printf("units flagged as outliers: %d of %d\n", length(flagged), n)
println("flagged units: ", flagged)


# Example 2 - FSR with optional arguments.

# init starts the monitoring from a chosen subset size rather than the
# default. Useful when the early steps are not interesting.

out2 = FSR(ycont, X; init = 60, msg = 0, plots = 0)

@printf("with init=60: %d steps monitored, %d outliers\n",
        size(out2["mdr"], 1), length(vec(out2["ListOut"])))

stop_engine()
