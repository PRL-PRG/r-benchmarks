# Filter + mean over paired length-n vectors (vector code).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).

execute <- function(n = 20000000L) {
    cat('[example]n =', n, '\n')
    data <- list(
        as.double(1:n),
        as.double(1:n)
    )

    bin <- function(x) { ifelse(x > 0, 1, ifelse(x < 0, -1, 0)) }
    ignore <- function(x) { is.na(x) | x == 9999 }

    clean <- function(data) {
        data[[2]][!ignore(data[[1]]) & bin(data[[1]]) == 1]
    }

    r <- mean(clean(data))
    cat(r, '\n')
    invisible(r)
}
