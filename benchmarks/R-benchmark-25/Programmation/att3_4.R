# R-benchmark-25 (ATT) III.4: creation of a 500x500 Toeplitz matrix (nested loops).
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).

execute <- function(runs = 3L) {
    cat("Creation of a 500x500 Toeplitz matrix (loops)\n")
    for (i in 1:runs) {
        b <- rep(0, 500 * 500)
        dim(b) <- c(500, 500)
        for (j in 1:500) {
            for (k in 1:500) {
                jk <- j - k
                b[k, j] <- abs(jk) + 1
            }
        }
    }
    invisible(NULL)
}
