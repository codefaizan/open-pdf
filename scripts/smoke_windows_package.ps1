# Clean-machine smoke checks for a built Windows Open PDF MSIX (Ticket 10).
# Exercises offline conversion via the embedded helper; documents publisher UI checks.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputPath
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Write-Usage {
    @"
Usage: smoke_windows_package.ps1 <Open-PDF-x64.msix|stage-x64>

Checks:
  - package inventory (app, PDF engine, worker, OCR, notices)
  - helper resolves from the installed layout
  - offline conversion (network proxies cleared for the worker process)
  - paths with spaces and non-English characters
  - cancel leaves no complete workbook
  - Authenticode status when signed

Full GUI navigate/search/uninstall still requires a clean Windows x64 manual pass;
this script covers the automatable packaging smoke seam.
"@
}

if (-not $InputPath -or $InputPath -in @("-h", "--help")) {
    Write-Usage
    exit 2
}

$Work = Join-Path $env:TEMP ("open-pdf-smoke-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $Work | Out-Null
try {
    $Payload = $null
    if ($InputPath -like "*.msix") {
        $Extract = Join-Path $Work "payload"
        New-Item -ItemType Directory -Force -Path $Extract | Out-Null
        $ZipCopy = Join-Path $Work "package.zip"
        Copy-Item -Force $InputPath $ZipCopy
        Expand-Archive -Force -Path $ZipCopy -DestinationPath $Extract
        $Payload = $Extract
    } elseif (Test-Path (Join-Path $InputPath "open_pdf.exe")) {
        $Payload = Join-Path $Work "payload"
        Copy-Item -Recurse -Force $InputPath $Payload
    } else {
        Write-Error "Expected .msix or staging directory containing open_pdf.exe"
        exit 2
    }

    python (Join-Path $Root "scripts\verify_windows_package.py") $Payload
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $Worker = Join-Path $Payload "data\worker\open_pdf_worker\open_pdf_worker.exe"
    $Tesseract = Join-Path $Payload "data\worker\open_pdf_worker\tesseract.exe"
    if (-not (Test-Path $Tesseract)) {
        Write-Error "bundled tesseract missing"
        exit 1
    }

    $HelperPy = Join-Path $Work "worker_job.py"
    @'
import json, os, subprocess, sys, time
from pathlib import Path

def run_job(worker, pdf, out, pages=None):
    env = os.environ.copy()
    env["TESSERACT_CMD"] = str(Path(worker).parent / "tesseract.exe")
    for key in list(env):
        if key.lower().endswith("_proxy") or key.lower() in {"http_proxy", "https_proxy", "all_proxy"}:
            env.pop(key, None)
    # Keep PATH minimal so conversion cannot silently use a host Python/OCR install.
    env["PATH"] = os.environ.get("SystemRoot", r"C:\Windows") + r"\System32"

    proc = subprocess.Popen(
        [worker],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    )
    assert proc.stdin and proc.stdout

    def send(obj):
        proc.stdin.write(json.dumps(obj) + "\n")
        proc.stdin.flush()

    def read():
        line = proc.stdout.readline()
        if not line:
            raise SystemExit(f"worker closed stdout; stderr={proc.stderr.read()}")
        return json.loads(line)

    send({"type": "handshake", "protocol_version": "1.0"})
    assert read()["type"] == "handshake_ack"
    payload = {
        "type": "convert",
        "request_id": "smoke",
        "input_pdf": pdf,
        "output_xlsx": out,
    }
    if pages:
        payload["pages"] = pages
    send(payload)
    terminal = None
    while True:
        event = read()
        if event.get("type") in {"complete", "error"}:
            terminal = event
            break
    proc.stdin.close()
    proc.wait(timeout=120)
    print(json.dumps(terminal))
    return terminal


def run_cancel(worker, pdf, out):
    env = os.environ.copy()
    env["TESSERACT_CMD"] = str(Path(worker).parent / "tesseract.exe")
    env["PATH"] = os.environ.get("SystemRoot", r"C:\Windows") + r"\System32"
    proc = subprocess.Popen(
        [worker],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    )
    assert proc.stdin and proc.stdout

    def send(obj):
        proc.stdin.write(json.dumps(obj) + "\n")
        proc.stdin.flush()

    def read():
        line = proc.stdout.readline()
        if not line:
            return None
        return json.loads(line)

    send({"type": "handshake", "protocol_version": "1.0"})
    assert read()["type"] == "handshake_ack"
    send({
        "type": "convert",
        "request_id": "smoke-cancel",
        "input_pdf": pdf,
        "output_xlsx": out,
    })
    while True:
        event = read()
        if event is None:
            raise SystemExit("worker exited before progress")
        if event.get("type") == "progress":
            send({"type": "cancel", "request_id": "smoke-cancel"})
            break
        if event.get("type") in {"complete", "error"}:
            raise SystemExit(f"finished before cancel: {event}")

    deadline = time.time() + 60
    while time.time() < deadline:
        event = read()
        if event is None:
            break
        if event.get("type") == "error" and event.get("code") == "CANCELLED":
            break
        if event.get("type") == "complete":
            raise SystemExit("cancel raced with completion")
    proc.stdin.close()
    try:
        proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        proc.kill()
    if Path(out).is_file():
        raise SystemExit("cancel left a workbook that could be mistaken for success")
    print("ok: cancel cleanup")


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "convert":
        run_job(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else None)
    elif mode == "cancel":
        run_cancel(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        raise SystemExit(f"unknown mode {mode}")
'@ | Set-Content -Path $HelperPy -Encoding utf8

    Write-Host "==> Offline conversion with spaced / unicode paths"
    $PdfDir = Join-Path $Work "docs with spaces\Документы"
    New-Item -ItemType Directory -Force -Path $PdfDir | Out-Null
    $Pdf = Join-Path $PdfDir "sample report.pdf"
    $Out = Join-Path $PdfDir "output workbook.xlsx"
    Copy-Item -Force (Join-Path $Root "corpus\ruled_table.pdf") $Pdf

    $Before = @(Get-ChildItem -Recurse -File $Payload).Count
    $terminal = python $HelperPy convert $Worker $Pdf $Out
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $terminal | python -c "import json,sys; e=json.load(sys.stdin); assert e['type']=='complete', e"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path $Out)) { throw "workbook missing" }
    $After = @(Get-ChildItem -Recurse -File $Payload).Count
    if ($After -ne $Before) {
        Write-Error "helper wrote into the package payload ($Before -> $After files)"
        exit 1
    }
    Write-Host "ok: offline conversion (helper did not write into package)"

    Write-Host "==> Offline OCR conversion (bundled tesseract, cleared proxies)"
    $OcrPdf = Join-Path $PdfDir "clean scan.pdf"
    $OcrOut = Join-Path $PdfDir "ocr workbook.xlsx"
    Copy-Item -Force (Join-Path $Root "corpus\clean_scan.pdf") $OcrPdf
    $terminal = python $HelperPy convert $Worker $OcrPdf $OcrOut
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $terminal | python -c "import json,sys; e=json.load(sys.stdin); assert e['type']=='complete', e"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path $OcrOut)) { throw "OCR workbook missing" }
    Write-Host "ok: offline OCR conversion"

    Write-Host "==> Recover from invalid page range, then convert again"
    $BadOut = Join-Path $PdfDir "bad range.xlsx"
    $terminal = python $HelperPy convert $Worker $Pdf $BadOut "9999"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $terminal | python -c "import json,sys; e=json.load(sys.stdin); assert e['type']=='error', e"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (Test-Path $BadOut) { throw "bad conversion left a workbook" }
    $RecoverOut = Join-Path $PdfDir "recovered.xlsx"
    $terminal = python $HelperPy convert $Worker $Pdf $RecoverOut
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $terminal | python -c "import json,sys; e=json.load(sys.stdin); assert e['type']=='complete', e"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "ok: failure recovery"

    Write-Host "==> Cancel leaves no complete workbook"
    $CancelPdf = Join-Path $PdfDir "multi page.pdf"
    $CancelOut = Join-Path $PdfDir "cancelled.xlsx"
    Copy-Item -Force (Join-Path $Root "corpus\multi_page_table.pdf") $CancelPdf
    python $HelperPy cancel $Worker $CancelPdf $CancelOut
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if ($InputPath -like "*.msix") {
        Write-Host "==> Authenticode assessment (informational if unsigned)"
        $Sig = Get-AuthenticodeSignature -FilePath $InputPath
        Write-Host "Authenticode status: $($Sig.Status); signer: $($Sig.SignerCertificate.Subject)"
        if ($Sig.Status -eq "Valid") {
            Write-Host "ok: Windows verified publisher signature"
        } else {
            Write-Host "note: signature not Valid (expected for unsigned/local builds)."
            Write-Host "      A trusted-publisher PFX should yield Status=Valid on a clean machine."
        }
    }

    Write-Host "==> Manual clean-Windows checklist (GUI)"
    @"
After installing Open-PDF-x64.msix on a clean supported Windows x64 machine:
  [ ] Launch Open PDF (no Python / model download / local server prompts)
  [ ] Open a PDF (including a path with spaces / non-English characters)
  [ ] Navigate with thumbnails / page controls and search text
  [ ] Convert to Excel, observe progress, open/reveal the workbook
  [ ] Cancel an in-flight conversion
  [ ] Recover from a forced failure (e.g. invalid page range) and convert again
  [ ] Disable network and repeat open + convert
  [ ] Uninstall from Settings > Apps
  [ ] Publisher: SmartScreen / Authenticode shows the expected publisher for a signed MSIX
"@

    Write-Host "smoke_windows_package: automatable checks passed"
}
finally {
    Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}
