from __future__ import annotations

import re
from pathlib import Path

import pypdfium2 as pdfium

MIN_RELIABLE_TEXT_CHARS = 20
_RELIABLE_TEXT = re.compile(r"[A-Za-z0-9]{3,}")


def parse_page_numbers(page_spec: str, page_count: int) -> list[int]:
    spec = page_spec.strip()
    if spec == "all":
        return list(range(1, page_count + 1))

    pages: set[int] = set()
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start_text, end_text = part.split("-", 1)
            start = int(start_text)
            end = int(end_text)
            if start > end:
                start, end = end, start
            pages.update(range(start, end + 1))
        else:
            pages.add(int(part))

    selected = sorted(page for page in pages if 1 <= page <= page_count)
    if not selected:
        raise ValueError(f"No valid pages in range: {page_spec!r}")
    return selected


def page_count(input_pdf: Path) -> int:
    document = pdfium.PdfDocument(str(input_pdf))
    return len(document)


def embedded_text(input_pdf: Path, page_number: int) -> str:
    document = pdfium.PdfDocument(str(input_pdf))
    if page_number < 1 or page_number > len(document):
        raise ValueError(f"Page {page_number} is out of range.")
    page = document[page_number - 1]
    return page.get_textpage().get_text_bounded().strip()


def page_has_reliable_text(text: str) -> bool:
    if len(text) < MIN_RELIABLE_TEXT_CHARS:
        return False
    return _RELIABLE_TEXT.search(text) is not None


def page_needs_ocr(input_pdf: Path, page_number: int) -> bool:
    return not page_has_reliable_text(embedded_text(input_pdf, page_number))


def classify_pages(input_pdf: Path, page_spec: str) -> tuple[list[int], list[int]]:
    total_pages = page_count(input_pdf)
    pages = parse_page_numbers(page_spec, total_pages)
    digital_pages: list[int] = []
    scan_pages: list[int] = []
    for page_number in pages:
        if page_needs_ocr(input_pdf, page_number):
            scan_pages.append(page_number)
        else:
            digital_pages.append(page_number)
    return digital_pages, scan_pages


def pages_to_spec(pages: list[int]) -> str:
    if not pages:
        raise ValueError("At least one page is required.")
    return ",".join(str(page) for page in sorted(pages))
