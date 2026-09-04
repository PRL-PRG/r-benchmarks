# Householder QR decomposition of an N x N matrix (vector code).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# NOTE: this benchmark relies on riposte-VM-specific semantics for `strip`,
# `outer` and `rep` and does NOT run under GNU R (it errors on an NA pivot) -
# it was already broken in stock R in the original RB repo. It is kept here for
# completeness but is intentionally NOT registered as a runnable benchmark in
# rbench.py. The `strip` shim below covers only the dropped-dims builtin.

execute <- function(N = 1000L) {
    set.seed(42L)
    cat('[qr]N =', N, '\n')
    m <- runif(N * N)
    dim(m) <- c(N, N)

    strip <- function(x) { dim(x) <- NULL; x }  # riposte builtin: drop dims/attributes

    mv <- function(m, v) {
        r <- 0
        for (i in 1L:ncol(m)) {
            r <- r + m[, i] * v[[i]]
        }
        r
    }

    vm <- function(v, m) {
        r <- 0
        for (i in 1L:ncol(m)) {
            r <- r + m[i, ] * v[[i]]
        }
        r
    }

    outer <- function(v) {
        v[rep(length(v), 1L, length(v)^2)] * v[rep(length(v), length(v), length(v)^2)]
    }

    myqr <- function(m) {
        for (i in 1L:ncol(m)) {
            a <- (m[, i])[i:nrow(m)]
            n <- -sign(m[, i][i]) * sqrt(sum(a * a))
            v <- ifelse(1:nrow(m) < i, 0,
                    ifelse(1:nrow(m) == i, m[i, i] - n, m[, i]))
            b <- sum(v * v)
            if (b == 0) next
            m <- strip(m) - 2 / b * outer((vm(v, m)))
            dim(m) <- c(N, N)
        }
        m
    }

    res <- myqr(m)
    cat(length(res), '\n')
    invisible(res)
}
