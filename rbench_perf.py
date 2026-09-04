#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.12"
# dependencies = ["bench"]
#
# [tool.uv.sources]
# bench = { git = "https://github.com/PRL-PRG/bench.git", rev = "e895298db063039fdff8a8b3c1b725569ec25ab4" }
# ///
"""Profile the R benchmarks with `perf record`."""

import csv
import re
import subprocess
from collections.abc import Iterable, Iterator
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
from bench.core.invocation import InvocationResult
from bench.core.results import Sample


# ---------------------------------------------------------------------------
# the flat recording: no call graph at all
# ---------------------------------------------------------------------------
# `--call-graph none` is what CPython's benchmark runner does, and it is a
# different *kind* of recording rather than a fourth unwinder: nothing is walked,
# reconstructed or read out of hardware, so a sample is one address and there is
# no stack to attribute it with. `bench_runner` recorded `--call-graph=dwarf`
# until 2024-03-07 and dropped it in commit 3e9e8eb, "Collect a lot less data
# (and be faster)"; what is left is pyperf's `perf_record` hook with no extra
# options, i.e. perf's own defaults.
#
# Two things follow, and both need code rather than a flag.
#
# `perf record` must be given neither `-g` nor `--call-graph`. Passing
# `--call-graph none` alongside `-g` is accepted by perf but says two things at
# once, and which one wins is a property of perf's argument parser rather than of
# this experiment; the flags are simply left off instead.
#
# And `perf script` then prints a different shape. With a call graph a sample is
# a header line followed by one indented `addr sym+0xoff (dso)` line per frame,
# which is what `bench.perf.iter_perf_frames` parses. Without one there are no
# indented lines at all: the single address is appended to the header itself. A
# parser that only knows the indented form reads such a recording as a file of
# headers with no frames and writes an empty `perf-frames.csv` -- 0 rows, exit
# code 0, and nothing downstream able to tell that from a benchmark that spent no
# time anywhere. Hence the second parser here, writing the same five columns so
# that every reader of a recording stays one reader.
_FLAT_RE = re.compile(
    r"^.*?\s(?P<ts>\d+\.\d+):\s+\d+\s+\S+:\s+(?P<ip>[0-9a-fA-F]+)\s+(?P<rest>\S.*)$"
)
_OFFSET_RE = re.compile(r"\+0x[0-9a-fA-F]+$")


def iter_flat_frames(script_stdout: str) -> Iterator[tuple[int, str, int, str, str]]:
    """Yield `(sample_id, timestamp, 1, sym, dso)` for a recording with no stacks.

    One row per sample, at `frame_pos` 1, so a flat recording is a stack of depth
    one rather than a special case: `read_perf_frames` reads it, the leaf is the
    only frame, and the walk that would look for a caller finds none. That is the
    honest rendering of what the method captured.
    """
    sid = 0
    for line in script_stdout.split("\n"):
        m = _FLAT_RE.match(line)
        if m is None:
            continue
        sid += 1
        rest = m.group("rest").strip()
        dso = ""
        # `sym+0xoff (dso)`; the symbol may contain spaces, the dso may not be
        # parenthesised at all when perf has no object for the address.
        if rest.endswith(")"):
            open_at = rest.rfind("(")
            if open_at != -1:
                dso = rest[open_at + 1 : -1]
                rest = rest[:open_at].strip()
        yield (sid, m.group("ts"), 1, _OFFSET_RE.sub("", rest), dso)


def write_flat_frames(script_stdout: str, out_csv: Path) -> tuple[int, int]:
    """Write `iter_flat_frames` rows to `out_csv`; return `(n_samples, n_frames)`."""
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    n = 0
    with open(out_csv, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["sample_id", "timestamp", "frame_pos", "sym", "dso"])
        for row in iter_flat_frames(script_stdout):
            w.writerow(row)
            n = row[0]
    return n, n  # one frame per sample, so the two counts coincide


@dataclass(frozen=True)
class FlatPerfRecord(PerfRecord):
    """`perf record` with no call graph, and the matching `perf script` reader."""

    def call_graph_arg(self) -> str:
        return "none"

    def record_prefix(self) -> list[str]:
        # `-k1` stays: the marked `execute()` interval is how every arm of this
        # experiment is cut down to the kernel, and CPython's own equivalent --
        # gating the recording live through perf's control FIFO -- would change
        # what is being compared rather than reproducing it.
        return [
            "perf", "record",
            "-F", str(self.freq),
            "-k1",
            "-e", self.event,
            "-o", str(self.data_file()),
            "--",
        ]

    def extract(self, result: InvocationResult) -> Iterable[Sample]:
        data = self.data_file()
        if not data.exists():
            return
        yield Sample(metric="perf_data_size", value=float(data.stat().st_size), unit="B")
        if not self.frames:
            return
        proc = subprocess.run(
            ["perf", "script", "-i", str(data)], capture_output=True, text=True
        )
        if proc.returncode != 0:
            return
        n_samples, n_frames = write_flat_frames(proc.stdout, self.frames_file())
        yield Sample(metric="perf_samples", value=float(n_samples), unit="")
        yield Sample(metric="perf_frames", value=float(n_frames), unit="")


@dataclass(frozen=True)
class Params(rb.Params):
    # One recording per `rep`; `runs` keeps bench's meaning (measured iterations
    # inside a process) and stays 1, since harness_instrument.R runs the kernel once.
    invocations: int = 1
    runs: int = 1
    freq: int = 99  # perf sampling frequency (Hz)
    # How the stack is obtained: `dwarf` reconstructs it from CFI, `fp` walks
    # saved frame pointers, `lbr` reads the CPU's branch stack, and `none` asks
    # for no stack at all -- a flat, leaf-only recording, which is CPython's
    # method. `flat` is accepted as a synonym for `none`.
    call_graph: str = "dwarf"  # unwind method: dwarf | fp | lbr | none
    stack_size: int = 16384  # dwarf stack dump size (bytes; 16 kB)
    frames: bool = True  # run `perf script` and write perf-frames.csv
    # Override the inherited --dir default (None) so that the perf output has home
    # Relative to the caller's cwd, deliberately: an absolute default rooted at
    # this file would write recordings inside the corpus checkout, which in a
    # consuming repository is a submodule.
    dir: str = field(
        default="output/perf",
        metadata={
            "metavar": "DIR",
            "help": "Per-execution tree (stdout/stderr/exitcode/seq + perf.data) "
            "under DIR (default: output/perf).",
        },
    )


@cache
def _dir_reporter(root: Path) -> DirReporter:
    return DirReporter(root)


# The names that mean "record no call graph".
_FLAT_MODES = ("none", "flat")


def _perf(ctx: Context[Params]) -> PerfRecord:
    p = ctx.params
    out_dir = _dir_reporter(Path(p.dir)).output_dir(
        ctx.suite, ctx.benchmark, ctx.variant
    )
    cls = FlatPerfRecord if p.call_graph in _FLAT_MODES else PerfRecord
    return cls(
        freq=p.freq,
        call_graph=p.call_graph,
        stack_size=p.stack_size,
        frames=p.frames,
        out_dir=out_dir,
    )


# The corpus and the sealed environment come from `base_app`; what a perf run
# changes is the command (wrapped in `perf record`), the fact that there is no
# iteration loop to measure, and where the output tree goes. Everything not named
# here -- suites, sizes, shuffle seed, `bench_env` -- is the shared definition.
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
