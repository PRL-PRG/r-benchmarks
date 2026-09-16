# riposte — origin

Vector-heavy benchmarks from the Riposte project: Black-Scholes, k-means, PCA,
logistic regression, sparse matrix-vector multiply, ray-sphere intersection and
others.

| | |
|---|---|
| Upstream | R Benchmark Suite (RB) <https://github.com/rbenchmark/benchmarks> |
| Original | [jtalbot/riposte](https://github.com/jtalbot/riposte) (Justin Talbot) |
| License | BSD-3-Clause |

Six benchmarks (`kmeans`, `lr`, `lr_test`, `pca`, `pca-blocked`, `smv_builtin`)
generate their input in `setup()` on first run and read it back afterwards; four
of them need `clusterGeneration` and `MASS` to build it, which their `doctor()`
checks.

Upstream's `qr` is deliberately not registered: it relies on Riposte-VM
semantics and does not run under GNU R.

## What was changed

The files are vendored copies, not a dependency. Every benchmark was adapted to
the harness contract in [`../README.md`](../README.md): a top-level
`execute(size)` doing the work, an optional `setup(size)` drawing or loading the
inputs outside the timed region, and an optional `doctor()` reporting a missing
dependency. Where upstream generated its input inside the timed loop, or printed
bulk output, that was moved into `setup()` or reduced to a checksum, so that
what is measured is the kernel. Individual files record their own deviations in
a comment at the top.
