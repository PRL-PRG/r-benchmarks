# R-benchmark-25 (ATT) I.3: 2800x2800 cross-product matrix (b = a' * a).
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the input again inside every one of the `runs` repeats, so part
# of what this benchmark measured was the random number generator rather than the
# cross product. setup() draws it once into `.data`. It is not cached on disk:
# 7.84M normals are drawn faster than the file is read back (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    .data <<- rnorm(2800 * 2800)
    invisible()
}

execute <- function(runs = 3L) {
    cat("2800x2800 cross-product matrix (b = a' * a)\n")
    x <- .data
    for (i in 1:runs) {
        a <- x
        dim(a) <- c(2800, 2800)
        b <- crossprod(a)  # equivalent to: b <- t(a) %*% a
    }
    invisible(NULL)
}
