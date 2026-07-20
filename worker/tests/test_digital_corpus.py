from __future__ import annotations

import json
from pathlib import Path

import pytest

from open_pdf_worker.harness import (
    CORPUS_DIR,
    benchmark_digital_corpus,
    compare_expected_workbook,
    ensure_corpus,
    load_digital_corpus_manifest,
    load_expected_spec,
    run_conversion,
    workbook_fingerprint,
    workbook_has_review_sheet,
)


@pytest.fixture(scope="session")
def digital_corpus_manifest() -> list[dict]:
    ensure_corpus()
    return load_digital_corpus_manifest()


@pytest.mark.parametrize("entry", load_digital_corpus_manifest(), ids=lambda entry: entry["id"])
def test_digital_corpus_entry_produces_expected_workbook(
    entry: dict,
    tmp_path: Path,
) -> None:
    ensure_corpus()
    pdf_path = CORPUS_DIR / entry["pdf"]
    expected = load_expected_spec(CORPUS_DIR / entry["expected"])
    output = tmp_path / f"{entry['id']}.xlsx"

    events, _, _, exit_code = run_conversion(
        pdf_path,
        output,
        pages=entry.get("pages", "1"),
        request_id=f"corpus-{entry['id']}",
    )

    assert exit_code == 0
    assert events[-1]["type"] == "complete"
    assert output.exists()
    assert len(events[-1]["worksheets"]) >= expected["minimum_worksheets"]

    metrics = compare_expected_workbook(output, expected)
    assert metrics["cell_recall"] == 1.0
    assert metrics["values_missing"] == []
    assert metrics["source_metadata_found"]
    assert metrics["review_sheet_ok"]
    assert metrics["merged_ranges_ok"]
    assert metrics["source_pages_ok"]
    if expected.get("rows"):
        assert metrics["matched_rows"] == metrics["expected_rows"]
        assert metrics["headers_found"] == metrics["headers_expected"]


def test_repeated_conversion_is_deterministic(tmp_path: Path) -> None:
    ensure_corpus()
    pdf_path = CORPUS_DIR / "multi_table.pdf"
    first = tmp_path / "first.xlsx"
    second = tmp_path / "second.xlsx"

    for index, output in enumerate((first, second)):
        events, _, _, exit_code = run_conversion(
            pdf_path,
            output,
            pages="1",
            request_id=f"deterministic-{index}",
        )
        assert exit_code == 0
        assert events[-1]["type"] == "complete"

    assert workbook_fingerprint(first) == workbook_fingerprint(second)


def test_low_confidence_conversion_adds_review_worksheet(tmp_path: Path) -> None:
    ensure_corpus()
    pdf_path = CORPUS_DIR / "uncertain_table.pdf"
    output = tmp_path / "uncertain.xlsx"

    events, _, _, exit_code = run_conversion(
        pdf_path,
        output,
        pages="1",
        request_id="uncertain-review",
    )

    assert exit_code == 0
    assert events[-1]["type"] == "complete"
    assert workbook_has_review_sheet(output)


def test_high_confidence_conversion_omits_review_worksheet(tmp_path: Path) -> None:
    ensure_corpus()
    pdf_path = CORPUS_DIR / "ruled_table.pdf"
    output = tmp_path / "ruled.xlsx"

    events, _, _, exit_code = run_conversion(
        pdf_path,
        output,
        pages="1",
        request_id="ruled-no-review",
    )

    assert exit_code == 0
    assert events[-1]["type"] == "complete"
    assert not workbook_has_review_sheet(output)


def test_borderless_digital_pdf_converts_without_review_sheet(tmp_path: Path) -> None:
    ensure_corpus()
    pdf_path = CORPUS_DIR / "borderless_table.pdf"
    output = tmp_path / "borderless.xlsx"
    expected = load_expected_spec(CORPUS_DIR / "borderless_table.expected.json")

    events, _, _, exit_code = run_conversion(
        pdf_path,
        output,
        pages="1",
        request_id="borderless-digital",
    )

    assert exit_code == 0
    assert events[-1]["type"] == "complete"
    metrics = compare_expected_workbook(output, expected)
    assert metrics["cell_recall"] == 1.0
    assert metrics["review_sheet_ok"]


def test_benchmark_reports_accuracy_by_document_class(tmp_path: Path) -> None:
    report = benchmark_digital_corpus(tmp_path)
    by_class = report["by_class"]

    assert set(by_class) == {"ruled", "borderless", "merged_cell", "multi_table", "multi_page", "rotated"}
    for class_id, metrics in by_class.items():
        assert metrics["document_class"] == class_id
        assert metrics["completed"]
        assert metrics["cell_recall"] == 1.0
        assert metrics["values_missing"] == []
        assert metrics["review_sheet_ok"]

    report_path = tmp_path / "digital_benchmark_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    assert report_path.exists()
