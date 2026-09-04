#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.12"
# dependencies = ["bench"]
#
# [tool.uv.sources]
# bench = { git = "https://github.com/PRL-PRG/bench.git", rev = "e895298db063039fdff8a8b3c1b725569ec25ab4" }
# ///
"""Run the R benchmark corpus on any R build, uninstrumented -- and define it.

This file is two things at once, and deliberately so. It is the plain timing
driver:

    ./rbench.py --R /path/to/R --invocations 1 --runs 10 --warmups 0

and it is the single definition every other driver starts from -- the suites and
their sizes, the shuffle seed, the harness contract, the iteration framing and
the sealed child environment. A driver imports `base_app()` and overrides
exactly what makes it different:

    rbench.py        nothing; the plain timing run
    rbench_perf.py   the command (wrapped in `perf record`) and the metrics

and, in a repository that consumes this one:

    rbench_timeR.py  the command (`--time=`) and the metrics
    rbench_rcp.py    the harness script (`harness_rcp.R`) and the metrics
    rbench_rsh.py    the environment (`PIR_WARMUP`) and the warm-up regime

`bench`'s builder replaces rather than accumulates on every `with_*`, so an
override touches one piece and leaves the rest identical. That is the whole
point: the suites, their sizes, the shuffle seed, the iteration framing and the
sealed environment are shared by construction, and two arms' CSVs can therefore
be divided by each other. A driver that copied any of it would be free to drift.

The measured unit is one *invocation*: a fresh R process that runs `warmups +
runs` iterations of one benchmark.

`R_DISABLE_BYTECODE=1` in the caller's environment turns the byte-code compiler
off in the child (it is on the `_INHERIT` whitelist), which is the whole of the
`ast` arm of a bytecode comparison: one binary, one flag.

A repository that wants to measure benchmarks of its own alongside these adds
them with `--suite-path`; see `load_suites` below.
"""
import os
import platform
import sys
import tomllib
from collections.abc import Iterator, Sequence
from dataclasses import dataclass, field
from pathlib import Path

from bench import (
    Context,
    FixedRuns,
    GeomeanSummary,
    HarnessHandle,
    Regex,
    Results,
    SharedBenchParams,
    Summary,
    SummaryReporter,
    SuiteBuilder,
    SystemEnvironment,
    bench,
    bench_app,
    default_reporter,
    line_monitor,
    max_rss,
    suite,
)

_HERE = Path(__file__).resolve().parent

# Fixed so the shuffled order is reproducible across sessions and drivers.
SHUFFLE_SEED = 20260810


@dataclass(frozen=True)
class Params(SharedBenchParams):
    R: Path = Path("R")
    benchmarks: Path = _HERE / "benchmarks"
    suite_path: list[Path] | None = field(
        default=None,
        metadata={
            "metavar": "DIR",
            "help": "Also take suites from DIR, a directory holding a "
            "`suites.toml` and one subdirectory per suite it declares. "
            "Repeatable. This is how a repository that consumes this corpus "
            "adds benchmarks of its own without forking it: the declared "
            "suites join the registered ones, so every driver built on "
            "`base_app()` sees them on the same terms as the corpus.",
        },
    )
    invocations: int = field(
        default=5,
        metadata={
            "metavar": "N",
            "help": "Measure each benchmark in N separate R processes "
            "(default: 5). The unit of replication: 5x4 puts the 95%% interval "
            "of a benchmark's mean at about 1%%, where 1x10 claims 0.5%% and "
            "delivers 2-3%%.",
        },
    )
    runs: int = field(
        default=4,
        metadata={
            "metavar": "N",
            "help": "Measured iterations inside each process (default: 4).",
        },
    )
    warmups: int = field(
        default=1,
        metadata={
            "metavar": "N",
            "help": "Iterations discarded at the start of each process "
            "(default: 1). The first one is 2%% slower than the steady state at "
            "the median of the corpus and up to 25%% on the worst benchmark, and "
            "the penalty differs between the configurations being compared - the "
            "byte-code compiler pays it, an `ast` run does not.",
        },
    )
    aslr: bool = field(
        default=False,
        metadata={
            "help": "Leave address-space randomization on with --aslr. Off by "
            "default (`setarch -R`, which needs no privileges): layout-dependent "
            "noise is a large part of what separates two invocations.",
        },
    )
    numa: int | None = field(
        default=None,
        metadata={
            "metavar": "NODE",
            "help": "Bind CPUs and memory to this NUMA node (`numactl`). Unset "
            "leaves placement to the kernel, which on a multi-socket machine can "
            "put a process's memory on another socket than its core.",
        },
    )
    denoise: bool = field(
        default=False,
        metadata={
            "help": "Quiet the machine's noisy kernel knobs for the duration of "
            "this run and put them back afterwards. Requires root, and so makes "
            "the whole run root -- see `make denoise` for why the campaign does "
            "it once, separately, instead.",
        },
    )


