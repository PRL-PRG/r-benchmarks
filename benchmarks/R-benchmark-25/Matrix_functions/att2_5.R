# R-benchmark-25 (ATT) II.5: inverse of a 1600x1600 random matrix.
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
# Depends on the Matrix package (dgeMatrix); see doctor().
#
# Upstream drew the input again inside every one of the `runs` repeats; setup()
# draws it once into `.data` instead, so what is measured is the inverse. It is
# not cached on disk: 2.56M normals are drawn faster than the file is read back
# (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

doctor <- function() {
    if (requireNamespace("Matrix", quietly = TRUE)) TRUE
    else "R package 'Matrix' is required"
}

setup <- function() {
    library(Matrix)   # here, not in execute(): attaching it deserialises the
                      # package's lazy-load database, which is not the kernel
    set.seed(42L)
    .data <<- rnorm(1600 * 1600)
    invisible()
}

execute <- function(runs = 3L) {
    cat("Inverse of a 1600x1600 random matrix\n")
    x <- .data
    for (i in 1:runs) {
        a <- new("dgeMatrix", x = x, Dim = as.integer(c(1600, 1600)))
        b <- solve(a)
    }
    invisible(NULL)
}
