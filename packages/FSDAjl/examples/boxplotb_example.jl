# boxplotb - bivariate boxplot.
#
#   out = boxplotb(Y)
#
#   Y    n x 2 data matrix
#   out  Dict with "outliers" (units outside the outer contour), "cent"
#        (the centre), "Spl" (the contour coordinates) and "handles"
#
# This example opens a plot window. Close it to let the script finish.
#
# Full documentation: the boxplotb page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - bivariate boxplot of the geyser data.

# A univariate boxplot looks at one variable at a time, so a point can sit
# inside the normal range on both variables and still be an odd combination.
# The bivariate boxplot draws two contours around the data - an inner one
# holding roughly half the points, and an outer fence - and flags whatever
# falls outside the fence.

Y = eval_expr("table2array(getfield(load('geyser2.mat'),'geyser2'))")
@printf("geyser2: %d eruptions, %d variables\n\n", size(Y, 1), size(Y, 2))

out = boxplotb(Y)

outl = Int.(vec(out["outliers"]))
@printf("units outside the outer contour: %d\n", length(outl))
println("flagged units: ", outl)
@printf("centre: %.4f, %.4f\n", out["cent"][1], out["cent"][2])

# Paint the figure, then hold it open until it is closed by hand.
# render_figures() forces MATLAB to actually paint the plot. The window then
# stays on screen after the script ends, so there is no need to wait for it.
# FSDAjl also has wait_for_figures(), which blocks until you close the window,
# but that is for working interactively rather than for a script like this.
render_figures()

stop_engine()