# FIXME: this should be by default from internal denoise
def denoise_prefix(p: Params) -> list[str]:
    """The unprivileged half of `bench denoise`, as a command prefix.

    The privileged knobs (THP, swappiness, governor) need root and are left to
    `bench denoise minimize`; these two do not, so they are applied per process
    and always, rather than depending on who runs the session. Both `exec` into
    the next program, so they add no process to the tree a profiler records.
    """
    pre: list[str] = []
    if not p.aslr:
        pre += ["setarch", platform.machine(), "-R"]
    if p.numa is not None:
        pre += ["numactl", f"--cpunodebind={p.numa}", f"--membind={p.numa}"]
    return pre


# Everything the child gets from the caller. `env` on an Invocation replaces the
# environment rather than extending it, so listing what to keep is the same work
# as listing what to drop - and a run then depends on the shell that started it
# only through these, instead of through whatever happened to be exported.
#
# `RCP` is read by no part of R: it is what the profile in rcp/benchmarking looks
# at to decide whether to compile each benchmark with the copy-and-patch JIT or
# with the byte-code compiler, and it is here for the same reason
# `R_PROFILE_USER` is below - a driver's startup code is of no use if it cannot
# be told which of its jobs to do. Unset, as it is for every other run, it is
# absent from the child too.
# `R_DISABLE_BYTECODE` is whitelisted for the same reason: the `ast` arm of the
# bytecode comparison is this same binary with the compiler switched off, so the
# only thing that distinguishes the two runs is a variable the child has to see.
#
# `PIR_WARMUP` likewise, and it was missing: `Archive/rir-comparison/run-suite.sh` sets it
# to 5 in its own environment and says why -- RIR's default threshold is 100
# *closure invocations*, the corpus calls the top-level `execute()` once per
# iteration, so at 100 PIR never fires in a 15-iteration run. But the whitelist
# dropped it before the child ever saw it, so that arm was measured with PIR at
# its default: RIR's interpreter rather than its JIT. Anything measured with an
# Ř binary before this line existed should be re-run.
_INHERIT = ("PATH", "HOME", "SHELL", "USER", "TMPDIR", "LD_LIBRARY_PATH",
            "LANG", "LC_ALL", "LC_COLLATE", "TZ", "RCP", "R_DISABLE_BYTECODE",
            "PIR_WARMUP")


