# Score - Box-Cox score test for a transformation of the response.
#
#   out = Score(y, X; la = ..., intercept = true)
#
#   y     n x 1 response column (a 1-D Julia vector crosses as a MATLAB row,
#         and Score expects a column, so use W[:, 4:4] not W[:, 4])
#   X     n x (p-1) predictors; the intercept is added by default
#   la    candidate transformation parameters to test
#   out   Dict with keys "Score" (statistic per lambda) and "Lik"
#
# Full documentation: the Score page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - Score test on the wool data.

# Box and Cox (1964) asked whether a regression fits better after transforming
# the response. Each lambda is a different transformation: lambda = 1 leaves the
# response alone, lambda = 0 takes logs. The lambda whose score statistic is
# closest to zero is the best supported.

# wool ships with FSDA, so it is loaded through MATLAB rather than copied here.
W = eval_expr("table2array(getfield(load('wool.mat'),'wool'))")
@printf("wool: %d observations, %d columns\n\n", size(W, 1), size(W, 2))

y  = W[:, 4:4]
X  = W[:, 1:3]
# These five lambdas are what Score tests by default, so no options are needed.
la = [-1.0, -0.5, 0.0, 0.5, 1.0]

out = Score(y, X)

println("score test statistic per lambda")
for (lam, s) in zip(la, vec(out["Score"]))
    @printf("  lambda = %+4.1f    score = %9.4f\n", lam, s)
end

best = la[argmin(abs.(vec(out["Score"])))]
@printf("\nbest supported transformation: lambda = %+.1f\n", best)
println("lambda = 0 means the response is better modelled after taking logs.")

stop_engine()
