# Element-wise add of two length-N double vectors (10% NA), built-in + operator.
# Ported from the RB `mathkernel` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# The size parameter is the number of times the kernel is repeated, not the
# vector length: one `A + B` over 10 million doubles is far too short to measure
# on its own, and growing N would measure the memory system instead. N is
# upstream's 10 million, the same as T1 (see DoubleVecAdd-T2.R).
#
# Upstream drew the vectors and punched the NAs in inside the timed kernel;
# setup() builds them into `.data` instead. They are not cached on disk (see
# harness.R).

.N <- 10000000L
.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    A <- rnorm(.N)
    B <- rnorm(.N)
    idx <- runif(.N * 0.1, 1, .N)  # 10% are NA
    A[idx] <- NA
    idx <- runif(.N * 0.1, 1, .N)  # 10% are NA
    B[idx] <- NA
    .data <<- list(A = A, B = B)
    invisible()
}

execute <- function(rep = 24L) {
    cat("Vector Add two", .N, "size vectors(10% NA), built-in +, x", rep, "\n")
    A <- .data$A
    B <- .data$B
    for (k in 1:rep) {
        C <- A + B
    }
    invisible(C)
}
