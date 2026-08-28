#' Forward Search for Multivariate data (FSM)
#'
#' Thin wrapper around `fsda_call()` for the FSDA `FSM` routine — robust
#' multivariate outlier detection via forward search, tracking the minimum
#' Mahalanobis distance (`mmd`) as units are added to the subset.
#'
#' @param handle Engine handle from [start_engine()].
#' @param Y Data matrix (n, p) of observations.
#' @param ... Name/value options passed straight through to FSM (e.g.
#'   `plots`, `msg`, `init`).
#' @return The FSM output converted to R (named list), including `mmd`
#'   (the minimum Mahalanobis distance trajectory, as a two-column
#'   step/value matrix).
#' @examples
#' \dontrun{
#' h = start_engine("FSM")
#' out = FSM(h, Y, plots = 0)
#' stop_engine(h)
#' }
#' @export
FSM = function(handle, Y, ...) {
  fsda_call(handle, "FSM", Y, ...)
}
