#!/usr/bin/env python3
"""Verify a Windows Open PDF MSIX payload contains the Ticket 10 release inventory."""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path


REQUIRED_RELATIVE = (
    "AppxManifest.xml",
    "open_pdf.exe",
    "data/THIRD_PARTY_NOTICES",
    "data/worker/open_pdf_worker/open_pdf_worker.exe",
    "data/worker/open_pdf_worker/tesseract.exe",
)


def _fail(message: str) -> int:
    print(f"verify_windows_package: {message}", file=sys.stderr)
    return 1


def _resolve_root(path: Path) -> tuple[Path, Path | None]:
    """Return (payload_root, temp_dir_to_cleanup)."""
    if path.is_file() and path.suffix.lower() == ".msix":
        temp = Path(tempfile.mkdtemp(prefix="open-pdf-msix-"))
        with zipfile.ZipFile(path) as archive:
            archive.extractall(temp)
        return temp, temp
    if path.is_dir():
        return path, None
    raise ValueError(f"expected an MSIX file or staging directory, got {path}")


def verify_payload(root: Path) -> int:
    for relative in REQUIRED_RELATIVE:
        candidate = root / relative
        if not candidate.exists():
            return _fail(f"missing {relative}")

    worker = root / "data/worker/open_pdf_worker/open_pdf_worker.exe"
    if not worker.is_file():
        return _fail("worker executable is not a file")

    tesseract = root / "data/worker/open_pdf_worker/tesseract.exe"
    if not tesseract.is_file():
        return _fail("bundled tesseract is not a file")

    tessdata_candidates = [
        root
        / "data/worker/open_pdf_worker/_internal/open_pdf_worker/tessdata/eng.traineddata",
        root / "data/worker/open_pdf_worker/tessdata/eng.traineddata",
    ]
    if not any(path.is_file() for path in tessdata_candidates):
        return _fail("missing OCR model eng.traineddata")

    notices = (root / "data/THIRD_PARTY_NOTICES").read_text(encoding="utf-8")
    for needle in ("camelot", "eng.traineddata", "pdfrx", "Tesseract"):
        if needle.lower() not in notices.lower():
            return _fail(f"THIRD_PARTY_NOTICES missing expected entry for {needle}")

    flutter_dll = root / "flutter_windows.dll"
    pdfium_hits = list(root.glob("**/pdfium*.dll")) + list(root.glob("**/*pdfium*"))
    if not flutter_dll.is_file() and not pdfium_hits:
        return _fail("missing Flutter or PDFium engine artifacts")

    manifest = (root / "AppxManifest.xml").read_text(encoding="utf-8")
    if "runFullTrust" not in manifest:
        return _fail("AppxManifest.xml missing runFullTrust capability")
    if "open_pdf.exe" not in manifest:
        return _fail("AppxManifest.xml missing open_pdf.exe entry point")

    print("ok: Windows package inventory verified")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path, help="Path to .msix or staging directory")
    args = parser.parse_args(argv)
    temp: Path | None = None
    try:
        root, temp = _resolve_root(args.package.resolve())
        return verify_payload(root)
    except ValueError as exc:
        return _fail(str(exc))
    finally:
        if temp is not None:
            shutil.rmtree(temp, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
