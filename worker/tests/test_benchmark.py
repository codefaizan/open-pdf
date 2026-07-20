from __future__ import annotations

import json
from pathlib import Path

import pytest

from open_pdf_worker.harness import (
    EXPECTED_PATH,
    SAMPLE_PDF,
    compare_expected_workbook,
    ensure_corpus,
    run_conversion,
)


def test_benchmark_reports_accuracy_runtime_and_memory(tmp_path: Path) -> None:
    ensure_corpus()
    sample_pdf = SAMPLE_PDF
    output = tmp_path / "benchmark.xlsx"
    events, runtime_seconds, peak_memory, exit_code = run_conversion(
        sample_pdf,
        output,
        pages="1",
        request_id="benchmark",
    )

    assert output.exists()
    assert exit_code == 0
    assert events[-1]["type"] == "complete"

    expected = json.loads(EXPECTED_PATH.read_text(encoding="utf-8"))
    metrics = compare_expected_workbook(output, expected)
    metrics.update(
        {
            "runtime_seconds": round(runtime_seconds, 3),
            "peak_memory_bytes": peak_memory,
            "exit_code": exit_code,
            "progress_events": sum(1 for event in events if event["type"] == "progress"),
        }
    )

    assert metrics["cell_recall"] == 1.0
    assert metrics["matched_rows"] == metrics["expected_rows"]
    assert metrics["headers_found"] == metrics["headers_expected"]
    assert metrics["source_metadata_found"]
    assert metrics["runtime_seconds"] >= 0
    assert metrics["peak_memory_bytes"] > 0
    assert metrics["progress_events"] >= 2

    report_path = tmp_path / "benchmark_report.json"
    report_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    assert report_path.exists()
