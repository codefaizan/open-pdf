# Build a distributable Windows x64 Open PDF MSIX with worker, OCR, notices.
# Must run on Windows with Flutter + Windows SDK (MakeAppx).
[CmdletBinding()]
param(
    [switch]$SkipSign,
    [switch]$SkipPack,
    [string]$Version = "",
    [string]$Publisher = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AppDir = Join-Path $Root "app"
$OutDir = if ($env:OPEN_PDF_WINDOWS_OUT) { $env:OPEN_PDF_WINDOWS_OUT } else { Join-Path $Root "artifacts\windows" }
$StageDir = Join-Path $OutDir "stage-x64"

function Write-Usage {
    @"
Usage: package_windows.ps1 [-SkipSign] [-SkipPack] [-Version 1.0.0.0] [-Publisher 'CN=...']

Builds the Flutter Windows x64 release app, embeds the frozen conversion worker,
bundled Tesseract (+ DLLs), OCR models, and THIRD_PARTY_NOTICES, then packs an MSIX.

Signing uses scripts/sign_windows.ps1 and environment credentials only
(never source control):
  OPEN_PDF_WINDOWS_PFX_PATH
  OPEN_PDF_WINDOWS_PFX_PASSWORD
  OPEN_PDF_WINDOWS_PUBLISHER   (must match the PFX subject; default CN=Open PDF)
"@
}

if ($args -contains "-h" -or $args -contains "--help") {
    Write-Usage
    exit 0
}

if ($env:OS -ne "Windows_NT") {
    Write-Error "package_windows.ps1 must run on Windows x64."
    exit 1
}

if (-not $Publisher) {
    $Publisher = if ($env:OPEN_PDF_WINDOWS_PUBLISHER) { $env:OPEN_PDF_WINDOWS_PUBLISHER } else { "CN=Open PDF" }
}

if (-not $Version) {
    $pubspec = Get-Content (Join-Path $AppDir "pubspec.yaml") -Raw
    if ($pubspec -match '(?m)^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)') {
        $Version = "$($Matches[1]).$($Matches[2]).$($Matches[3]).0"
    } else {
        $Version = "1.0.0.0"
    }
}

Write-Host "==> Freezing conversion worker"
$Freeze = Join-Path $Root "scripts\freeze_worker.ps1"
if (Test-Path $Freeze) {
    & $Freeze
} else {
    # Fallback when only the bash freezer exists (Git Bash / WSL).
    $BashFreeze = Join-Path $Root "scripts\freeze_worker.sh"
    & bash $BashFreeze
}

$WorkerDist = Join-Path $Root "worker\dist\open_pdf_worker"
$WorkerExe = Join-Path $WorkerDist "open_pdf_worker.exe"
if (-not (Test-Path $WorkerExe)) {
    Write-Error "Frozen worker missing at $WorkerExe"
    exit 1
}

$TesseractDir = $env:OPEN_PDF_TESSERACT_DIR
if (-not $TesseractDir) {
    $cmd = Get-Command tesseract.exe -ErrorAction SilentlyContinue
    if ($cmd) { $TesseractDir = Split-Path -Parent $cmd.Source }
}
if (-not $TesseractDir -or -not (Test-Path (Join-Path $TesseractDir "tesseract.exe"))) {
    Write-Error "tesseract.exe not found; set OPEN_PDF_TESSERACT_DIR to a folder containing tesseract.exe and its DLLs"
    exit 1
}

Write-Host "==> Building Flutter Windows release (x64)"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Push-Location $AppDir
try {
    flutter pub get
    flutter build windows --release
} finally {
    Pop-Location
}

$Built = Join-Path $AppDir "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $Built "open_pdf.exe"))) {
    Write-Error "Flutter release payload not found at $Built"
    exit 1
}

Write-Host "==> Staging MSIX payload"
if (Test-Path $StageDir) { Remove-Item -Recurse -Force $StageDir }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
Copy-Item -Recurse -Force (Join-Path $Built "*") $StageDir

