#!/usr/bin/env python3
"""Repeatable conversion benchmark grouped by digital document class."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from open_pdf_worker.harness import REPO_ROOT, benchmark_digital_corpus, ensure_corpus


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "artifacts" / "digital_corpus",
        help="Directory for generated workbooks",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=REPO_ROOT / "artifacts" / "digital_benchmark_report.json",
        help="JSON report output path",
    )
    args = parser.parse_args()

    ensure_corpus()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    report = benchmark_digital_corpus(args.output_dir)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))

    for metrics in report["by_class"].values():
        if metrics["values_missing"]:
            return 1
        if metrics["cell_recall"] < 1.0:
            return 1
        if not metrics["source_metadata_found"]:
            return 1
        if not metrics["review_sheet_ok"]:
            return 1
        if metrics.get("rows") and metrics["matched_rows"] != metrics["expected_rows"]:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
