#!/usr/bin/env python3
"""Repeatable conversion benchmark for the representative ruled-table PDF."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from open_pdf_worker.harness import (
    EXPECTED_PATH,
    REPO_ROOT,
    SAMPLE_PDF,
    compare_expected_workbook,
    ensure_corpus,
    run_conversion,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=REPO_ROOT / "artifacts" / "ruled_table.xlsx",
        help="Workbook output path",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=REPO_ROOT / "artifacts" / "benchmark_report.json",
        help="JSON report output path",
    )
    args = parser.parse_args()

    ensure_corpus()
    args.output.parent.mkdir(parents=True, exist_ok=True)

    events, runtime_seconds, peak_memory_bytes_value, exit_code = run_conversion(
        SAMPLE_PDF,
        args.output,
        pages="1",
        request_id="verify",
    )
    if events[-1]["type"] == "error":
        print(json.dumps(events[-1], indent=2), file=sys.stderr)
        return 1

    expected = json.loads(EXPECTED_PATH.read_text(encoding="utf-8"))
    accuracy = compare_expected_workbook(args.output, expected)
    report = {
        "document": str(SAMPLE_PDF),
        "output_xlsx": str(args.output),
        "runtime_seconds": round(runtime_seconds, 3),
        "peak_memory_bytes": peak_memory_bytes_value,
        "exit_code": exit_code,
        "progress_events": sum(1 for event in events if event["type"] == "progress"),
        **accuracy,
    }

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))

    if report["values_missing"]:
        return 1
    if report["cell_recall"] < 1.0:
        return 1
    if report["matched_rows"] != report["expected_rows"]:
        return 1
    if not report["source_metadata_found"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
