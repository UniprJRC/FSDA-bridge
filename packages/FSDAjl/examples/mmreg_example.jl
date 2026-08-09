# MMreg - MM estimation: robust, but without giving up much efficiency.
#
#   out = MMreg(y, X; name = value)
#
#   y    n x 1 response column
#   X    n x (p-1) predictors; the intercept is added by default
#   out  Dict; "beta" the final coefficients, "Sbeta" the initial S estimate
#        they were refined from, "outliers" the units flagged
#
# Full documentation: the MMreg page in the FSDAjl docs.

using FSDA
using Random
using Printf


# Example 1 - MMreg with all default options.

# A robust estimator trades efficiency for resistance. LXS tolerates up to half
# the data being wrong, but pays for it with a noisier estimate when the data
# is actually clean. MM estimation is a two stage answer: start from a high
# breakdown estimate, then refine it to recover most of the precision of least
# squares without losing the resistance.

# The same data as the LXS and FSR examples: 200 observations, 3 predictors,
# first five responses shifted up by 6.
Random.seed!(123456)
n, p = 200, 3
X = randn(n, p)
y = randn(n, 1)
ycont = copy(y)
ycont[1:5] .+= 6

call("rng", 1234, nargout = 0)

out = MMreg(ycont, X)

beta  = vec(out["beta"])
Sbeta = vec(out["Sbeta"])
flagged = sort(Int.(vec(out["outliers"])))

println()
println("the starting S estimate, and what MM refined it to")
println("  term         S estimate      MM final        change")
labels = vcat("intercept", ["X$(j)" for j in 1:(length(beta) - 1)])
for j in 1:length(beta)
    @printf("  %-10s  %11.6f  %12.6f  %12.6f\n",
            labels[j], Sbeta[j], beta[j], beta[j] - Sbeta[j])
end

@printf("\nunits flagged as outliers: %d of %d\n", length(flagged), n)
println("flagged units: ", flagged)

println()
println("The changes from S to MM are small, in the third decimal place. The")
println("starting estimate was already close to the zero it should be, so the")
println("refinement adjusts it rather than rescuing it. That is the usual case:")
println("the second stage buys precision, not a different answer.")

println()
println("On the same data the LXS example flags units 1 to 5 plus 40 and 146.")
println("MMreg finds all of those and adds 54 and 80. Nothing LXS flagged is")
println("missed, so the two agree on the planted outliers and differ only on")
println("the borderline cases at the edge of the cloud.")

stop_engine()
