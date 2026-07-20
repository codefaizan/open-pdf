from __future__ import annotations

import json
from pathlib import Path

import pytest

from open_pdf_worker.harness import (
    EXPECTED_PATH,
    SAMPLE_PDF,
    WorkerClient,
    compare_expected_workbook,
    ensure_sample_pdf,
    handshake,
    read_workbook_cell_formats,
    read_workbook_cells,
)


@pytest.fixture(scope="session")
def sample_pdf() -> Path:
    return ensure_sample_pdf()


@pytest.fixture(scope="session")
def expected_spec() -> dict:
    return json.loads(EXPECTED_PATH.read_text(encoding="utf-8"))


@pytest.fixture
def worker() -> WorkerClient:
    client = WorkerClient()
    yield client
    if client.process.poll() is None:
        client.process.terminate()
        client.process.wait(timeout=5)


__all__ = [
    "WorkerClient",
    "compare_expected_workbook",
    "expected_spec",
    "handshake",
    "read_workbook_cell_formats",
    "read_workbook_cells",
    "sample_pdf",
    "worker",
]
