#!/usr/bin/env -S uv run --script --quiet
"""Defines and runs the R benchmark corpus."""

import csv
import dataclasses
import os
import re
import sys
import shutil
from collections.abc import Sequence
from dataclasses import field
from pathlib import Path
from typing import Any, Callable, Iterable

from bench import *

_HERE = Path(__file__).resolve().parent
BENCHMARKS_FOLDER = _HERE / "benchmarks"

# ------------------------------------------------------------
# DEFAULTS
# ------------------------------------------------------------


class DefaultRbenchParams(Params):
    runs: int = field(
        default=5,
        metadata={
            "metavar": "N",
            "help": "Measure each benchmark in N separate R processes.",
        },
    )
    iterations: int = field(
        default=4,
        metadata={
            "metavar": "N",
            "help": "Iterations inside each run.",
        },
    )


DEFAULT_ENV = {
    "OPENBLAS_NUM_THREADS": "1",
    "OMP_NUM_THREADS": "1",
    "MKL_NUM_THREADS": "1",
    "VECLIB_MAXIMUM_THREADS": "1",
    "R_LIBS": "",
    "R_LIBS_USER": "",
    "R_LIBS_SITE": "",
}


def inherit_shell_env() -> Env:
    return {
        k: os.environ[k]
        for k in [
            "PATH",
            "HOME",
            "SHELL",
            "USER",
            "TMPDIR",
            "LD_LIBRARY_PATH",
            "LANG",
            "LC_ALL",
            "LC_COLLATE",
            "TZ",
            "R_DISABLE_BYTECODE",
        ]
    }


def default_cmd(
    Rpath: Path,
    ctx: Context[DefaultRbenchParams],
    args: Callable[[str], Sequence[str]],
    # Call with the path to benchmark
    # Return the harness to run (first arg) and its arguments
) -> Command:
    """
    Rpath is the path to the R binary tha shall be executed
    """
    benchmark = str(BENCHMARKS_FOLDER / ctx.suite / (ctx.benchmark + ".R"))
    concrete_args = args(benchmark)

    return [
        str(Rpath),
        "--no-echo",
        "--vanilla",
        "-f",
        concrete_args[0],
        "--args",
        *concrete_args[1:],
    ]


# ------------------------------------------------------------
# SUITE DEFINITION
# ------------------------------------------------------------


ARE_WE_FAST = suite(
    "areWeFast",
    bench("bounce", arg=3000),
    bench("bounce_nonames", arg=10000),
    bench("bounce_nonames_simple", arg=10000),
    bench("mandelbrot", arg=450),
    bench("storage", arg=11),
)

REAL_THING = suite(
    "RealThing",
    bench("convolution", arg=1453),
    bench("convolution_slow", arg=1500),
    bench("convolution_v", arg=2000),
    bench("volcano", arg=1),
    bench("flexclust", arg=5),
    bench("flexclust_no_s4", arg=5),
)

# shootout: `knucleotide`, `regexdna` and `reversecomplement` read a committed
# input named after their size, `fasta/fasta<size>.txt`, so their size has to be
# one of the files that exist (10, 100, 1000..5000, 10000, 50000, 100000, 150000,
# 300000, 500000) - any other value fails to open the file rather than running
# longer.
SHOOTOUT = suite(
    "shootout",
    suite(
        "binarytrees",
        bench("binarytrees", arg=12),
        bench("binarytrees_2", arg=12),
        bench("binarytrees_naive", arg=12),
    ),
    suite(
        "fannkuch",
        bench("fannkuchredux", arg=9),
        bench("fannkuchredux_naive", arg=9),
    ),
    suite(
        "fasta",
        bench("fasta", arg=120000),
        bench("fasta_2", arg=112000),
        bench("fasta_3", arg=86000),
        bench("fasta_naive", arg=102000),
        bench("fasta_naive_2", arg=64000),
    ),
    suite(
        "fastaredux",
        bench("fastaredux", arg=150000),
        bench("fastaredux_naive", arg=110000),
    ),
    suite(
        "knucleotide",
        bench("knucleotide", arg=3000),
        bench("knucleotide_brute", arg=2000),
        bench("knucleotide_brute_2", arg=3000),
        bench("knucleotide_brute_3", arg=2000),
    ),
    suite(
        "mandelbrot",
        bench("mandelbrot_ascii", arg=1700),
        bench("mandelbrot_naive_ascii", arg=370),
        bench("mandelbrot_noout", arg=3200),
        bench("mandelbrot_noout_naive", arg=2161),
    ),
    suite(
        "nbody",
        bench("nbody", arg=25000),
        bench("nbody_2", arg=12000),
        bench("nbody_3", arg=25000),
        bench("nbody_naive", arg=25000),
        bench("nbody_naive_2", arg=25000),
    ),
    suite(
        "pidigits",
        bench("pidigits", arg=112),
    ),
    suite(
        "regexdna",
        bench("regexdna", arg=500000),
    ),
    suite(
        "reversecomplement",
        bench("reversecomplement", arg=300000),
        bench("reversecomplement_2", arg=300000),
        bench("reversecomplement_naive", arg=100000),
    ),
    suite(
        "spectralnorm",
        bench("spectralnorm", arg=220),
        bench("spectralnorm_alt", arg=4989),
        bench("spectralnorm_alt_2", arg=1200),
        bench("spectralnorm_alt_3", arg=250),
        bench("spectralnorm_alt_4", arg=318),
        bench("spectralnorm_math", arg=1200),
        bench("spectralnorm_naive", arg=303),
    ),
)

