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
# RBENCH_PROFILE, if set, names an R file sourced before the benchmark. If it
# defines `rbench_prepare()`, that is called after setup() and before the first
# iteration, for anything that must act on the benchmark's loaded functions.
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

prepare <- function(name, size) {
  if (exists("doctor") && is.function(doctor)) {
    diagnosis <- doctor()
    if (!isTRUE(diagnosis))
      stop(sprintf("%s: %s", name, diagnosis), call. = FALSE)
  }

  if (exists("setup") && is.function(setup)) {
    tm <- system.time(
      if (length(formals(setup))) {
        setup(size)
      } else {
        setup()
      })

    cat(sprintf("====== %s, setup completed (%.3f ms) ======\n",
                name, tm[["elapsed"]] * 1000))
  }

  if (exists("rbench_prepare") && is.function(rbench_prepare)) {
    tm <- system.time(rbench_prepare())
    cat(sprintf("====== %s, prepare completed (%.3f ms) ======\n",
                name, tm[["elapsed"]] * 1000))
  }
}

iterate <- function(name, size, iters) {
  for (i in seq_len(iters)) {
    it <- i - 1L
    cat(sprintf("====== %s, iteration %d started ======\n", name, it))

    forced <- Sys.time()
    gc()
    forced <- as.numeric(difftime(Sys.time(), forced, units = "secs"))
    flush(stdout())

    g0 <- gc.time()
    c0 <- proc.time()
    t0 <- Sys.time()

    execute(size)

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
      (c1[[1L]] - c0[[1L]] + c1[[2L]] - c0[[2L]]) * 1000)
    )
  }
}

run <- function(args) {
  if (length(args) < 2L || length(args) > 4L) {
    stop("usage: harness.R <benchmark.R> <iterations> [<size>] [<rbench_profile>]", call. = FALSE)
  }

  file  <- args[[1L]]
  source(file)

  iters <- as.integer(args[[2L]])

  # Get the size from cmdline if available, from formals otherwise
  size <- if (length(args) >= 3L) {
    as.integer(args[[3L]])
  } else {
    formals(execute)[[1L]]
  }

  # Source rbench_profile if it exists
  if (length(args) > 3L) {
    source(args[[4L]])
  }

  name <- sub("\\.[Rr]$", "", basename(file))

  prepare(name, size)
  iterate(name, size, iters)
}

run(commandArgs(trailingOnly = TRUE))
