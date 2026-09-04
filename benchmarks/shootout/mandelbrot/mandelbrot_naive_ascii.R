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


execute <- function(n=200) {
    .cksum <<- 0
    lim <- 2
    iter <- 50

    n <- as.integer(n)
    for (y in 0:(n-1)) {
        bits <- 0L
        x <- 0L
        while (x < n) {
            c <- 2 * x / n - 1.5 + 1i * (2 * y / n - 1)
            z <- 0+0i
            i <- 0L
            while (i < iter && abs(z) <= lim) {
                z <- z * z + c
                i <- i + 1L
            }
            bits <- 2L * bits + as.integer(abs(z) <= lim)
            if ((x <- x + 1L) %% 8L == 0) {
                .ck(bits)
                bits <- 0L
            }
        }
        xmod <- x %% 8L
        if (xmod)
            .ck(bits * as.integer(2^(8L - xmod)))
    }
    cat("mandelbrot_naive_ascii checksum:", .cksum, "\n")
}
