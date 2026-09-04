# r-benchmarks

A corpus of **118 R programs in 8 suites**, the R harnesses that run them, and
two drivers: one that times them on any R build, one that profiles them with
`perf`.

It is meant to be usable by anything that needs to measure an R implementation —
a new interpreter, a JIT, a change to GNU R, a compiler flag — without adopting
whatever study it was extracted from. The benchmarks are plain R files with a
three-function contract; the measurement design (process framing, warm-up,
sealed environment, sizes) is one Python module you can import and override.

```sh
git clone https://github.com/PRL-PRG/r-benchmarks && cd r-benchmarks
./rbench.py --R "$(command -v R)" --include '^areWeFast/' --invocations 1 --runs 3
```

No install step: the drivers are [PEP 723](https://peps.python.org/pep-0723/)
scripts and `uv` builds their environment on first run. You need `uv` and an R
binary.

## What is here

| | |
|---|---|
| `benchmarks/` | the 8 suites, the three R harnesses, `install_packages.R`, `marker.c`. Each suite carries its own `LICENSE` and `ORIGIN.md`. |
| `benchmarks/README.md` | the benchmark contract, the suite table, and what was deliberately left out |
| `rbench.py` | the plain timing driver **and** the shared definition every driver starts from |
| `rbench_perf.py` | the same corpus under `perf record`, one recording per invocation |

## The benchmark contract

A benchmark is one `.R` file that defines `execute(size)`, and may define
`setup(size)` and `doctor()`. Timing, repetition and process management belong
to the harness, never to the benchmark. [`benchmarks/README.md`](benchmarks/README.md)
has the full contract.

Sizes are not in the files. They are registered in `SUITES` in
[`rbench.py`](rbench.py), calibrated so each benchmark runs about a second, with
a comment wherever the number means something other than "how much data" — for
`mathkernel`'s `*VecAdd-*` and several others it is a repetition count, and the
comment says why.

## The measurement design

The measured unit is one **invocation**: a fresh R process running
`warmups + runs` iterations of one benchmark. `--invocations` is the unit of
replication, because the spread between processes is larger than the spread
within one.

Every run is sealed the same way, and the reasons are in the docstrings rather
than here: threaded BLAS pinned to one thread, `R_LIBS*` neutralized, startup
files off, the child environment built from a whitelist instead of inherited,
and ASLR disabled via `setarch -R`. Two arms that differ only in the interpreter
are therefore divisible by each other, which is the property the whole design
exists to protect.

`--dry` prints the exact command and environment each child would get, without
running anything, which is the quickest way to see what a flag actually did:

```sh
./rbench.py --R "$(command -v R)" --include '^mathkernel/MMM-T3/rep0' --dry
```

Setting the thread variables is not the same as the pin having worked, and
`--dry` cannot tell you that it did — only that they were set. To check the
pin itself, run a large `%*%` under that environment and compare CPU time to
elapsed: about 1 when it took, about the core count when it did not.

## R package dependencies

Three CRAN packages — `Matrix`, `MASS`, `clusterGeneration` — needed by 9 of the
118 benchmarks, each guarded by a `doctor()` that fails loudly rather than
skipping. Install them into a specific interpreter's own library:

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

Without forking: put them in `<dir>/<suite>/<name>.R`, declare their sizes in
`<dir>/suites.toml`, and pass `--suite-path <dir>`.

```toml
# mybench/suites.toml
[mysuite]
fib = 25
"nested/matmul" = 300
```

```sh
./rbench.py --R /path/to/R --suite-path ./mybench --include '^mysuite/'
```

They run on exactly the corpus's terms — same harness, same sealed environment,
same framing — and land in the same report. Every declared file is checked at
startup, so a typo costs a second rather than a campaign.

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

Your header is what decides which `bench` you measure with — this repository
deliberately does not pin one for its consumers. See the note in
[`pyproject.toml`](pyproject.toml).

## Licenses

The benchmarks are vendored from several projects under several licenses (MIT,
BSD-3-Clause, GPL-2). Each suite directory has its own `LICENSE` and an
`ORIGIN.md` naming the upstream and what was changed; the summary table is in
[`benchmarks/README.md`](benchmarks/README.md).

The harnesses, `marker.c` and the drivers are this repository's own work, under
BSD-3-Clause — see [`LICENSE`](LICENSE).