SPEED_TEST = suite(
    "SpeedTest",
    bench("prg/cholesky", arg=200),
    bench("prg/cv-basisfun", arg=31),
    bench("prg/data", arg=10),
    bench("prg/em", arg=30),
    bench("prg/gcd", arg=500),
    bench("prg/gp", arg=1),
    bench("prg/heat", arg=10),
    bench("prg/hmc/hmc1", arg=50000),
    bench("prg/hmc/hmc2", arg=25000),
    bench("prg/kernel-PCA", arg=100),
    bench("prg/lm-nn", arg=57),
    bench("prg/matexp/matexp_large", arg=20),
    bench("prg/matexp/matexp_medium", arg=30),
    bench("prg/matexp/matexp_small", arg=10),
    bench("prg/matmult/matmult_sumprd", arg=150),
    bench("prg/matmult/matmult_triplp", arg=50),
    bench("prg/mlp", arg=200),
    bench("prg/near/near_large", arg=1000),
    bench("prg/near/near_small", arg=59),
    bench("prg/primes", arg=16),
    bench("prg/Qlearn", arg=30000),
    bench("prg/sieve/sieve1", arg=1505),
    bench("prg/sieve/sieve2", arg=1000),
    bench("prg/text/text_look", arg=50000),
    bench("prg/text/text_replace", arg=1000),
)

# mathkernel: for `MMM-*` the size is the matrix dimension, but for the eight
# `*VecAdd-*` it is the **number of repetitions** of the kernel - their vector
# length is fixed at upstream's 10 million inside the .R files. One `A + B` over
# 10M doubles takes 65 ms, so a size that meant "vector length" would have to
# reach a quarter of a billion elements to be measurable, and the benchmark would
# then be reporting the memory system and its own input generation. Fixing N also
# puts each T1 and its T2 back on the same data, which is the point of the pair.
MATHKERNEL = suite(
    "mathkernel",
    bench("MMM-T1", arg=200),
    bench("MMM-T2", arg=781),
    bench("MMM-T3", arg=1600),
    bench("DoubleVecAdd-T1", arg=2),
    bench("DoubleVecAdd-T2", arg=24),
    bench("IntVecAdd-T1", arg=2),
    bench("IntVecAdd-T2", arg=16),
    bench("IntNAVecAdd-T1", arg=1),
    bench("IntNAVecAdd-T2", arg=15),
    bench("DoubleNAVecAdd-T1", arg=2),
    bench("DoubleNAVecAdd-T2", arg=24),
)

MISC = suite(
    "misc",
    bench("2DRandomWalk/rw2d1", arg=597610),
    bench("2DRandomWalk/rw2d2", arg=4838710),
    bench("2DRandomWalk/rw2d3", arg=10500000),
)

