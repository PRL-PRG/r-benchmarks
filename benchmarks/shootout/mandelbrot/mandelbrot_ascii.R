# ------------------------------------------------------------------
# The Computer Language Shootout
# http://shootout.alioth.debian.org/
#
# Contributed by Leo Osvald
# ------------------------------------------------------------------
# Output replaced by checksum. The original shootout benchmark writes its
# generated data to stdout, which could mean hundreds of kilobytes per iteration
# resulting in IO dominating the benchmark.
.cksum <- 0
.ck <- function(x) {
    v <- if (is.character(x)) utf8ToInt(paste0(x, collapse = "")) else as.integer(x)
    .cksum <<- (.cksum + sum(v)) %% 2147483647L
}


execute <- function(n=300) {
    .cksum <<- 0
    lim <- 2
    iter <- 50

    n <- as.integer(n)
    n_mod8 = n %% 8L
    pads <- if (n_mod8) rep.int(0, 8L - n_mod8) else integer(0)
    p <- rep(as.integer(rep.int(2, 8) ^ (7:0)), length.out=n)

    for (y in 0:(n-1)) {
        c <- 2 * 0:(n-1) / n - 1.5 + 1i * (2 * y / n - 1)
        z <- rep(0+0i, n)
        i <- 0L
        while (i < iter) {  # faster than for loop
            z <- z * z + c
            i <- i + 1L
        }
        bits <- as.integer(abs(z) <= lim)
        bytes <- as.raw(colSums(matrix(c(bits * p, pads), 8L)))
        .ck(bytes)
    }
    cat("mandelbrot_ascii checksum:", .cksum, "\n")
}
