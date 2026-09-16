# SpeedTest — origin

Numerical and text programs: Cholesky, cross-validation, EM, Gaussian
processes, HMC, kernel PCA, matrix exponential, MLP, Q-learning, sieves and
text processing.

| | |
|---|---|
| Upstream | Radford Neal's [pqR](https://github.com/radfordneal/pqR), the `SpeedTest/prg` programs |
| License | GPL-2 |

Only pqR's `prg` tree is here. Its `tst` tree — 89 files, each timing a single
operation in a repetition loop — was deliberately left out; see *What is
deliberately not here* in [`../README.md`](../README.md).

## What was changed

The files are vendored copies, not a dependency. Every benchmark was adapted to
the harness contract in [`../README.md`](../README.md): a top-level
`execute(size)` doing the work, an optional `setup(size)` drawing or loading the
inputs outside the timed region, and an optional `doctor()` reporting a missing
dependency. Where upstream generated its input inside the timed loop, or printed
bulk output, that was moved into `setup()` or reduced to a checksum, so that
what is measured is the kernel. Individual files record their own deviations in
a comment at the top.
