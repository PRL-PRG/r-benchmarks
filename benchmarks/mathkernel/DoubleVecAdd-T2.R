# Element-wise add of two length-N double vectors, built-in + operator.
# Ported from the RB `mathkernel` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# The size parameter is the number of times the kernel is repeated, not the
# vector length. One `A + B` over 10 million doubles takes 65 ms, and the only
# way to reach a measurable second by growing N is to draw gigabytes of input -
# which would measure the memory system, and would put the draw rather than the
# add into a profiled recording. N is upstream's 10 million.
#
# Upstream drew the two vectors inside the timed kernel; setup() draws them into
# `.data` instead. They are not cached on disk: drawing 2N normals is no slower
# than reading them back (see harness.R). T1 and T2 use the same N and the same
# seed, so the iterative and the built-in variant add the same numbers.

.N <- 10000000L
.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    A <- rnorm(.N)
    B <- rnorm(.N)
    .data <<- list(A = A, B = B)
    invisible()
}

execute <- function(rep = 24L) {
    cat("Vector Add two", .N, "size vectors, built-in +, x", rep, "\n")
    A <- .data$A
    B <- .data$B
    for (k in 1:rep) {
        C <- A + B
    }
    invisible(C)
}