def bench_env(p: Params) -> dict[str, str]:
    """A hermetic child environment with every threaded-BLAS knob pinned to one.

    The thread counts are not tuning. The system BLAS/LAPACK here is
    OpenBLAS-pthread, so an unpinned R starts a worker pool sized to the host in
    every process (2.7 s of CPU over 11 cores before it has evaluated anything)
    and runs `eigen`, `svd`, `chol` and friends across all of them. That makes the
    corpus not single-threaded, makes its timings depend on what else the machine
    is doing, and inflates a sampling profile by the thread count. Pinned to one
    thread those benchmarks are no slower (`eigen_full` is 4% faster) while their
    invocation-to-invocation spread drops from 5.8% to 1.1%.

    Setting the variables is not the same as it having worked: `make blas-check`
    runs a large `%*%` under this exact environment and reports CPU time over
    elapsed time, which is about 1 when the pin took and the core count when it
    did not. OPENBLAS_NUM_THREADS is what the pthread build reads and
    OMP_NUM_THREADS what an OpenMP build would; both are set so that neither
    packaging of OpenBLAS can slip through.

    `R_LIBS*` are neutralized because a user library is per *minor* version, so a
    stale `~/R/<arch>-library/4.3` would be on the path of the 4.3.x interpreters
    and of no others, and they would run against a differently built MASS or
    Matrix than their neighbours. A single space and
    not "": R keeps an empty `R_LIBS_USER` and substitutes its default, but drops
    one that names no directory. The cost is that a benchmark whose package lives
    only in a user library now fails its `doctor()` instead of quietly working -
    which is the contract this corpus already has for a missing dependency.
    """
    return {
        **{k: os.environ[k] for k in _INHERIT if k in os.environ},
        "OPENBLAS_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
        "VECLIB_MAXIMUM_THREADS": "1",
        "R_LIBS": " ",
        "R_LIBS_USER": " ",
        "R_LIBS_SITE": " ",
        # The one startup file `bench_cmd` leaves on, and the only channel a
        # caller has into an otherwise sealed process: a driver that needs code
        # to run before the harness - compiling every benchmark with a JIT, say -
        # points `R_PROFILE_USER` at it, and whatever that profile needs to be
        # told it reads from its own path rather than from here. "" and not
        # absent when the caller sets nothing: R falls back to `~/.Rprofile` for
        # a variable that is missing, and reads no profile at all for one that is
        # empty.
        "R_PROFILE_USER": os.environ.get("R_PROFILE_USER", ""),
    }


def _abs(p: Path) -> Path:
    """`p` made absolute against the driver's cwd.

    Not `_anchor_path`'s job, which `--R` gets: that leaves a bare name alone so
    the PATH can resolve it. A suite root is a directory and there is no PATH to
    look one up on, and leaving it relative would be actively wrong -- the
    *child* runs with its cwd set to `params.benchmarks` (see `base_app`), so a
    relative root would mean one directory in the driver and another in the
    process it starts. abspath and not resolve, to match `_anchor_path`:
    normalize without following symlinks.
    """
    return Path(os.path.abspath(p))


def benchmark_roots(p: Params) -> tuple[Path, ...]:
    """Where a benchmark's `.R` file may live: the corpus, then any `--suite-path`."""
    return (_abs(p.benchmarks), *(_abs(d) for d in p.suite_path or ()))


def resolve_bench(ctx: Context[Params]) -> Path:
    """The `.R` file of `ctx`'s benchmark, looked up across the suite roots.

    The corpus wins over a `--suite-path` when both define the same
    `<suite>/<benchmark>`, so nothing downstream shadows a corpus benchmark by
    accident; and the error names every root that was tried, because "no such
    benchmark" carrying a single path is the least useful form of that message
    once there is more than one root.
    """
    rel = Path(ctx.suite) / f"{ctx.benchmark}.R"
    roots = benchmark_roots(ctx.params)
    for root in roots:
        f = root / rel
        if f.is_file():
            return f
    tried = ", ".join(str(r) for r in roots)
    raise FileNotFoundError(f"{rel}: no such benchmark under any of: {tried}")


# The manifest a `--suite-path` directory is required to carry.
SUITES_TOML = "suites.toml"


def load_suites(root: Path) -> tuple[SuiteBuilder, ...]:
    """The suites a `--suite-path` directory declares, from its `suites.toml`.

    One table per suite, one key per benchmark, the value its size argument:

        [synthetic]
        interpreter = 36000000
        "mem-alloc" = 27000

    Quoted keys where a name contains `/`, which `shootout` does -- its
    benchmarks sit a directory deeper than their suite.

    A file rather than Python, because the point of `--suite-path` is that a
    consuming repository needs neither an import of this module nor a fork of it
    to add benchmarks: it drops a directory of suite subdirectories with this
    manifest beside them and names it on the command line. The sizes of *this*
    corpus stay in `SUITES` below, where the paragraph explaining why a given
    number is a repetition count and not a data dimension can sit next to it.

    Every declared file is checked here, at startup, rather than left to
    `resolve_bench` when the run reaches it: a typo in a manifest should cost a
    second, not a campaign that fails an hour in with most of its output already
    written.
    """
    manifest = root / SUITES_TOML
    if not manifest.is_file():
        raise FileNotFoundError(f"--suite-path {root}: no {SUITES_TOML}")
    with open(manifest, "rb") as f:
        declared = tomllib.load(f)

    suites: list[SuiteBuilder] = []
    for group, entries in declared.items():
        if not isinstance(entries, dict):
            raise TypeError(
                f"{manifest}: [{group}] must be a table of benchmark = size, "
                f"got {type(entries).__name__}"
            )
        items: list[tuple[str, int]] = []
        for name, arg in entries.items():
            if not isinstance(arg, int):
                raise TypeError(
                    f"{manifest}: [{group}] {name} must be an integer size, "
                    f"got {arg!r}"
                )
            if not (root / group / f"{name}.R").is_file():
                raise FileNotFoundError(
                    f"{manifest}: [{group}] {name} declares no such file "
                    f"{root / group / f'{name}.R'}"
                )
            items.append((name, arg))
        suites.append(_suite(group, items))
    return tuple(suites)


