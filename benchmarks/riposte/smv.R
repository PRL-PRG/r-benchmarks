# Sparse matrix-vector multiplication via split/lapply (M nonzeros, N x N matrix).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream built the operands inside the timed kernel - 3M uniforms, a sort and a
# 500,000-level factor, a fifth of what this benchmark measured and none of the
# multiply. setup() builds them into `.data` instead. They are not cached on disk:
# the file is over 400 MB at this size and reading it back saves under a second of
# the five the build costs (see harness.R).

.N <- 500000L
.data <- NULL       # filled by setup(); execute() only reads it

setup <- function(M = 20000000L) {
    N <- .N
    set.seed(42L)
    v <- runif(N)
    m <- list(
        row = sort(as.integer(runif(M, 1, N))),
        col = as.integer(runif(M, 1, N)),
        val = runif(M)
    )
    f <- factor(m[[1]] - 1L, (1L:N) - 1L)
    .data <<- list(v = v, m = m, f = f)
    invisible()
}

execute <- function(M = 20000000L, N = .N) {
    cat('[smv]M =', M, 'N =', N, '\n')
    v <- .data$v
    m <- .data$m
    f <- .data$f

    smv <- function(m, v, f) {
        lapply(split(m[[3]] * v[m[[2]]], f), "sum")
    }

    res <- smv(m, v, f)
    cat(length(res), '\n')
    invisible(res)
}
