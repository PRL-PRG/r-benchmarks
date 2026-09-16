# r-benchmarks

A curated benchmark suite for the R programming language including a common
harness to run them. It uses the [bench](https://github.com/PRL-PRG/bench)
benchmarking framework.

```sh
$ git clone https://github.com/PRL-PRG/r-benchmarks && cd r-benchmarks
$ ./rbench.py --R "$(command -v R)" --include 'areWeFast/mandelbrot' --runs 1 --iterations 3

Finished: areWeFast/mandelbrot/run0: 4.18 elapsed [s] (harness)

areWeFast/mandelbrot   runtime [ms]
  matrix   mean ± σ        min … max
  run0     985.79 ± 4.42   (980.98 … 989.69) (1 warmup, 3 runs, 0 failed)

areWeFast/mandelbrot   gc [ms]
  matrix   mean ± σ      min … max
  run0     6.67 ± 1.53   (5.00 … 8.00) (1 warmup, 3 runs, 0 failed)

areWeFast/mandelbrot   cpu [ms]
  matrix   mean ± σ        min … max
  run0     985.67 ± 4.51   (981.00 … 990.00) (1 warmup, 3 runs, 0 failed)

areWeFast/mandelbrot   elapsed [s]
  matrix   value
  run0     4.18    (1 samples, 1 warmup, 3 runs, 0 failed)

areWeFast/mandelbrot   max_rss [MB]
  matrix   value
  run0     69.59   (1 samples, 1 warmup, 3 runs, 0 failed)
```

No install step: the drivers are [PEP 723](https://peps.python.org/pep-0723/)
scripts and `uv` builds their environment on first run. You need `uv` and an R
binary.

## The benchmark contract

A benchmark is one `.R` file under `benchmarks/<suite>/`. Timing, repetition and
process management belong to the harness, never to the benchmark. A benchmark's
size is its `execute()` default, calibrated so it runs about a second.

It must define:

- **`execute(size = <default>)`** — the workload, run once per iteration and
  timed. Its first argument is the sizing parameter; the harness passes the
  registered value, falling back to this default.

It may additionally define:

- **`doctor()`** — returns `TRUE` when its dependencies (R packages, data files)
  are present, or a **string** describing what is missing. When it is not `TRUE`
  the harness **fails** with that message and runs no iterations: a missing
  dependency is an error, not a quietly absent benchmark.
- **`setup(size)`** — prepares inputs (draws them, or reads a cached data file).
  It runs once, after `doctor()` and **before** the timed iterations, so its cost
  is excluded from the runtime, and it leaves the inputs **in memory** (by
  convention in a top-level `.data` it fills with `<<-`). `execute()` must
  neither generate nor load data. `setup()` must be idempotent, and it is given
  the same size `execute()` will get.

## How a benchmark is run

One benchmark at one size, in one process, is:

```sh
R --no-echo --vanilla -f benchmarks/harness.R --args <benchmark>.R <warmups+iterations> <size>
```

The harness sources `RBENCH_PROFILE` if set, then `setwd()`s to the
**benchmark's own directory** — which is what lets a benchmark reach its `data/`
cache and its helpers by relative path, and `shootout` reach `../fasta/` — then
sources the benchmark and runs `doctor()`, `setup(size)`, the optional
`rbench_prepare()` hook, and finally `iterations` calls of `execute(size)`.

The harness does not know about warm-up. It is passed `warmups + iterations` and
runs exactly that many, printing one line per iteration; deciding that the first
`warmups` of them do not count is the driver's job, not the harness's.

The child's environment is **replaced**, not extended — only `PATH`, `HOME`,
`SHELL`, `USER`, `TMPDIR`, `LD_LIBRARY_PATH`, `LANG`, `LC_ALL`, `LC_COLLATE`,
`TZ`, `R_DISABLE_BYTECODE` and `RBENCH_PROFILE` are passed through. A run
therefore depends on the calling shell only through those, and anything else is
dropped silently rather than changing a measurement invisibly.

The resolved variants are **shuffled** under a fixed seed, so the runs of one
benchmark are spread across the suite rather than done back to back: a machine
that drifts during a long session then spreads that drift across every
benchmark instead of concentrating it in whichever ran while it drifted.

### Running benchmark without bench

The harness is usable on its own, which is the quickest way to try a change to
one benchmark:

```sh
cd benchmarks
R --no-echo --vanilla -f harness.R --args areWeFast/mandelbrot.R 3
```

That prints a `====== ... completed in <t> ms ... ======` line per iteration and
nothing else. Pass a size as a third argument to override the benchmark's own
default; omit it and `formals(execute)[[1]]` is used.

What you give up is the sealing, so numbers from this are for looking at, not
for comparing against another build. To get the driver's environment, set it
yourself:

```sh
cd benchmarks
env OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    VECLIB_MAXIMUM_THREADS=1 R_LIBS=" " R_LIBS_USER=" " R_LIBS_SITE=" " \
  R --no-echo --vanilla -f harness.R --args riposte/kmeans.R 3
```

The single space in `R_LIBS*` is deliberate and not the same as `""`: R
substitutes its default for an empty value, but drops one that names no
directory.

## Running in Docker

The image built by [`Dockerfile`](Dockerfile) carries R, the corpus, the CRAN
packages the benchmarks need and a resolved `bench`, and its entrypoint is the
driver — so flags are all there is to pass:

```sh
docker build -t r-benchmarks .
docker run --rm r-benchmarks --include '^areWeFast/' --runs 1 --iterations 3
```

`docker run --rm r-benchmarks` with no flags runs the whole corpus at the
driver's defaults. To keep the results, write them into a mounted directory:

```sh
docker run --rm -v "$PWD/out:/out" --user "$(id -u):$(id -g)" r-benchmarks \
  --runs 3 --iterations 5 --warmups 2 \
  --json /out/report.json --csv /out/samples.csv --dir /out/runs
```

`--user` is worth the noise: without it the container writes as root and you get
a `out/` you need `sudo` to delete.

CI publishes the same image per commit, so a run can be reproduced without
building anything:

```sh
docker run --rm ghcr.io/prl-prg/r-benchmarks:<commit-sha> --list
```

Anything other than the driver needs `--entrypoint`, e.g.
`docker run --rm --entrypoint R r-benchmarks --version`.

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

## The measurement design

The scripts takes a few flags to control how the benchmarks are run:

- `--runs` controls how many R process will run.
- `--iterations` is the number of iterations the benchmark will run in one R process.
- `--warmups` controls how many iterations will be discarded for the statistics (marked as warmup in the results).

R runs under `--vanilla`, so no startup file of the user's or the machine's can
change what is measured. The one way in is `RBENCH_PROFILE`, an R file sourced
before the benchmark — for installing a JIT, setting a compiler option, or
starting a tracer. If it defines `rbench_prepare()`, that is called after
`setup()` and before the first iteration, which is where an ahead-of-time
compiler acts on the benchmark's loaded functions. Either way the run reports
that it was used, and the report records it.

`--dry` prints the exact command and environment each child would get, without
running anything, which is the quickest way to see what a flag actually did:

```sh
./rbench.py --R "$(command -v R)" --include '^mathkernel/MMM-T3/run0' --dry
```

Setting the thread variables is not the same as the pin having worked, and
`--dry` cannot tell you that it did — only that they were set. To check the
pin itself, run a large `%*%` under that environment and compare CPU time to
elapsed: about 1 when it took, about the core count when it did not.

## R package dependencies

Some benchmarks need a few CRAN packages. Then can be installed using:

```sh
cd benchmarks && R_LIBS=" " R_LIBS_USER=" " R_LIBS_SITE=" " \
  /path/to/R --slave --no-restore -f install_packages.R \
  --args "$(/path/to/R RHOME)/library"
```

One library per interpreter, because compiled code is not portable across R
builds.

## Profiling

`rbench_perf.py` runs each benchmark once through `harness_instrument.R`, which
brackets `source`/`setup`/`gc`/`execute` with CLOCK_MONOTONIC `MARK` lines so a
recording can be cut down to the kernel. That needs `marker.so`:

```sh
make -C benchmarks marker
./rbench_perf.py --R /path/to/R --include '^areWeFast/bounce/' --dir output/perf
```

`--call-graph` selects the unwinder (`dwarf`, `fp`, `lbr`, or `none`/`flat` for
a leaf-only recording). Which one you pick changes the answer, not just the
cost; `dwarf` is the default because it is the only mode that carries inlined
callees.

## Adding your own benchmarks

Suites are **declared, not discovered**: `SUITES` in `rbench.py` is the corpus,
one line per benchmark and its size. Nothing on disk changes what runs, so the
corpus is exactly what that file says it is — an unlisted `.R` file does not
run, and a listed one is measured at the size beside it.

Your own suite is a `suite_of` call and an `add`, which is also how this
repository's consumers register a control group without touching the corpus:

```sh
mkdir -p mine/mysuite && cat > mine/mysuite/fib.R <<'R'
execute <- function(n = 24L) {
  fib <- function(k) if (k < 2L) k else fib(k - 1L) + fib(k - 2L)
  fib(n)
}
R
```

```python
import rbench as rb

MINE = rb.suite_of("mysuite", [("fib", 24), ("deep/prog", 100)])

app = rb.base_app().add(MINE)
```

A benchmark's **name is its file**: `<root>/<suite>/<name>.R`, so `deep/prog`
is `mysuite/deep/prog.R`. Nothing is searched for and nothing is checked at
startup — the path is built when the command is, and a name with no file behind
it fails in R like any other missing input.

`--benchmarks` is the one optional root, and says where those files are looked
up — the directory bundled beside `rbench.py` when it is not given. The
harnesses are *not* taken from it: they come from the bundled directory always,
because a harness is part of the measurement design rather than of a suite, so
a relocated corpus is still measured by the same rules.

```sh
./your_driver.py --R "$(command -v R)"                     # the bundled corpus
./your_driver.py --R "$(command -v R)" --benchmarks ./mine # your suites' files
```

One root per invocation, so a suite whose files live elsewhere gets its own
invocation — which is what the consumers of this corpus do for a control group,
one `--include` and one `--benchmarks` at a time. A helper your benchmarks
`source()` needs no mention anywhere: it is simply not a line in a suite.

They run on exactly the corpus's terms — same harness, same sealed environment,
same framing — and land in the same report.

## Building your own driver

`rbench.py` is a module as well as a script. Import `base_app()` and override
only what differs; `bench`'s builder replaces rather than accumulates, so
everything you do not name stays identical to the plain run:

```python
import rbench as rb

@dataclass(frozen=True)
class Params(rb.Params):
    my_flag: int = 5

app = rb.base_app(Params).with_env(lambda ctx: {**rb.bench_env(ctx.params), ...})
```

`rbench_perf.py` is the worked example: it changes the command, the metrics and
the output tree, and inherits the corpus, the sizes, the shuffle seed and the
environment.

To consume this from another repository, add it as a submodule and declare it as
an editable path dependency in your driver's script header:

```python
# /// script
# requires-python = ">=3.12"
# dependencies = ["bench", "rbench"]
#
# [tool.uv.sources]
# bench  = { git = "https://github.com/PRL-PRG/bench.git", rev = "..." }
# rbench = { path = "r-benchmarks", editable = true }
# ///
```

Your header is what decides which `bench` you measure with, and this repository
deliberately does not pin one for its consumers: `bench` fixes the iteration
framing and the report schema, and it is the consuming repository that has to
keep its own arms comparable to each other. Pinning it in
[`pyproject.toml`](pyproject.toml) as well would decide that for you — and uv
treats it as a hard error rather than a precedence (*"Requirements contain
conflicting URLs for package `bench`"*).

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

The harnesses (`harness*.R`), `marker.c` and the drivers are this repository's
own work, under the MIT license — see [`LICENSE`](LICENSE). The vendored suites
keep the licenses above; those are the upstreams' terms and are not ours to
change.
