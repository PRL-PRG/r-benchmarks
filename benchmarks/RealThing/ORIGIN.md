# RealThing — origin

Real-world R workloads rather than kernels: polynomial convolution, volcano
surface rendering, and flexclust clustering.

| | |
|---|---|
| Upstream | `convolution*` from the R *Writing R Extensions* manual; `volcano` from the R `datasets`/`graphics` examples; `flexclust*` from [flexclust](https://cran.r-project.org/package=flexclust) (© Friedrich Leisch) |
| License | GPL-2 |

`flexclust.R` and `flexclust_no_s4.R` are a vendored extract of the package
rather than a call into it, which is why the suite has no `library(flexclust)`
and no `doctor()` for it: the pair exists to measure the cost of S4 dispatch by
holding the algorithm fixed and removing the classes.

`aloi-8d.csv.gz` is the clustering input, shipped with the suite.

## What was changed

The files are vendored copies, not a dependency. Every benchmark was adapted to
the harness contract in [`../README.md`](../README.md): a top-level
`execute(size)` doing the work, an optional `setup(size)` drawing or loading the
inputs outside the timed region, and an optional `doctor()` reporting a missing
dependency. Where upstream generated its input inside the timed loop, or printed
bulk output, that was moved into `setup()` or reduced to a checksum, so that
what is measured is the kernel. Individual files record their own deviations in
a comment at the top.
