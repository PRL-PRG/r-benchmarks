# 2D random walk of n steps, scalar version (Type I).
# src: https://www.stat.auckland.ac.nz/~ihaka/downloads/Taupo-handouts.pdf
# Ported from the RB `misc` suite (Author: Ross Ihaka).
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).

execute <- function(n = 100000L) {
    set.seed(42L)
    xpos <- ypos <- numeric(n)
    for (i in 2:n) {
        # Decide whether we are moving horizontally or vertically.
        delta <- if (runif(1) > .5) 1 else -1
        if (runif(1) > .5) {
            xpos[i] <- xpos[i - 1] + delta
            ypos[i] <- ypos[i - 1]
        } else {
            xpos[i] <- xpos[i - 1]
            ypos[i] <- ypos[i - 1] + delta
        }
    }
    cat(length(xpos), length(ypos), "\n")
    invisible(list(x = xpos, y = ypos))
}
