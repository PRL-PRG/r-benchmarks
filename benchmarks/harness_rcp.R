#!/usr/bin/env Rscript
#
# Copy-and-patch (rcp) AOT harness.
#
# Usage: Rscript harness_rcp.R <benchmark.R> <iterations> [<arg>]
#
# Identical to harness.R (same per-iteration output, so the same monitor parses
# it), with one addition: after `setup` and *before* the timed iterations, every
# closure the benchmark defines is ahead-of-time compiled with rcp's
# copy-and-patch compiler (`rcp_cmpfun`) and put back in place. Compilation is
# entirely up front and deterministic - nothing is left to a JIT to trigger
# itself. rcp's JIT is off by default, so it is not touched here.
#
# `optimize` is the R *bytecode* optimize level rcp compiles through before
# copy-and-patching. It defaults to 2 - the same level R's own byte-compiler /
# JIT uses - so the copy-and-patch code runs the *same bytecode* as the vanilla
# bytecode baseline, isolating the native-codegen effect. Override with the
# RCP_OPT environment variable (0-3) to sweep it.
#
# A closure that rcp cannot compile is reported and left interpreted rather than
# aborting the benchmark; the summary line names any such functions and whether
# `execute` (the timed entry point) itself compiled.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("usage: harness_rcp.R <benchmark.R> <iterations> [<arg>]", call. = FALSE)
}

file  <- args[[1L]]
iters <- as.integer(args[[2L]])

setwd(dirname(file))
name <- sub("\\.[Rr]$", "", basename(file))

suppressMessages(library(rcp))

# Bytecode optimize level rcp compiles through (default 2 = R's own default, so
# the copy-and-patch code runs the same bytecode as the vanilla bc baseline).
rcp_opt <- suppressWarnings(as.integer(Sys.getenv("RCP_OPT", "2")))
if (is.na(rcp_opt)) rcp_opt <- 2L

source(basename(file))

arg <- if (length(args) >= 3L) as.integer(args[[3L]]) else formals(execute)[[1L]]

if (exists("doctor") && is.function(doctor)) {
  diagnosis <- doctor()
  if (!isTRUE(diagnosis)) stop(sprintf("%s: %s", name, diagnosis), call. = FALSE)
}

if (exists("setup") && is.function(setup)) {
  # Not timed: prepare inputs in memory. Runs interpreted, before compilation.
  tm <- system.time(if (length(formals(setup))) setup(arg) else setup())
  cat(sprintf("====== %s, setup completed (%.3f ms) ======\n",
              name, tm[["elapsed"]] * 1000))
}

# --- AOT copy-and-patch compilation of every user-defined closure (not timed) ---
# `doctor` is a dependency probe, not part of the workload, so it is left alone.
user_fns <- Filter(is.function, mget(ls(envir = globalenv()), envir = globalenv()))
skip <- c("doctor")
ok <- character(0); fail <- character(0)
tm <- system.time({
  for (nm in setdiff(names(user_fns), skip)) {
    res <- tryCatch({
      cf <- rcp_cmpfun(user_fns[[nm]], options = list(name = nm, optimize = rcp_opt))
      assign(nm, cf, envir = globalenv())
      TRUE
    }, error = function(e) {
      message(sprintf("rcp compile failed: %s: %s", nm, conditionMessage(e)))
      FALSE
    })
    if (isTRUE(res)) ok <- c(ok, nm) else fail <- c(fail, nm)
  }
})
exec_ok <- tryCatch(isTRUE(rcp_is_compiled(get("execute", envir = globalenv()))),
                    error = function(e) NA)
cat(sprintf(
  "====== %s, rcp compiled %d/%d closures (execute compiled: %s; failed: %s) (%.3f ms) ======\n",
  name, length(ok), length(ok) + length(fail), exec_ok,
  if (length(fail)) paste(fail, collapse = ",") else "none", tm[["elapsed"]] * 1000))

for (i in seq_len(iters)) {
  it <- i - 1L
  cat(sprintf("====== %s, iteration %d started ======\n", name, it))
  tm <- system.time(res <- execute(arg))
  cat(sprintf("====== %s, iteration %d completed (%.3f ms) ======\n",
              name, it, tm[["elapsed"]] * 1000))
}