def bench_cmd(
    ctx: Context[Params], iterations: int, harness: str | Path = "harness.R"
) -> list[str]:
    """The R harness command running `<suite>/<benchmark>.R` `iterations` times.

    `harness` names the script under `params.benchmarks` that does the running,
    and is the one part of this command a timing driver is expected to vary:
    `harness_rcp.R` compiles every closure with a JIT on the way in and is
    otherwise this same run. It is resolved against the corpus root and never
    against a `--suite-path`, because a harness belongs to the measurement
    design rather than to any suite -- an extra suite that shipped its own would
    be measured by different rules than the corpus it is compared against. An
    absolute `harness` overrides that and is used as given (`pathlib` returns
    the right operand of `/` when it is absolute), so a driver that genuinely
    has a harness outside the corpus can still point at it.

    The startup files are switched off one at a time and not with `--vanilla`,
    which is these four plus `--no-init-file`. `Rprofile.site`, `.Renviron` and a
    restored workspace are contamination - each can set the JIT level,
    `options(matprod)` or the library path, the same class of problem as a stale
    user library shadowing a build's own packages - but the *user* profile is the
    one startup file a driver has a use for, since it is how code gets to run
    before the harness does: rcp/benchmarking points `R_PROFILE_USER` at a
    profile that compiles each benchmark with a JIT on its way in, and measures
    that against this same command. `bench_env` keeps it under the caller's
    control and reads none by default, so a run that asks for no profile is
    exactly as sealed as `--vanilla` made it. A driver that wants the strict
    flag regardless takes it itself.
    (`--no-echo` is spelled `--slave` before R 4.0.)
    """

    p = ctx.params
    return [
        *denoise_prefix(p),
        str(p.R),
        "--no-echo",
        "--no-save",
        "--no-restore",
        "--no-environ",
        "--no-site-file",
        "-f",
        str(p.benchmarks / harness),
        "--args",
        str(resolve_bench(ctx)),
        str(iterations),
        str(ctx.data.arg),
    ]


def instrument_cmd(ctx: Context[Params]) -> list[str]:
    """The one-shot harness command: `setup(arg)` then one `execute(arg)`.

    The repeat loop of `harness.R` would pollute a recording, so a profiled run
    goes through `benchmarks/harness_instrument.R` instead - it prepares the
    benchmark's inputs and runs the kernel exactly once, and brackets each phase
    with a CLOCK_MONOTONIC `MARK` line so the recording can be cut down to
    `execute` alone. Shared rather than copied into each profiling driver:
    `perf` and timeR are compared against each other, so they have to record the
    same process, and they no longer live in the same repository.

    `--vanilla` here rather than `bench_cmd`'s five separate flags: a profiled
    run has no use for the `R_PROFILE_USER` escape hatch, and the stricter flag
    says so.
    """
    p = ctx.params
    return [
        *denoise_prefix(p),
        str(p.R),
        "--no-echo",
        "--vanilla",
        "-f",
        str(p.benchmarks / "harness_instrument.R"),
        "--args",
        str(resolve_bench(ctx)),
        str(ctx.data.arg),
    ]


def _cmd(ctx: Context[Params]):
    return bench_cmd(ctx, ctx.params.warmups + ctx.params.runs)


