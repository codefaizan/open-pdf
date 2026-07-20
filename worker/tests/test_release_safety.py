"""Fail-safe and leak checks for the conversion release gate."""

from __future__ import annotations

import subprocess
import tempfile
import time
from pathlib import Path

import pytest
from reportlab.lib.pdfencrypt import StandardEncryption
from reportlab.pdfgen import canvas

from open_pdf_worker.harness import SAMPLE_PDF, WorkerClient, ensure_corpus, handshake, run_conversion
from open_pdf_worker.release_gate import frozen_worker_executable, require_frozen_worker


def _ocr_temp_dirs() -> list[Path]:
    root = Path(tempfile.gettempdir())
    return [path for path in root.glob("open-pdf-ocr-*") if path.is_dir()]


def _worker_pids() -> set[int]:
    result = subprocess.run(
        ["pgrep", "-f", "open_pdf_worker"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode not in {0, 1}:
        return set()
    return {int(line) for line in result.stdout.splitlines() if line.strip()}


@pytest.fixture(scope="module")
def corpus_ready() -> None:
    ensure_corpus()


@pytest.fixture(scope="module")
def gate_worker_command() -> list[str] | None:
    """Prefer the frozen worker when present — same binary the release gate uses."""
    if frozen_worker_executable().is_file():
        return require_frozen_worker()
    return None


def test_adversarial_filename_fails_or_completes_without_shell_side_effects(
    tmp_path: Path,
    corpus_ready: None,
    gate_worker_command: list[str] | None,
) -> None:
    marker = tmp_path / "pwned"
    adversarial_dir = tmp_path / "dir with spaces" / "unicodé"
    adversarial_dir.mkdir(parents=True)
    # Shell metacharacters in the basename must not execute.
    pdf = adversarial_dir / '"; touch pwned; echo ".pdf'
    pdf.write_bytes(SAMPLE_PDF.read_bytes())
    output = adversarial_dir / "out.xlsx"

    events, _, _, _ = run_conversion(
        pdf,
        output,
        pages="1",
        request_id="adversarial",
        worker_command=gate_worker_command,
    )
    assert events[-1]["type"] in {"complete", "error"}
    assert not marker.exists()
    if events[-1]["type"] == "error":
        assert not output.exists()


def test_malformed_and_encrypted_inputs_fail_without_workbook(
    tmp_path: Path,
    gate_worker_command: list[str] | None,
) -> None:
    corrupt = tmp_path / "corrupt.pdf"
    corrupt.write_text("%PDF-1.4\nnot a real pdf", encoding="utf-8")
    output = tmp_path / "corrupt.xlsx"
    events, _, _, _ = run_conversion(
        corrupt,
        output,
        request_id="corrupt",
        worker_command=gate_worker_command,
    )
    assert events[-1]["type"] == "error"
    assert events[-1]["code"] == "PDF_UNREADABLE"
    assert not output.exists()

    encrypted = tmp_path / "secret.pdf"
    enc = StandardEncryption(userPassword="user", ownerPassword="owner")
    c = canvas.Canvas(str(encrypted), encrypt=enc)
    c.drawString(100, 700, "secret")
    c.save()
    output2 = tmp_path / "secret.xlsx"
    events2, _, _, _ = run_conversion(
        encrypted,
        output2,
        request_id="encrypted",
        worker_command=gate_worker_command,
    )
    assert events2[-1]["type"] == "error"
    assert events2[-1]["code"] == "PDF_ENCRYPTED"
    assert not output2.exists()


def test_very_large_pdf_fails_or_completes_safely(
    tmp_path: Path,
    gate_worker_command: list[str] | None,
) -> None:
    large = tmp_path / "large.pdf"
    c = canvas.Canvas(str(large))
    for page in range(80):
        c.drawString(72, 720, f"Page {page + 1}")
        c.drawString(72, 700, "Item ID  Quantity")
        c.drawString(72, 680, f"00{page:03d}  {page}")
        c.showPage()
    c.save()

    output = tmp_path / "large.xlsx"
    events, _, _, exit_code = run_conversion(
        large,
        output,
        pages="all",
        request_id="large",
        worker_command=gate_worker_command,
    )
    assert events[-1]["type"] in {"complete", "error"}
    assert exit_code == 0 or events[-1]["type"] == "error"
    if events[-1]["type"] == "error":
        assert not output.exists()
        assert "code" in events[-1]


def test_repeated_conversions_do_not_accumulate_temp_dirs_or_workers(
    tmp_path: Path,
    corpus_ready: None,
    gate_worker_command: list[str] | None,
) -> None:
    before_temps = len(_ocr_temp_dirs())
    before_pids = _worker_pids()
    peaks: list[int] = []

    for index in range(3):
        output = tmp_path / f"repeat-{index}.xlsx"
        events, _, peak_memory, _ = run_conversion(
            SAMPLE_PDF,
            output,
            pages="1",
            request_id=f"repeat-{index}",
            worker_command=gate_worker_command,
        )
        assert events[-1]["type"] == "complete"
        assert output.exists()
        peaks.append(peak_memory)

    time.sleep(0.5)
    after_temps = len(_ocr_temp_dirs())
    after_pids = _worker_pids()

    assert after_temps <= before_temps
    assert len(after_pids) <= len(before_pids)
    # Cumulative child peak should not explode across short serial runs.
    assert max(peaks) <= max(peaks[0] * 3, peaks[0] + 200_000_000)


def test_concurrent_workers_leave_no_orphans(
    tmp_path: Path,
    corpus_ready: None,
    gate_worker_command: list[str] | None,
) -> None:
    before_pids = _worker_pids()
    before_temps = len(_ocr_temp_dirs())
    clients: list[WorkerClient] = []
    outputs: list[Path] = []

    try:
        for index in range(3):
            client = WorkerClient(command=gate_worker_command)
            clients.append(client)
            handshake(client)
            output = tmp_path / f"concurrent-{index}.xlsx"
            outputs.append(output)
            client.send(
                {
                    "type": "convert",
                    "request_id": f"concurrent-{index}",
                    "input_pdf": str(SAMPLE_PDF.resolve()),
                    "output_xlsx": str(output.resolve()),
                    "pages": "1",
                }
            )

        for client in clients:
            while True:
                event = client.read_event()
                if event["type"] in {"complete", "error"}:
                    break
    finally:
        for client in clients:
            if client.process.poll() is None:
                client.close()

    time.sleep(0.5)
    assert len(_worker_pids()) <= len(before_pids)
    assert len(_ocr_temp_dirs()) <= before_temps
    assert all(path.exists() for path in outputs)


@pytest.mark.skipif(
    not frozen_worker_executable().is_file(),
    reason="Frozen worker binary not built",
)
def test_frozen_worker_handles_adversarial_path(tmp_path: Path, corpus_ready: None) -> None:
    command = require_frozen_worker()
    target_dir = tmp_path / "spaces and 名称"
    target_dir.mkdir()
    pdf = target_dir / "input.pdf"
    pdf.write_bytes(SAMPLE_PDF.read_bytes())
    output = target_dir / "out.xlsx"
    events, _, _, _ = run_conversion(
        pdf,
        output,
        pages="1",
        request_id="frozen-adversarial",
        worker_command=command,
    )
    assert events[-1]["type"] == "complete"
    assert output.exists()
