# Logistic regression via hand-coded gradient descent (vector code).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# setup() generates data/lr.rds (list of p, r, w, wi) on first run (idempotent;
# reused if present), reads it into `.data` and is not timed; execute() only reads
# `.data`, so the load is not part of the measurement. The file is worth keeping:
# generating the data costs far more than reading it back, and it needs
# clusterGeneration and MASS, which doctor() reports when the data is absent.

.data <- NULL       # filled by setup(); execute() only reads it

doctor <- function() {
    if (file.exists("data/lr.rds")) return(TRUE)
    missing <- Filter(function(p) !requireNamespace(p, quietly = TRUE),
                      c("clusterGeneration", "MASS"))
    if (length(missing))
        paste0("need R package(s) ", paste(missing, collapse = ", "),
               " to generate data/lr.rds")
    else TRUE
}

setup <- function() {
    if (file.exists("data/lr.rds")) {
        .data <<- readRDS("data/lr.rds")                     # reuse existing data
        return(invisible())
    }
    set.seed(42L)
    library(clusterGeneration)
    library(MASS)
    N <- 50000L
    D <- 30L
    dir.create("data", showWarnings = FALSE)
    cov.matrix <- genPositiveDefMat(D - 1, ratioLambda = 100)
    p <- scale(mvrnorm(N, rep(0, D - 1), cov.matrix$Sigma))
    p <- cbind(rep(1, N), p)
    w <- rnorm(D)
    r <- as.double(((p %*% w) + rnorm(N, 0, 10)) > 0)
    wi <- rnorm(D)
    .data <<- list(p = p, r = r, w = w, wi = wi)
    saveRDS(.data, "data/lr.rds", compress = FALSE)
    invisible()
}

execute <- function(N = 50000L, reps = 100L) {
    cat('[lr]N =', N, 'reps =', reps, '\n')
    D <- 30L

    p <- .data$p
    r <- .data$r
    wi <- .data$wi

    update <- function(w) {
        diff <- 1 / (1 + exp(p %*% w)) - r
        grad <- double(D)
        for (i in 1L:D) {
            grad[i] <- mean((p[, i] * diff))
        }
        grad
    }

    w <- wi
    epsilon <- 0.07
    for (j in 1L:reps) {
        grad <- update(w)
        delta <- grad * epsilon
        w <- w - delta
    }

    cat(length(w), '\n')
    invisible(w)
}
