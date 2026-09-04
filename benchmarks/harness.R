#!/usr/bin/env Rscript
#
# Minimal benchmark harness.
#
# Usage: Rscript harness.R <benchmark.R> <iterations> [<size>]
#
# 1. sets the working directory to be the one of the <benchmark.R>
# 2. sources <benchmark.R>
# 3. if <benchmark.R> defines 'doctor', it will run the function
# 4. if <benchmark.R> defines 'setup', it will run 'setup(<size>)'
# 5. finally, runs <iterations> times 'execute(<size>)'
#
# If <size> is omitted the benchmark's own default is used.
# 
# Contract:
#
# - `doctor()` returns TRUE when everything it needs is present, or a
# string describing what is missing. That string is an error the harness stops with.
#
# - `setup(<size>)` is used to prepare any necessary input. It runs before the 
# benchmark iterations and cost is excluded from the runtime. It must leave 
# the inputs in memory, i.e. `execute` shall neither generate nor
# load data, because then the measurement would be of the input rather than of
# the program. The convention is a top-level `.data` that `setup` fills with
# `<<-` and `execute` only reads. It may cache what it generates under the benchmark's 
# `data/` directory, and must be idempotent - reuse an already-prepared input 
# when it is present. Caching is worth it when generating the input costs real 
# time in each of the processes that will run the benchmark.
#
# - `execute(<size>)` is the meat of the benchmark. The `<size>` is what shall
# control the size of the problem. It will be run in a loop `<iterations>` times.
#
# One fenced block is printed per iteration.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("usage: harness.R <benchmark.R> <iterations> [<size>]", call. = FALSE)
}

file  <- args[[1L]]
iters <- as.integer(args[[2L]])

# Phase marks for the bytecode profiler: it snapshots its counters under a label,
# so the phases below can be told apart from each other and from R's own startup
# (which it marks itself). `.Internal(bcprof_mark)` exists only in that build, and
# only that harness sets RSH_TIMING, so everywhere else this is a no-op -- the
# try() is for a stray RSH_TIMING under an R without the internal.
# RSH_MARK_ITER additionally marks every iteration, which is how JIT warmup
# becomes visible; off by default because it multiplies the output.
.bc_mark <- if (nzchar(Sys.getenv("RSH_TIMING"))) {
  function(label) try(.Internal(bcprof_mark(label)), silent = TRUE)
} else {
  function(label) invisible(NULL)
}
.bc_mark_iter <- if (nzchar(Sys.getenv("RSH_MARK_ITER"))) .bc_mark else
  function(label) invisible(NULL)

setwd(dirname(file))                    # so benchmarks resolve their data/helpers
name <- sub("\\.[Rr]$", "", basename(file))
source(basename(file))

size <- if (length(args) >= 3L) as.integer(args[[3L]]) else formals(execute)[[1L]]

if (exists("doctor") && is.function(doctor)) {
  diagnosis <- doctor()
  if (!isTRUE(diagnosis)) stop(sprintf("%s: %s", name, diagnosis), call. = FALSE)
}

# Sourcing the benchmark and its doctor(): any top-level library() it does lands
# here. Not all of them -- a few load packages inside setup() or execute()
# instead, so this is the boundary of *this file's* work, not of package loading.
.bc_mark("sourced")

if (exists("setup") && is.function(setup)) {
  tm <- system.time(if (length(formals(setup))) setup(size) else setup())
  cat(sprintf("====== %s, setup completed (%.3f ms) ======\n",
              name, tm[["elapsed"]] * 1000))
}
.bc_mark("setup")                       # emitted even with no setup(), so the
                                        # phase list has a fixed shape

for (i in seq_len(iters)) {
  it <- i - 1L
  cat(sprintf("====== %s, iteration %d started ======\n", name, it))

  # Two instruments because two problems: the forced GC is an event we call, so
  # it is timed directly, while the collections inside `execute` happen when R
  # decides and only R's own counter sees them. They are not interchangeable -
  # `gc.time()` is quantized to 1 ms and only starts accumulating on its first
  # call, so it would report this first forced GC as 0.
  forced <- Sys.time()
  gc(full = TRUE)
  forced <- as.numeric(difftime(Sys.time(), forced, units = "secs"))

  g0 <- gc.time()
  c0 <- proc.time()
  t0 <- Sys.time()
  res <- execute(size)
  t1 <- Sys.time()
  c1 <- proc.time()
  g1 <- gc.time()

  cat(sprintf(
    "====== %s, iteration %d completed in %.3f ms (gc %.3f ms, forced-gc %.3f ms, cpu %.3f ms) ======\n",
    name,
    it,
    as.numeric(difftime(t1, t0, units = "secs")) * 1000,
    (g1[[3L]] - g0[[3L]]) * 1000,
    forced * 1000,
    (c1[[1L]] - c0[[1L]] + c1[[2L]] - c0[[2L]]) * 1000))
}
.bc_mark("execute")                     # last mark, so it equals the totals
