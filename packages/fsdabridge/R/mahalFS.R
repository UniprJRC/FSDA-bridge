#
#' Mahalanobis Distance (mahalFS)
#
#' Thin wrapper around `fsda_call()` for the FSDA `mahalFS` routine —
#' computes the Mahalanobis distance of each observation in `Y` from a
#' given mean vector `MU` and covariance matrix `SIGMA`.
#
#' @param handle Engine handle from [start_engine()].
#' @param Y Data matrix (n, p) of observations.
#' @param MU Mean vector of length p.
#' @param SIGMA Covariance matrix (p, p).
#' @param ... Additional name/value options passed straight through to
#'   mahalFS.
#' @return The Mahalanobis distances for each observation, as a numeric
#'   vector.
#' @examples
#' \dontrun{
#' h = start_engine("mahalFS")
#' d = mahalFS(h, Y, MU, SIGMA)
#' stop_engine(h)
#' }
#' @export
mahalFS = function(handle, Y, MU, SIGMA, ...) {
  fsda_call(handle, "mahalFS", Y, MU, SIGMA, ...)
}