def _iteration_monitor(handle: HarnessHandle) -> Iterator[str]:
    """Frame each harness `started -> completed` block into one iteration."""

    # Two spellings, because the harnesses do not agree on one: `harness.R`
    # writes "iteration N completed in X ms (gc ...)", `harness_rcp.R` writes
    # "iteration N completed (X ms)". Framing on only the first silently yields
    # no iterations at all for the second -- every benchmark then reports zero
    # samples and is marked failed while exiting 0, which is exactly what the rcp
    # arm did. The metric regexes still differ per driver; this only decides
    # where one iteration's output ends.
    buf: list[str] = []
    for line in line_monitor(handle):
        if ", iteration" in line and "started ======" in line:
            buf = [line]
        elif ", iteration" in line and ("completed in " in line
                                        or "completed (" in line):
            buf.append(line)
            yield "\n".join(buf)
            buf = []
        elif buf:
            buf.append(line)


def _suite(group: str, entries: list[tuple[str, int]]):
    # Shuffled at the suite level, which is where `bench` can do it: it permutes
    # the *resolved* variants, so the invocations of one benchmark end up spread
    # across the suite rather than run back to back.
    s = suite(group).with_shuffle(SHUFFLE_SEED)
    for name, arg in entries:
        s = s.add(bench(name, arg=arg))
    return s


# All three come from the harness's single `completed` line. `runtime` is the
# metric everything downstream reads; the other two are what make the
# memory-management cost and an accidentally threaded run visible instead of
# folded into `runtime`.
def metrics() -> tuple[Regex, ...]:
    return (
        Regex(
            "runtime", r"iteration \d+ completed in ([\d.]+) ms", unit="ms"
        ).lower_is_better(),
        Regex(
            "gc", r"completed in [\d.]+ ms \(gc ([\d.]+) ms", unit="ms"
        ).lower_is_better(),
        Regex("cpu", r"completed in .*cpu ([\d.]+) ms\)", unit="ms").lower_is_better(),
    )


def summary(axis: str | Sequence[str] = "rep") -> SummaryReporter:
    """The summary block of a timing report, ranked over `axis` of the matrix.

    `Results` and `Summary` are what `bench` shows by default - the per-variant
    samples and their statistics. `GeomeanSummary` is the block that reads a whole
    session at once: it ranks the values of `axis` by the geometric mean of
    `runtime` over the benchmarks of a suite, relative to the fastest, so a
    difference that is spread thinly over a hundred benchmarks is one line rather
    than a hundred comparisons done by eye. Only `runtime`: `gc` and `cpu`
    diagnose an individual benchmark, and a geomean of either says nothing.

    The default axis is the only dimension this app has, the invocation, and there
    the block is a noise check rather than a comparison - every `rep` is the same
    program on the same interpreter, so a spread between them is the spread of the
    machine, and the drift over a session the module docstring describes shows up
    as a monotone ranking. A driver that varies something real passes its own --
    `["version", "mode"]` for one that sweeps interpreter builds -- and shares
    this function so that its report and this one cannot drift apart.
    """
    return SummaryReporter(
        Results() & Summary() & GeomeanSummary(axis=axis, metrics="runtime")
    )


are_we_fast = _suite(
    "areWeFast",
    [
        ("bounce", 3000),
        ("bounce_nonames", 10000),
        ("bounce_nonames_simple", 10000),
        ("mandelbrot", 450),
        ("storage", 11),
    ],
)

real_thing = _suite(
    "RealThing",
    [
        ("convolution", 1453),
        ("convolution_slow", 1500),
        ("convolution_v", 2000),
        ("volcano", 1),
        ("flexclust", 5),
        ("flexclust_no_s4", 5),
    ],
)

