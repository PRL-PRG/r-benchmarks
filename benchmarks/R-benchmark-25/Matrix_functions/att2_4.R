# R-benchmark-25 (ATT) II.4: Cholesky decomposition of a 3000x3000 matrix.
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
# Depends on the Matrix package (dgeMatrix); see doctor().
#
# setup() builds the input into `.data`: the random draw, and the crossproduct
# that turns it into the positive-definite matrix `chol` needs. Upstream did both
# inside the timed kernel, where the crossproduct - 54 GFlop against the 9 GFlop
# of the decomposition - was four fifths of what this benchmark reported as the
# cost of a Cholesky decomposition.
#
# This input is worth a file: building it takes 19 s (nearly all of it the
# crossproduct) against 0.7 s to read the 72 MB back, so setup() caches it under
# data/ - unlike the benchmarks whose input is a plain RNG draw (see harness.R).

.inputs <- "data/att2_4.rds"
.data <- NULL       # filled by setup(); execute() only reads it

doctor <- function() {
    if (requireNamespace("Matrix", quietly = TRUE)) TRUE
    else "R package 'Matrix' is required"
}

setup <- function() {
    library(Matrix)   # must precede readRDS: the cache holds an S4 dpoMatrix
    if (file.exists(.inputs)) {
        .data <<- readRDS(.inputs)               # reuse existing input
        return(invisible())
    }
    set.seed(42L)
    x <- rnorm(3000 * 3000)
    .data <<- crossprod(new("dgeMatrix", x = x, Dim = as.integer(c(3000, 3000))))
    dir.create("data", showWarnings = FALSE)
    saveRDS(.data, .inputs, compress = FALSE)
    invisible()
}

execute <- function(runs = 1L) {
    cat("Cholesky decomposition of a 3000x3000 matrix\n")
    for (i in 1:runs) {
        # Matrix stores a factorization in the object it factored, so factoring
        # the same matrix twice returns the first result instead of doing the
        # work - the second iteration would take 2 ms. Each repeat therefore
        # starts from an unfactored copy, as upstream's did: it built a fresh
        # matrix every time (and paid a 54 GFlop crossproduct for it).
        a <- .data
        a@factors <- list()
        b <- chol(a)
    }
    invisible(NULL)
}
