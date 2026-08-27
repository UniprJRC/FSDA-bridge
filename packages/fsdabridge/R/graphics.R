#' Bivariate boxplot
#'
#' @param handle Engine handle from [start_engine()].
#' @param Y Numeric matrix with two columns.
#' @param ... Optional arguments for `boxplotb`.
#' @return A list with centroid, contour and outlier indices.
#' @examples
#' \dontrun{
#' h = start_engine("boxplotb")
#' out = boxplotb(h, Y)
#' stop_engine(h)
#' }
#' @export
boxplotb = function(handle, Y, ...) {
  fsda_call(handle, "boxplotb", Y, ...)
}

#' Plot y against each column of X
#'
#' @param handle Engine handle from [start_engine()].
#' @param y Response.
#' @param X Predictors.
#' @param ... Optional arguments for `yXplot`.
#' @return `NULL`.
#' @examples
#' \dontrun{
#' h = start_engine("yXplot")
#' yXplot(h, y, X)
#' stop_engine(h)
#' }
#' @export
yXplot = function(handle, y, X, ...) {
  fsda_call(handle, "yXplot", y, X, nargout = 0, ...)
}

#' Mahalanobis distance trajectories from a forward search
#'
#' @param handle Engine handle from [start_engine()].
#' @param out Output of `FSMeda`.
#' @param ... Optional arguments for `malfwdplot`.
#' @return `NULL`.
#' @examples
#' \dontrun{
#' h = start_engine("malfwdplot")
#' malfwdplot(h, out)
#' stop_engine(h)
#' }
#' @export
malfwdplot = function(handle, out, ...) {
  fsda_call(handle, "malfwdplot", out, nargout = 0, ...)
}