# shootout: `knucleotide`, `regexdna` and `reversecomplement` read a committed
# input named after their size, `fasta/fasta<size>.txt`, so their size has to be
# one of the files that exist (10, 100, 1000..5000, 10000, 50000, 100000, 150000,
# 300000, 500000) - any other value fails to open the file rather than running
# longer. analysis/calibrate-sizes.py snaps them to the nearest available.
shootout = _suite(
    "shootout",
    [
        ("binarytrees/binarytrees", 12),
        ("binarytrees/binarytrees_2", 12),
        ("binarytrees/binarytrees_naive", 12),
        ("fannkuch/fannkuchredux", 9),
        ("fannkuch/fannkuchredux_naive", 9),
        # Resized 2026-08-29, when the bulk `cat` in these twelve was replaced
        # by a checksum (they wrote up to 3 MB per iteration against a corpus
        # median of 203 B, so a fifth of their samples landed in output
        # formatting). Removing that made them ~40% faster, so the sizes were
        # re-fitted to about a second of kernel. The three `reversecomplement`
        # sizes name an input file rather than a scale, so they take the nearest
        # size a file exists for: 0.83-0.89 s rather than 1.00 s.
        ("fasta/fasta", 120000),
        ("fasta/fasta_2", 112000),
        ("fasta/fasta_3", 86000),
        ("fasta/fasta_naive", 102000),
        ("fasta/fasta_naive_2", 64000),
        ("fastaredux/fastaredux", 150000),
        ("fastaredux/fastaredux_naive", 110000),
        ("knucleotide/knucleotide", 3000),
        ("knucleotide/knucleotide_brute", 2000),
        ("knucleotide/knucleotide_brute_2", 3000),
        ("knucleotide/knucleotide_brute_3", 2000),
        ("mandelbrot/mandelbrot_ascii", 1700),
        ("mandelbrot/mandelbrot_naive_ascii", 370),
        ("mandelbrot/mandelbrot_noout", 3200),
        ("mandelbrot/mandelbrot_noout_naive", 2161),
        ("nbody/nbody", 25000),
        ("nbody/nbody_2", 12000),
        ("nbody/nbody_3", 25000),
        ("nbody/nbody_naive", 25000),
        ("nbody/nbody_naive_2", 25000),
        ("pidigits/pidigits", 112),
        ("regexdna/regexdna", 500000),
        ("reversecomplement/reversecomplement", 300000),
        ("reversecomplement/reversecomplement_2", 300000),
        ("reversecomplement/reversecomplement_naive", 100000),
        ("spectralnorm/spectralnorm", 220),
        ("spectralnorm/spectralnorm_alt", 4989),
        ("spectralnorm/spectralnorm_alt_2", 1200),
        ("spectralnorm/spectralnorm_alt_3", 250),
        ("spectralnorm/spectralnorm_alt_4", 318),
        ("spectralnorm/spectralnorm_math", 1200),
        ("spectralnorm/spectralnorm_naive", 303),
    ],
)

speed_test = _suite(
    "SpeedTest",
    [
        ("prg/cholesky", 200),
        ("prg/cv-basisfun", 31),
        ("prg/data", 10),
        ("prg/em", 30),
        ("prg/gcd", 500),
        ("prg/gp", 1),
        ("prg/heat", 10),
        ("prg/hmc/hmc1", 50000),
        ("prg/hmc/hmc2", 25000),
        ("prg/kernel-PCA", 100),
        ("prg/lm-nn", 57),
        ("prg/matexp/matexp_large", 20),
        ("prg/matexp/matexp_medium", 30),
        ("prg/matexp/matexp_small", 10),
        ("prg/matmult/matmult_sumprd", 150),
        ("prg/matmult/matmult_triplp", 50),
        ("prg/mlp", 200),
        ("prg/near/near_large", 1000),
        ("prg/near/near_small", 59),
        ("prg/primes", 16),
        ("prg/Qlearn", 30000),
        ("prg/sieve/sieve1", 1505),
        ("prg/sieve/sieve2", 1000),
        ("prg/text/text_look", 50000),
        ("prg/text/text_replace", 1000),
    ],
)

# mathkernel: for `MMM-*` the size is the matrix dimension, but for the eight
# `*VecAdd-*` it is the **number of repetitions** of the kernel - their vector
# length is fixed at upstream's 10 million inside the .R files. One `A + B` over
# 10M doubles takes 65 ms, so a size that meant "vector length" would have to
# reach a quarter of a billion elements to be measurable, and the benchmark would
# then be reporting the memory system and its own input generation. Fixing N also
# puts each T1 and its T2 back on the same data, which is the point of the pair.
mathkernel = _suite(
    "mathkernel",
    [
        ("MMM-T1", 200),
        ("MMM-T2", 781),
        ("MMM-T3", 1600),
        ("DoubleVecAdd-T1", 2),
        ("DoubleVecAdd-T2", 24),
        ("IntVecAdd-T1", 2),
        ("IntVecAdd-T2", 16),
        ("IntNAVecAdd-T1", 1),
        ("IntNAVecAdd-T2", 15),
        ("DoubleNAVecAdd-T1", 2),
        ("DoubleNAVecAdd-T2", 24),
    ],
)

