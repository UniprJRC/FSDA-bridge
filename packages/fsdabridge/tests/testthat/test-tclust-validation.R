library(testthat)
library(fsdabridge)

# ---------------------------------------------------------------------------
# Helper: find the permutation of R's cluster labels that best aligns
# result$muopt with matlab_mu (tclust-type algorithms have no canonical
# cluster ordering, so labels can differ between implementations even when
# the underlying partition is identical).
# ---------------------------------------------------------------------------
match_labels <- function(mu_r, mu_matlab) {
    k <- nrow(mu_r)

    # all permutations of 1:k
    perm_matrix <- t(expand.grid(rep(list(seq_len(k)), k)))
    valid <- apply(perm_matrix, 2, function(p) length(unique(p)) == k)
    perm_matrix <- perm_matrix[, valid, drop = FALSE]

    best_perm <- NULL
    best_cost <- Inf

    for (j in seq_len(ncol(perm_matrix))) {
        p <- perm_matrix[, j]
        cost <- sum((mu_r[p, , drop = FALSE] - mu_matlab)^2)
        if (cost < best_cost) {
            best_cost <- cost
            best_perm <- p
        }
    }

    best_perm
}

test_that("TCLUST matches MATLAB benchmark", {
    # -------------------------------------------------------------------
    # Load data
    # -------------------------------------------------------------------
    data_path <- system.file(
        "extdata",
        "geyser2.txt",
        package = "fsdabridge"
    )

    Y <- as.matrix(
        read.table(
            data_path,
            header = FALSE
        )
    )

    storage.mode(Y) <- "double"

    # -------------------------------------------------------------------
    # Run R/FSDA-bridge tclust
    # -------------------------------------------------------------------
    result <- fsda_tclust(
        Y,
        k = 3,
        alpha = 0.1,
        restrfactor = 10000
    )

    # -------------------------------------------------------------------
    # Load MATLAB benchmark outputs
    # -------------------------------------------------------------------
    matlab_mu <- as.matrix(
        read.csv(
            system.file("extdata", "tclust", "mu_MATLAB.csv", package = "fsdabridge"),
            header = FALSE
        )
    )
    storage.mode(matlab_mu) <- "double"

    matlab_obj <- as.numeric(
        read.csv(
            system.file("extdata", "tclust", "obj_MATLAB.csv", package = "fsdabridge"),
            header = FALSE
        )[[1]]
    )

    # siz is a (k+1) x 3 matrix in MATLAB: label | size | percentage
    matlab_siz <- as.matrix(
        read.csv(
            system.file("extdata", "tclust", "siz_MATLAB.csv", package = "fsdabridge"),
            header = FALSE
        )
    )
    storage.mode(matlab_siz) <- "double"

    matlab_idx <- as.integer(
        as.numeric(
            read.csv(
                system.file("extdata", "tclust", "idx_MATLAB.csv", package = "fsdabridge"),
                header = FALSE
            )[[1]]
        )
    )

    # -------------------------------------------------------------------
    # Normalize R-side shapes before comparing
    # -------------------------------------------------------------------
    result_idx <- as.integer(as.vector(result$idx))

    # -------------------------------------------------------------------
    # Align cluster labels between R and MATLAB (order is arbitrary)
    # -------------------------------------------------------------------
    perm <- match_labels(result$muopt, matlab_mu)

    mu_aligned <- result$muopt[perm, , drop = FALSE]

    # map: old R label -> aligned label (1..k); 0 (trimmed) stays 0
    relabel_map <- setNames(seq_along(perm), perm)
    idx_aligned <- ifelse(
        result_idx == 0,
        0L,
        as.integer(relabel_map[as.character(result_idx)])
    )

    # siz: row 1 is the trimmed group (label 0), keep as-is;
    # remaining rows follow the same permutation as the clusters
    siz_aligned <- result$siz[c(1, perm + 1), , drop = FALSE]

    # -------------------------------------------------------------------
    # Assertions
    # -------------------------------------------------------------------
    expect_lt(
        max(abs(mu_aligned - matlab_mu)),
        1e-9
    )

    expect_lt(
        abs(result$obj - matlab_obj),
        1e-9
    )

    # compare sizes/percentages only (column 1 is just the label convention)
    expect_equal(
        siz_aligned[, 2:3],
        matlab_siz[, 2:3],
        check.attributes = FALSE
    )

    expect_equal(
        idx_aligned,
        matlab_idx
    )
})
