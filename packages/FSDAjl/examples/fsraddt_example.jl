# FSRaddt - added t tests monitored along the forward search.
#
#   out = FSRaddt(y, X; name = value)
#
#   y     n x 1 response column (use D[:, 4:4], not D[:, 4]: a 1-D Julia
#         vector crosses as a MATLAB row)
#   X     n x (p-1) predictors; the intercept is added by default
#   out   Dict; "Tdel" is steps x (1 + p-1), the subset size followed by one
#         deletion t statistic per predictor
#
# Full documentation: the FSRaddt page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - added t tests on the multiple regression data.

# An ordinary t test asks whether a predictor matters, using all the data at
# once. FSRaddt asks the same question at every step of the forward search, so
# you can see whether a predictor is consistently important or only looks
# important because of a few observations.

D = eval_expr("table2array(getfield(load('multiple_regression.mat'),'multiple_regression'))")
@printf("multiple_regression: %d observations, %d columns\n\n", size(D, 1), size(D, 2))

y = D[:, 4:4]
X = D[:, 1:3]

# FSRaddt subsamples, so seed MATLAB or the search differs between runs.
call("rng", 1234, nargout = 0)

out = FSRaddt(y, X; msg = 0, plots = 0)

Tdel = out["Tdel"]
nsteps = size(Tdel, 1)
npred  = size(Tdel, 2) - 1

# Roughly, |t| above 2 is significant at the usual 5 percent level.
println("at the full sample")
for j in 1:npred
    t = Tdel[end, j + 1]
    @printf("  X%-2d  t = %8.4f   %s\n", j, t,
            abs(t) > 2 ? "significant" : "not significant")
end

println("\nhow often each predictor was significant across the search")
for j in 1:npred
    cnt = count(>(2), abs.(Tdel[:, j + 1]))
    @printf("  X%-2d  %3d of %d steps (%.0f%%)\n", j, cnt, nsteps, 100 * cnt / nsteps)
end

println("\nA predictor significant at only some steps is one whose importance")
println("depends on which observations are included.")

stop_engine()
