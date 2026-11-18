# r-benchmarks

A curated benchmark suite for the R programming language including a common
harness to run them. It uses the [bench](https://github.com/PRL-PRG/bench)
benchmarking framework.

```sh
$ ./rbench.py --include 'areWeFast/mandelbrot' --runs 1 --iterations 3

Finished: areWeFast/mandelbrot: 4.62 s (1 runs)

areWeFast/mandelbrot (runtime)
  mean    ± σ        min      … max
  1435.91 ± 26.37 ms (1417.26 … 1454.56) (1 runs)

areWeFast/mandelbrot (gc)
  mean  ± σ       min    … max
  19.00 ± 4.24 ms (16.00 … 22.00) (1 runs)

areWeFast/mandelbrot (forced_gc)
  mean  ± σ       min    … max
  25.15 ± 0.30 ms (24.93 … 25.36) (1 runs)

areWeFast/mandelbrot (cpu)
  mean    ± σ        min      … max
  1419.00 ± 18.38 ms (1406.00 … 1432.00) (1 runs)

areWeFast/mandelbrot (elapsed)
  value
  4.62  s (1 runs)

areWeFast/mandelbrot (max_rss)
  value
  72.05 MB (1 runs)
```

## How to use

The only dependency is [`uv`](https://docs.astral.sh/uv/).
All other dependencies are managed by it.

You also need some `R` binary to run.
Some of the benchmarks need some `R` package dependencies to run.
These are downloaded by default via a `bench` hook.

### Running directly

To run the benchmark, use the `rbench.py` script. By running
```sh
./rbench.py --help
```
you can see all of the available options. Note that if the R binary is available
on the `PATH`, it is used by default, otherwise the option `--R` needs to be
explicitly passed.

This runs with the harness located at `benchmarks/harness.R`.

#### Running with `perf`

To profile with `perf`, use the `rbench_perf.py` script. This requires `perf`
to be available and in the `PATH`. To see all of the available options, run
```sh
rbench_perf.py --help
```
Note that this builds the `perf/marker.c` via a `bench` hook.
This runs with the `perf/harness_instrument.py`, executing one iteration
of the benchmark. It brackets the sections `source`/`setup`/`gc`/`execute`.

### Extending the suite
`rbench.py` is separated into multiple parts and can be reused and/or extended
in multiple ways. One of the examples is the `rbench_perf.py`, which reuses the
suites definition, but defines different ways of running them, as well as
different CLI.

**Importing the suite** To import the project from out-of-tree scripts, use the
`uv` tool. Specify in the header:
```python
#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.12"
# dependencies = ["rbench"]
#
# [tool.uv.sources]
# rbench = {git = "https://github.com/PRL-PRG/r-benchmarks/"}
# ///
```
Then you can import the components of `rbench.py` as the `rbench` module, and
the `rbench_perf.py` components as `rbench.perf` Python module.

**Suites** The suites can be reused by referencing `ALL_SUITES`. Note that by
default it does not specify the command. A helper
function `default_cmd` should help with formatting the R flags, as well as the
path to the files.

**Harness** The default harness can either be used with the 
defined benchmarks, or with different ones that conform to the same structure.
For more details about the structure, see `benchmarks/harness.R` directly.
The helpers are `RbenchHarnessSuccess` which makes sure that at least one
iteration was executed, `RbenchHarnessMetric` which parses the captured
metrics, and `harness_default_cmd`, a constructor function that uses the format
of the harness.

**Automatic package hooks** Every benchmark that has the `required_packages`
data field is picked up by the `InstallPackagesHook`, satisfying its
dependencies before running the benchmark.

**CLI** The input components - parameters and controller, as well
as the whole `bench_app` can be imported and extended/reused as well. If only
a single instance of R is desired for benchmarking at all times, the
`RbenchSingleRParams` parameters together with the `InstallPackagesHook` can
be used.

### Running benchmark without bench

The harness is usable on its own:
```sh
cd benchmarks/areWeFast
R --no-echo --vanilla -f ../harness.R --args mandelbrot.R 3
```

The same effect can be achieved by using the `bench` filters:
```sh
./rbench.py --runs 1 --iteration 3 --include 'areWeFast/mandelbrot'
```

This makes the run more reproducible and flexible, the benchmarks need to
be run in the folder they are defined in.

## Running in Docker

The image built by [`Dockerfile`](Dockerfile) carries R, the corpus, the CRAN
packages the benchmarks need and a resolved `bench`.
The entrypoint is the driver, so flags can be passed as

```sh
docker build -t r-benchmarks .
docker run r-benchmarks <rbench.py args...>
```
Without any specified flags, it runs the whole corpus with defaults.

To keep the results, write them into a mounted directory:

```sh
docker run -v "$PWD/out:/out" --user "$(id -u):$(id -g)" r-benchmarks \
  --json /out/report.json --csv /out/samples.csv --dir /out/runs
```

CI publishes the same image per commit, so a run can be reproduced without
building anything:

```sh
docker run --rm ghcr.io/prl-prg/r-benchmarks:<commit-sha> --list
```

Note the image is for reproducibility and convenience, not for the best
numbers: it links R's own reference BLAS rather than OpenBLAS, and a container
does nothing about a noisy host.

## Suites

The following benchmarks are included:

| Suite | Description | Original source | License |
|---|---|---|---|
| [areWeFast](benchmarks/areWeFast) | Core micro-benchmarks from the *Are We Fast Yet?* cross-language suite (bounce, mandelbrot, storage), translated to R by Kalibera et al. (VEE'14, doi:10.1145/2576195.2576205). | [smarr/are-we-fast-yet](https://github.com/smarr/are-we-fast-yet) | MIT |
| [RealThing](benchmarks/RealThing) | Real-world R workloads: convolution, volcano rendering, flexclust clustering. | R *Writing R Extensions* manual; [flexclust](https://cran.r-project.org/package=flexclust) (© F. Leisch) | GPL-2 |
| [shootout](benchmarks/shootout) | R port of the Computer Language Benchmarks Game (binary-trees, fasta, n-body, spectral-norm, …). | [RB](https://github.com/rbenchmark/benchmarks); orig [Benchmarks Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/) | BSD-3-Clause |
| [SpeedTest](benchmarks/SpeedTest) | Numerical and text programs: Cholesky, EM, Gaussian processes, HMC, matrix exponential, sieve, MLP, Q-learning. | Radford Neal's [pqR](https://github.com/radfordneal/pqR) speed tests | GPL-2 |
| [mathkernel](benchmarks/mathkernel) | Math kernels: matrix-matrix multiply and vector add (double/int, ±NA; scalar/vector/builtin variants). | [RB](https://github.com/rbenchmark/benchmarks) | BSD-3-Clause |
| [misc](benchmarks/misc) | 2D random walk (scalar / vector / optimized). | [RB](https://github.com/rbenchmark/benchmarks); orig R. Ihaka | BSD-3-Clause |
| [R-benchmark-25](benchmarks/R-benchmark-25) | The ATT *R-benchmark-25*: matrix calculation, matrix functions, and "programmation" kernels. | [RB](https://github.com/rbenchmark/benchmarks); orig [r.research.att.com](http://r.research.att.com/benchmarks/) | BSD-3-Clause |
| [riposte](benchmarks/riposte) | Vector-heavy benchmarks from the Riposte project (black-scholes, k-means, PCA, logistic regression, …). | [RB](https://github.com/rbenchmark/benchmarks); orig [jtalbot/riposte](https://github.com/jtalbot/riposte) (J. Talbot) | BSD-3-Clause |

## Licenses

The benchmarks are vendored from several projects under several licenses. Every
suite directory carries its own `LICENSE` and an `ORIGIN.md` naming the project
the files came from, the original authors where RB repackaged someone else's
work, and what was changed to fit the harness contract. Start there.

| Suite | License | Details |
|---|---|---|
| areWeFast | MIT, and Revised BSD for `mandelbrot` | [ORIGIN.md](benchmarks/areWeFast/ORIGIN.md) |
| RealThing | GPL-2 | [ORIGIN.md](benchmarks/RealThing/ORIGIN.md) |
| SpeedTest | GPL-2 | [ORIGIN.md](benchmarks/SpeedTest/ORIGIN.md) |
| shootout | BSD-3-Clause | [ORIGIN.md](benchmarks/shootout/ORIGIN.md) |
| mathkernel | BSD-3-Clause | [ORIGIN.md](benchmarks/mathkernel/ORIGIN.md) |
| misc | BSD-3-Clause | [ORIGIN.md](benchmarks/misc/ORIGIN.md) |
| R-benchmark-25 | BSD-3-Clause | [ORIGIN.md](benchmarks/R-benchmark-25/ORIGIN.md) |
| riposte | BSD-3-Clause | [ORIGIN.md](benchmarks/riposte/ORIGIN.md) |

The five BSD-3-Clause suites were ported from the **R Benchmark Suite (RB)**,
<https://github.com/rbenchmark/benchmarks>, and each ported file carries an
`# Upstream:` comment pointing back to it. RB had itself repackaged several from
their own upstreams; both links are in each `ORIGIN.md`.

The harnesses (`harness*.R`), `marker.c`, the drivers, `scripts/` and `perf/` are
this repository's own work, under the MIT license — see [`LICENSE`](LICENSE).
The vendored suites keep the licenses above; those are the upstreams' terms
and are not ours to change.
