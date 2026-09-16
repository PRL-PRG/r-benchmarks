# benchmarks

The corpus: one directory per suite, each carrying its own `LICENSE` and
`ORIGIN.md`. What the suites are, the contract a benchmark file has to meet, and
how any of this is run is in the [top-level README](../README.md) — this file
only says what the loose files beside the suites are for.

### `harness.R`

The harness. Runs one benchmark in one R process:

```sh
R --no-echo --vanilla -f harness.R --args <benchmark.R> <iterations> [<size>]
```

Sources `RBENCH_PROFILE` if set, `setwd()`s to the benchmark's own directory,
then runs `doctor()`, `setup(size)`, the optional `rbench_prepare()` hook, and
`<iterations>` calls of `execute(size)` — printing one line per iteration with
its runtime, gc, forced-gc and cpu times. It has no notion of warm-up: it runs
the count it is given, and which of those count is the driver's decision.

### `harness_instrument.R`

The profiling harness. Runs `setup()` and then `execute()` **exactly once**,
because a repeat loop would pollute a recording, and brackets each phase with a
`CLOCK_MONOTONIC` `MARK` line so a recording can be cut down to `execute` alone.

Two constraints: it needs `marker.so`, and it must be launched as `R -f`, never
`Rscript` — it locates its own directory by finding `-f` in `commandArgs()`,
which `Rscript` rewrites. It does **not** call `doctor()`.

### `marker.c`

The one compiled part, and only `harness_instrument.R` needs it. Exposes
`clock_gettime(CLOCK_MONOTONIC)` to R as `rbench_monotonic`, so the phase marks
share a clock with a `perf` recording. It links against no `libR`, so one
`marker.so` is valid for every R build in a comparison.

### `Makefile`

Builds `marker.so` from `marker.c`, through `R CMD SHLIB` so the compiler and
flags come from the target R's own `Makeconf` rather than from here:

```sh
make -C benchmarks marker            # with `R` from PATH
make -C benchmarks marker R=/path/to/R
make -C benchmarks clean
```

### `install_packages.R`

Installs the three CRAN packages some benchmarks need — `Matrix`, `MASS` and
`clusterGeneration` — into the library named as its one argument, skipping
whatever is already present.

That argument should be `$(R RHOME)/library`, the interpreter's *own* library: a
run has `R_LIBS`, `R_LIBS_USER` and `R_LIBS_SITE` blanked, so it cannot see a
user or site library. One library per interpreter, because compiled package code
is not portable across R builds. The invocation is in the
[top-level README](../README.md).