# R-benchmark-25 (ATT): the sizing arg is `runs`, the kernel repeat count. It is
# registered as 1 because the harness already repeats each benchmark; the R
# files keep the original default of 3 for standalone use. Several kernels are
# heavyweight (att1_3 ~15s, att2_4 ~25s per run).
R_BENCHMARK_25 = suite(
    "R-benchmark-25",
    bench("Matrix_calculation/att1_1", arg=3),
    bench("Matrix_calculation/att1_2", arg=3),
    bench("Matrix_calculation/att1_3", arg=1),
    bench("Matrix_calculation/att1_4", arg=2),
    bench("Matrix_calculation/att1_5", arg=1),
    bench("Matrix_functions/att2_1", arg=4),
    bench("Matrix_functions/att2_2", arg=2),
    bench("Matrix_functions/att2_3", arg=1),
    bench("Matrix_functions/att2_4", arg=1),
    bench("Matrix_functions/att2_5", arg=1),
    bench("Programmation/att3_1", arg=6),
    bench("Programmation/att3_2", arg=3),
    bench("Programmation/att3_3", arg=2),
    bench("Programmation/att3_4", arg=23),
    bench("Programmation/att3_5", arg=3),
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
RIPOSTE = suite(
    "riposte",
    bench("black_scholes", arg=10000),
    bench("cleaning", arg=20000000),
    bench("example", arg=20000000),
    bench("filter1d", arg=10000000),
    bench("histogram", arg=9),
    bench("kmeans", arg=1000000),
    bench("lr", arg=50000),
    bench("lr_test", arg=3),
    bench("mandelbrot", arg=100),
    bench("pca", arg=100000),
    bench("pca-blocked", arg=100000),
    bench("raysphere", arg=10000000),
    bench("sample", arg=10000000),
    bench("sample_builtin", arg=10000000),
    bench("smv", arg=20000000),
    bench("smv_builtin", arg=6),
)

ALL_SUITES = (
    suite(
        "",
        ARE_WE_FAST,
        REAL_THING,
        SHOOTOUT,
        SPEED_TEST,
        MATHKERNEL,
        MISC,
        R_BENCHMARK_25,
        RIPOSTE,
    )
    .with_cwd(lambda ctx: BENCHMARKS_FOLDER / ctx.suite)
    .with_env(DEFAULT_ENV)
)
# ------------------------------------------------------------
# DEFAULT HARNESS INSTRUMENTATION
# ------------------------------------------------------------


class RbenchHarnessSuccess:
    COMPLETED = re.compile(r"iteration \d+ completed in ")

    def __call__(self, result: InvocationResult) -> str | None:
        verdict = default_success(result)
        if verdict is None and not self.COMPLETED.search(result.stdout or ""):
            return "no iterations parsed from harness output"
        return verdict


class RbenchHarnessMetric(Metric):
    REGEX = re.compile(
        r"^====== .+?, iteration (?P<iteration>\d+) completed in (?P<runtime>-?\d+\.\d{3}) ms "
        r"\(gc (?P<gc>-?\d+\.\d{3}) ms, forced-gc (?P<forced_gc>-?\d+\.\d{3}) ms, cpu (?P<cpu>-?\d+\.\d{3}) ms\) ======$",
        re.MULTILINE,
    )

    def __init__(self):
        super().__init__(
            "",
            unit="ms",
            direction="lower better",
        )

    def process(self, data: InvocationResult) -> Iterable[Sample]:
        if data.stdout is None:
            return

        for m in self.REGEX.finditer(data.stdout):
            iteration = int(m["iteration"])

            for group in ["runtime", "gc", "forced_gc", "cpu"]:
                yield self.get_sample(
                    float(m[group]),
                    metric=group,
                    iteration=iteration,
                )


def harness_default_cmd(
    Rpath: Path,
    profile: Path | None,
    ctx: Context[DefaultRbenchParams],
) -> Command:
    return default_cmd(
        Rpath,
        ctx,
        lambda file: [
            str(BENCHMARKS_FOLDER / "harness.R"),
            file,
            str(ctx.params.iterations),
            str(ctx.data.arg),
            *((str(profile),) if profile is not None else ()),
        ],
    )


# ------------------------------------------------------------
# DEFAULT MAIN
# ------------------------------------------------------------

# Fixed so the shuffled order is reproducible across sessions and drivers.
SHUFFLE_SEED = 20260810


def default_R():
    help_string = (
        "A path to the R binary. If R is in path, it is used as default"
        "Otherwise it needs to be specified"
    )
    R = shutil.which("R")
    if R is None:
        return field(
            metadata={
                "required": True,
                "help": help_string,
            },
        )
    else:
        return field(
            default=Path(R),
            metadata={"help": help_string},
        )


class RbenchParams(SharedBenchParams, DefaultRbenchParams):
    R: Path = default_R()
    warmups: int = field(
        default=1,
        metadata={
            "metavar": "N",
            "help": "Number of iterations discarded at the start of each run.",
        },
    )
    profile: Path | None = field(
        default=None,
        metadata={
            "help": "A file sourced before running the harness.",
        },
    )


class InProcessWarmup(Controller):
    "Flag the first `warmups` iterations of every execution as warm-up."

    def __init__(self, warmups: int) -> None:
        super().__init__()
        self.warmups = warmups

    def extract_execution(self, b, result: InvocationResult, run: int) -> Execution:
        e = super().extract_execution(b, result, run)
        its = [
            dataclasses.replace(it, warmup=True) if i < self.warmups else it
            for i, it in enumerate(e.iterations)
        ]
        return dataclasses.replace(e, iterations=its)


DEFAULT_APP = (
    bench_app(params=RbenchParams)
    .add(ALL_SUITES.with_shuffle(SHUFFLE_SEED))
    # Cmd
    .with_command(
        lambda ctx: harness_default_cmd(
            ctx.params.R,
            ctx.params.profile,
            ctx,
        )
    )
    # Control
    .with_runs(lambda ctx: FixedRuns(ctx.params.runs))
    .with_controller(lambda ctx: InProcessWarmup(ctx.params.warmups))
    # Result
    .with_success(RbenchHarnessSuccess())
    .with_metric(RbenchHarnessMetric(), Time(), max_rss())
    .with_probe(SystemProbe())
    .with_summary((ByBenchmarkMetricSummary() & ComparisonSummary()))
)

if __name__ == "__main__":
    DEFAULT_APP.main()
