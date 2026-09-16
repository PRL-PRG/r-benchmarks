#!/usr/bin/env Rscript
#
# One-shot harness for the instrumented interpreters: source the benchmark, run
# `setup()`, force a GC, run `execute()` exactly once. Each phase prints
#
#   MARK<TAB><phase><TAB><begin><TAB><end>
#
# in CLOCK_MONOTONIC, the clock `perf record -k1` timestamps its samples with, so
# a recording can be cut down to `execute` alone afterwards.
#
# marker.so is required, not optional: the obvious fallback (`Sys.time()`) is on
# a different clock and would produce marks that are silently wrong.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  stop("usage: harness_instrument.R <benchmark.R> [<size>]", call. = FALSE)
}
file <- args[[1L]]

# `R -f <this file> --args ...`, with marker.so next to it. Before the setwd().
argv <- commandArgs()
here <- dirname(normalizePath(argv[[match("-f", argv) + 1L]]))
dyn.load(file.path(here, "marker.so"))

now <- function() .Call("rbench_monotonic")
mark <- function(tag, t0, t1) cat(sprintf("MARK\t%s\t%.6f\t%.6f\n", tag, t0, t1))

# Same hook as harness.R, and marked, so whatever it does is a phase of its own
# rather than time charged to `source`.
.profile <- Sys.getenv("RBENCH_PROFILE")
if (nzchar(.profile)) {
  if (!file.exists(.profile))
    stop(sprintf("RBENCH_PROFILE: no such file: %s", .profile), call. = FALSE)
  t0 <- now()
  source(.profile)
  mark("profile", t0, now())
}

setwd(dirname(file))                    # so benchmarks resolve their data/helpers

t0 <- now()
source(basename(file))
t1 <- now()
mark("source", t0, t1)

size <- if (length(args) >= 2L) as.integer(args[[2L]]) else formals(execute)[[1L]]

if (exists("setup") && is.function(setup)) {
  t0 <- now()
  if (length(formals(setup))) setup(size) else setup()
  t1 <- now()
  mark("setup", t0, t1)
}

# A phase of its own so that neither its cost nor `setup`'s garbage lands in
# `execute`.
t0 <- now()
invisible(gc(full = TRUE))
t1 <- now()
mark("gc", t0, t1)

t0 <- now()
res <- execute(size)
t1 <- now()
mark("execute", t0, t1)
