# Sparse matrix-vector multiplication using the Matrix package builtin %*%.
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
# Depends on the Matrix package; see doctor().
#
# The size parameter is the number of times the kernel is repeated, not the
# number of nonzeros: one `m %*% v` over N = 10 million nonzeros takes 250 ms,
# and reaching a second by growing N would cost 16 s of sparse assembly per run
# (which is what an earlier size did, for a 460 MB cache file). N stays at the
# 10 million this benchmark was ported with.
#
# Upstream assembled the matrix inside the timed kernel, where it was over half
# of the measurement; setup() builds it into `.data` instead. This is the one
# input in the suite worth a file: assembling it costs several seconds against
# well under one to read it back, so setup() caches it under data/.

.N <- 10000000L
.inputs <- sprintf("data/smv_builtin-%d.rds", .N)
.data <- NULL       # filled by setup(); execute() only reads it

doctor <- function() {
    if (requireNamespace("Matrix", quietly = TRUE)) TRUE
    else "R package 'Matrix' is required"
}

setup <- function() {
    library(Matrix)   # must precede readRDS: the cache holds an S4 dgCMatrix
    if (file.exists(.inputs)) {
        .data <<- readRDS(.inputs)               # reuse existing input
        return(invisible())
    }
    set.seed(42L)
    m <- sparseMatrix(
        as.integer(runif(.N, 1, .N)),
        sort(as.integer(runif(.N, 1, .N))),
        x = runif(.N),
        dims = c(.N, .N))
    v <- runif(.N)
    .data <<- list(m = m, v = v)
    dir.create("data", showWarnings = FALSE)
    saveRDS(.data, .inputs, compress = FALSE)
    invisible()
}

execute <- function(rep = 6L) {
    cat('[smv_builtin]n =', .N, 'rep =', rep, '\n')
    m <- .data$m
    v <- .data$v

    smv <- function(m, v) {
        m %*% v
    }

    for (k in 1:rep) {
        res <- smv(m, v)
    }
    cat(length(res), '\n')
    invisible(res)
}
