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
