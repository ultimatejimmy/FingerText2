<#
.SYNOPSIS
    Prepare a pull request against notepad-plus-plus/nppPluginList for FingerText2.

.DESCRIPTION
    Fetches the latest stable GitHub release, downloads both ZIPs, computes SHA-256,
    and generates the JSON entries for pl.x86.json and pl.x64.json.
    With -OpenPR it clones a fork, inserts the entries alphabetically, runs
    validator.py, and pushes a branch ready for a PR.

.PARAMETER OpenPR
    If set, clone a fork of nppPluginList (or use an existing one), insert the
    entries, run validator.py, commit, push, and print the PR URL.

.PARAMETER ForkOwner
    GitHub username owning the nppPluginList fork. Defaults to 'ultimatejimmy'.

.PARAMETER Repo
    The main plugin repo slug (owner/name). Defaults to 'ultimatejimmy/FingerText2'.
#>
param(
    [switch]$OpenPR,
    [string]$ForkOwner = 'ultimatejimmy',
    [string]$Repo = 'ultimatejimmy/FingerText2'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Fetch latest stable release via gh CLI ────────────────────────────────────
Write-Host "Fetching latest stable release from $Repo..."
$releaseJson = gh release view --repo $Repo --json tagName,assets,isPrerelease 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "gh release view failed. Make sure you are authenticated: gh auth login"
    exit 1
}
$release = $releaseJson | ConvertFrom-Json

if ($release.isPrerelease) {
    Write-Error "Latest release ($($release.tagName)) is a pre-release. Publish a stable release first."
    exit 1
}

$version = $release.tagName -replace '^v', ''
Write-Host "Release: $($release.tagName)  (version $version)"

# ── Find ZIPs ─────────────────────────────────────────────────────────────────
$zip32 = $release.assets | Where-Object { $_.name -like "*_32bit.zip" } | Select-Object -First 1
$zip64 = $release.assets | Where-Object { $_.name -like "*_64bit.zip" } | Select-Object -First 1

if (-not $zip32) { Write-Error "No _32bit.zip asset found in release $($release.tagName)"; exit 1 }
if (-not $zip64) { Write-Error "No _64bit.zip asset found in release $($release.tagName)"; exit 1 }

# ── Download ZIPs ─────────────────────────────────────────────────────────────
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "ft2_pr_$version"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$local32 = Join-Path $tmpDir $zip32.name
$local64 = Join-Path $tmpDir $zip64.name

Write-Host "Downloading $($zip32.name)..."
Invoke-WebRequest -Uri $zip32.url -OutFile $local32
Write-Host "Downloading $($zip64.name)..."
Invoke-WebRequest -Uri $zip64.url -OutFile $local64

# ── Compute SHA-256 ───────────────────────────────────────────────────────────
$hash32 = (Get-FileHash -Path $local32 -Algorithm SHA256).Hash.ToLower()
$hash64 = (Get-FileHash -Path $local64 -Algorithm SHA256).Hash.ToLower()

Write-Host ""
Write-Host "32-bit ZIP: $($zip32.name)"
Write-Host "  URL:  $($zip32.url)"
Write-Host "  SHA256: $hash32"
Write-Host ""
Write-Host "64-bit ZIP: $($zip64.name)"
Write-Host "  URL:  $($zip64.url)"
Write-Host "  SHA256: $hash64"
Write-Host ""

# ── Build JSON entries ────────────────────────────────────────────────────────
$description = "Tab-triggered snippet plugin with hotspot navigation, dynamic hotspots, and a snippet dock."
$homepage    = "https://github.com/$Repo"

$entry32 = [ordered]@{
    'folder-name'  = 'FingerText2'
    'display-name' = 'FingerText2'
    'version'      = $version
    'id'           = $hash32
    'repository'   = $zip32.url
    'description'  = $description
    'author'       = 'Jimmy Pautz'
    'homepage'     = $homepage
}

$entry64 = [ordered]@{
    'folder-name'  = 'FingerText2'
    'display-name' = 'FingerText2'
    'version'      = $version
    'id'           = $hash64
    'repository'   = $zip64.url
    'description'  = $description
    'author'       = 'Jimmy Pautz'
    'homepage'     = $homepage
}

$json32 = $entry32 | ConvertTo-Json
$json64 = $entry64 | ConvertTo-Json

$snippet32Path = Join-Path $tmpDir "entry_x86.json"
$snippet64Path = Join-Path $tmpDir "entry_x64.json"
$json32 | Set-Content $snippet32Path
$json64 | Set-Content $snippet64Path

Write-Host "JSON entries written to:"
Write-Host "  $snippet32Path"
Write-Host "  $snippet64Path"
Write-Host ""

if (-not $OpenPR) {
    Write-Host "Done. To insert these entries into nppPluginList and open a PR, re-run with -OpenPR."
    exit 0
}

# ── Clone / update fork ───────────────────────────────────────────────────────
$forkRepo   = "$ForkOwner/nppPluginList"
$forkDir    = Join-Path $tmpDir "nppPluginList"
$branchName = "add-fingertext2-$version"

Write-Host "Cloning fork $forkRepo..."
git clone "https://github.com/$forkRepo.git" $forkDir
Set-Location $forkDir

git remote add upstream "https://github.com/notepad-plus-plus/nppPluginList.git"
git fetch upstream
git checkout -b $branchName upstream/master

# ── Insert entry alphabetically ───────────────────────────────────────────────
function Insert-EntryAlphabetically {
    param([string]$JsonFile, [hashtable]$Entry)

    $content  = Get-Content $JsonFile -Raw
    $plugins  = $content | ConvertFrom-Json
    $newEntry = [PSCustomObject]$Entry

    # Remove existing entry if present
    $plugins = $plugins | Where-Object { $_.'folder-name' -ne 'FingerText2' }

    # Append and sort
    $plugins = @($plugins) + $newEntry
    $sorted  = $plugins | Sort-Object { $_.'display-name'.ToLower() }

    $sorted | ConvertTo-Json -Depth 5 | Set-Content $JsonFile
}

Write-Host "Inserting x86 entry..."
Insert-EntryAlphabetically -JsonFile "src/pl.x86.json" -Entry $entry32

Write-Host "Inserting x64 entry..."
Insert-EntryAlphabetically -JsonFile "src/pl.x64.json" -Entry $entry64

# ── Run validator ─────────────────────────────────────────────────────────────
Write-Host "Running validator.py..."
python validator.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "validator.py failed. Fix the schema error before submitting the PR."
    exit 1
}
Write-Host "  Validator passed." -ForegroundColor Green

# ── Commit and push ───────────────────────────────────────────────────────────
git add "src/pl.x86.json" "src/pl.x64.json"
git commit -m "Add FingerText2 $version"
git push origin $branchName

Write-Host ""
Write-Host "Branch '$branchName' pushed to https://github.com/$forkRepo"
Write-Host "Open a PR at: https://github.com/notepad-plus-plus/nppPluginList/compare/master...${ForkOwner}:${branchName}"
Write-Host ""
Write-Host "Suggested PR title: Add FingerText2 plugin"
Write-Host "Suggested PR body:"
Write-Host "  - Adds FingerText2 $version (32-bit and 64-bit)"
Write-Host "  - Homepage: $homepage"
Write-Host "  - Release: https://github.com/$Repo/releases/tag/$version"
Write-Host "  - Automated tests pass (link to green workflow run)"
