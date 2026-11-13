#!/usr/bin/env -S uv run --script --quiet
"""Profile the R benchmark corpus with `perf record`."""

from dataclasses import field
from pathlib import Path
import re
from typing import Iterable

import rbench as rb
from bench import *

_HERE = Path(__file__).resolve().parent
PERF_SUBFOLDER = _HERE / "perf"

DEFAULT_PERF_DIR = Path().cwd() / "output/perf"

class RbenchProfileParams(SharedBenchParams, rb.DefaultRbenchParams):
    R: Path = rb.default_R()
    freq: int = field(
        default=1999,
        metadata={
            "help": "perf sampling frequency (Hz)",
        },
    )
    call_graph: str = field(
        default="dwarf",
        metadata={
            "help": "How the stack is obtained: `dwarf` reconstructs it from CFI, `fp` walks"
            "saved frame pointers, `lbr` reads the CPU's branch stack.",
        },
    )
    stack_size: int = field(
        default=16384,
        metadata={"help": "dwarf stack dump size (bytes; 16 kB)"},
    )

    frames: bool = field(
        default=True,
        metadata={
            "help": "run `perf script` and write perf-frames.csv"
            "The inherited default is None, which writes no tree; a recording needs"
            "somewhere to go. Relative to the caller's cwd, so recordings do not land"
            "inside this checkout.",
        },
    )

    def get_dir(self) -> Path:
        return Path(self.dir).resolve() if self.dir is not None else DEFAULT_PERF_DIR


def instrument_harness_default_cmd(
    Rpath: Path,
    marker: Path,
    ctx: Context[rb.DefaultRbenchParams],
) -> Command:
    return rb.default_cmd(
        Rpath,
        ctx,
        lambda file: [
            str(PERF_SUBFOLDER / "harness_instrument.R"),
            file,
            str(marker),
            str(ctx.data.arg),
        ],
    )


def get_perf(ctx: Context[RbenchProfileParams]) -> PerfRecord:
    p = ctx.params
    return PerfRecord(
        Path(p.get_dir()),
        freq=p.freq,
        call_graph=p.call_graph,
        stack_size=p.stack_size,
        frames=p.frames,
    )


class CompileMarkerHook(Hook):
    executed: bool
    R: Path
    result_dir: Path

    __slots__ = ("executed", "R", "result_dir")

    def __init__(self, R: Path, result_dir: Path) -> None:
        self.executed = False
        self.R = R
        self.result_dir = result_dir

    def setup(self, benchmark: Benchmark) -> None:
        if not self.executed:
            self.result_dir.mkdir(parents=True, exist_ok=True)
            res = execute(
                command=[
                    str(self.R),
                    "CMD",
                    "SHLIB",
                    str(PERF_SUBFOLDER / "marker.c"),
                    "-o",
                    str(self.result_dir / "marker.so"),
                ],
                cwd=rb.BENCHMARKS_FOLDER,
                inherit_env=True,
            )

            if res.returncode != 0:
                raise BenchError("Failed to compile marker.c\n" + res.stderr)

            self.executed = True


class MarkMetric(Metric):
    REGEX = re.compile(
        r"^MARK\t(?P<tag>[^\t\n]*)\t(?P<begin>-?\d+\.\d{6})\t(?P<end>-?\d+\.\d{6})$",
        re.MULTILINE,
    )

    def __init__(self) -> None:
        super().__init__("mark", "", "uncomparable")

    def process(self, data: InvocationResult) -> Iterable[Sample]:
        if data.stdout is None:
            return

        for m in self.REGEX.finditer(data.stdout):
            yield self.get_sample(
                float(m["begin"]),
                extra={
                    "end": float(m["end"]),
                    "tag": m["tag"],
                },
            )


INSTRUMENT_APP = (
    bench_app(params=RbenchProfileParams)
    .add(rb.ALL_SUITES)
    # Cmd
    .with_command(
        lambda ctx: instrument_harness_default_cmd(
            ctx.params.R,
            Path(ctx.params.get_dir()) / "marker.so",
            ctx,
        )
    )
    .with_cwd(lambda ctx: rb.BENCHMARKS_FOLDER / ctx.suite)
    .with_env(rb.DEFAULT_ENV)
    # Control
    .with_runs(1)
    .with_controller(get_perf)
    # Prepare
    .with_hook(lambda ctx: CompileMarkerHook(ctx.params.R, ctx.params.get_dir()))
    # Result
    .with_metric(Time(), MarkMetric())
    .with_probe(SystemProbe())
    .with_summary(ByBenchmarkMetricSummary().on_metrics("elapsed"))
)

if __name__ == "__main__":
    INSTRUMENT_APP.main()
