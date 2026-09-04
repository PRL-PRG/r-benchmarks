# Mandelbrot set over a 2048x1536 grid, maxIterations iterations (vector code).
# adapted from https://github.com/ispc/ispc/tree/master/examples/mandelbrot
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).

execute <- function(maxIterations = 100L) {
    width <- 2048
    height <- 1536

    cat('[mandelbrot]width =', width, 'height =', height, 'maxIterations =', maxIterations, '\n')

    x0 <- -2
    x1 <- 1
    y0 <- -1
    y1 <- 1

    dx <- (x1 - x0) / width
    dy <- (y1 - y0) / height

    c <- (1:(width * height)) - 1
    i <- c %% width
    j <- floor(c / width)

    c_re <- x0 + i * dx
    c_im <- y0 + j * dy

    z_re <- c_re
    z_im <- c_im
    cnt <- 0
    for (i in 1:maxIterations) {
        cnt <- cnt + (z_re * z_re + z_im * z_im <= 4)
        z_re2 <- c_re + (z_re * z_re - z_im * z_im)
        z_im2 <- c_im + (2. * z_re * z_im)
        z_re <- z_re2
        z_im <- z_im2
    }
    cat(length(cnt), '\n')
    invisible(cnt)
}
