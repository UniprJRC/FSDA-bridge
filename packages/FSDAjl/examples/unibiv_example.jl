# unibiv - flags outliers one variable at a time and two variables at a time.
#
#   out = unibiv(Y; name = value)
#
#   Y    n x v data matrix
#   out  n x 4 matrix, one row per unit:
#          column 1  the unit number
#          column 2  how often it fell outside a single-variable limit
#          column 3  how often it fell outside a two-variable ellipse
#          column 4  a pseudo Mahalanobis distance, its overall score
#
# Full documentation: the unibiv page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - unibiv on the Swiss banknotes data.

# A single variable can be checked with a boxplot: anything past the whiskers is
# unusual. A pair of variables can be checked with an ellipse drawn around the
# bulk of the points. unibiv does both, for every variable and every pair, and
# counts how often each unit falls outside. A unit that looks ordinary on each
# variable alone but keeps landing outside the ellipses is one worth a look.

# 200 notes, 6 measurements in millimetres. The first 100 are genuine and the
# last 100 are forged.
Y = eval_expr("table2array(getfield(load('swiss_banknotes.mat'),'swiss_banknotes'))")
@printf("swiss_banknotes: %d observations, %d variables\n\n", size(Y, 1), size(Y, 2))

fre = unibiv(Y)

ord = sortperm(fre[:, 4], rev = true)

println("the ten most unusual notes")
println("   unit   single-variable   two-variable   overall score")
for i in ord[1:10]
    @printf("  %5d  %16d  %14d  %14.4f\n",
            Int(fre[i, 1]), Int(fre[i, 2]), Int(fre[i, 3]), fre[i, 4])
end

@printf("\n%d notes were flagged at least once on a single variable,\n",
        count(>(0), fre[:, 2]))
@printf("%d were flagged at least once on a pair of variables.\n",
        count(>(0), fre[:, 3]))

# The lowest scoring units are the most ordinary ones. The forward search needs
# a starting subset that is known to be clean, and this is the usual way to
# build one - see the FSMeda example.
typical = sortperm(fre[:, 4])[1:20]
println()
println("the twenty most ordinary notes, a natural starting subset:")
println("  ", Int.(fre[typical, 1]))

println()
println("Notice that unibiv does not separate the forgeries. Of the ten most")
println("unusual notes, five are genuine and five are forged. That is expected:")
println("unibiv looks at one or two variables at a time, so it finds notes with")
println("an extreme single measurement, not notes that are odd in the way a")
println("forgery is odd. Its job here is to supply a starting subset that is")
println("probably clean, and let the forward search take it from there.")

stop_engine()
