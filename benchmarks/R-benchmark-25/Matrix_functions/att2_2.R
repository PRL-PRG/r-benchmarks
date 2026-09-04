# R-benchmark-25 (ATT) II.2: eigenvalues of a 600x600 random matrix.
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the input again inside every one of the `runs` repeats; setup()
# draws it once into `.data` instead, so what is measured is the
# eigendecomposition. It is not cached on disk: 360k normals cost under 10 ms to
# draw, which no file round trip beats (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    .data <<- rnorm(600 * 600)
    invisible()
}

execute <- function(runs = 3L) {
    cat("Eigenvalues of a 600x600 random matrix\n")
    x <- .data
    for (i in 1:runs) {
        a <- array(x, dim = c(600, 600))
        b <- eigen(a, symmetric = FALSE, only.values = TRUE)$Value
    }
    invisible(NULL)
}
