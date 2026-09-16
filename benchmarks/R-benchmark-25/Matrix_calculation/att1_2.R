# R-benchmark-25 (ATT) I.2: creation, transpose, deformation of a 2500x2500 matrix.
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the input again inside every one of the `runs` repeats, so a
# large share of what this benchmark measured was the random number generator
# rather than the transpose and reshape. setup() draws it once into `.data`. It
# is not cached on disk: 6.25M normals are drawn faster than the file is read
# back (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    .data <<- rnorm(2500 * 2500)
    invisible()
}

execute <- function(runs = 3L) {
    cat("Creation, transp., deformation of a 2500x2500 matrix\n")
    x <- .data
    for (i in 1:runs) {
        a <- matrix(x / 10, ncol = 2500, nrow = 2500)
        b <- t(a)
        dim(b) <- c(1250, 5000)
        a <- t(b)
    }
    invisible(NULL)
}