misc = _suite(
    "misc",
    [
        ("2DRandomWalk/rw2d1", 597610),
        ("2DRandomWalk/rw2d2", 4838710),
        ("2DRandomWalk/rw2d3", 10500000),
    ],
)

# R-benchmark-25 (ATT): the sizing arg is `runs`, the kernel repeat count. It is
# registered as 1 because the harness already repeats each benchmark; the R
# files keep the original default of 3 for standalone use. Several kernels are
# heavyweight (att1_3 ~15s, att2_4 ~25s per run).
r_benchmark_25 = _suite(
    "R-benchmark-25",
    [
        ("Matrix_calculation/att1_1", 3),
        ("Matrix_calculation/att1_2", 3),
        ("Matrix_calculation/att1_3", 1),
        ("Matrix_calculation/att1_4", 2),
        ("Matrix_calculation/att1_5", 1),
        ("Matrix_functions/att2_1", 4),
        ("Matrix_functions/att2_2", 2),
        ("Matrix_functions/att2_3", 1),
        ("Matrix_functions/att2_4", 1),
        ("Matrix_functions/att2_5", 1),
        ("Programmation/att3_1", 6),
        ("Programmation/att3_2", 3),
        ("Programmation/att3_3", 2),
        ("Programmation/att3_4", 23),
        ("Programmation/att3_5", 3),
    ],
)

# riposte: the data-file benchmarks (kmeans, lr, lr_test, pca, pca-blocked, and
# smv_builtin) generate their input in setup() on first run and read it back
# afterwards; the first four need clusterGeneration/MASS to build theirs, which
# their doctor() checks. qr is intentionally omitted: it relies on riposte-VM
# semantics and cannot run under GNU R.
#
# For `histogram`, `smv_builtin` and `lr_test` the size is the **number of
# repetitions** of the kernel, not a data dimension: one tabulate over 100M
# integers is 164 ms, one sparse matvec over 10M nonzeros is 250 ms, and lr_test's
# workload is fixed by the data file it shares with lr. Growing the data instead
# would have meant gigabytes of input and tens of seconds of setup per run.
riposte = _suite(
    "riposte",
    [
        ("black_scholes", 10000),
        ("cleaning", 20000000),
        ("example", 20000000),
        ("filter1d", 10000000),
        ("histogram", 9),
        ("kmeans", 1000000),
        ("lr", 50000),
        ("lr_test", 3),
        ("mandelbrot", 100),
        ("pca", 100000),
        ("pca-blocked", 100000),
        ("raysphere", 10000000),
        ("sample", 10000000),
        ("sample_builtin", 10000000),
        ("smv", 20000000),
        ("smv_builtin", 6),
    ],
)

# The corpus: eight suites, 118 benchmarks. Shared so a driver - e.g.
# rbench_perf.py - can reuse them via `rbench.SUITES` and build its own app with
# whatever configuration it needs.
#
# A control group is deliberately not among them. Programs written so that each
# lands in one known category, so that a profiling method can be checked against
# an answer instead of against another method, are not part of the population
# they control: registering them here would move every corpus-wide number
# computed from `SUITES`. They belong to the study that needs them and reach
# this corpus through `--suite-path`.
SUITES = (
    are_we_fast,
    real_thing,
    shootout,
    speed_test,
    mathkernel,
    misc,
    r_benchmark_25,
    riposte,
)

# The suite-shared configuration lives on the app (not per suite) so a variant -
# e.g. rbench_perf.py - can reuse the suites and override just what it needs with

