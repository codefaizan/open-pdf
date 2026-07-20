from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

from open_pdf_worker.harness import CORPUS_DIR, ensure_scan_corpus
from open_pdf_worker.ocr import (
    bundled_tessdata_available,
    configure_tesseract,
    recognize_image,
    render_page_image,
)


@pytest.fixture(scope="session")
def scan_corpus() -> None:
    ensure_scan_corpus()


def test_bundled_tesseract_models_are_available() -> None:
    assert bundled_tessdata_available()


def test_configure_tesseract_uses_bundled_models_directory() -> None:
    configure_tesseract()
    assert os.environ["TESSDATA_PREFIX"].endswith("tessdata")


def test_scan_page_image_is_recognized_offline(scan_corpus: None) -> None:
    image = render_page_image(CORPUS_DIR / "clean_scan.pdf", 1)
    result = recognize_image(image)
    values = {word.text for word in result.words}
    assert "00123" in values
    assert result.average_confidence > 0.8


def test_ocr_runs_without_network_access(scan_corpus: None, tmp_path: Path) -> None:
    script = tmp_path / "offline_ocr.py"
    script.write_text(
        "\n".join(
            [
                "from open_pdf_worker.ocr import configure_tesseract, recognize_image, render_page_image",
                "from pathlib import Path",
                "configure_tesseract()",
                "image = render_page_image(Path(%r), 1)" % str(CORPUS_DIR / "clean_scan.pdf"),
                "result = recognize_image(image)",
                "assert result.words",
                "print('ok')",
            ]
        ),
        encoding="utf-8",
    )
    env = os.environ.copy()
    env.pop("TESSDATA_PREFIX", None)
    env["PYTHONPATH"] = str(Path(__file__).resolve().parents[1])
    completed = subprocess.run(
        [sys.executable, str(script)],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    assert completed.stdout.strip() == "ok"
