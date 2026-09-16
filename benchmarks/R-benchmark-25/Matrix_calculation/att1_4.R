# R-benchmark-25 (ATT) I.4: sorting of 7,000,000 random values.
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the input again inside every one of the `runs` repeats, so a
# large share of what this benchmark measured was the random number generator
# rather than the sort. setup() draws it once into `.data`. It is not cached on
# disk: 7M normals are drawn faster than the file is read back (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    .data <<- rnorm(7000000)
    invisible()
}

execute <- function(runs = 3L) {
    cat("Sorting of 7,000,000 random values\n")
    a <- .data
    for (i in 1:runs) {
        b <- sort(a, method = "quick")
    }
    invisible(NULL)
}
