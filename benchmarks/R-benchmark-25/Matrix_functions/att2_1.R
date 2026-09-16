# R-benchmark-25 (ATT) II.1: FFT over 2,400,000 random values.
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the input again inside every one of the `runs` repeats, so a
# large share of what this benchmark measured was the random number generator
# rather than the FFT. setup() draws it once into `.data`. It is not cached on
# disk: 2.4M normals are drawn faster than the file is read back (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    .data <<- rnorm(2400000)
    invisible()
}

execute <- function(runs = 3L) {
    cat("FFT over 2,400,000 random values\n")
    a <- .data
    for (i in 1:runs) {
        b <- fft(a)
    }
    invisible(NULL)
}
