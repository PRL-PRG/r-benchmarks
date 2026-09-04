# Benchmarks

R benchmark suites.

## Benchmark conventions

Every benchmark is an `.R` file that defines:

- **`execute(size = <default>)`** — the workload, run once per iteration and
  timed. Its first argument is the sizing parameter (the harness passes the
  registered value, falling back to this default).

A benchmark may additionally define:

- **`doctor()`** — returns `TRUE` when its dependencies (R packages, data files)
  are present, or a **string** describing what is missing. When it is not `TRUE`
  the harness **fails** with that message and runs no iterations: a missing
  dependency is an error, not a quietly absent benchmark.
- **`setup()`** — prepares inputs (draws them, or reads a cached data file). It
  runs once, after `doctor()` and **before** the timed iterations, so its cost is
  excluded from the runtime, and it leaves the inputs **in memory** (by
  convention in a top-level `.data` it fills with `<<-`). `execute()` must
  neither generate nor load data. `setup()` must be idempotent, and it is given
  the same size `execute()` will get.

## Suites

This table is an interface, not just documentation: a consumer parses it to
decide what the corpus contains, keying on lines that begin with `| [`. Keep the
four columns, keep the suite name a markdown link in the first one, and do not
start any other table's rows that way.

| Suite | Description | Original source | License |
|---|---|---|---|
| [areWeFast](areWeFast) | Core micro-benchmarks from the *Are We Fast Yet?* cross-language suite (bounce, mandelbrot, storage), translated to R by Kalibera et al. (VEE'14, doi:10.1145/2576195.2576205). | [smarr/are-we-fast-yet](https://github.com/smarr/are-we-fast-yet) | MIT |
| [RealThing](RealThing) | Real-world R workloads: convolution, volcano rendering, flexclust clustering. | R *Writing R Extensions* manual; [flexclust](https://cran.r-project.org/package=flexclust) (© F. Leisch) | GPL-2 |
| [shootout](shootout) | R port of the Computer Language Benchmarks Game (binary-trees, fasta, n-body, spectral-norm, …). | [RB](https://github.com/rbenchmark/benchmarks); orig [Benchmarks Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/) | BSD-3-Clause |
| [SpeedTest](SpeedTest) | Numerical and text programs: Cholesky, EM, Gaussian processes, HMC, matrix exponential, sieve, MLP, Q-learning. | Radford Neal's [pqR](https://github.com/radfordneal/pqR) speed tests | GPL-2 |
| [mathkernel](mathkernel) | Math kernels: matrix-matrix multiply and vector add (double/int, ±NA; scalar/vector/builtin variants). | [RB](https://github.com/rbenchmark/benchmarks) | BSD-3-Clause |
| [misc](misc) | 2D random walk (scalar / vector / optimized). | [RB](https://github.com/rbenchmark/benchmarks); orig R. Ihaka | BSD-3-Clause |
| [R-benchmark-25](R-benchmark-25) | The ATT *R-benchmark-25*: matrix calculation, matrix functions, and "programmation" kernels. | [RB](https://github.com/rbenchmark/benchmarks); orig [r.research.att.com](http://r.research.att.com/benchmarks/) | BSD-3-Clause |
| [riposte](riposte) | Vector-heavy benchmarks from the Riposte project (black-scholes, k-means, PCA, logistic regression, …). | [RB](https://github.com/rbenchmark/benchmarks); orig [jtalbot/riposte](https://github.com/jtalbot/riposte) (J. Talbot) | BSD-3-Clause |

### What is deliberately not here

A benchmark is a *program*: it computes something a reader can name. Suites of
single-operation probes — one assignment, one `cumsum`, one empty loop, timed in
a repetition loop — were dropped, because their profile is a property of the
operation and not of any program, and averaging over a hundred of them is
averaging over an arbitrary choice of which operations to include. That removed
the whole `simple` and `scalar` suites and pqR's `SpeedTest/tst` tree (89 files);
pqR's `SpeedTest/prg` programs are kept.

### Suites this repository does not define

A consuming repository can add benchmarks of its own without forking the corpus:
put them in `<dir>/<suite>/<name>.R`, declare their sizes in `<dir>/suites.toml`,
and pass `--suite-path <dir>`. They are then run on exactly the terms the corpus
is — same harness, same sealed environment, same iteration framing — and appear
in the same reports. See `load_suites` in [`../rbench.py`](../rbench.py).

This is where a control group belongs: programs written so that each lands in
one known category, so that a measurement method can be checked against an
answer, are not part of the population they control and must not enter a
corpus-wide number.

## Attribution & licenses

Every suite directory carries its own `LICENSE` and an `ORIGIN.md` naming the
project the files came from, the original authors where RB repackaged someone
else's work, and what was changed to fit the harness contract. Start there.

| Suite | License | Details |
|---|---|---|
| areWeFast | MIT, and Revised BSD for `mandelbrot` | [ORIGIN.md](areWeFast/ORIGIN.md) |
| RealThing | GPL-2 | [ORIGIN.md](RealThing/ORIGIN.md) |
| SpeedTest | GPL-2 | [ORIGIN.md](SpeedTest/ORIGIN.md) |
| shootout | BSD-3-Clause | [ORIGIN.md](shootout/ORIGIN.md) |
| mathkernel | BSD-3-Clause | [ORIGIN.md](mathkernel/ORIGIN.md) |
| misc | BSD-3-Clause | [ORIGIN.md](misc/ORIGIN.md) |
| R-benchmark-25 | BSD-3-Clause | [ORIGIN.md](R-benchmark-25/ORIGIN.md) |
| riposte | BSD-3-Clause | [ORIGIN.md](riposte/ORIGIN.md) |

The five BSD-3-Clause suites were ported from the **R Benchmark Suite (RB)**,
<https://github.com/rbenchmark/benchmarks>, and each ported file carries an
`# Upstream:` comment pointing back to it. RB had itself repackaged several from
their own upstreams; both links are in each `ORIGIN.md`.

The harnesses (`harness*.R`, `marker.c`) and the drivers above them are this
repository's own, under BSD-3-Clause — see [`../LICENSE`](../LICENSE).
