#!/usr/bin/env Rscript
#
# One-shot harness for the instrumented interpreters: source the benchmark, run
# `setup()`, force a GC, run `execute()` exactly once. Each phase prints
#
#   MARK<TAB><phase><TAB><begin><TAB><end>
#
# in CLOCK_MONOTONIC, the clock `perf record -k1` timestamps its samples with, so
# a recording can be cut down to `execute` alone afterwards.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L || length(args) > 3L) {
  stop("usage: harness_instrument.R <benchmark.R> <marker.so> [<size>]", call. = FALSE)
}

file <- args[[1L]]

marker <- args[[2L]]
dyn.load(marker)

# Helper functions
now <- function()
  .Call("rbench_monotonic")

mark <- function(tag, t0, t1) {
  cat(sprintf("MARK\t%s\t%.6f\t%.6f\n", tag, t0, t1))
}

# Source
t0 <- now()
source(basename(file))
t1 <- now()

mark("source", t0, t1)

# Get the size from cmdline if available, from formals otherwise
size <- if (length(args) >= 3L) {
  as.integer(args[[3L]])
} else {
  formals(execute)[[1L]]
}

# Setup
if (exists("setup") && is.function(setup)) {
  t0 <- now()
  if (length(formals(setup))) {
    setup(size)
  } else {
    setup()
  }
  t1 <- now()
  mark("setup", t0, t1)
}

# GC
t0 <- now()
invisible(gc())
t1 <- now()
mark("gc", t0, t1)

# execute
t0 <- now()
res <- execute(size)
t1 <- now()
mark("execute", t0, t1)
