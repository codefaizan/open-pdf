from __future__ import annotations

from pathlib import Path

import pytest

from open_pdf_worker.harness import CORPUS_DIR, ensure_corpus
from open_pdf_worker.page_detection import (
    classify_pages,
    page_has_reliable_text,
    page_needs_ocr,
    parse_page_numbers,
)


@pytest.fixture(scope="session")
def corpus() -> None:
    ensure_corpus()


def test_digital_pdf_page_is_not_marked_for_ocr(corpus: None) -> None:
    pdf_path = CORPUS_DIR / "ruled_table.pdf"
    assert page_needs_ocr(pdf_path, 1) is False


def test_scan_pdf_page_is_marked_for_ocr(corpus: None) -> None:
    pdf_path = CORPUS_DIR / "clean_scan.pdf"
    assert page_needs_ocr(pdf_path, 1) is True


def test_reliable_text_requires_meaningful_characters() -> None:
    assert page_has_reliable_text("Item ID Product Code Quantity") is True
    assert page_has_reliable_text("   ") is False
    assert page_has_reliable_text("abc") is False


def test_classify_pages_splits_digital_and_scan_pages(corpus: None) -> None:
    digital_pages, scan_pages = classify_pages(CORPUS_DIR / "clean_scan.pdf", "1")
    assert digital_pages == []
    assert scan_pages == [1]

    digital_pages, scan_pages = classify_pages(CORPUS_DIR / "ruled_table.pdf", "1")
    assert digital_pages == [1]
    assert scan_pages == []


def test_parse_page_numbers_supports_ranges() -> None:
    assert parse_page_numbers("1,3-4", 5) == [1, 3, 4]
    assert parse_page_numbers("all", 2) == [1, 2]
