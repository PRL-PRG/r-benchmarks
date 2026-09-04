# Sample a mixture of gaussians via a rational approximation of the inverse CDF.
# http://home.online.no/~pjacklam/notes/invnorm/
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# setup() draws the component index into `.data`; execute() times only the
# sampling. The `runif(n)` inside the local `rnorm` stays where it is: it is what
# this variant substitutes for the builtin. The index is not cached on disk: 2n
# uniforms are drawn faster than the file is read back (see harness.R).
#
# Two details keep this equivalent to the original. The upstream program also drew
# a length-n vector `a` that it never used, so setup() still draws it and the
# stream reaching `i` is unchanged; and this kernel itself consumes randomness, so
# setup() records the RNG state the original kernel would have started from and
# execute() restores it, which also makes the repeated iterations identical.

.data <- NULL       # filled by setup(); execute() only reads it

setup <- function(n = 10000000L) {
    set.seed(42L)
    a <- runif(n)                                # unused upstream; keeps the stream
    i <- floor(runif(n) * 3) + 1L
    .data <<- list(i = i, seed = .Random.seed)
    invisible()
}

execute <- function(n = 10000000L) {
    cat('[sample]n =', n, '\n')

    ca <- c(-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
            1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00)
    cb <- c(-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
            6.680131188771972e+01, -1.328068155288572e+01)
    cc <- c(-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
            -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00)
    cd <- c(7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
            3.754408661907416e+00)

    inv.cdf <- function(p) {
        ifelse(p < 0.02425,
            { q <- sqrt(-2 * log(p))
              (((((cc[1L] * q + cc[2L]) * q + cc[3L]) * q + cc[4L]) * q + cc[5L]) * q + cc[6L]) /
                  ((((cd[1L] * q + cd[2L]) * q + cd[3L]) * q + cd[4L]) * q + 1) },
            ifelse(p <= (1 - 0.02425),
                { q <- (p - 0.5); r <- q * q
                  (((((ca[1L] * r + ca[2L]) * r + ca[3L]) * r + ca[4L]) * r + ca[5L]) * r + ca[6L]) * q /
                      (((((cb[1L] * r + cb[2L]) * r + cb[3L]) * r + cb[4L]) * r + cb[5L]) * r + 1) },
                { q <- sqrt(-2 * log(1 - p))
                  -(((((cc[1L] * q + cc[2L]) * q + cc[3L]) * q + cc[4L]) * q + cc[5L]) * q + cc[6L]) /
                      ((((cd[1L] * q + cd[2L]) * q + cd[3L]) * q + cd[4L]) * q + 1) }))
    }

    rnorm <- function(n, m = 0, sd = 1) {
        inv.cdf(runif(n)) * sd + m
    }

    means <- c(0, 2, 10)
    sd <- c(1, 0.1, 3)

    i <- .data$i
    assign(".Random.seed", .data$seed, envir = globalenv())
    res <- rnorm(n, means[i], sd[i])
    cat(length(res), '\n')
    invisible(res)
}
