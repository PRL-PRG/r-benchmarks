# Matrix-Matrix multiply of two n x n matrices, built-in %*% operator.
# Ported from the RB `mathkernel` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the two matrices inside the timed kernel, which for this variant
# cost more than the multiply itself: setup() draws them and leaves them in
# `.data` instead. They are not cached on disk: 2n^2 normals are drawn faster
# than the file is read back (see harness.R). The T1/T2/T3 variants draw the same
# matrices from the same seed, but not at the same n - the loops and BLAS differ
# by orders of magnitude and no single n makes both measurable.

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function(n = 200L) {
    set.seed(42L)
    A <- matrix(rnorm(n * n), ncol = n, nrow = n)
    B <- matrix(rnorm(n * n), ncol = n, nrow = n)
    .data <<- list(A = A, B = B)
    invisible()
}

execute <- function(n = 200L) {
    cat("Matrix-Matrix Multiply of two", n, "x", n, "matrices, built-in %*%\n")
    A <- .data$A
    B <- .data$B
    C <- A %*% B
    invisible(C)
}
