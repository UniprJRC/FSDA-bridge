match_labels_km <- function(mu_r, mu_matlab) {
    k <- nrow(mu_r)
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

test_that("KMEANS matches MATLAB benchmark", {
    skip_if_not(
        identical(Sys.getenv("FSDA_LIVE"), "1"),
        "set FSDA_LIVE=1 to run the live MATLAB/FSDA test"
    )

    data_path <- system.file("extdata", "geyser2.txt", package = "fsdabridge")
    Y <- as.matrix(read.table(data_path, header = FALSE))
    storage.mode(Y) <- "double"

    result <- fsda_kmeans(Y, k = 3, replicates = 10, seed = 0)

    matlab_mu <- as.matrix(read.csv(
        system.file("extdata", "kmeans", "mu_MATLAB_kmeans.csv", package = "fsdabridge"),
        header = FALSE
    ))
    storage.mode(matlab_mu) <- "double"

    matlab_obj <- as.numeric(read.csv(
        system.file("extdata", "kmeans", "obj_MATLAB_kmeans.csv", package = "fsdabridge"),
        header = FALSE
    )[[1]])
    # MATLAB stores obj per-cluster (length k); R's result$obj is the total
    # across clusters, so sum before comparing.
    matlab_obj_total <- sum(matlab_obj)

    matlab_siz <- as.matrix(read.csv(
        system.file("extdata", "kmeans", "siz_MATLAB_kmeans.csv", package = "fsdabridge"),
        header = FALSE
    ))
    storage.mode(matlab_siz) <- "double"

    matlab_idx <- as.integer(as.numeric(read.csv(
        system.file("extdata", "kmeans", "idx_MATLAB_kmeans.csv", package = "fsdabridge"),
        header = FALSE
    )[[1]]))

    result_idx <- as.integer(as.vector(result$idx))

    perm <- match_labels_km(result$C, matlab_mu)
    mu_aligned <- result$C[perm, , drop = FALSE]

    relabel_map <- setNames(seq_along(perm), perm)
    idx_aligned <- as.integer(relabel_map[as.character(result_idx)])

    siz_aligned <- result$siz[perm, , drop = FALSE]

    expect_lt(max(abs(mu_aligned - matlab_mu)), 1e-9)
    expect_lt(abs(result$obj - matlab_obj_total), 1e-9)

    expect_equal(
        siz_aligned[, 2:3],
        matlab_siz[, 2:3],
        ignore_attr = TRUE
    )

    expect_equal(idx_aligned, matlab_idx)
})
