#!/usr/bin/env python3
"""Repeatable OCR conversion benchmark grouped by scanned document class."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from open_pdf_worker.harness import REPO_ROOT, benchmark_scan_corpus, ensure_scan_corpus, load_scan_corpus_manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "artifacts" / "scan_corpus",
        help="Directory for generated workbooks",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=REPO_ROOT / "artifacts" / "scan_benchmark_report.json",
        help="JSON report output path",
    )
    args = parser.parse_args()

    ensure_scan_corpus()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    report = benchmark_scan_corpus(args.output_dir)
    manifest = {entry["id"]: entry for entry in load_scan_corpus_manifest()}

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))

    for class_id, metrics in report["by_class"].items():
        expected_path = REPO_ROOT / "corpus" / manifest[class_id]["expected"]
        expected = json.loads(expected_path.read_text(encoding="utf-8"))
        minimum_recall = expected.get("minimum_cell_recall", 1.0)
        if metrics["cell_recall"] < minimum_recall:
            return 1
        if minimum_recall == 1.0 and metrics["values_missing"]:
            return 1
        if not metrics["source_metadata_found"]:
            return 1
        if not metrics["review_sheet_ok"]:
            return 1
        if minimum_recall == 1.0 and metrics.get("rows") and metrics["matched_rows"] != metrics["expected_rows"]:
            return 1
        if not all(method.startswith("ocr") for method in metrics["extraction_methods"]):
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