$WorkerDest = Join-Path $StageDir "data\worker\open_pdf_worker"
New-Item -ItemType Directory -Force -Path (Split-Path $WorkerDest) | Out-Null
if (Test-Path $WorkerDest) { Remove-Item -Recurse -Force $WorkerDest }
Copy-Item -Recurse -Force $WorkerDist $WorkerDest

# Bundle tesseract next to the worker (see open_pdf_worker.ocr.find_tesseract_binary).
Copy-Item -Force (Join-Path $TesseractDir "tesseract.exe") (Join-Path $WorkerDest "tesseract.exe")
Get-ChildItem $TesseractDir -Filter *.dll | ForEach-Object {
    Copy-Item -Force $_.FullName (Join-Path $WorkerDest $_.Name)
}

Copy-Item -Force (Join-Path $Root "THIRD_PARTY_NOTICES") (Join-Path $StageDir "data\THIRD_PARTY_NOTICES")

# Package assets + manifest
$AssetsSrc = Join-Path $Root "packaging\windows\Assets"
$AssetsDest = Join-Path $StageDir "Assets"
New-Item -ItemType Directory -Force -Path $AssetsDest | Out-Null
if (Test-Path $AssetsSrc) {
    Copy-Item -Force (Join-Path $AssetsSrc "*") $AssetsDest
} else {
    # Generate minimal solid PNGs when Assets/ was not checked in.
    python -c @"
from pathlib import Path
import struct, zlib

def png(path, w, h, rgb=(26, 86, 219)):
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    raw = b''.join(b'\x00' + bytes(rgb) * w for _ in range(h))
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
    Path(path).write_bytes(data)

dest = Path(r'$AssetsDest')
png(dest / 'StoreLogo.png', 50, 50)
png(dest / 'Square44x44Logo.png', 44, 44)
png(dest / 'Square150x150Logo.png', 150, 150)
png(dest / 'Wide310x150Logo.png', 310, 150)
"@
}

$ManifestTemplate = Get-Content (Join-Path $Root "packaging\windows\AppxManifest.xml") -Raw
$Manifest = $ManifestTemplate.Replace("__PUBLISHER__", $Publisher).Replace("__VERSION__", $Version)
$ManifestPath = Join-Path $StageDir "AppxManifest.xml"
# Avoid UTF-8 BOM — MakeAppx rejects a BOM before the XML declaration.
[System.IO.File]::WriteAllText($ManifestPath, $Manifest)

Write-Host "==> Verifying package inventory"
python (Join-Path $Root "scripts\verify_windows_package.py") $StageDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$Msix = Join-Path $OutDir "Open-PDF-x64.msix"
if (-not $SkipPack) {
    Write-Host "==> Packing MSIX"
    $MakeAppx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter MakeAppx.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\MakeAppx\.exe$' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if (-not $MakeAppx) {
        Write-Error "MakeAppx.exe not found. Install the Windows SDK."
        exit 1
    }
    if (Test-Path $Msix) { Remove-Item -Force $Msix }
    & $MakeAppx.FullName pack /d $StageDir /p $Msix /o
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    python (Join-Path $Root "scripts\verify_windows_package.py") $Msix
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not $SkipSign) {
    if (-not $env:OPEN_PDF_WINDOWS_PFX_PATH) {
        Write-Warning "OPEN_PDF_WINDOWS_PFX_PATH unset; producing unsigned package (use -SkipSign to silence)."
        $SkipSign = $true
    }
}

if (-not $SkipSign -and -not $SkipPack) {
    Write-Host "==> Signing MSIX"
    & (Join-Path $Root "scripts\sign_windows.ps1") $Msix
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Windows package ready:"
Write-Host "  $StageDir"
if (-not $SkipPack) {
    Write-Host "  $Msix"
}
if (-not $SkipSign -and -not $SkipPack) {
    Write-Host "Publisher check: Get-AuthenticodeSignature '$Msix'"
}
