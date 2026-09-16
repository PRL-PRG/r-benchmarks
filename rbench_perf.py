#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.12"
# dependencies = ["bench"]
#
# [tool.uv.sources]
# bench = { git = "https://github.com/PRL-PRG/bench.git", rev = "7bc2cbbfd96ebbf4cd52f67054d5b04f52247b78" }
# ///
"""Profile the R benchmark corpus with `perf record`."""

from dataclasses import dataclass, field
from pathlib import Path

from functools import cache

from bench.run import default_reporter

import rbench as rb
from bench import (
    Context,
    DirReporter,
    PerfRecord,
)


@dataclass(frozen=True)
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


@cache
def _dir_reporter(root: Path) -> DirReporter:
    return DirReporter(root)


def _perf(ctx: Context[Params]) -> PerfRecord:
    p = ctx.params
    out_dir = _dir_reporter(Path(p.dir)).output_dir(
        ctx.suite, ctx.benchmark, ctx.variant
    )
    return PerfRecord(
        freq=p.freq,
        call_graph=p.call_graph,
        stack_size=p.stack_size,
        frames=p.frames,
        out_dir=out_dir,
    )


# What a perf run changes: the command, the absence of an iteration loop, and
# where the output goes. Everything else is `base_app`'s.
app = (
    rb.base_app(Params)
    .with_command(rb.instrument_cmd)
    .with_metric()  # no iteration metric; keeps the intrinsic `elapsed` sample
    .with_process_metric(lambda ctx: (_perf(ctx),))
    .with_warmup(0)
    .with_runs(1)
    .with_reporter(lambda ctx: default_reporter(ctx, dir=_dir_reporter(Path(ctx.params.dir))))
)


if __name__ == "__main__":
    raise SystemExit(app.main())
