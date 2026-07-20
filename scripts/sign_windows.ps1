# Sign an Open PDF MSIX with a trusted publisher certificate.
# Credentials come only from the environment — never source control.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Package
)

$ErrorActionPreference = "Stop"

function Write-Usage {
    @"
Usage: sign_windows.ps1 <Open-PDF-x64.msix>

Required environment:
  OPEN_PDF_WINDOWS_PFX_PATH       Path to the .pfx used for trusted publisher signing
  OPEN_PDF_WINDOWS_PFX_PASSWORD   PFX password (empty string allowed for passwordless PFX)

Optional:
  OPEN_PDF_WINDOWS_TIMESTAMP_URL  RFC3161 timestamp server
                                  (default https://timestamp.digicert.com)

Never commit credential values to this repository.
"@
}

if (-not $Package -or $Package -in @("-h", "--help")) {
    Write-Usage
    exit 2
}

if (-not (Test-Path $Package)) {
    Write-Error "Package not found: $Package"
    exit 1
}

$Pfx = $env:OPEN_PDF_WINDOWS_PFX_PATH
if (-not $Pfx) {
    Write-Error "OPEN_PDF_WINDOWS_PFX_PATH is required."
    exit 1
}
if (-not (Test-Path $Pfx)) {
    Write-Error "PFX not found: $Pfx"
    exit 1
}

$Password = $env:OPEN_PDF_WINDOWS_PFX_PASSWORD
if ($null -eq $Password) {
    Write-Error "OPEN_PDF_WINDOWS_PFX_PASSWORD must be set (use empty string for passwordless PFX)."
    exit 1
}

$Timestamp = if ($env:OPEN_PDF_WINDOWS_TIMESTAMP_URL) {
    $env:OPEN_PDF_WINDOWS_TIMESTAMP_URL
} else {
    "https://timestamp.digicert.com"
}

$SignTool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if (-not $SignTool) {
    Write-Error "signtool.exe not found. Install the Windows SDK."
    exit 1
}

Write-Host "Signing $Package with $Pfx"
& $SignTool.FullName sign /fd SHA256 /td SHA256 /tr $Timestamp /f $Pfx /p $Password $Package
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$Sig = Get-AuthenticodeSignature -FilePath $Package
if ($Sig.Status -ne "Valid") {
    Write-Error "Authenticode signature status is $($Sig.Status), expected Valid."
    exit 1
}

Write-Host "ok: signed by $($Sig.SignerCertificate.Subject)"
Write-Host "Signing pipeline complete for $Package"
