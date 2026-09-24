"""Asset audit reconciliation tool.

Sanitised reference implementation created for portfolio purposes. This is *not*
the original enterprise application (which was developed by a colleague); it is a
small, independent tool that demonstrates the reconciliation principle behind a
scan-based stock audit.

Given two CSV files -- an *expected* inventory and a set of *scanned* assets --
the tool reconciles them and reports four categories:

* ``matched``    -- present and expected exactly once on both sides;
* ``missing``    -- expected but not scanned;
* ``unexpected`` -- scanned but not in the expected inventory;
* ``duplicate``  -- an asset tag scanned more than once.

All data used with this tool in the repository is entirely synthetic.
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List

ASSET_TAG_FIELD = "asset_tag"


@dataclass
class ReconciliationResult:
    """Outcome of reconciling an expected inventory against scanned assets."""

    matched: List[str] = field(default_factory=list)
    missing: List[str] = field(default_factory=list)
    unexpected: List[str] = field(default_factory=list)
    duplicate: List[str] = field(default_factory=list)

    def as_summary(self) -> Dict[str, int]:
        """Return a count-only summary of each category."""
        return {
            "matched": len(self.matched),
            "missing": len(self.missing),
            "unexpected": len(self.unexpected),
            "duplicate": len(self.duplicate),
        }


def _normalise(tag: str) -> str:
    """Normalise an asset tag for comparison (trim and upper-case)."""
    return tag.strip().upper()


def read_asset_tags(path: Path) -> List[str]:
    """Read asset tags from a CSV file.

    The file must contain a header with an ``asset_tag`` column. Blank tags are
    ignored. Raises :class:`ValueError` if the column is absent and
    :class:`FileNotFoundError` if the file does not exist.
    """
    if not path.exists():
        raise FileNotFoundError(f"CSV file not found: {path}")

    tags: List[str] = []
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None or ASSET_TAG_FIELD not in reader.fieldnames:
            raise ValueError(
                f"Expected a '{ASSET_TAG_FIELD}' column in {path}; "
                f"found: {reader.fieldnames}"
            )
        for row in reader:
            raw = (row.get(ASSET_TAG_FIELD) or "").strip()
            if raw:
                tags.append(_normalise(raw))
    return tags


def reconcile(expected: List[str], scanned: List[str]) -> ReconciliationResult:
    """Reconcile expected asset tags against scanned asset tags.

    Args:
        expected: Asset tags from the expected inventory.
        scanned: Asset tags collected during the scan.

    Returns:
        A :class:`ReconciliationResult` with sorted category lists.
    """
    expected_set = set(expected)
    scanned_counts = Counter(scanned)
    scanned_set = set(scanned_counts)

    result = ReconciliationResult()
    result.matched = sorted(expected_set & scanned_set)
    result.missing = sorted(expected_set - scanned_set)
    result.unexpected = sorted(scanned_set - expected_set)
    result.duplicate = sorted(
        tag for tag, count in scanned_counts.items() if count > 1
    )
    return result


def _format_report(result: ReconciliationResult) -> str:
    """Render a human-readable text report."""
    summary = result.as_summary()
    lines = ["Asset audit reconciliation", "=" * 26, ""]
    for category in ("matched", "missing", "unexpected", "duplicate"):
        lines.append(f"{category.capitalize():<11}: {summary[category]}")
    lines.append("")
    for category in ("missing", "unexpected", "duplicate"):
        items = getattr(result, category)
        if items:
            lines.append(f"{category.capitalize()} tags:")
            lines.extend(f"  - {tag}" for tag in items)
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def parse_args(argv: List[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument(
        "--expected",
        required=True,
        type=Path,
        help="Path to the expected inventory CSV (asset_tag column).",
    )
    parser.add_argument(
        "--scanned",
        required=True,
        type=Path,
        help="Path to the scanned assets CSV (asset_tag column).",
    )
    return parser.parse_args(argv)


def main(argv: List[str] | None = None) -> int:
    """Entry point. Returns a process exit code."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        expected = read_asset_tags(args.expected)
        scanned = read_asset_tags(args.scanned)
    except (FileNotFoundError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    result = reconcile(expected, scanned)
    print(_format_report(result), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
