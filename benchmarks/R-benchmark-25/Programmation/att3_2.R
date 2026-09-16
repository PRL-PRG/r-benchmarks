# R-benchmark-25 (ATT) III.2: creation of a 3000x3000 Hilbert matrix (matrix calc).
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).

execute <- function(runs = 3L) {
    cat("Creation of a 3000x3000 Hilbert matrix (matrix calc)\n")
    a <- 3000
    for (i in 1:runs) {
        b <- rep(1:a, a)
        dim(b) <- c(a, a)
        b <- 1 / (t(b) + 0:(a - 1))
    }
    invisible(NULL)
}
