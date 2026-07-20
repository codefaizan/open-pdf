from __future__ import annotations

import json
from pathlib import Path

import pytest

from open_pdf_worker.harness import (
    CORPUS_DIR,
    benchmark_scan_corpus,
    compare_expected_workbook,
    ensure_scan_corpus,
    load_expected_spec,
    load_scan_corpus_manifest,
    run_conversion,
    workbook_has_review_sheet,
)


@pytest.fixture(scope="session")
def scan_corpus_manifest() -> list[dict]:
    ensure_scan_corpus()
    return load_scan_corpus_manifest()


@pytest.mark.parametrize("entry", load_scan_corpus_manifest(), ids=lambda entry: entry["id"])
def test_scan_corpus_entry_produces_expected_workbook(
    entry: dict,
    tmp_path: Path,
) -> None:
    ensure_scan_corpus()
    pdf_path = CORPUS_DIR / entry["pdf"]
    expected = load_expected_spec(CORPUS_DIR / entry["expected"])
    output = tmp_path / f"{entry['id']}.xlsx"

    events, _, _, exit_code = run_conversion(
        pdf_path,
        output,
        pages=entry.get("pages", "1"),
        request_id=f"scan-corpus-{entry['id']}",
    )

    assert exit_code == 0
    assert events[-1]["type"] == "complete"
    assert output.exists()
    assert len(events[-1]["worksheets"]) >= expected["minimum_worksheets"]
    assert all(
        worksheet["extraction_method"].startswith("ocr")
        for worksheet in events[-1]["worksheets"]
    )

    metrics = compare_expected_workbook(output, expected)
    minimum_recall = expected.get("minimum_cell_recall", 1.0)
    assert metrics["cell_recall"] >= minimum_recall
    assert metrics["source_metadata_found"]
    assert metrics["review_sheet_ok"]
    if minimum_recall == 1.0:
        assert metrics["values_missing"] == []
        if expected.get("rows") and not expected.get("expect_review_sheet"):
            assert metrics["matched_rows"] == metrics["expected_rows"]
        if not expected.get("expect_review_sheet"):
            assert metrics["headers_found"] == metrics["headers_expected"]


def test_digital_pdf_does_not_use_ocr_path(tmp_path: Path) -> None:
    ensure_scan_corpus()
    pdf_path = CORPUS_DIR / "ruled_table.pdf"
    output = tmp_path / "digital.xlsx"

    events, _, _, exit_code = run_conversion(
        pdf_path,
        output,
        pages="1",
        request_id="digital-no-ocr",
    )

    assert exit_code == 0
    assert events[-1]["type"] == "complete"
    methods = {worksheet["extraction_method"] for worksheet in events[-1]["worksheets"]}
    assert methods.issubset({"lattice", "stream"})


def test_noisy_and_rotated_scans_are_flagged_for_review(tmp_path: Path) -> None:
    ensure_scan_corpus()
    for scan_id in ("noisy_scan", "rotated_scan"):
        pdf_path = CORPUS_DIR / f"{scan_id}.pdf"
        output = tmp_path / f"{scan_id}.xlsx"
        events, _, _, exit_code = run_conversion(
            pdf_path,
            output,
            pages="1",
            request_id=scan_id,
        )
        assert exit_code == 0
        assert events[-1]["type"] == "complete"
        assert workbook_has_review_sheet(output)


def test_benchmark_reports_accuracy_by_scan_class(tmp_path: Path) -> None:
    report = benchmark_scan_corpus(tmp_path)
    by_class = report["by_class"]

    assert set(by_class) == {
        "clean_scan",
        "noisy_scan",
        "ruled_scan",
        "borderless_scan",
        "rotated_scan",
    }
    for class_id, metrics in by_class.items():
        assert metrics["document_class"] == class_id
        assert metrics["completed"]
        assert metrics["runtime_seconds"] >= 0
        assert metrics["peak_memory_bytes"] > 0
        assert metrics["source_metadata_found"]
        assert metrics["extraction_methods"]
        assert all(method.startswith("ocr") for method in metrics["extraction_methods"])

    report_path = tmp_path / "scan_benchmark_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    assert report_path.exists()
