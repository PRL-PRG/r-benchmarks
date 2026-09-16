# K-means (K=5) over an N x 2 data set, `reps` iterations (vector code).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# setup() generates data/kmeans.rds on first run (idempotent; reused if present),
# reads it into `.data` and is not timed; execute() only reads `.data`, so the
# load is not part of the measurement. The file is worth keeping: the mixture is
# far more expensive to draw than to read back, and it needs MASS, which doctor()
# reports when the data is absent.

.data <- NULL       # filled by setup(); execute() only reads it

doctor <- function() {
    if (file.exists("data/kmeans.rds")) return(TRUE)
    if (!requireNamespace("MASS", quietly = TRUE))
        "need R package MASS to generate data/kmeans.rds"
    else TRUE
}

setup <- function() {
    if (file.exists("data/kmeans.rds")) {
        .data <<- readRDS("data/kmeans.rds")                 # reuse existing data
        return(invisible())
    }
    set.seed(42L)
    library(MASS)
    N <- 1000000L
    dir.create("data", showWarnings = FALSE)
    a <- rbind(
        mvrnorm(N / 5, c(0, 0), matrix(c(1, 0, 0, 1), 2, 2)),
        mvrnorm(N / 5, c(4, 0), matrix(c(0.5, 0, 0, 0.5), 2, 2)),
        mvrnorm(N / 5, c(0, 4), matrix(c(1, 0, 0, 1), 2, 2)),
        mvrnorm(N / 5, c(2, 2), matrix(c(0.25, 0.2, 0.2, 0.25), 2, 2)),
        mvrnorm(N / 5, c(1, 0), matrix(c(0.25, 0.22, 0.22, 0.25), 2, 2))
    )
    saveRDS(a, "data/kmeans.rds", compress = FALSE)
    .data <<- a
    invisible()
}

execute <- function(N = 1000000L, reps = 10L) {
    cat('[kmeans]N =', N, 'reps =', reps, '\n')
    K <- 5L

    a <- .data

    means <- list(a[1, ], a[2, ], a[3, ], a[4, ], a[5, ])

    assignment <- function(data, means) {
        min.value <- Inf
        min.index <- 0L
        for (k in 1L:length(means)) {
            d2 <- 0
            for (j in 1L:ncol(data)) {
                d2 <- d2 + (data[, j] - means[[k]][j])^2
            }
            min.index <- ifelse(d2 < min.value, k, min.index)
            min.value <- pmin(d2, min.value)
        }
        min.index
    }

    update.means <- function(data, index) {
        means <- list()
        for (i in 1L:ncol(data)) {
            means[[i]] <- lapply(split(data[, i], index - 1L, K), "mean")
        }
        means
    }

    for (i in 1L:reps) {
        m <- update.means(a, assignment(a, means))
        # reorganize means from SoA to AoS
        for (i in 1L:K) {
            means[[i]] <- c(m[[1]][[i]], m[[2]][[i]])
        }
    }

    for (i in 1L:K) cat(means[[i]], "\n")
    invisible(means)
}
