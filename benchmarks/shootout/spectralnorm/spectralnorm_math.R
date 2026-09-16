# ------------------------------------------------------------------
# The Computer Language Shootout
# http://shootout.alioth.debian.org/
#
# Contributed by Leo Osvald
# ------------------------------------------------------------------

eval_A <- function(i, j) 1 / ((i + j - 2) * (i + j - 1) / 2 + i)

execute <- function(n=1200) {
    n <- as.integer(n)
    options(digits=10)

    m <- outer(seq(n), seq(n), FUN=eval_A)
    cat(sqrt(max(eigen(t(m) %*% m)$val)), "\n")
}
