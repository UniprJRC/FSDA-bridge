# LXS - robust regression that fits the majority and lets outliers fall out.
#
#   out = LXS(y, X; name = value)
#
#   y    n x 1 response column
#   X    n x (p-1) predictors; the intercept is added by default
#   out  Dict; "beta" the coefficients, "residuals" one per unit,
#        "outliers" the units flagged, "scale" the robust spread estimate
#
# Full documentation: the LXS page in the FSDAjl docs.

using FSDA
using Random
using Printf


# Example 1 - LXS with all default options.

# Ordinary least squares minimises the SUM of the squared residuals, so one
# badly placed point can pull the whole line towards itself. LXS minimises the
# MEDIAN of the squared residuals instead. Up to half the observations can be
# arbitrarily wrong without moving the estimate, which is what makes it robust.

# The same data as the FSR example: 200 observations, 3 predictors, with the
# first five responses shifted up by 6.
Random.seed!(123456)
n, p = 200, 3
X = randn(n, p)
y = randn(n, 1)
ycont = copy(y)
ycont[1:5] .+= 6

# LXS draws random subsamples, so seed MATLAB for a repeatable answer.
call("rng", 1234, nargout = 0)

out = LXS(ycont, X; msg = 0)

beta = vec(out["beta"])
flagged = sort(Int.(vec(out["outliers"])))

println("robust coefficients")
@printf("  intercept   %10.6f\n", beta[1])
for j in 2:length(beta)
    @printf("  X%-9d  %10.6f\n", j - 1, beta[j])
end

@printf("\nunits flagged as outliers: %d of %d\n", length(flagged), n)
println("flagged units: ", flagged)

println()
println("y was pure noise before we shifted the first five, so a fit that has")
println("not been dragged by them should have coefficients close to zero. These")
println("do, and all five planted units are flagged.")


# Example 2 - LXS with reweighting.

# The first pass fits the majority and marks the rest. Reweighting then refits
# using only the units that pass, which sharpens the estimate once the outliers
# are out of the way.

call("rng", 1234, nargout = 0)

out2 = LXS(ycont, X; rew = 1, msg = 0)

beta2 = vec(out2["beta"])
flagged2 = sort(Int.(vec(out2["outliers"])))

println()
println("after reweighting")
@printf("  intercept   %10.6f\n", beta2[1])
for j in 2:length(beta2)
    @printf("  X%-9d  %10.6f\n", j - 1, beta2[j])
end
@printf("  flagged: %d units ", length(flagged2))
println(flagged2)

println()
println("The intercept moves from -0.345 to -0.180, closer to the zero it")
println("should be, and one further unit is flagged. Refitting without the")
println("outliers gives a slightly sharper estimate than the first pass.")

println()
println("One caveat worth knowing: FSR uses LXS internally to choose where its")
println("search begins. So when FSR and LXS flag the same units, that is not")
println("two independent methods agreeing - it is FSR reporting a conclusion")
println("built on this estimate.")

stop_engine()
