"""Meeting room readiness reporting tool.

Sanitised reference implementation created for portfolio purposes. It summarises
the outcome of meeting room readiness checks recorded in a CSV file and reports
the number of rooms that pass, warn or fail, plus an overall readiness rate.

The expected CSV has a header with at least ``room`` and ``result`` columns. Each
``result`` value is one of ``pass``, ``warning`` or ``fail`` (case-insensitive).

All data used with this tool in the repository is entirely synthetic and the
room identifiers are fictional (``Room-01`` .. ``Room-19``).
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

ROOM_FIELD = "room"
RESULT_FIELD = "result"
VALID_RESULTS = ("pass", "warning", "fail")


@dataclass
class ReadinessReport:
    """Aggregated readiness outcome across a set of rooms."""

    total: int
    passed: int
    warning: int
    failed: int

    @property
    def readiness_rate(self) -> float:
        """Percentage of rooms that passed, rounded to one decimal place."""
        if self.total == 0:
            return 0.0
        return round(self.passed / self.total * 100, 1)

    def as_dict(self) -> Dict[str, float]:
        """Return the report as a plain dictionary."""
        return {
            "total": self.total,
            "pass": self.passed,
            "warning": self.warning,
            "fail": self.failed,
            "readiness_rate": self.readiness_rate,
        }


def read_results(path: Path) -> List[str]:
    """Read and normalise the ``result`` column from a readiness CSV.

    Raises:
        FileNotFoundError: if the file does not exist.
        ValueError: if the required columns are missing or a result value is
            not one of ``pass``, ``warning`` or ``fail``.
    """
    if not path.exists():
        raise FileNotFoundError(f"CSV file not found: {path}")

    results: List[str] = []
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        fields = reader.fieldnames or []
        for required in (ROOM_FIELD, RESULT_FIELD):
            if required not in fields:
                raise ValueError(
                    f"Expected a '{required}' column in {path}; found: {fields}"
                )
        for line_no, row in enumerate(reader, start=2):
            value = (row.get(RESULT_FIELD) or "").strip().lower()
            if value not in VALID_RESULTS:
                raise ValueError(
                    f"Invalid result '{row.get(RESULT_FIELD)}' on line {line_no}; "
                    f"expected one of {VALID_RESULTS}"
                )
            results.append(value)
    return results


def build_report(results: List[str]) -> ReadinessReport:
    """Aggregate a list of normalised result strings into a report."""
    counts = Counter(results)
    return ReadinessReport(
        total=len(results),
        passed=counts.get("pass", 0),
        warning=counts.get("warning", 0),
        failed=counts.get("fail", 0),
    )


def _format_report(report: ReadinessReport) -> str:
    """Render a human-readable text report."""
    data = report.as_dict()
    return (
        "Meeting room readiness report\n"
        "=============================\n"
        f"Rooms assessed : {data['total']}\n"
        f"Pass           : {data['pass']}\n"
        f"Warning        : {data['warning']}\n"
        f"Fail           : {data['fail']}\n"
        f"Readiness rate : {data['readiness_rate']}%\n"
    )


def parse_args(argv: List[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument(
        "--input",
        required=True,
        type=Path,
        help="Path to the room readiness results CSV (room, result columns).",
    )
    return parser.parse_args(argv)


def main(argv: List[str] | None = None) -> int:
    """Entry point. Returns a process exit code."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        results = read_results(args.input)
    except (FileNotFoundError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    report = build_report(results)
    print(_format_report(report), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
