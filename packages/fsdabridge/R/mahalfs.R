#' Mahalanobis Distance / MahalFS Routine
#'
#' Thin wrapper around fsda_call for the FSDA mahalFS routine.
#'
#' @param handle Engine handle from start_engine().
#' @param y Response vector or data matrix.
#' @param X Predictor matrix or input data.
#' @param ... Additional options passed to mahalFS.
#' @return The mahalFS output converted to R (named list).
#' @export
mahalFS <- function(handle, y, X, ...) {
  fsda_call(handle, "mahalFS", y, X, ...)
}