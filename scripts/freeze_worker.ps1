# Freeze the conversion worker on Windows (Ticket 10 packaging).
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$WorkerDir = Join-Path $Root "worker"
$DistDir = Join-Path $WorkerDir "dist\open_pdf_worker"

Set-Location $WorkerDir

if (-not (Test-Path ".venv")) {
    python -m venv .venv
}

$Activate = Join-Path $WorkerDir ".venv\Scripts\Activate.ps1"
. $Activate

python -m pip install --upgrade pip | Out-Null
python -m pip install -e ".[dev]" "pyinstaller==6.21.0" | Out-Null
if (Test-Path "requirements.lock") {
    python -m pip install -r requirements.lock | Out-Null
}

pyinstaller --noconfirm open_pdf_worker.spec

$Exe = Join-Path $DistDir "open_pdf_worker.exe"
if (-not (Test-Path $Exe)) {
    Write-Error "Frozen worker executable not found in $DistDir"
    exit 1
}

Write-Host "Frozen worker ready at $DistDir"
