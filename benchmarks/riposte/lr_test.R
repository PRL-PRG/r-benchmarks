# Logistic regression via the built-in glm (native library glue).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# setup() generates data/lr.rds (shared with lr.R) on first run (idempotent;
# reused if present), reads it into `.data` and is not timed; execute() only reads
# `.data`, so the load is not part of the measurement. doctor() reports what
# setup() needs.
#
# The size parameter is the number of times the fit is repeated: the workload is
# otherwise fixed by the data file (one glm over 50,000 x 30 takes 594 ms), and
# the data is shared with lr.R, so it cannot be resized here.

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

execute <- function(rep = 3L) {
    cat('[lr_test]rep =', rep, '\n')
    p <- .data$p
    r <- .data$r
    for (k in 1:rep) {
        res <- glm(r ~ p - 1, family = binomial(link = "logit"))
    }
    cat(length(coef(res)), '\n')
    invisible(res)
}
