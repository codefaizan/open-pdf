"""Package inventory and signing-config seams for the Windows MSIX installer (Ticket 10)."""

from __future__ import annotations

import shutil
import stat
import subprocess
import sys
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "scripts" / "verify_windows_package.py"
SIGN = ROOT / "scripts" / "sign_windows.ps1"
PACKAGE = ROOT / "scripts" / "package_windows.ps1"
SMOKE = ROOT / "scripts" / "smoke_windows_package.ps1"
MANIFEST = ROOT / "packaging" / "windows" / "AppxManifest.xml"
NOTICES = ROOT / "THIRD_PARTY_NOTICES"


def _make_fake_payload(tmp_path: Path) -> Path:
    """Layout matching WorkerLocator Windows bundled path and MSIX staging."""
    payload = tmp_path / "payload"
    data = payload / "data"
    worker = data / "worker" / "open_pdf_worker"
    tessdata = worker / "_internal" / "open_pdf_worker" / "tessdata"
    assets = payload / "Assets"

    for path in (tessdata, assets):
        path.mkdir(parents=True)

    exe = payload / "open_pdf.exe"
    exe.write_bytes(b"MZ\x00fake")
    (payload / "flutter_windows.dll").write_bytes(b"\x00flutter")
    (payload / "pdfium.dll").write_bytes(b"\x00pdfium")

    worker_exe = worker / "open_pdf_worker.exe"
    worker_exe.write_bytes(b"MZ\x00worker")
    worker_exe.chmod(worker_exe.stat().st_mode | stat.S_IXUSR)

    tesseract = worker / "tesseract.exe"
    tesseract.write_bytes(b"MZ\x00tess")
    tesseract.chmod(tesseract.stat().st_mode | stat.S_IXUSR)
    (worker / "tesseract50.dll").write_bytes(b"\x00dll")

    (tessdata / "eng.traineddata").write_bytes(b"model")
    shutil.copy(NOTICES, data / "THIRD_PARTY_NOTICES")

    for name in (
        "StoreLogo.png",
        "Square44x44Logo.png",
        "Square150x150Logo.png",
        "Wide310x150Logo.png",
    ):
        (assets / name).write_bytes(b"\x89PNG\r\n\x1a\n")

    shutil.copy(MANIFEST, payload / "AppxManifest.xml")
    return payload


def test_verify_script_and_packaging_scripts_exist() -> None:
    assert VERIFY.is_file()
    assert SIGN.is_file()
    assert PACKAGE.is_file()
    assert SMOKE.is_file()
    assert MANIFEST.is_file()


def test_appx_manifest_declares_full_trust_desktop_x64() -> None:
    text = MANIFEST.read_text(encoding="utf-8")
    assert 'ProcessorArchitecture="x64"' in text or "ProcessorArchitecture=\"x64\"" in text
    assert "runFullTrust" in text
    assert "Windows.Desktop" in text
    assert "open_pdf.exe" in text
    assert "__PUBLISHER__" in text or "CN=" in text


def test_signing_script_requires_env_credentials_not_repo_secrets() -> None:
    text = SIGN.read_text(encoding="utf-8")
    assert "OPEN_PDF_WINDOWS_PFX_PATH" in text
    assert "OPEN_PDF_WINDOWS_PFX_PASSWORD" in text
    lowered = text.lower()
    assert "-----begin" not in lowered
    assert "password =" not in lowered.replace(" ", "")
    # No hardcoded PFX path assignments with real values.
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("<#"):
            continue
        if "OPEN_PDF_WINDOWS_PFX_PATH" in stripped and "=" in stripped:
            # PowerShell env reads are fine; literal path assignments are not.
            if "$env:OPEN_PDF_WINDOWS_PFX_PATH" in stripped:
                continue
            rhs = stripped.split("=", 1)[1].strip().strip('"').strip("'")
            assert rhs in {"", "$null"} or rhs.startswith("$"), stripped


def test_verify_accepts_complete_fake_payload(tmp_path: Path) -> None:
    payload = _make_fake_payload(tmp_path)
    completed = subprocess.run(
        [sys.executable, str(VERIFY), str(payload)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 0, completed.stderr + completed.stdout
    assert "ok" in completed.stdout.lower()


def test_verify_accepts_msix_zip(tmp_path: Path) -> None:
    payload = _make_fake_payload(tmp_path)
    msix = tmp_path / "Open-PDF-x64.msix"
    with zipfile.ZipFile(msix, "w") as archive:
        for path in payload.rglob("*"):
            if path.is_file():
                archive.write(path, path.relative_to(payload).as_posix())
    completed = subprocess.run(
        [sys.executable, str(VERIFY), str(msix)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 0, completed.stderr + completed.stdout


def test_verify_rejects_package_missing_worker(tmp_path: Path) -> None:
    payload = _make_fake_payload(tmp_path)
    (payload / "data" / "worker" / "open_pdf_worker" / "open_pdf_worker.exe").unlink()
    completed = subprocess.run(
        [sys.executable, str(VERIFY), str(payload)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode != 0
    assert "worker" in (completed.stderr + completed.stdout).lower()


def test_verify_rejects_package_missing_notices(tmp_path: Path) -> None:
    payload = _make_fake_payload(tmp_path)
    (payload / "data" / "THIRD_PARTY_NOTICES").unlink()
    completed = subprocess.run(
        [sys.executable, str(VERIFY), str(payload)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode != 0


def test_verify_rejects_package_missing_ocr_model(tmp_path: Path) -> None:
    payload = _make_fake_payload(tmp_path)
    model = (
        payload
        / "data"
        / "worker"
        / "open_pdf_worker"
        / "_internal"
        / "open_pdf_worker"
        / "tessdata"
        / "eng.traineddata"
    )
    model.unlink()
    completed = subprocess.run(
        [sys.executable, str(VERIFY), str(payload)],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode != 0


def test_bundled_helper_path_matches_worker_locator_contract(tmp_path: Path) -> None:
    payload = _make_fake_payload(tmp_path)
    expected = (
        payload / "data" / "worker" / "open_pdf_worker" / "open_pdf_worker.exe"
    )
    assert expected.is_file()
    # Mirrors app/lib/services/worker_locator.dart Windows bundled layout:
    # $exeDir\data\worker\open_pdf_worker\open_pdf_worker.exe
    exe_dir = payload
    assert (exe_dir / "open_pdf.exe").is_file()
    assert (
        exe_dir / "data" / "worker" / "open_pdf_worker" / "open_pdf_worker.exe"
    ).is_file()


def test_repo_contains_no_windows_signing_credentials() -> None:
    forbidden = (
        "OPEN_PDF_WINDOWS_PFX_PASSWORD=",
        "-----BEGIN PRIVATE KEY-----",
        "-----BEGIN CERTIFICATE-----",
    )
    for path in (ROOT / "scripts").glob("*"):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for needle in forbidden:
            if needle.endswith("=") and needle in text:
                for line in text.splitlines():
                    if needle in line and not line.strip().startswith("#"):
                        rhs = line.split(needle, 1)[1].strip().strip('"').strip("'")
                        assert rhs in {"", "${", "$("} or rhs.startswith("$") or rhs.startswith(
                            "${"
                        ), f"{path} appears to embed a credential: {line}"
            elif needle.startswith("-----") and needle in text:
                pytest.fail(f"{path} appears to embed PEM material")


def test_find_tesseract_checks_exe_beside_worker() -> None:
    from open_pdf_worker import ocr

    source = ocr.find_tesseract_binary.__code__.co_consts
    blob = " ".join(str(item) for item in source)
    assert "tesseract.exe" in blob
