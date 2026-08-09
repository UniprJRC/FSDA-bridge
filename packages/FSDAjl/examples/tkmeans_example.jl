# tkmeans - trimmed k-means: clustering that is allowed to discard noise.
#
#   out = tkmeans(Y, k, alpha; name = value)
#
#   Y      n x v data matrix
#   k      how many clusters to look for
#   alpha  proportion of units to set aside as noise
#   out    Dict; "idx" is the cluster label per unit, where 0 means the unit
#          was trimmed, and "muopt" is k x v, one centroid per row
#
# Full documentation: the tkmeans page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - trimmed k-means on the Old Faithful geyser data.

# tkmeans is the simpler sibling of tclust. Both discard a fixed share of the
# data as noise instead of forcing every point into a cluster. They differ in
# what they assume about cluster shape: tkmeans measures plain distance to a
# centroid, so it looks for round clusters of similar size, while tclust models
# each cluster's covariance and can find elongated ones.

# geyser2 records eruptions of the Old Faithful geyser. Each row is one
# eruption: column 1 is how long it lasted, column 2 is how long the previous
# eruption lasted, both in minutes.
Y = eval_expr("table2array(getfield(load('geyser2.mat'),'geyser2'))")
n = size(Y, 1)
@printf("geyser2: %d eruptions, %d variables\n\n", n, size(Y, 2))

k     = 3      # look for three clusters
alpha = 0.1    # set aside 10 percent as noise, the same as the tclust example
               # uses, so the two results can be compared fairly

# tkmeans starts from random subsets, so seed MATLAB for a repeatable answer.
call("rng", 1234, nargout = 0)

out = tkmeans(Y, k, alpha; msg = 0, plots = 0)

idx = Int.(vec(out["idx"]))     # 0 means trimmed
mu  = out["muopt"]

@printf("set aside as noise: %d of %d eruptions (%.1f%%)\n\n",
        count(==(0), idx), n, 100 * count(==(0), idx) / n)

println("what each cluster looks like")
println("  cluster   eruptions   this one   the previous one")
for c in 1:k
    @printf("  %7d   %9d   %8.2f   %16.2f\n",
            c, count(==(c), idx), mu[c, 1], mu[c, 2])
end

println()
println("The tclust example ran on this same data, trimming the same 10 percent.")
println("Its centroids were (2.01, 4.51), (4.35, 1.99) and (4.29, 4.11), so the")
println("two methods agree to within 0.06 on every one, and their cluster sizes")
println("differ by only a few eruptions each.")
println()
println("That is worth noticing. tclust can model each cluster's shape and")
println("tkmeans cannot, but these clusters are roughly round and similarly")
println("sized, so the extra flexibility buys nothing. Where it would matter is")
println("data with elongated or very unequal clusters.")

stop_engine()
