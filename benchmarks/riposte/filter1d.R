# 1D convolution filter over a length-n vector (subsetting + length-changing).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the input inside the timed kernel, where it was a seventh of what
# this benchmark measured and none of the filter. setup() draws it into `.data`
# instead. It is not cached on disk: n uniforms are drawn in a third of the time
# the file takes to read back (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function(n = 10000000L) {
    set.seed(42L)
    .data <<- runif(n)
    invisible()
}

execute <- function(n = 10000000L) {
    cat('[filter1d]n =', n, '\n')
    a <- .data

    filter <- function(v, f) {
        r <- 0
        for (i in 1L:length(f)) {
            r <- r + v[(1L + i):((length(v) - length(f)) + i)] * f[i]
        }
        r
    }

    res <- filter(a, c(0.1, 0.15, 0.2, 0.3, 0.2, 0.15, 0.1))
    r <- length(res)
    cat(r, '\n')
    invisible(r)
}
