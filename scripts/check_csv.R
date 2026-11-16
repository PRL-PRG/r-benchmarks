#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 1)

d <- read.csv(args[1], comment.char = "#", colClasses = "character")

# Validate the column names
stopifnot(nrow(d) > 0, all(c("suite", "benchmark", "failure") %in% names(d)))

name <- paste(d$suite, d$benchmark, sep = "/")
bad <- trimws(d$failure) != ""
n <- length(unique(name))
cat(sprintf("%d samples over %d benchmarks\n", nrow(d), n))

ok <- TRUE
# Check no failure
if (any(bad)) {
  cat(sprintf("\n%d benchmark(s) failed:\n", length(unique(name[bad]))))
  for (s in sort(unique(sprintf("  %s: %s", name[bad], trimws(d$failure[bad])))))
    cat(s, "\n")
  ok <- FALSE
}
# Check all benchmarks are present
if (n != 118) {
  cat(sprintf("\nexpected 118 benchmarks, got %d\n", n))
  ok <- FALSE
}
if (!ok) quit(status = 1)
cat("no failures\n")
