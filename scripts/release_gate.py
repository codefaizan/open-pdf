#!/usr/bin/env python3
"""Run the conversion release gate against the frozen worker."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "worker"
if str(WORKER) not in sys.path:
    sys.path.insert(0, str(WORKER))

from open_pdf_worker.release_gate import (  # noqa: E402
    ADOBE_PARITY_DISCLAIMER,
    run_release_gate,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT / "artifacts" / "release_gate",
        help="Directory for generated workbooks",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=ROOT / "artifacts" / "release_gate_report.json",
        help="JSON report output path",
    )
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    report = run_release_gate(args.output_dir)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(ADOBE_PARITY_DISCLAIMER, file=sys.stderr)

    if not report["gate"]["passed"]:
        for failure in report["gate"]["failures"]:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("Release gate passed.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
