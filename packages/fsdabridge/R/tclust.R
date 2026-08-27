#' Run FSDA tclust clustering
#'
#' @param data Matrix of observations
#' @param k Number of clusters
#' @param alpha Trimming level
#' @param restrfactor Restriction factor on scatter matrices
#' @param ... Additional FSDA MATLAB name-value options
#'
#' @return An object of class \code{"fsda_tclust"}
#'
#' @export
fsda_tclust <- function(
  data,
  k,
  alpha,
  restrfactor = NULL,
  ...
) {
    eng <- start_engine()

    on.exit(
        stop_engine(eng),
        add = TRUE
    )


    args <- list(
        data,
        k,
        alpha
    )


    if (!is.null(restrfactor)) {
        args <- c(
            args,
            list(restrfactor)
        )
    }


    args <- c(
        args,
        list(...)
    )


    result <- do.call(
        fsda_call,
        c(
            list(
                handle = eng,
                name = "tclust"
            ),
            args
        )
    )


    result$call <- match.call()

    result$n <- nrow(data)
    result$p <- ncol(data)
    result$k <- k
    result$alpha <- alpha
    result$restrfactor <- restrfactor


    class(result) <- c(
        "fsda_tclust",
        class(result)
    )

    result
}
