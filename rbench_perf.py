#!/usr/bin/env -S uv run --script --quiet
"""Profile the R benchmark corpus with `perf record`."""

from dataclasses import field
from pathlib import Path

import rbench as rb
from bench import (
    ByBenchmarkMetricSummary,
    Context,
    PerfRecord,
    Time,
    default_success,
)


# No `@dataclass`: `bench.Params` subclasses are dataclasses already.
class Params(rb.Params):
    # One recording per run, and one `execute()` inside it: harness_instrument.R
    # runs the kernel exactly once, so there is no iteration loop to size.
    runs: int = 1
    iterations: int = 1
    freq: int = 1999  # perf sampling frequency (Hz)
    # How the stack is obtained: `dwarf` reconstructs it from CFI, `fp` walks
    # saved frame pointers, `lbr` reads the CPU's branch stack.
    call_graph: str = "dwarf"
    stack_size: int = 16384  # dwarf stack dump size (bytes; 16 kB)
    frames: bool = True  # run `perf script` and write perf-frames.csv
    # The inherited default is None, which writes no tree; a recording needs
    # somewhere to go. Relative to the caller's cwd, so recordings do not land
    # inside this checkout.
    dir: str = field(
        default="output/perf",
        metadata={
            "metavar": "DIR",
            "help": "Per-execution tree (stdout/stderr/exitcode/seq + perf.data) "
            "under DIR.",
        },
    )


def _perf(ctx: Context[Params]) -> PerfRecord:
    """`perf record` around each execution. It writes `perf.data` and
    `perf-frames.csv` into the same `<dir>/<suite>/<bench>/<variant>/<run>/`
    the dir reporter puts that run's stdout in, MARK lines included."""
    p = ctx.params
    return PerfRecord(
        Path(p.dir),
        freq=p.freq,
        call_graph=p.call_graph,
        stack_size=p.stack_size,
        frames=p.frames,
    )


# What a perf run changes: the command, the absence of an iteration loop, and
# where the output goes. Everything else is `base_app`'s.
app = (
    rb.base_app(Params)
    .with_command(rb.instrument_cmd, override=True)
    # No iteration metric, so no iteration to require and none to flag as a
    # warm-up; `elapsed` stays, `max_rss` goes, and the recording's own counts
    # (`perf_data_size`, `perf_samples`, `perf_frames`) come from `PerfRecord`.
    .with_metric(Time(), override=True)
    .with_success(default_success, override=True)
    .with_controller(_perf, override=True)
    .with_warmup(0, override=True)
    .with_runs(1, override=True)
    # Nothing to rank: there is no `runtime`, so the geomean block would only
    # say that it found none.
    .with_summary(ByBenchmarkMetricSummary(), override=True)
    .with_reporter(lambda p: rb.reporter(p, dir=p.dir), override=True)
)


if __name__ == "__main__":
    rb.main(app)
