# tclust - robust clustering that trims outliers instead of forcing them in.
#
#   out = tclust(Y, k, alpha, restrfactor; name = value)
#
#   Y            n x v data matrix
#   k            how many clusters to look for
#   alpha        proportion of units to discard as noise (0.1 = 10 percent)
#   restrfactor  how different cluster spreads are allowed to be
#   out          Dict; "idx" is the cluster label per unit, where 0 means the
#                unit was trimmed, and "muopt" is k x v, one centroid per row
#
# Full documentation: the tclust page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - tclust on the Old Faithful geyser data.

# Ordinary clustering has to put every point somewhere, so a handful of odd
# points can drag a cluster centre well away from where it belongs. Trimmed
# clustering may set aside a fixed share of the data as noise and fit the rest,
# which keeps the centres where the bulk of the data actually is.

# geyser2 records eruptions of the Old Faithful geyser. Each row is one
# eruption: column 1 is how long it lasted, column 2 is how long the previous
# eruption lasted, both in minutes.
Y = eval_expr("table2array(getfield(load('geyser2.mat'),'geyser2'))")
n = size(Y, 1)
@printf("geyser2: %d eruptions, %d variables\n\n", n, size(Y, 2))

k     = 3      # look for three clusters
alpha = 0.1    # set aside 10 percent of the eruptions as noise
restr = 12     # clusters may differ in spread, but not by more than this

# tclust starts from random subsets, so seed MATLAB for a repeatable answer.
call("rng", 1234, nargout = 0)

out = tclust(Y, k, alpha, restr; msg = 0, plots = 0)

idx = Int.(vec(out["idx"]))     # 0 means trimmed
mu  = out["muopt"]              # one row per cluster

@printf("set aside as noise: %d of %d eruptions (%.1f%%)\n\n",
        count(==(0), idx), n, 100 * count(==(0), idx) / n)

println("what each cluster looks like")
println("  cluster   eruptions   this one   the previous one")
for c in 1:k
    @printf("  %7d   %9d   %8.2f   %16.2f\n",
            c, count(==(c), idx), mu[c, 1], mu[c, 2])
end

println()
println("Read each centroid as a pair. Old Faithful alternates: a short eruption")
println("is followed by a long one, and a long eruption by either. So there are")
println("clusters for short-then-long and long-then-short, but none where both")
println("this eruption and the previous one were short.")

stop_engine()
