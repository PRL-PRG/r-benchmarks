# Matrix-Matrix multiply of two n x n matrices, row-times-column vector method.
# Ported from the RB `mathkernel` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the two matrices inside the timed kernel; setup() draws them and
# leaves them in `.data` instead, so what is measured is the multiply. They are
# not cached on disk: 2n^2 normals are drawn faster than the file is read back
# (see harness.R). The T1/T2/T3 variants draw the same matrices from the same
# seed, but not at the same n - the loops and BLAS differ by orders of magnitude
# and no single n makes both measurable.

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function(n = 200L) {
    set.seed(42L)
    A <- matrix(rnorm(n * n), ncol = n, nrow = n)
    B <- matrix(rnorm(n * n), ncol = n, nrow = n)
    .data <<- list(A = A, B = B)
    invisible()
}

execute <- function(n = 200L) {
    cat("Matrix-Matrix Multiply of two", n, "x", n, "matrices, vector method\n")
    A <- .data$A
    B <- .data$B
    C <- matrix(n * n, ncol = n, nrow = n)
    for (i in 1:n) {
        for (j in 1:n) {
            C[i, j] <- A[i, ] %*% B[, j]
        }
    }
    invisible(C)
}
