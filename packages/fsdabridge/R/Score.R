#' Score Function
#'
#' Thin wrapper around `fsda_call()` for the FSDA `Score` routine.
#'
#' @param handle Engine handle from [start_engine()].
#' @param y Response vector, as an (n, 1) matrix or plain numeric vector.
#' @param X Predictor matrix (n, p).
#' @param ... Name/value options passed straight through to `Score`.
#' @return The `Score` output converted to R.
#' @examples
#' \dontrun{
#' h = start_engine("Score")
#' out = Score(h, y, X)
#' stop_engine(h)
#' }
#' @export
Score = function(handle, y, X, ...) {
  fsda_call(handle, "Score", y, X, ...)
}