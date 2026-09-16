# R-benchmark-25 (ATT) III.3: greatest common divisors of 400,000 pairs (recursion).
# `runs` repeats the kernel. Ported from the RB `R-benchmark-25` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# Upstream drew the two operand vectors again inside every one of the `runs`
# repeats; setup() draws them once into `.data` instead, so what is measured is
# the recursive gcd. They are not cached on disk: 800k uniforms cost a few ms to
# draw, which no file round trip beats (see harness.R).

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    a <- ceiling(runif(400000) * 1000)
    b <- ceiling(runif(400000) * 1000)
    .data <<- list(a = a, b = b)
    invisible()
}

execute <- function(runs = 3L) {
    cat("Grand common divisors of 400,000 pairs (recursion)\n")
    gcd2 <- function(x, y) {
        if (sum(y > 1.0E-4) == 0) x
        else { y[y == 0] <- x[y == 0]; Recall(y, x %% y) }
    }
    a <- .data$a
    b <- .data$b
    for (i in 1:runs) {
        c <- gcd2(a, b)  # gcd2 is a recursive function
    }
    invisible(NULL)
}
