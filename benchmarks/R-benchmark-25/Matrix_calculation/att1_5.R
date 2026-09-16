# R-benchmark-25 (ATT) I.5: linear regression over a 2000x2000 matrix (c = a \ b').
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
# Depends on the Matrix package (dgeMatrix); see doctor().
#
# Upstream drew the input again inside every one of the `runs` repeats, so part
# of what this benchmark measured was the random number generator rather than the
# linear solve. setup() draws it once into `.data`; wrapping it in a dgeMatrix
# stays in the kernel, where upstream had it. It is not cached on disk: 4M
# normals are drawn faster than the file is read back (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

doctor <- function() {
    if (requireNamespace("Matrix", quietly = TRUE)) TRUE
    else "R package 'Matrix' is required"
}

setup <- function() {
    library(Matrix)   # here, not in execute(): attaching it deserialises the
                      # package's lazy-load database, which is not the kernel
    set.seed(42L)
    .data <<- rnorm(2000 * 2000)
    invisible()
}

execute <- function(runs = 3L) {
    cat("Linear regr. over a 2000x2000 matrix (c = a \\ b')\n")
    x <- .data
    for (i in 1:runs) {
        a <- new("dgeMatrix", x = x, Dim = as.integer(c(2000, 2000)))
        b <- as.double(1:2000)
        c <- solve(crossprod(a), crossprod(a, b))
    }
    invisible(NULL)
}
