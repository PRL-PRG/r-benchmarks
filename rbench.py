#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.12"
# dependencies = ["bench"]
#
# [tool.uv.sources]
# bench = { git = "https://github.com/PRL-PRG/bench.git", rev = "7bc2cbbfd96ebbf4cd52f67054d5b04f52247b78" }
# ///
"""Defines and runs the R benchmark corpus.
"""
import os
from collections.abc import Iterator, Sequence
from dataclasses import dataclass, field
from pathlib import Path

from bench import (
    Context,
    Diagnostic,
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

# The corpus as shipped, and where the harnesses and `marker.so` live. The
# harness is part of the measurement design rather than of any suite, so it
# comes from here and not from `--benchmarks`: a relocated corpus, or a suite
# declared somewhere else entirely, is still measured by the same rules.
_BUNDLED = _HERE / "benchmarks"

# Fixed so the shuffled order is reproducible across sessions and drivers.
SHUFFLE_SEED = 20260810

# An R file named here is sourced before the benchmark
PROFILE_VAR = "RBENCH_PROFILE"


@dataclass(frozen=True)
class Params(SharedBenchParams):
    R: Path = Path("R")
    benchmarks: Path | None = field(
        default=None,
        metadata={
            "metavar": "DIR",
            "help": "Look for the corpus under DIR (one subdirectory per suite) "
            "instead of the copy bundled beside this script. A suite declared "
            "elsewhere carries its own root and is unaffected.",
        },
    )
    # The three axes of one measurement, outermost first: N processes, each
    # running `warmups + iterations` of the kernel and reporting the last
    # `iterations` of them.
    runs: int = field(
        default=5,
        metadata={
            "metavar": "N",
            "help": "Measure each benchmark in N separate R processes. The unit "
            "of replication: the spread between processes is larger than the "
            "spread within one.",
        },
    )
    iterations: int = field(
        default=4,
        metadata={"metavar": "N", "help": "Measured iterations inside each run."},
    )
    warmups: int = field(
        default=1,
        metadata={
            "metavar": "N",
            "help": "Iterations discarded at the start of each run. The first is "
            "the slowest, and by how much differs between the configurations "
            "being compared.",
        },
    )


# Environment the benchmarks inherit. `env` on an Invocation *replaces* the
# environment rather than extending it, so a run depends on the calling shell
# only through these; anything not listed is dropped silently, and the run then
# succeeds with the default. `R_DISABLE_BYTECODE` is here because turning the
# byte-code compiler off is a property of the run, not of the machine.
_INHERIT = ("PATH", "HOME", "SHELL", "USER", "TMPDIR", "LD_LIBRARY_PATH",
            "LANG", "LC_ALL", "LC_COLLATE", "TZ", "R_DISABLE_BYTECODE",
            PROFILE_VAR)


def bench_env(p: Params) -> dict[str, str]:
    """A sealed child environment with the BLAS pinned to one thread. `R_LIBS*`
    are fixed to empty because a user library is per *minor* R version and
    could mistakenly mess the results. A single space and not "": R substitutes
    its default for an empty value, but drops one that names no directory. """

    return {
        **{k: os.environ[k] for k in _INHERIT if k in os.environ},
        "OPENBLAS_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
        "VECLIB_MAXIMUM_THREADS": "1",
        "R_LIBS": " ",
        "R_LIBS_USER": " ",
        "R_LIBS_SITE": " ",
    }


def diagnostics(p: Params) -> list[Diagnostic]:
    """Report anything about this run that a reader of its numbers should know."""
    hook = os.environ.get(PROFILE_VAR)
    if not hook:
        return []
    return [
        Diagnostic(
            "info", f"{PROFILE_VAR}={hook} is sourced before every benchmark."
        )
    ]


def benchmark_root(p: Params) -> Path:
    """Where benchmark files are looked up: the bundled corpus unless `--benchmarks`.

    Made absolute because it goes on a command line the child reads from another
    directory. `abspath` and not `resolve`, so a symlinked root stays the path
    that was given.
    """
    return Path(os.path.abspath(p.benchmarks or _BUNDLED))


def suite_of(group: str, entries: list[tuple[str, int]]) -> SuiteBuilder:
    """A suite named `group` from `(benchmark, size)` pairs, one per line.

    Registered and not discovered, so the corpus is what this file says it is:
    an `.R` file that is not listed does not run, and a listed one is measured
    at the size beside it.

    A benchmark's name *is* its file -- `<root>/<group>/<name>.R` -- so a nested
    one is spelled `nbody/nbody_naive`. Nothing is looked up here: the path is
    built where the command is, and a name with no file behind it fails in R,
    where every other missing input does.

    Shuffled here, which is where `bench` can do it: it permutes the *resolved*
    variants, so the runs of one benchmark are spread across the suite rather
    than done back to back.
    """
    s = suite(group).with_shuffle(SHUFFLE_SEED)
    for name, size in entries:
        s = s.add(bench(name, arg=size))
    return s


def bench_file(ctx: Context[Params]) -> Path:
    """The `.R` file of `ctx`'s benchmark; its name is its path under the root."""
    return benchmark_root(ctx.params) / ctx.suite / f"{ctx.benchmark}.R"


def _r_cmd(p: Params, harness: str, *args: object) -> list[str]:
    """`R --vanilla -f <harness> --args <args>`, `harness` from `_BUNDLED`.

    (`--no-echo` is spelled `--slave` before R 4.0.)
    """
    return [
        str(p.R),
        "--no-echo",
        "--vanilla",
        "-f",
        str(_BUNDLED / harness),
        "--args",
        *(str(a) for a in args),
    ]


def _cmd(ctx: Context[Params]) -> list[str]:
    """`harness.R` running this benchmark `warmups + iterations` times."""
    p = ctx.params
    return _r_cmd(
        p, "harness.R", bench_file(ctx), p.warmups + p.iterations, ctx.data.arg
    )


def instrument_cmd(ctx: Context[Params]) -> list[str]:
    """The one-shot command: `setup()` then one `execute()`, for a profiler.

    `harness.R`'s repeat loop would pollute a recording, so
    `harness_instrument.R` runs the kernel exactly once and brackets each phase
    with a CLOCK_MONOTONIC `MARK` line, which is what lets a recording be cut
    down to `execute` alone.
    """
    return _r_cmd(ctx.params, "harness_instrument.R", bench_file(ctx), ctx.data.arg)


def _iteration_monitor(handle: HarnessHandle) -> Iterator[str]:
    """Frame each harness `started -> completed` block into one iteration."""
    buf: list[str] = []
    for line in line_monitor(handle):
        if ", iteration" in line and "started ======" in line:
            buf = [line]
        elif ", iteration" in line and "completed in " in line:
            buf.append(line)
            yield "\n".join(buf)
            buf = []
        elif buf:
            buf.append(line)


are_we_fast = suite_of(
    "areWeFast",
    [
        ("bounce", 3000),
        ("bounce_nonames", 10000),
        ("bounce_nonames_simple", 10000),
        ("mandelbrot", 450),
        ("storage", 11),
    ],
)

real_thing = suite_of(
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
shootout = suite_of(
    "shootout",
    [
        ("binarytrees/binarytrees", 12),
        ("binarytrees/binarytrees_2", 12),
        ("binarytrees/binarytrees_naive", 12),
        ("fannkuch/fannkuchredux", 9),
        ("fannkuch/fannkuchredux_naive", 9),
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

speed_test = suite_of(
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
mathkernel = suite_of(
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

misc = suite_of(
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
r_benchmark_25 = suite_of(
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
riposte = suite_of(
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


def summary(axis: str | Sequence[str] = "run") -> SummaryReporter:
    """The report's summary block, ranked over `axis` of the matrix.

    `GeomeanSummary` ranks the values of `axis` by the geometric mean of
    `runtime` over a suite, so a difference spread thinly over a hundred
    benchmarks is one line. Only `runtime`: `gc` and `cpu` diagnose a single
    benchmark and a geomean of either says nothing.

    The default axis is the run, where the block is a noise check rather than a
    comparison -- every run is the same program, so a spread between them is the
    machine's. A driver that varies something real passes its own.
    """
    return SummaryReporter(
        Results() & Summary() & GeomeanSummary(axis=axis, metrics="runtime")
    )


def base_app(params: type = Params):
    """The corpus wired to the harness. `params` swaps in a driver's own flags."""
    return (
        bench_app()
        .with_params(params)
        .with_cwd(_BUNDLED)
        # One variant per run, so each is its own R process and the report
        # carries which process a measurement came from. `run` and not `runs`:
        # a `Benchmark` already has a `runs` field (the stopping policy) and a
        # matrix dimension of that name would silently resolve to it.
        .with_matrix(run=lambda ctx: range(ctx.params.runs))
        # Also decides how `--include` sees a benchmark: with a label a variant
        # renders `suite/bench/run0`, without one `suite/bench (run=0)`.
        .with_label(lambda b: f"run{b.run}")
        .with_command(_cmd)
        .with_env(lambda ctx: bench_env(ctx.params))
        .with_harness(monitor=_iteration_monitor)
        .with_warmup(lambda ctx: FixedRuns(ctx.params.warmups))
        # `bench`'s `runs` is the number of measured iterations it expects the
        # harness to report, which is this driver's `iterations`.
        .with_runs(lambda ctx: FixedRuns(ctx.params.iterations))
        .with_metric(lambda ctx: metrics())
        .with_process_metric(max_rss())
        # Snapshot the machine into the report and run the noise checks, so a
        # run carries the state it was measured in (and says so when it is bad).
        .with_environment(SystemEnvironment())
        .with_diagnostics(diagnostics)
        # Passed as `default_reporter`'s `summary` and not on its own: a bare
        # `SummaryReporter` replaces the whole bundle, which silently turns off
        # the progress bar and the --json/--csv/--dir sinks.
        .with_reporter(lambda ctx: default_reporter(ctx, summary=summary()))
        .add_all(*SUITES)
    )


app = base_app()


if __name__ == "__main__":
    raise SystemExit(app.main())
