# R-benchmark-25 (ATT) III.1: 3,500,000 Fibonacci numbers (vector calc).
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the exponents again inside every one of the `runs` repeats, so
# part of what this benchmark measured was the random number generator rather
# than the vectorised Fibonacci formula. setup() draws them once into `.data`.
# They are not cached on disk: 3.5M uniforms are drawn faster than the file is
# read back (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    .data <<- floor(runif(3500000) * 1000)
    invisible()
}

execute <- function(runs = 3L) {
    cat("3,500,000 Fibonacci numbers calculation (vector calc)\n")
    phi <- 1.6180339887498949
    a <- .data
    for (i in 1:runs) {
        b <- (phi^a - (-phi)^(-a)) / sqrt(5)
    }
    invisible(NULL)
}
