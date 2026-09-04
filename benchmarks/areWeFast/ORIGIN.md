# areWeFast — origin

Core micro-benchmarks from the *Are We Fast Yet?* cross-language suite,
translated to R.

| | |
|---|---|
| Upstream | [smarr/are-we-fast-yet](https://github.com/smarr/are-we-fast-yet) |
| R translation | Kalibera, Maj, Morandat, Vitek, *A Fast Abstract Syntax Tree Interpreter for R*, VEE'14, [doi:10.1145/2576195.2576205](https://doi.org/10.1145/2576195.2576205) |
| License | MIT (`bounce*`, `storage`, derived from the SOM class library); Revised BSD (`mandelbrot`, from the Computer Language Benchmarks Game) |

`random.r` is the suite's shared deterministic generator, sourced by `bounce*`.
It is not a benchmark and is not registered.

## What was changed

The files are vendored copies, not a dependency. Every benchmark was adapted to
the harness contract in [`../README.md`](../README.md): a top-level
`execute(size)` doing the work, an optional `setup(size)` drawing or loading the
inputs outside the timed region, and an optional `doctor()` reporting a missing
dependency. Where upstream generated its input inside the timed loop, or printed
bulk output, that was moved into `setup()` or reduced to a checksum, so that
what is measured is the kernel. Individual files record their own deviations in
a comment at the top.
