# shootout — origin

R port of the Computer Language Benchmarks Game: binary-trees, fannkuch-redux,
fasta, k-nucleotide, mandelbrot, n-body, pidigits, regex-dna,
reverse-complement and spectral-norm, most in several hand-written variants.

| | |
|---|---|
| Upstream | R Benchmark Suite (RB) <https://github.com/rbenchmark/benchmarks> |
| Original | [The Computer Language Benchmarks Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/), © 2008-2012 Isaac Gouy |
| License | BSD-3-Clause (RB); the Benchmarks Game originals are under the Revised BSD license reproduced below the RB text in `LICENSE` |

`fasta/fasta*.txt` are committed inputs, named for their size: `knucleotide`,
`regexdna` and `reversecomplement` read one rather than generating it, so their
registered size has to be a size a file exists for.

## What was changed

The files are vendored copies, not a dependency. Every benchmark was adapted to
the harness contract in [`../README.md`](../README.md): a top-level
`execute(size)` doing the work, an optional `setup(size)` drawing or loading the
inputs outside the timed region, and an optional `doctor()` reporting a missing
dependency. Where upstream generated its input inside the timed loop, or printed
bulk output, that was moved into `setup()` or reduced to a checksum, so that
what is measured is the kernel. Individual files record their own deviations in
a comment at the top.
