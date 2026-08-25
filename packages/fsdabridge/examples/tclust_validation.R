library(fsdabridge)

set.seed(123)

n <- 100
p <- 2

cluster1 <- matrix(
    rnorm(n / 3 * p, mean = 0, sd = 1),
    ncol = p
)

cluster2 <- matrix(
    rnorm(n / 3 * p, mean = 5, sd = 1),
    ncol = p
)

cluster3 <- matrix(
    rnorm(n / 3 * p, mean = -5, sd = 1),
    ncol = p
)

X <- rbind(
    cluster1,
    cluster2,
    cluster3
)

storage.mode(X) <- "double"

result <- fsda_tclust(
    X,
    k = 3,
    alpha = 0.05
)
