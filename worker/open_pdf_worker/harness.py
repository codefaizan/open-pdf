"""Shared subprocess harness and benchmark helpers for tests and scripts."""

from __future__ import annotations

import json
import resource
import subprocess
import sys
import threading
import time
from pathlib import Path

from openpyxl import load_workbook

from open_pdf_worker.version import PROTOCOL_VERSION

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKER_ROOT = Path(__file__).resolve().parents[1]
CORPUS_DIR = REPO_ROOT / "corpus"
SAMPLE_PDF = CORPUS_DIR / "ruled_table.pdf"
EXPECTED_PATH = CORPUS_DIR / "ruled_table.expected.json"


def ensure_sample_pdf() -> Path:
    if SAMPLE_PDF.exists():
        return SAMPLE_PDF
    subprocess.run(
        [sys.executable, str(CORPUS_DIR / "generate_ruled_table_pdf.py")],
        check=True,
        cwd=REPO_ROOT,
    )
    return SAMPLE_PDF


def peak_memory_bytes() -> int:
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    if sys.platform == "darwin":
        return usage.ru_maxrss
    return usage.ru_maxrss * 1024


def read_workbook_cells(workbook_path: Path) -> list[list[str]]:
    workbook = load_workbook(workbook_path, data_only=False)
    cells: list[list[str]] = []
    for sheet in workbook.worksheets:
        for row in sheet.iter_rows(values_only=True):
            cells.append(["" if value is None else str(value) for value in row])
    return cells


def read_workbook_cell_formats(workbook_path: Path) -> list[str]:
    workbook = load_workbook(workbook_path, data_only=False)
    formats: list[str] = []
    for sheet in workbook.worksheets:
        for row in sheet.iter_rows(min_row=1):
            for cell in row:
                if cell.value is not None and str(cell.value):
                    formats.append(cell.number_format)
    return formats


def flatten_values(cells: list[list[str]]) -> set[str]:
    return {value for row in cells for value in row if value}


def compare_expected_workbook(workbook_path: Path, expected: dict) -> dict:
    cells = read_workbook_cells(workbook_path)
    flat = flatten_values(cells)
    required = set(expected["required_values"])
    headers = set(expected["header_values"])
    width = len(expected["rows"][0])

    found_required = required & flat
    found_headers = headers & flat

    expected_rows = {tuple(row) for row in expected["rows"]}
    actual_rows = {
        tuple(row[:width])
        for row in cells
        if len(row) >= width and any(row[:width])
    }
    matched_rows = len(expected_rows & actual_rows)

    recall = len(found_required) / len(required) if required else 1.0
    precision = len(found_required) / (len(flat) or 1)

    source_metadata_found = any(
        row and row[0] == "Source page(s)" for row in cells
    )

    return {
        "cell_recall": recall,
        "cell_precision": precision,
        "matched_rows": matched_rows,
        "expected_rows": len(expected_rows),
        "headers_found": len(found_headers),
        "headers_expected": len(headers),
        "source_metadata_found": source_metadata_found,
        "values_found": sorted(found_required),
        "values_missing": sorted(required - found_required),
    }


class WorkerClient:
    def __init__(self) -> None:
        self.process = subprocess.Popen(
            [sys.executable, "-m", "open_pdf_worker"],
            cwd=WORKER_ROOT,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        assert self.process.stdin is not None
        assert self.process.stdout is not None
        assert self.process.stderr is not None
        self._stderr_lines: list[str] = []
        self._stderr_thread = threading.Thread(target=self._drain_stderr, daemon=True)
        self._stderr_thread.start()

    def _drain_stderr(self) -> None:
        assert self.process.stderr is not None
        for line in self.process.stderr:
            self._stderr_lines.append(line)

    def send(self, message: dict) -> None:
        assert self.process.stdin is not None
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()

    def read_event(self) -> dict:
        assert self.process.stdout is not None
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError("Worker closed stdout unexpectedly.")
        return json.loads(line)

    def close(self) -> list[str]:
        assert self.process.stdin is not None
        self.process.stdin.close()
        self.process.wait(timeout=30)
        self._stderr_thread.join(timeout=5)
        return list(self._stderr_lines)


def handshake(client: WorkerClient) -> dict:
    client.send({"type": "handshake", "protocol_version": PROTOCOL_VERSION})
    event = client.read_event()
    if event["type"] != "handshake_ack":
        raise RuntimeError(event)
    return event


def run_conversion(
    input_pdf: Path,
    output_xlsx: Path,
    *,
    pages: str | None = "1",
    request_id: str = "convert",
) -> tuple[list[dict], float, int, int]:
    if output_xlsx.exists():
        output_xlsx.unlink()

    client = WorkerClient()
    messages = [
        {"type": "handshake", "protocol_version": PROTOCOL_VERSION},
        {
            "type": "convert",
            "request_id": request_id,
            "input_pdf": str(input_pdf.resolve()),
            "output_xlsx": str(output_xlsx.resolve()),
            **({"pages": pages} if pages is not None else {}),
        },
    ]

    started = time.perf_counter()
    for message in messages:
        client.send(message)

    events: list[dict] = []
    while True:
        event = client.read_event()
        events.append(event)
        if event["type"] in {"complete", "error"}:
            break

    client.close()
    elapsed = time.perf_counter() - started
    return events, elapsed, peak_memory_bytes(), client.process.returncode or 0
