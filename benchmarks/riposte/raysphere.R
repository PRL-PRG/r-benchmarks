# Ray-sphere intersection over n spheres (vector code).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).

execute <- function(n = 10000000L) {
    cat('[raysphere]n =', n, '\n')
    xc <- as.double(0:(n - 1))
    yc <- as.double(0:(n - 1))
    zc <- as.double(0:(n - 1))

    xo <- 0; yo <- 0; zo <- 0
    xd <- 1; yd <- 0; zd <- 0

    intersect <- function() {
        rx <- xo - xc
        ry <- yo - yc
        rz <- zo - zc

        a <- 1
        b <- 2 * (xd * rx + yd * ry + zd * rz)
        c <- rx * rx + ry * ry + rz * rz - 1

        disc <- b * b - 4 * a * c

        m <- sqrt(disc)
        t0 <- (-b - m) / 2
        t1 <- (-b + m) / 2

        cond <- disc > 0
        min(pmin(t0[cond], t1[cond]))
    }

    r <- intersect()
    cat(r, '\n')
    invisible(r)
}
