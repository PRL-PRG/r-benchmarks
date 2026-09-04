# R-benchmark-25 — origin

The ATT *R-benchmark-25*: matrix calculation, matrix functions, and
"programmation" kernels.

| | |
|---|---|
| Upstream | R Benchmark Suite (RB) <https://github.com/rbenchmark/benchmarks> |
| Original | [r.research.att.com/benchmarks](http://r.research.att.com/benchmarks/) |
| License | BSD-3-Clause |

The sizing argument is `runs`, the kernel repeat count; the harness already
repeats each benchmark, so most are registered at 1-3. The `.R` files keep
upstream's default of 3 for standalone use.

## What was changed

The files are vendored copies, not a dependency. Every benchmark was adapted to
the harness contract in [`../README.md`](../README.md): a top-level
`execute(size)` doing the work, an optional `setup(size)` drawing or loading the
inputs outside the timed region, and an optional `doctor()` reporting a missing
dependency. Where upstream generated its input inside the timed loop, or printed
bulk output, that was moved into `setup()` or reduced to a checksum, so that
what is measured is the kernel. Individual files record their own deviations in
a comment at the top.
