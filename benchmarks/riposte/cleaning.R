# Outlier detection over a length-n vector via z-scores (vector code).
# Ported from the RB `riposte` suite (changed by hwang154@illinois.edu).
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).

execute <- function(n = 20000000L) {
    cat('[cleaning]n =', n, '\n')
    data <- as.double(1:n)

    z.score <- function(data, m = mean(data), stdev = sd(data)) {
        (data - m) / stdev
    }

    outliers <- function(data, ignore) {
        use <- !ignore(data)
        z <- z.score(data, mean(data[use]), sd(data[use]))
        sum(abs(z) > 1)
    }

    r <- outliers(data, function(x) { is.na(x) | x == 9999 })
    cat(r, '\n')
    invisible(r)
}
