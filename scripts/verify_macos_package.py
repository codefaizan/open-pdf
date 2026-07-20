#!/usr/bin/env python3
"""Verify a macOS Open PDF.app contains the Ticket 9 release inventory."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


REQUIRED_RELATIVE = (
    "Contents/MacOS",
    "Contents/Info.plist",
    "Contents/Resources/THIRD_PARTY_NOTICES",
    "Contents/Resources/worker/open_pdf_worker/open_pdf_worker",
    "Contents/Resources/worker/open_pdf_worker/tesseract",
)


def _fail(message: str) -> int:
    print(f"verify_macos_package: {message}", file=sys.stderr)
    return 1


def verify_app(app: Path) -> int:
    if not app.is_dir() or app.suffix != ".app":
        return _fail(f"expected an .app bundle, got {app}")

    for relative in REQUIRED_RELATIVE:
        path = app / relative
        if relative.endswith("MacOS"):
            executables = [p for p in path.iterdir() if p.is_file()] if path.is_dir() else []
            if not executables:
                return _fail(f"missing application executable under {relative}")
            continue
        if not path.exists():
            return _fail(f"missing {relative}")

    worker = app / "Contents/Resources/worker/open_pdf_worker/open_pdf_worker"
    if not os_access_executable(worker):
        return _fail("worker executable is not executable")

    tesseract = app / "Contents/Resources/worker/open_pdf_worker/tesseract"
    if not os_access_executable(tesseract):
        return _fail("bundled tesseract is not executable")

    tessdata_candidates = [
        app
        / "Contents/Resources/worker/open_pdf_worker/_internal/open_pdf_worker/tessdata/eng.traineddata",
        app / "Contents/Resources/worker/open_pdf_worker/tessdata/eng.traineddata",
    ]
    if not any(path.is_file() for path in tessdata_candidates):
        return _fail("missing OCR model eng.traineddata")

    notices = (app / "Contents/Resources/THIRD_PARTY_NOTICES").read_text(encoding="utf-8")
    for needle in ("camelot", "eng.traineddata", "pdfrx", "Tesseract"):
        if needle.lower() not in notices.lower():
            return _fail(f"THIRD_PARTY_NOTICES missing expected entry for {needle}")

    frameworks = app / "Contents/Frameworks"
    if not frameworks.is_dir():
        return _fail("missing Contents/Frameworks (PDF engine / Flutter runtime)")
    framework_names = " ".join(p.name.lower() for p in frameworks.iterdir())
    if "flutter" not in framework_names and "pdfium" not in framework_names:
        # Accept either Flutter framework or an explicit pdfium binary.
        dylibs = list(frameworks.glob("**/*pdfium*")) + list(frameworks.glob("**/*Flutter*"))
        if not dylibs:
            return _fail("Contents/Frameworks has no Flutter or PDFium engine artifacts")

    print("ok: macOS package inventory verified")
    return 0


def os_access_executable(path: Path) -> bool:
    import os

    return path.is_file() and os.access(path, os.X_OK)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Path to Open PDF.app")
    args = parser.parse_args(argv)
    return verify_app(args.app.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
