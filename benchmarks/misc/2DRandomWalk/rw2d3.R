# 2D random walk of n steps, optimized vector version (Type III).
# src: https://www.stat.auckland.ac.nz/~ihaka/downloads/Taupo-handouts.pdf
# Ported from the RB `misc` suite (Author: Ross Ihaka).
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).

execute <- function(n = 100000L) {
    set.seed(42L)
    xsteps <- c(-1, 1, 0, 0)
    ysteps <- c(0, 0, -1, 1)
    dir <- sample(1:4, n - 1, replace = TRUE)
    xpos <- c(0, cumsum(xsteps[dir]))
    ypos <- c(0, cumsum(ysteps[dir]))
    cat(length(xpos), length(ypos), "\n")
    invisible(list(x = xpos, y = ypos))
}
