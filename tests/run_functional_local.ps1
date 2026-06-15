# Run functional tests locally against a portable NPP instance.
#
# Usage:
#   cd C:\DigitalMeasures\FingerText
#   .\tests\run_functional_local.ps1
#
# The script uses a portable NPP in $env:TEMP\npp_portable_test (downloads
# once, reuses on subsequent runs).  It copies the installed plugin DLL so
# your running NPP instance is never touched.
#
# Requirements:
#   - Notepad++ installed at the default location (or edit $InstalledDll below)
#   - pywinauto==0.6.8  (pip install "pywinauto==0.6.8")

$ErrorActionPreference = "Stop"

# ── Config ────────────────────────────────────────────────────────────────────

$NppVer      = "8.9.6.1"
$InstalledDll = "C:\Program Files\Notepad++\plugins\FingerText2\FingerText2.dll"
$PortableDir  = "$env:TEMP\npp_portable_test"
$PortableExe  = "$PortableDir\notepad++.exe"
$TempDll      = "$env:TEMP\FingerText2_test.dll"
$RepoRoot     = Split-Path $PSScriptRoot -Parent

# ── Portable NPP ──────────────────────────────────────────────────────────────

if (-not (Test-Path $PortableExe)) {
    Write-Host "Downloading portable NPP $NppVer x64..."
    $zip = "$env:TEMP\npp_portable_test.zip"
    $url = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v${NppVer}/npp.${NppVer}.portable.x64.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive $zip -DestinationPath $PortableDir -Force
    Remove-Item $zip
    Write-Host "  Extracted to $PortableDir"
} else {
    Write-Host "Reusing portable NPP at $PortableDir"
}

# ── DLL copy ──────────────────────────────────────────────────────────────────

Write-Host "Copying plugin DLL from installed NPP..."
if (-not (Test-Path $InstalledDll)) {
    Write-Error "Installed DLL not found: $InstalledDll`nBuild the DLL first or adjust `$InstalledDll in this script."
}
Copy-Item $InstalledDll $TempDll -Force

# ── Kill leftover portable NPP processes ──────────────────────────────────────

Write-Host "Killing any leftover portable NPP test instances..."
Get-Process notepad++ -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        $path = $_.MainModule.FileName
        if ($path -like "*AppData*Temp*") {
            $_.Kill()
            Write-Host "  Killed PID $($_.Id)"
        }
    } catch { }
}

# ── Run tests ─────────────────────────────────────────────────────────────────

$env:NPP_EXE = $PortableExe
$env:FT2_DLL = $TempDll
$env:FT2_DB  = "$RepoRoot\tests\fixtures\FingerText2_seed.db3"
$env:FT2_FTD = "$RepoRoot\tests\fixtures\test_pack.ftd"

Write-Host "`nRunning functional tests..."
Write-Host "  NPP_EXE = $env:NPP_EXE"
Write-Host "  FT2_DLL = $env:FT2_DLL"
Write-Host ""

Set-Location $RepoRoot
python tests/functional.py
$exit = $LASTEXITCODE

# ── Cleanup ───────────────────────────────────────────────────────────────────

Get-Process notepad++ -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        if ($_.MainModule.FileName -like "*AppData*Temp*") { $_.Kill() }
    } catch { }
}

exit $exit
