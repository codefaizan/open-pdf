from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import pytest

from open_pdf_worker.converter import ConversionResult, WorksheetInfo
from tests.conftest import WorkerClient, handshake


def test_handshake(worker: WorkerClient) -> None:
    event = handshake(worker)
    assert event["protocol_version"] == "1.0"
    assert event["worker_version"]


def test_convert_before_handshake(worker: WorkerClient) -> None:
    worker.send(
        {
            "type": "convert",
            "request_id": "req-1",
            "input_pdf": "/tmp/sample.pdf",
            "output_xlsx": "/tmp/out.xlsx",
        }
    )
    event = worker.read_event()
    assert event["type"] == "error"
    assert event["code"] == "PROTOCOL_MISMATCH"


def test_invalid_json_line(worker: WorkerClient) -> None:
    assert worker.process.stdin is not None
    worker.process.stdin.write("{not-json\n")
    worker.process.stdin.flush()
    event = worker.read_event()
    assert event["type"] == "error"
    assert event["code"] == "INVALID_REQUEST"


def test_invalid_page_range(worker: WorkerClient, tmp_path: Path, sample_pdf: Path) -> None:
    handshake(worker)
    output = tmp_path / "out.xlsx"
    worker.send(
        {
            "type": "convert",
            "request_id": "bad-pages",
            "input_pdf": str(sample_pdf),
            "output_xlsx": str(output),
            "pages": "abc",
        }
    )
    event = worker.read_event()
    assert event["type"] == "error"
    assert event["code"] == "INVALID_REQUEST"
    assert not output.exists()


def test_missing_pdf_returns_error_without_workbook(worker: WorkerClient, tmp_path: Path) -> None:
    handshake(worker)
    output = tmp_path / "missing.xlsx"
    worker.send(
        {
            "type": "convert",
            "request_id": "missing-pdf",
            "input_pdf": str(tmp_path / "does-not-exist.pdf"),
            "output_xlsx": str(output),
        }
    )
    event = worker.read_event()
    assert event["type"] == "error"
    assert event["code"] == "PDF_UNREADABLE"
    assert not output.exists()


def test_corrupted_pdf_returns_error_without_workbook(
    worker: WorkerClient,
    tmp_path: Path,
) -> None:
    handshake(worker)
    corrupt_pdf = tmp_path / "corrupt.pdf"
    corrupt_pdf.write_text("not a pdf file", encoding="utf-8")
    output = tmp_path / "corrupt.xlsx"

    worker.send(
        {
            "type": "convert",
            "request_id": "corrupt-pdf",
            "input_pdf": str(corrupt_pdf),
            "output_xlsx": str(output),
        }
    )

    while True:
        event = worker.read_event()
        if event["type"] == "error":
            break
        if event["type"] == "complete":
            raise AssertionError("Expected conversion to fail for corrupted PDF.")

    assert event["code"] == "PDF_UNREADABLE"
    assert not output.exists()


def test_protocol_mismatch(worker: WorkerClient) -> None:
    worker.send({"type": "handshake", "protocol_version": "9.9"})
    event = worker.read_event()
    assert event["type"] == "error"
    assert event["code"] == "PROTOCOL_MISMATCH"


def test_progress_events_are_newline_delimited_json(
    worker: WorkerClient, tmp_path: Path, sample_pdf: Path
) -> None:
    handshake(worker)
    output = tmp_path / "ruled.xlsx"
    worker.send(
        {
            "type": "convert",
            "request_id": "progress-check",
            "input_pdf": str(sample_pdf),
            "output_xlsx": str(output),
            "pages": "1",
        }
    )

    events = []
    while True:
        event = worker.read_event()
        json.dumps(event)
        events.append(event)
        if event["type"] in {"complete", "error"}:
            break

    assert events[0]["type"] == "progress"
    assert events[-1]["type"] == "complete"
    assert all("\n" not in json.dumps(event) for event in events)


def test_cancelled_conversion_returns_error_without_workbook(
    worker: WorkerClient,
    tmp_path: Path,
    sample_pdf: Path,
) -> None:
    handshake(worker)
    output = tmp_path / "cancelled.xlsx"

    def slow_convert(input_pdf, output_xlsx, pages, on_progress):
        on_progress("starting", 5, "Preparing conversion.")
        on_progress("extracting", 20, "Extracting tables.")
        return ConversionResult(
            output_xlsx=output_xlsx,
            worksheets=[WorksheetInfo(name="Table 1 p1", source_pages=[1])],
        )

    with patch("open_pdf_worker.__main__.convert_pdf_to_excel", side_effect=slow_convert):
        worker.send(
            {
                "type": "convert",
                "request_id": "cancel-me",
                "input_pdf": str(sample_pdf),
                "output_xlsx": str(output),
            }
        )

        saw_progress = False
        while True:
            event = worker.read_event()
            if event["type"] == "progress":
                saw_progress = True
                worker.send({"type": "cancel", "request_id": "cancel-me"})
            if event["type"] == "error":
                assert event["code"] == "CANCELLED"
                break
            if event["type"] == "complete":
                raise AssertionError("Expected cancellation before completion.")

        assert saw_progress
        assert not output.exists()


def test_stderr_is_drained_during_conversion(
    worker: WorkerClient,
    tmp_path: Path,
    sample_pdf: Path,
) -> None:
    handshake(worker)
    output = tmp_path / "stderr-drain.xlsx"
    worker.send(
        {
            "type": "convert",
            "request_id": "stderr-drain",
            "input_pdf": str(sample_pdf),
            "output_xlsx": str(output),
            "pages": "1",
        }
    )

    while True:
        event = worker.read_event()
        if event["type"] in {"complete", "error"}:
            break

    stderr_lines = worker.close()
    assert isinstance(stderr_lines, list)


def test_encrypted_pdf_returns_pdf_encrypted(
    worker: WorkerClient,
    tmp_path: Path,
) -> None:
    from reportlab.lib.pdfencrypt import StandardEncryption
    from reportlab.pdfgen import canvas

    encrypted = tmp_path / "secret.pdf"
    enc = StandardEncryption(userPassword="user", ownerPassword="owner")
    c = canvas.Canvas(str(encrypted), encrypt=enc)
    c.drawString(100, 700, "secret")
    c.save()

    handshake(worker)
    output = tmp_path / "secret.xlsx"
    worker.send(
        {
            "type": "convert",
            "request_id": "encrypted",
            "input_pdf": str(encrypted),
            "output_xlsx": str(output),
        }
    )
    event = worker.read_event()
    assert event["type"] == "error"
    assert event["code"] == "PDF_ENCRYPTED"
    assert not output.exists()


def test_read_only_destination_returns_not_writable(
    worker: WorkerClient,
    tmp_path: Path,
    sample_pdf: Path,
) -> None:
    readonly_dir = tmp_path / "readonly"
    readonly_dir.mkdir()
    readonly_dir.chmod(0o555)

    handshake(worker)
    output = readonly_dir / "out.xlsx"
    try:
        worker.send(
            {
                "type": "convert",
                "request_id": "readonly",
                "input_pdf": str(sample_pdf),
                "output_xlsx": str(output),
            }
        )
        event = worker.read_event()
        assert event["type"] == "error"
        assert event["code"] == "DESTINATION_NOT_WRITABLE"
        assert not output.exists()
    finally:
        readonly_dir.chmod(0o755)
