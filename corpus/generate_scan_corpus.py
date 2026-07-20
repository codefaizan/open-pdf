"""Generate redistributable scanned PDFs for the OCR benchmark corpus."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pypdfium2 as pdfium
from PIL import Image
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas

CORPUS_DIR = Path(__file__).resolve().parent
DIGITAL_GENERATOR = CORPUS_DIR / "generate_digital_corpus.py"
RENDER_SCALE = 2


def _render_digital_page(pdf_path: Path) -> Image.Image:
    document = pdfium.PdfDocument(str(pdf_path))
    return document[0].render(scale=RENDER_SCALE).to_pil()


def _save_scan_pdf(image: Image.Image, output_pdf: Path) -> None:
    image_path = output_pdf.with_suffix(".png")
    image.save(image_path)
    page_width, page_height = letter
    pdf = canvas.Canvas(str(output_pdf), pagesize=letter)
    pdf.drawImage(str(image_path), 0, 0, width=page_width, height=page_height)
    pdf.showPage()
    pdf.save()
    image_path.unlink(missing_ok=True)


def _add_noise(image: Image.Image, *, seed: int, sigma: float) -> Image.Image:
    rng = np.random.default_rng(seed)
    array = np.array(image).astype(np.int16)
    noise = rng.normal(0, sigma, array.shape)
    noisy = np.clip(array + noise, 0, 255).astype(np.uint8)
    return Image.fromarray(noisy)


def generate_clean_scan(output_pdf: Path) -> None:
    image = _render_digital_page(CORPUS_DIR / "ruled_table.pdf")
    _save_scan_pdf(image, output_pdf)


def generate_noisy_scan(output_pdf: Path) -> None:
    image = _render_digital_page(CORPUS_DIR / "ruled_table.pdf")
    noisy = _add_noise(image, seed=42, sigma=30.5)
    _save_scan_pdf(noisy, output_pdf)


def generate_ruled_scan(output_pdf: Path) -> None:
    image = _render_digital_page(CORPUS_DIR / "multi_table.pdf")
    _save_scan_pdf(image, output_pdf)


def generate_borderless_scan(output_pdf: Path) -> None:
    image = _render_digital_page(CORPUS_DIR / "borderless_table.pdf")
    _save_scan_pdf(image, output_pdf)


def generate_rotated_scan(output_pdf: Path) -> None:
    image = _render_digital_page(CORPUS_DIR / "rotated_table.pdf")
    _save_scan_pdf(image, output_pdf)


GENERATORS = {
    "clean_scan.pdf": generate_clean_scan,
    "noisy_scan.pdf": generate_noisy_scan,
    "ruled_scan.pdf": generate_ruled_scan,
    "borderless_scan.pdf": generate_borderless_scan,
    "rotated_scan.pdf": generate_rotated_scan,
}


def _load_expected(source_name: str) -> dict:
    expected_path = CORPUS_DIR / source_name
    return json.loads(expected_path.read_text(encoding="utf-8"))


def _write_scan_expected(output_name: str, source_name: str, *, expect_review_sheet: bool) -> None:
    expected = _load_expected(source_name)
    scan_expected = {
        **expected,
        "document": output_name,
        "document_class": output_name.replace(".pdf", ""),
        "expect_review_sheet": expect_review_sheet,
    }
    output_path = CORPUS_DIR / output_name.replace(".pdf", ".expected.json")
    output_path.write_text(json.dumps(scan_expected, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    if DIGITAL_GENERATOR.exists():
        import subprocess
        import sys

        subprocess.run([sys.executable, str(DIGITAL_GENERATOR)], check=True, cwd=CORPUS_DIR.parent)

    CORPUS_DIR.mkdir(parents=True, exist_ok=True)
    for filename, generator in GENERATORS.items():
        path = CORPUS_DIR / filename
        generator(path)
        print(f"Wrote {path}")

    _write_scan_expected("clean_scan.pdf", "ruled_table.expected.json", expect_review_sheet=False)
    _write_scan_expected("noisy_scan.pdf", "ruled_table.expected.json", expect_review_sheet=True)
    _write_scan_expected("ruled_scan.pdf", "multi_table.expected.json", expect_review_sheet=False)
    _write_scan_expected("borderless_scan.pdf", "borderless_table.expected.json", expect_review_sheet=False)
    _write_scan_expected("rotated_scan.pdf", "rotated_table.expected.json", expect_review_sheet=True)
    rotated_expected = {
        "document": "rotated_scan.pdf",
        "document_class": "rotated_scan",
        "pages": "1",
        "minimum_worksheets": 1,
        "expect_review_sheet": True,
        "minimum_cell_recall": 0.5,
        "required_values": [
            "00987",
            "50",
            "35"
        ],
        "header_values": [
            "Item ID",
            "Batch",
            "Count"
        ],
        "rows": []
    }
    (CORPUS_DIR / "rotated_scan.expected.json").write_text(
        json.dumps(rotated_expected, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