def _denoise_from_argv(argv: Sequence[str] | None = None) -> bool:
    """Whether this run should denoise the machine around itself.

    Off unless `--denoise` is given, because denoising needs root and `bench`
    applies it around the *whole* run -- so asking for it here makes the R
    processes, and everything they write, root-owned. A campaign therefore
    quiets the machine once with `make denoise` and runs the arms unprivileged;
    `make denoise-check` is what stops an arm that would otherwise measure a
    machine nobody quieted. `--denoise` remains for a one-off `sudo ./rbench.py`.

    Read from argv rather than from the parsed params, and the duplication is the
    library's shape rather than a choice: `with_denoise()` stores a plain bool
    and the runner tests it directly, so it is decided when the app is *built* --
    at import, before argparse has run. Declaring it on `Params` is what puts it
    in `--help`; reading argv here is what makes it take effect.

    `bench` raises rather than warns when it is asked for without root, so a run
    that could not quiet the machine stops rather than quietly producing noisier
    numbers.
    """
    argv = sys.argv if argv is None else argv
    return "--denoise" in argv


def _suites_from_argv(argv: Sequence[str] | None = None) -> tuple[SuiteBuilder, ...]:
    """The extra suites named by `--suite-path` on the command line.

    Read from argv for the same reason `_denoise_from_argv` is, and the comment
    there applies verbatim: `add_all` runs when the app is *built*, at import,
    before argparse has run. Declaring `suite_path` on `Params` is what puts it
    in `--help` and what lets `resolve_bench` find the files; reading argv here
    is what gets the suites registered at all.
    """
    argv = sys.argv if argv is None else argv
    out: list[SuiteBuilder] = []
    for i, a in enumerate(argv):
        if a == "--suite-path" and i + 1 < len(argv):
            root = argv[i + 1]
        elif a.startswith("--suite-path="):
            root = a.split("=", 1)[1]
        else:
            continue
        out.extend(load_suites(_abs(Path(root))))
    return tuple(out)


# The suite-shared configuration lives on the app and not per suite, so a driver
# can reuse the suites and override just what it needs with app-level `with_*`
# calls.
def base_app(params: type = Params):
    """The common app: every suite, wired to the shared harness contract.

    `params` lets a driver swap in its own flags -- a subclass of `Params` that
    adds `--freq`, `--pir-warmup` and so on -- while inheriting everything else.
    """
    return (
        bench_app()
        .with_params(params)
        .with_cwd(lambda ctx: ctx.params.benchmarks)
        # One variant per invocation, so each is its own R process and the report
        # carries which process a measurement came from. Named `rep` and not
        # `invocation`: a `Benchmark` already has an `invocation` field (the
        # subprocess spec), and a matrix dimension of that name silently resolves
        # to it in labels and skip rules.
        .with_matrix(rep=lambda ctx: range(ctx.params.invocations))
        # The label also decides how `--include` sees a benchmark: with one, a
        # variant renders `suite/bench/rep0`; without, `suite/bench (rep=0)`.
        # analysis/record.sh has to match both.
        .with_label(lambda b: f"rep{b.rep}")
        .with_command(_cmd)
        .with_env(lambda ctx: bench_env(ctx.params))
        .with_harness(monitor=_iteration_monitor)
        .with_warmup(lambda ctx: FixedRuns(ctx.params.warmups))
        .with_runs(lambda ctx: FixedRuns(ctx.params.runs))
        .with_metric(lambda ctx: metrics())
        .with_process_metric(max_rss())
        # Snapshot the machine into the report and run the noise checks, so a run
        # carries the state it was measured in (and says so when that state is
        # bad).
        .with_environment(SystemEnvironment())
        # Passed as `default_reporter`'s `summary` and not on its own: a bare
        # `SummaryReporter` here replaces the whole bundle, which silently turns
        # off the progress bar and the --json/--csv/--dir sinks.
        .with_reporter(lambda ctx: default_reporter(ctx, summary=summary()))
        # Minimize the noisy kernel knobs on entry and restore them on exit --
        # including on error, so an interrupted arm does not leave the machine
        # pinned. This is the whole of the denoise story: there is no separate
        # step to remember, and an arm that could not do it fails rather than
        # measuring a noisy machine.
        .with_denoise(_denoise_from_argv())
        # The corpus, plus whatever `--suite-path` adds. An extra suite joins on
        # exactly the corpus's terms - same harness, same environment, same
        # framing - which is the only way its numbers mean anything beside the
        # corpus's.
        .add_all(*SUITES, *_suites_from_argv())
    )


app = base_app()


if __name__ == "__main__":
    raise SystemExit(app.main())
