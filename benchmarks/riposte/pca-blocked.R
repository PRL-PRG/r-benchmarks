# PCA via covariance matrix, cache-blocked variant, N x 50 data matrix (vector code).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# setup() generates data/pca.rds on first run (idempotent; reused if present),
# reads it into `.data` and is not timed; execute() only reads `.data`, so the load
# is not part of the measurement. The file is worth keeping: generating the data
# costs far more than reading it back, and it needs clusterGeneration and MASS,
# which doctor() reports when the data is absent.

.data <- NULL       # filled by setup(); execute() only reads it

doctor <- function() {
    if (file.exists("data/pca.rds")) return(TRUE)
    missing <- Filter(function(p) !requireNamespace(p, quietly = TRUE),
                      c("clusterGeneration", "MASS"))
    if (length(missing))
        paste0("need R package(s) ", paste(missing, collapse = ", "),
               " to generate data/pca.rds")
    else TRUE
}

setup <- function() {
    if (file.exists("data/pca.rds")) {
        .data <<- readRDS("data/pca.rds")                    # reuse existing data
        return(invisible())
    }
    set.seed(42L)
    library(clusterGeneration)
    library(MASS)
    N <- 100000L
    D <- 50L
    dir.create("data", showWarnings = FALSE)
    cov.matrix <- genPositiveDefMat(D, ratioLambda = 100)
    a <- mvrnorm(N, rep(0, D), cov.matrix$Sigma)
    dim(a) <- c(N, D)
    saveRDS(a, "data/pca.rds", compress = FALSE)
    .data <<- a
    invisible()
}

execute <- function(N = 100000L) {
    cat('[pca-blocked]N =', N, '\n')

    a <- .data

    cov <- function(a, b) {
        if (!all(dim(a) == dim(b))) stop("matrices must be same shape")

        m <- nrow(a)
        n <- ncol(a)

        ma <- double(n)
        mb <- double(n)
        for (i in 1L:n) {
            ma[[i]] <- mean(a[, i])
            mb[[i]] <- mean(b[, i])
        }

        bs <- 6
        r <- double(2500)
        for (ii in 1L:ceiling(n / bs)) {
            for (jj in 1L:ceiling(n / bs)) {
                for (io in 1L:bs) {
                    for (jo in 1L:bs) {
                        i <- as.integer((ii - 1) * bs + (io - 1) + 1)
                        j <- as.integer((jj - 1) * bs + (jo - 1) + 1)
                        if (j >= i && i <= n && j <= n) {
                            k <- sum((a[, i] - ma[[i]]) * (b[, j] - mb[[j]]))
                            r[[(i - 1L) * n + j]] <- k
                            r[[(j - 1L) * n + i]] <- k
                        }
                    }
                }
            }
        }
        r <- r / (m - 1)
        dim(r) <- c(n, n)
        r
    }

    pca <- function(a) cov(a, a)

    res <- pca(a)
    cat(length(res), '\n')
    invisible(length(res))
}
