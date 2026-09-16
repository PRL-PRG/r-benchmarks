# Histogram of N integers in [0,100) via tabulate (vector code).
# Ported from the RB `riposte` suite.
# Upstream: R Benchmark Suite <https://github.com/rbenchmark/benchmarks> (BSD-3-Clause).
#
# The size parameter is the number of times the kernel is repeated, not the
# length of the data: one `tabulate` over N = 100 million integers takes 164 ms,
# and reaching a second by growing N would need gigabytes of input - so what was
# measured would be the draw and the allocation, not the tabulate. N stays at the
# 100 million this benchmark was ported with.
#
# Upstream drew and truncated the data inside the timed kernel, where two thirds
# of the profile was the random number generator; setup() builds it into `.data`
# instead. It is not cached on disk: the file would be 400 MB and reads back no
# faster than the numbers are drawn (see harness.R).

.N <- 100000000L
.data <- NULL       # filled by setup(); execute() only reads it

setup <- function() {
    set.seed(42L)
    .data <<- as.integer(runif(.N, 0, 100))
    invisible()
}

execute <- function(rep = 9L) {
    cat('[histogram]n =', .N, 'rep =', rep, '\n')
    data <- .data
    for (k in 1:rep) {
        r <- tabulate(data, 100L)
    }
    cat(length(r), '\n')
    invisible(r)
}
