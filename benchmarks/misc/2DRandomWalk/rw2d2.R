# 2D random walk of n steps, vector version (Type II).
# src: https://www.stat.auckland.ac.nz/~ihaka/downloads/Taupo-handouts.pdf
# Ported from the RB `misc` suite (Author: Ross Ihaka).
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).

execute <- function(n = 100000L) {
    set.seed(42L)
    steps <- sample(c(-1, 1), n - 1, replace = TRUE)
    xdir <- sample(c(TRUE, FALSE), n - 1, replace = TRUE)
    xpos <- c(0, cumsum(ifelse(xdir, steps, 0)))
    ypos <- c(0, cumsum(ifelse(xdir, 0, steps)))
    cat(length(xpos), length(ypos), "\n")
    invisible(list(x = xpos, y = ypos))
}
