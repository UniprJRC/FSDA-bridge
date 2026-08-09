# FSRfan - does the best transformation hold throughout the data, or not?
#
#   out = FSRfan(y, X; name = value)
#
#   y    n x 1 response column
#   X    n x (p-1) predictors; the intercept is added by default
#   out  Dict; "Score" is steps x (1 + number of lambdas), the subset size
#        followed by the score statistic for each candidate lambda
#
# Full documentation: the FSRfan page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - FSRfan with all default options.

# The Score example tested transformations once, on the whole wool dataset, and
# found logs best supported. FSRfan asks a sharper question: does that hold all
# the way through, or does it only appear once certain observations are in?
#
# It recomputes the score statistic for every candidate lambda at every step of
# the forward search. A transformation supported only at the end is one resting
# on a handful of observations.

W = eval_expr("table2array(getfield(load('wool.mat'),'wool'))")
@printf("wool: %d observations, %d columns\n\n", size(W, 1), size(W, 2))

y = W[:, 4:4]
X = W[:, 1:3]

# The default candidates, the same five the Score example used.
la = [-1.0, -0.5, 0.0, 0.5, 1.0]

out = FSRfan(y, X; msg = 0, plots = 0)

Sc = out["Score"]
nsteps = size(Sc, 1)

@printf("monitored from subset size %d to %d, %d steps\n\n",
        Int(Sc[1, 1]), Int(Sc[end, 1]), nsteps)

println("score statistic per lambda, every fourth step")
print("  subset")
for l in la
    @printf("%10.1f", l)
end
println()
for i in 1:4:nsteps
    @printf("  %6d", Int(Sc[i, 1]))
    for j in 2:size(Sc, 2)
        @printf("%10.3f", Sc[i, j])
    end
    println()
end

# The best supported lambda at each step is whichever statistic is nearest zero.
best = [la[argmin(abs.(Sc[i, 2:end]))] for i in 1:nsteps]
@printf("\nlambda = 0 was best supported at %d of the %d steps\n",
        count(==(0.0), best), nsteps)

print("at the full sample: ")
for j in 2:size(Sc, 2)
    @printf("%.4f  ", Sc[end, j])
end
println()

println()
println("Read the table down each column. The first row is all zeros, which is")
println("expected: five observations cannot support a test with three")
println("predictors. After that the lambda = 1 column marches steadily away")
println("from zero, so leaving the response untransformed becomes less and less")
println("tenable as more data enters. The lambda = 0 column stays close to zero")
println("throughout, so the log transformation is supported by the whole data")
println("rather than by a few late observations.")

println()
println("The full sample row is exactly what the Score example produced on the")
println("same data: 17.7059, 7.4927, -0.9122, -9.5511, -18.5576. Score answers")
println("the question once; FSRfan shows how the answer held up along the way.")

stop_engine()
