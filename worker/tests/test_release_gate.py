"""Release-gate evaluation: thresholds, report schema, Adobe disclaimer."""

from __future__ import annotations

from pathlib import Path

import pytest

from open_pdf_worker.release_gate import (
    ADOBE_PARITY_DISCLAIMER,
    DEFAULT_THRESHOLDS,
    evaluate_release_gate,
    frozen_worker_command,
)


def _class_metrics(**overrides: object) -> dict:
    base = {
        "document_class": "ruled",
        "cell_recall": 1.0,
        "cell_precision": 1.0,
        "table_detection": 1.0,
        "structural_accuracy": 1.0,
        "runtime_seconds": 1.0,
        "peak_memory_bytes": 50_000_000,
        "completed": True,
        "values_missing": [],
        "source_metadata_found": True,
        "review_sheet_ok": True,
        "extraction_methods": ["lattice"],
    }
    base.update(overrides)
    return base


def test_evaluate_release_gate_passes_when_thresholds_met() -> None:
    report = {
        "digital": {"by_class": {"ruled": _class_metrics()}},
        "scan": {"by_class": {"clean_scan": _class_metrics(document_class="clean_scan", extraction_methods=["ocr"])}},
        "worker": {"kind": "frozen", "command": ["/tmp/open_pdf_worker"]},
        "conversion_engine": "camelot+ocr",
        "heavier_fallback_engine": False,
    }

    result = evaluate_release_gate(report, DEFAULT_THRESHOLDS)

    assert result["passed"] is True
    assert result["failures"] == []
    assert ADOBE_PARITY_DISCLAIMER in result["adobe_parity_disclaimer"]
    assert result["heavier_fallback_engine"] is False


def test_evaluate_release_gate_fails_on_low_recall() -> None:
    report = {
        "digital": {"by_class": {"ruled": _class_metrics(cell_recall=0.5)}},
        "scan": {"by_class": {}},
        "worker": {"kind": "frozen", "command": ["/tmp/open_pdf_worker"]},
        "conversion_engine": "camelot+ocr",
        "heavier_fallback_engine": False,
    }

    result = evaluate_release_gate(report, DEFAULT_THRESHOLDS)

    assert result["passed"] is False
    assert any("cell_recall" in failure for failure in result["failures"])


def test_evaluate_release_gate_uses_per_class_scan_threshold() -> None:
    report = {
        "digital": {"by_class": {}},
        "scan": {
            "by_class": {
                "rotated_scan": _class_metrics(
                    document_class="rotated_scan",
                    cell_recall=0.5,
                    structural_accuracy=0.5,
                    extraction_methods=["ocr"],
                )
            }
        },
        "worker": {"kind": "frozen", "command": ["/tmp/open_pdf_worker"]},
        "conversion_engine": "camelot+ocr",
        "heavier_fallback_engine": False,
    }

    result = evaluate_release_gate(report, DEFAULT_THRESHOLDS)

    assert result["passed"] is True


def test_evaluate_release_gate_rejects_module_worker() -> None:
    report = {
        "digital": {"by_class": {"ruled": _class_metrics()}},
        "scan": {"by_class": {}},
        "worker": {"kind": "module", "command": ["python", "-m", "open_pdf_worker"]},
        "conversion_engine": "camelot+ocr",
        "heavier_fallback_engine": False,
    }

    result = evaluate_release_gate(report, DEFAULT_THRESHOLDS)

    assert result["passed"] is False
    assert any("frozen" in failure.lower() for failure in result["failures"])


def test_frozen_worker_command_points_at_dist_executable() -> None:
    command = frozen_worker_command()
    assert len(command) == 1
    path = Path(command[0])
    assert path.name in {"open_pdf_worker", "open_pdf_worker.exe"}
    assert "dist" in path.parts


def test_third_party_notices_cover_pinned_production_dependencies() -> None:
    notices = Path(__file__).resolve().parents[2] / "THIRD_PARTY_NOTICES"
    text = notices.read_text(encoding="utf-8")
    for required in (
        "camelot-py 2.0.0",
        "openpyxl 3.1.5",
        "pytesseract 0.3.13",
        "reportlab 4.2.5",
        "eng.traineddata",
        "pdfrx",
        "requirements.lock",
        "pubspec.lock",
        "PaddleOCR",
    ):
        assert required in text
