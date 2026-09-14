#!/usr/bin/env python3
"""Fail the build when the corpus did not run clean.

`rbench.py` exits 0 whether or not the benchmarks worked. A benchmark whose R
process dies is judged by `default_success`, recorded on the execution, printed
in the report, and written to the CSV's `failure` column -- and then the driver
moves on to the next one and still returns 0. Only a `BenchError` (an `--include`
that matched nothing, a suite that would not materialize) or SIGINT is non-zero.

So CI has to read the report to learn what happened. This does that, reading the
CSV rather than the JSON: its columns are a flat, stable contract, and the one
column that differs between drivers is the variant column, which we address by
name and never touch.

    ci/check-failures.py results/samples.csv --expect-benchmarks 118
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


def read_rows(path: Path) -> list[dict[str, str]]:
    """Rows of the CSV, minus the leading `#` environment snapshot.

    The snapshot (timestamp, governors, aslr, ...) is prepended as comment lines
    by `CsvReporter`, so the real header is the first line that is not a comment.
    A data row can never start with `#`, because the first field is a suite name.
    """
    with path.open(newline="", encoding="utf-8") as f:
        body = (line for line in f if not line.startswith("#"))
        return list(csv.DictReader(body))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("csv", type=Path, help="the --csv file rbench.py wrote")
    ap.add_argument(
        "--expect-benchmarks",
        type=int,
        default=None,
        metavar="N",
        help="also fail unless exactly N distinct benchmarks appear, which is "
        "how a silently truncated run gets caught",
    )
    args = ap.parse_args(argv)

    if not args.csv.is_file():
        print(f"error: no such file: {args.csv}", file=sys.stderr)
        return 2

    rows = read_rows(args.csv)
    if not rows:
        print(f"error: {args.csv} has no data rows", file=sys.stderr)
        return 2

    for column in ("suite", "benchmark", "failure"):
        if column not in rows[0]:
            print(
                f"error: {args.csv} has no {column!r} column "
                f"(found: {', '.join(rows[0])})",
                file=sys.stderr,
            )
            return 2

    # One benchmark failing every run would otherwise be one line per sample.
    failures: dict[str, set[str]] = {}
    for row in rows:
        verdict = (row.get("failure") or "").strip()
        if verdict:
            name = f"{row['suite']}/{row['benchmark']}"
            failures.setdefault(name, set()).add(verdict)

    names = {f"{row['suite']}/{row['benchmark']}" for row in rows}
    print(f"{len(rows)} samples over {len(names)} benchmarks in {args.csv}")

    status = 0

    if failures:
        print(f"\n{len(failures)} benchmark(s) failed:\n", file=sys.stderr)
        for name in sorted(failures):
            for verdict in sorted(failures[name]):
                print(f"  {name}: {verdict}", file=sys.stderr)
        status = 1

    if args.expect_benchmarks is not None and len(names) != args.expect_benchmarks:
        print(
            f"\nexpected {args.expect_benchmarks} benchmarks, got {len(names)}",
            file=sys.stderr,
        )
        # A benchmark that dies before its first iteration still emits a row, so
        # a short corpus means something dropped out of SUITES or the run was
        # cut short -- either way it is not the corpus CI was asked to gate.
        status = 1

    if status == 0:
        print("no failures")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
