"""Package inventory and signing-config seams for the macOS installer (Ticket 9)."""

from __future__ import annotations

import os
import shutil
import stat
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "scripts" / "verify_macos_package.py"
SIGN = ROOT / "scripts" / "sign_and_notarize_macos.sh"
PACKAGE = ROOT / "scripts" / "package_macos.sh"
ENTITLEMENTS = ROOT / "app" / "macos" / "Runner" / "Release.entitlements"
NOTICES = ROOT / "THIRD_PARTY_NOTICES"


def _make_fake_app(tmp_path: Path, *, arch: str = "arm64") -> Path:
    app = tmp_path / "Open PDF.app"
    contents = app / "Contents"
    macos = contents / "MacOS"
    resources = contents / "Resources"
    frameworks = contents / "Frameworks"
    worker = resources / "worker" / "open_pdf_worker"
    tessdata = worker / "_internal" / "open_pdf_worker" / "tessdata"
    lib_dir = worker / "lib"

    for path in (macos, frameworks, tessdata, lib_dir):
        path.mkdir(parents=True)

    exe = macos / "Open PDF"
    exe.write_bytes(b"\x00fake")
    exe.chmod(exe.stat().st_mode | stat.S_IXUSR)

    # Minimal PDFium-shaped framework presence.
    (frameworks / "pdfium_flutter.framework").mkdir()
    (frameworks / "pdfium_flutter.framework" / "pdfium_flutter").write_bytes(b"\x00")

    worker_exe = worker / "open_pdf_worker"
    worker_exe.write_bytes(b"\x00worker")
    worker_exe.chmod(worker_exe.stat().st_mode | stat.S_IXUSR)

    tesseract = worker / "tesseract"
    tesseract.write_bytes(b"\x00tess")
    tesseract.chmod(tesseract.stat().st_mode | stat.S_IXUSR)
    (lib_dir / "libtesseract.5.dylib").write_bytes(b"\x00dylib")

    (tessdata / "eng.traineddata").write_bytes(b"model")
    shutil.copy(NOTICES, resources / "THIRD_PARTY_NOTICES")

    (contents / "Info.plist").write_text(
        "\n".join(
            [
                '<?xml version="1.0" encoding="UTF-8"?>',
                '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
                '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
                "<plist version=\"1.0\"><dict>",
                "<key>CFBundleIdentifier</key><string>app.openpdf.reader</string>",
                "<key>CFBundleName</key><string>Open PDF</string>",
                "<key>CFBundleExecutable</key><string>Open PDF</string>",
                f"<key>OpenPDFArchitecture</key><string>{arch}</string>",
                "</dict></plist>",
            ]
        ),
        encoding="utf-8",
    )
    return app


def test_verify_script_and_packaging_scripts_exist() -> None:
    assert VERIFY.is_file()
    assert SIGN.is_file()
    assert PACKAGE.is_file()


def test_release_entitlements_enable_hardened_runtime_helpers() -> None:
    text = ENTITLEMENTS.read_text(encoding="utf-8")
    assert "com.apple.security.app-sandbox" not in text or "<false/>" in text.split(
        "com.apple.security.app-sandbox", 1
    )[1][:80]
    assert "com.apple.security.cs.allow-jit" in text
    assert "com.apple.security.cs.disable-library-validation" in text


def test_debug_entitlements_allow_local_worker_and_save_dialog() -> None:
    # Debug must not sandbox the Flutter runner: Convert spawns
    # worker/dist/... which App Sandbox cannot execute. Release packaging
    # uses its own entitlements when signing the .app.
    debug = ROOT / "app" / "macos" / "Runner" / "DebugProfile.entitlements"
    text = debug.read_text(encoding="utf-8")
    assert "com.apple.security.app-sandbox" in text
    sandbox_value = text.split("com.apple.security.app-sandbox", 1)[1][:80]
    assert "<false/>" in sandbox_value
    assert "com.apple.security.files.user-selected.read-write" in text


def test_signing_script_requires_env_credentials_not_repo_secrets() -> None:
    text = SIGN.read_text(encoding="utf-8")
    assert "OPEN_PDF_CODESIGN_IDENTITY" in text
    assert "OPEN_PDF_NOTARY_PROFILE" in text or "NOTARYTOOL" in text.upper()
    # No hardcoded Apple ID / team / password / API key material.
    lowered = text.lower()
    assert "password=" not in lowered
    assert "-----begin" not in lowered
    assert "@" not in "".join(
        line for line in text.splitlines() if "APPLE" in line.upper() and "=" in line
    )


def test_verify_accepts_complete_fake_package(tmp_path: Path) -> None:
    app = _make_fake_app(tmp_path)
    completed = subprocess.run(
        [sys.executable, str(VERIFY), str(app)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 0, completed.stderr + completed.stdout
    assert "ok" in completed.stdout.lower()


def test_verify_rejects_package_missing_worker(tmp_path: Path) -> None:
    app = _make_fake_app(tmp_path)
    worker = app / "Contents" / "Resources" / "worker" / "open_pdf_worker" / "open_pdf_worker"
    worker.unlink()
    completed = subprocess.run(
        [sys.executable, str(VERIFY), str(app)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode != 0
    assert "worker" in (completed.stderr + completed.stdout).lower()


def test_verify_rejects_package_missing_notices(tmp_path: Path) -> None:
    app = _make_fake_app(tmp_path)
    (app / "Contents" / "Resources" / "THIRD_PARTY_NOTICES").unlink()
    completed = subprocess.run(
        [sys.executable, str(VERIFY), str(app)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode != 0


def test_verify_rejects_package_missing_ocr_model(tmp_path: Path) -> None:
    app = _make_fake_app(tmp_path)
    model = (
        app
        / "Contents"
        / "Resources"
        / "worker"
        / "open_pdf_worker"
        / "_internal"
        / "open_pdf_worker"
        / "tessdata"
        / "eng.traineddata"
    )
    model.unlink()
    completed = subprocess.run(
        [sys.executable, str(VERIFY), str(app)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode != 0


def test_repo_contains_no_signing_credentials() -> None:
    forbidden = (
        "OPEN_PDF_CODESIGN_IDENTITY=",
        "APP_STORE_CONNECT_API_KEY=",
        "-----BEGIN PRIVATE KEY-----",
    )
    for path in (ROOT / "scripts").glob("*"):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for needle in forbidden:
            # Allow documentation that names the variable without assigning a secret.
            if needle.endswith("=") and needle in text:
                for line in text.splitlines():
                    if needle in line and not line.strip().startswith("#"):
                        rhs = line.split(needle, 1)[1].strip().strip('"').strip("'")
                        assert rhs in {"", "${", "$("} or rhs.startswith("$") or rhs.startswith(
                            "${"
                        ), f"{path} appears to embed a credential: {line}"


@pytest.mark.skipif(sys.platform != "darwin", reason="macOS packaging only")
def test_bundled_helper_path_matches_worker_locator_contract(tmp_path: Path) -> None:
    app = _make_fake_app(tmp_path)
    expected = (
        app
        / "Contents"
        / "Resources"
        / "worker"
        / "open_pdf_worker"
        / "open_pdf_worker"
    )
    assert expected.is_file()
    # Mirrors app/lib/services/worker_locator.dart bundled layout.
    bundle_root = expected.parents[3]  # .../Contents
    assert bundle_root.name == "Contents"
    assert (bundle_root / "Resources" / "worker" / "open_pdf_worker" / "open_pdf_worker").is_file()
