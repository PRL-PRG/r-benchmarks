# mathkernel — origin

Math kernels: matrix-matrix multiply and vector add, over double and integer
data, with and without `NA`, in scalar, vectorised and builtin variants.

| | |
|---|---|
| Upstream | R Benchmark Suite (RB) <https://github.com/rbenchmark/benchmarks> |
| License | BSD-3-Clause |

For the `MMM-*` benchmarks the registered size is the matrix dimension. For the
eight `*VecAdd-*` it is the *number of repetitions*: their vector length is
fixed at upstream's 10 million inside the files, so that a T1 and its T2 run on
the same data.

## What was changed

The files are vendored copies, not a dependency. Every benchmark was adapted to
the harness contract in [`../README.md`](../README.md): a top-level
`execute(size)` doing the work, an optional `setup(size)` drawing or loading the
inputs outside the timed region, and an optional `doctor()` reporting a missing
dependency. Where upstream generated its input inside the timed loop, or printed
bulk output, that was moved into `setup()` or reduced to a checksum, so that
what is measured is the kernel. Individual files record their own deviations in
a comment at the top.
