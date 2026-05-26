<#
.SYNOPSIS
    Cut a FingerText2 release with date-based versioning.

.PARAMETER Version
    Version string in YY.M.D, YY.M.D.N, YY.M.D-beta, or YY.M.D.N-beta format.
    Example: 26.5.26  or  26.5.26.1  or  26.5.26-beta

.PARAMETER DryRun
    Print planned edits without committing, tagging, or pushing.
#>
param(
    [string]$Version,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Resolve repo root ─────────────────────────────────────────────────────────
$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

# ── Prompt if not supplied ────────────────────────────────────────────────────
if (-not $Version) {
    $Version = Read-Host 'Enter version (e.g. 26.5.26 or 26.5.26-beta)'
}
$Version = $Version.Trim()

# ── Validate version format ───────────────────────────────────────────────────
if ($Version -notmatch '^\d+\.\d+\.\d+(\.\d+)?(-beta)?$') {
    Write-Error "Invalid version '$Version'. Expected YY.M.D, YY.M.D.N, YY.M.D-beta, or YY.M.D.N-beta."
    exit 1
}

# ── Parse components ──────────────────────────────────────────────────────────
$isBeta     = $Version.EndsWith('-beta')
$core       = $Version -replace '-beta$', ''
$parts      = $core.Split('.')
$year       = [int]$parts[0]
$month      = [int]$parts[1]
$day        = [int]$parts[2]
$revision   = if ($parts.Count -ge 4) { [int]$parts[3] } else { 0 }

$versionNum    = "$year,$month,$day,$revision"
$betaBit       = if ($isBeta) { 1 } else { 0 }
$versionLinear = $year * 10000000 + $month * 100000 + $day * 1000 + $revision * 10 + $betaBit
$tagName       = "v$Version"

# ── Guard: dirty working tree ─────────────────────────────────────────────────
$dirty = git status --porcelain | Where-Object { $_ -notmatch '^\?\?' }
if ($dirty) {
    Write-Error "Working tree is dirty. Commit or stash all changes before releasing.`n$dirty"
    exit 1
}

# ── Guard: tag must not already exist ────────────────────────────────────────
$existingTag = git tag --list $tagName
if ($existingTag) {
    Write-Error "Tag $tagName already exists locally. Use a different version."
    exit 1
}
$remoteTag = git ls-remote --tags origin $tagName 2>$null
if ($LASTEXITCODE -eq 0 -and $remoteTag) {
    Write-Error "Tag $tagName already exists on remote. Use a different version."
    exit 1
} elseif ($LASTEXITCODE -ne 0) {
    Write-Host "  (Could not reach remote to check for duplicate tag — will let git push catch it.)" -ForegroundColor DarkYellow
}

# ── Print plan ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Release plan for $Version" -ForegroundColor Cyan
Write-Host "  VERSION_TEXT    = `"$Version`""
Write-Host "  VERSION_NUM     = $versionNum"
Write-Host "  VERSION_LINEAR  = $versionLinear"
Write-Host "  VERSION_STAGE   = `"`""
Write-Host "  Tag             = $tagName"
Write-Host "  Pre-release     = $isBeta"
Write-Host ""

if ($DryRun) {
    Write-Host "[DryRun] Skipping file edits, commit, tag, and push." -ForegroundColor Yellow
    exit 0
}

# ── Rewrite Config/Version.h ──────────────────────────────────────────────────
$vhPath = Join-Path $repoRoot 'Config\Version.h'
$vh = Get-Content $vhPath -Raw

$vh = $vh -replace '#define VERSION_TEXT\s+"[^"]*"',   "#define VERSION_TEXT `"$Version`""
$vh = $vh -replace '#define VERSION_NUM\s+[\d,]+',      "#define VERSION_NUM $versionNum"
$vh = $vh -replace '#define VERSION_LINEAR\s+\d+',      "#define VERSION_LINEAR $versionLinear"
$vh = $vh -replace '#define VERSION_STAGE\s+"[^"]*"',   '#define VERSION_STAGE ""'

# Refresh DATE_TEXT with current month/year
$monthNames = @('','January','February','March','April','May','June',
                'July','August','September','October','November','December')
$dateText = "$($monthNames[$month]) 20$year"
$vh = $vh -replace '#define DATE_TEXT\s+"[^"]*"', "#define DATE_TEXT `"$dateText`""

# Refresh COPYRIGHT_TEXT year
$vh = $vh -replace '#define COPYRIGHT_TEXT\s+"[^"]*"', "#define COPYRIGHT_TEXT `"Copyright (C) 20$year`""

Set-Content $vhPath $vh -NoNewline

Write-Host "Updated Config/Version.h" -ForegroundColor Green

# ── Commit and tag ────────────────────────────────────────────────────────────
git add "Config/Version.h"
git commit -m "Release $tagName"
git tag -a $tagName -m "$tagName"

Write-Host "Created commit and tag $tagName" -ForegroundColor Green

# ── Push ─────────────────────────────────────────────────────────────────────
git push origin master
git push origin $tagName

Write-Host "Pushed master and tag $tagName to origin" -ForegroundColor Green
Write-Host ""
Write-Host "Done. The release workflow will now build both architectures and create a draft GitHub Release." -ForegroundColor Cyan
