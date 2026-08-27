#' Print method for fsda_tclust objects
#'
#' Displays a summary of a \code{\link{fsda_tclust}} result: observation and
#' variable counts, number of clusters, trim level, cluster sizes (with
#' trimmed units labeled separately), and the objective function value.
#'
#' @param x An object of class \code{"fsda_tclust"}.
#' @param ... Further arguments passed to or from other methods (unused).
#'
#' @return Invisibly returns \code{x}.
#' @export
print.fsda_tclust <- function(x, ...) {
    cat("\n")
    cat("FSDA TCLUST\n")
    cat("============\n\n")

    cat("Observations :", x$n, "\n")
    cat("Variables    :", x$p, "\n")
    cat("Clusters     :", x$k, "\n")
    cat("Trim level   :", x$alpha, "\n\n")

    if (!is.null(x$siz)) {
        cat("Cluster sizes\n")
        cat("-------------\n")

        sz <- x$siz

        for (i in seq_len(nrow(sz))) {
            cl <- sz[i, 1]
            n <- sz[i, 2]

            if (cl == 0) {
                cat("Trimmed :", n, "\n")
            } else {
                cat("Cluster", cl, ":", n, "\n")
            }
        }

        cat("\n")
    }

    if (!is.null(x$obj)) {
        cat("Objective function :", round(x$obj, 4), "\n")
    }

    invisible(x)
}
