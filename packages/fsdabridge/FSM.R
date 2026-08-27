#' Thin wrapper around fsda_call for the FSDA FSM routine.
#'
#' @param handle Engine handle from start_engine().
#' @param y Response vector or data matrix.
#' @param X Predictor matrix or input data.
#' @param ... Additional options passed to FSM.
#' @return The FSM output converted to R (named list).
#' @export
FSM <- function(handle, y, X, ...) {
  fsda_call(handle, "FSM", y, X, ...)
}
