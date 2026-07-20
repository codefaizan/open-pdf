from __future__ import annotations

import os
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import pytesseract
from PIL import Image
from reportlab.pdfgen import canvas

PACKAGE_ROOT = Path(__file__).resolve().parent
RENDER_SCALE = 2


@dataclass(frozen=True)
class OcrWord:
    text: str
    confidence: float


@dataclass(frozen=True)
class OcrResult:
    words: list[OcrWord]
    average_confidence: float


def _meipass() -> Path | None:
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        return Path(meipass)
    return None


def bundled_tessdata_dir() -> Path:
    meipass = _meipass()
    if meipass is not None:
        candidates = [
            meipass / "open_pdf_worker" / "tessdata",
            meipass / "tessdata",
            Path(sys.executable).resolve().parent / "_internal" / "open_pdf_worker" / "tessdata",
        ]
        for candidate in candidates:
            if (candidate / "eng.traineddata").is_file():
                return candidate
    return PACKAGE_ROOT / "tessdata"


def bundled_tessdata_available() -> bool:
    return (bundled_tessdata_dir() / "eng.traineddata").is_file()


def find_tesseract_binary() -> str:
    meipass = _meipass()
    bundled_candidates: list[str] = []
    if meipass is not None:
        bundled_candidates.extend(
            [
                str(meipass / "tesseract"),
                str(meipass / "tesseract.exe"),
                str(Path(sys.executable).resolve().parent / "tesseract"),
            ]
        )
    candidates = [
        os.environ.get("TESSERACT_CMD"),
        *bundled_candidates,
        shutil.which("tesseract"),
        "/opt/homebrew/bin/tesseract",
        "/usr/local/bin/tesseract",
        "/usr/bin/tesseract",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    raise RuntimeError(
        "Tesseract OCR binary not found. Install Tesseract or set TESSERACT_CMD."
    )


def configure_tesseract() -> None:
    tessdata = bundled_tessdata_dir()
    if not (tessdata / "eng.traineddata").is_file():
        raise RuntimeError(
            f"Bundled OCR models are missing from {tessdata}. "
            "The application must ship tessdata for offline conversion."
        )
    os.environ["TESSDATA_PREFIX"] = str(tessdata)
    pytesseract.pytesseract.tesseract_cmd = find_tesseract_binary()


def recognize_image(image: Image.Image) -> OcrResult:
    configure_tesseract()
    data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
    words: list[OcrWord] = []
    confidences: list[float] = []
    for index in range(len(data["text"])):
        text = data["text"][index].strip()
        if not text:
            continue
        confidence = float(data["conf"][index])
        if confidence < 0:
            continue
        normalized = confidence / 100.0
        words.append(OcrWord(text=text, confidence=normalized))
        confidences.append(normalized)

    average_confidence = sum(confidences) / len(confidences) if confidences else 0.0
    return OcrResult(words=words, average_confidence=average_confidence)


def build_searchable_pdf(image: Image.Image, output_pdf: Path) -> OcrResult:
    configure_tesseract()
    data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
    words: list[OcrWord] = []
    confidences: list[float] = []
    page_width = image.width / RENDER_SCALE
    page_height = image.height / RENDER_SCALE

    image_path = output_pdf.with_suffix(".png")
    image.save(image_path)

    pdf = canvas.Canvas(str(output_pdf), pagesize=(page_width, page_height))
    pdf.drawImage(str(image_path), 0, 0, width=page_width, height=page_height)
    pdf.setFont("Helvetica", 8)

    for index in range(len(data["text"])):
        text = data["text"][index].strip()
        if not text:
            continue
        confidence = float(data["conf"][index])
        if confidence < 0:
            continue
        normalized = confidence / 100.0
        words.append(OcrWord(text=text, confidence=normalized))
        confidences.append(normalized)
        x = data["left"][index] / RENDER_SCALE
        y = page_height - (data["top"][index] + data["height"][index]) / RENDER_SCALE
        pdf.drawString(x, y, text)

    pdf.showPage()
    pdf.save()
    image_path.unlink(missing_ok=True)

    average_confidence = sum(confidences) / len(confidences) if confidences else 0.0
    return OcrResult(words=words, average_confidence=average_confidence)


def render_page_image(input_pdf: Path, page_number: int) -> Image.Image:
    import pypdfium2 as pdfium

    document = pdfium.PdfDocument(str(input_pdf))
    page = document[page_number - 1]
    return page.render(scale=RENDER_SCALE).to_pil()


def build_searchable_page_pdf(input_pdf: Path, page_number: int, output_pdf: Path) -> OcrResult:
    image = render_page_image(input_pdf, page_number)
    return build_searchable_pdf(image, output_pdf)
