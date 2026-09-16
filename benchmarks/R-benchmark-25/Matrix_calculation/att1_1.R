# R-benchmark-25 (ATT) I.1: 2500x2500 random matrix raised to the power 1000.
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the input again inside every one of the `runs` repeats, so a
# large share of what this benchmark measured was the random number generator
# rather than the elementwise power. setup() draws it once into `.data`. It is
# not cached on disk: 6.25M normals are drawn faster than the file is read back
# (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    .data <<- rnorm(2500 * 2500)
    invisible()
}

execute <- function(runs = 3L) {
    cat("2500x2500 normal distributed random matrix ^1000\n")
    x <- .data
    for (i in 1:runs) {
        a <- abs(matrix(x / 2, ncol = 2500, nrow = 2500))
        b <- a^1000
    }
    invisible(NULL)
}
