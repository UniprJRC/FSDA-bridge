# yXplot - the response plotted against each predictor in turn.
#
#   yXplot(y, X; nargout = 0)
#   yXplot(y, X, group; nargout = 0)
#
#   y      n x 1 response column
#   X      n x (p-1) predictors
#   group  optional n x 1 vector of group labels, drawn in different colours
#
# yXplot returns nothing. It is called for the plot it draws, so nargout = 0
# tells the bridge not to ask for a return value.
#
# Full documentation: the yXplot page in the FSDAjl docs.

using FSDA
using Printf


# Example 1 - yXplot with all default options.

# Before reaching for a robust method it is worth looking at the data. yXplot
# draws the response against each explanatory variable in turn, so curvature,
# clusters and obvious outliers show up straight away.

# stack_loss records 21 days of operation at a plant that oxidises ammonia.
D = eval_expr("table2array(getfield(load('stack_loss.mat'),'stack_loss'))")
n = size(D, 1)
@printf("stack_loss: %d observations, %d columns\n", n, size(D, 2))
println("  X1 air flow, X2 water temperature, X3 acid concentration")
println("  y  stack loss, the ammonia lost as unabsorbed gas")
println()

y = D[:, 4:4]
X = D[:, 1:3]

yXplot(y, X; nargout = 0)

# render_figures() paints the plot. The figure belongs to the MATLAB engine, so
# it disappears when the script ends; saving it keeps a copy you can open.
render_figures()

outfile = joinpath(tempdir(), "yxplot.png")
eval_expr("saveas(gcf, '$outfile')", nargout = 0)
println("plot saved to: ", outfile)
println()

# The plot shows the shape of each relationship; a correlation only summarises
# its direction and strength. Both are worth having.
yv = vec(y)
ybar = sum(yv) / n
yc = yv .- ybar
println("correlation of the response with each predictor")
for j in 1:3
    xj = X[:, j]
    xc = xj .- sum(xj) / n
    r = sum(xc .* yc) / sqrt(sum(xc .^ 2) * sum(yc .^ 2))
    @printf("  X%d  r = %+.4f\n", j, r)
end

stop_engine()
