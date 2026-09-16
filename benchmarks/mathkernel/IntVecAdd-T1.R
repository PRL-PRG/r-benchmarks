# Element-wise add of two length-N integer vectors, iterative method.
# Ported from the RB `mathkernel` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# The size parameter is the number of times the kernel is repeated, not the
# vector length: N is upstream's 10 million, so that this variant and the
# built-in `+` of T2 add the same numbers (see DoubleVecAdd-T2.R).
#
# Upstream built the two vectors inside the timed kernel; setup() builds them
# into `.data` instead. They are not cached on disk (see harness.R).

.N <- 10000000L
.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    A <- as.integer(rnorm(.N) * 1000)
    B <- as.integer(rnorm(.N) * 1000)
    .data <<- list(A = A, B = B)
    invisible()
}

execute <- function(rep = 2L) {
    cat("Vector Add two integer", .N, "size vectors, iterative method, x", rep, "\n")
    A <- .data$A
    B <- .data$B
    for (k in 1:rep) {
        C <- vector("double", .N)
        for (i in 1:.N) {
            C[i] <- A[i] + B[i]
        }
    }
    invisible(C)
}
