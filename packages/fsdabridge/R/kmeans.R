#' Run FSDA k-means clustering
#'
#' Calls MATLAB's \code{kmeans} through the FSDA bridge engine. Unlike
#' \code{\link{fsda_tclust}}, MATLAB's kmeans returns unnamed positional
#' outputs (not a struct), so this wrapper assigns names itself and derives
#' \code{siz} and \code{obj} manually from the raw output.
#'
#' @param data Matrix of observations (n x p).
#' @param k Number of clusters.
#' @param replicates Number of times to repeat clustering with new initial
#'   centroids (passed to MATLAB's \code{Replicates} option). Default 10.
#' @param seed Integer seed. Since MATLAB's kmeans has no direct seed
#'   argument, this sets the engine's global RNG via \code{rng()}
#'   immediately before the call. Default 0.
#' @param ... Additional FSDA MATLAB name-value options.
#'
#' @return An object of class \code{"fsda_kmeans"}, a list with elements:
#'   \code{idx} (cluster assignment per observation), \code{C} (cluster
#'   centroids), \code{sumd} (within-cluster sums of point-to-centroid
#'   distances), \code{D} (distances from each point to every centroid),
#'   \code{siz} (cluster sizes with percentages), \code{obj} (total
#'   within-cluster sum of distances), plus \code{call}, \code{n}, \code{p},
#'   \code{k}, \code{replicates}, and \code{seed}.
#'
#' @examples
#' \dontrun{
#' result <- fsda_kmeans(data, k = 3, replicates = 10, seed = 42)
#' print(result)
#' }
#' @export
fsda_kmeans <- function(
  data,
  k,
  replicates = 10,
  seed = 0,
  ...
) {
    eng <- start_engine()
    on.exit(stop_engine(eng), add = TRUE)

    # MATLAB kmeans has no seed argument -- set global rng on this session
    # immediately before the call so it's the last thing to touch the RNG.
    eval_m(eng, sprintf("rng(%d);", as.integer(seed)), nargout = 0)

    raw <- fsda_call(
        eng,
        name = "kmeans",
        data, k,
        Replicates = replicates,
        ...,
        nargout = 4
    )

    # raw is an UNNAMED list here: kmeans returns positional outputs, not a
    # struct, so we assign names ourselves -- this does NOT come for free
    # the way fsda_tclust's muopt/obj/siz/idx did.
    result <- list(
        idx  = raw[[1]],
        C    = raw[[2]],
        sumd = raw[[3]],
        D    = raw[[4]]
    )

    idxv <- as.integer(as.vector(result$idx))
    tab <- table(idxv)
    result$siz <- cbind(
        as.integer(names(tab)),
        as.integer(tab),
        100 * as.integer(tab) / length(idxv)
    )
    result$obj <- sum(result$sumd)

    result$call <- match.call()
    result$n <- nrow(data)
    result$p <- ncol(data)
    result$k <- k
    result$replicates <- replicates
    result$seed <- seed

    class(result) <- c("fsda_kmeans", class(result))
    result
}
