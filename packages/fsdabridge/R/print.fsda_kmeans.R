#' Print method for fsda_kmeans objects
#'
#' Displays a summary of a \code{\link{fsda_kmeans}} result: observation and
#' variable counts, number of clusters, number of replicates, cluster sizes,
#' and the total within-cluster sum of distances.
#'
#' @param x An object of class \code{"fsda_kmeans"}.
#' @param ... Further arguments passed to or from other methods (unused).
#'
#' @return Invisibly returns \code{x}.
#' @export
print.fsda_kmeans <- function(x, ...) {
    cat("\n")
    cat("FSDA KMEANS\n")
    cat("============\n\n")

    cat("Observations :", x$n, "\n")
    cat("Variables    :", x$p, "\n")
    cat("Clusters     :", x$k, "\n")
    cat("Replicates   :", x$replicates, "\n\n")

    if (!is.null(x$siz)) {
        cat("Cluster sizes\n")
        cat("-------------\n")

        sz <- x$siz

        for (i in seq_len(nrow(sz))) {
            cat("Cluster", sz[i, 1], ":", sz[i, 2], "\n")
        }

        cat("\n")
    }

    if (!is.null(x$obj)) {
        cat("Objective function (total within-cluster sum of dist) :", round(x$obj, 4), "\n")
    }

    invisible(x)
}
