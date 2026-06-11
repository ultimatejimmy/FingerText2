# Building & Releasing FingerText2

This is the single source of truth for building, testing, and shipping FingerText2. It orchestrates the existing scripts and GitHub Actions workflows — read it before cutting a release.

## Prerequisites

- **To build locally:** Visual Studio 2022 Build Tools with the **Desktop development with C++** workload (provides MSBuild + toolset v143 + Windows 10 SDK).
- **To run tests locally:** Python 3 with `pywinauto` (`python -m pip install pywinauto`).
- **To submit to nppPluginList:** the GitHub CLI `gh`, authenticated (`gh auth login`).
- If you do not have Visual Studio, you **cannot** compile locally — verify builds through CI instead (see "Build via CI").

## Version is defined in one place

All version numbers live in [`Config/Version.h`](Config/Version.h): `VERSION_TEXT`, `VERSION_NUM`, `VERSION_LINEAR`, plus `DATE_TEXT` and `COPYRIGHT_TEXT`. Do not hand-edit these unless you must — `scripts/release.py` rewrites them all consistently (see "Cut a release"). `VERSION_LINEAR = year*10000000 + month*100000 + day*1000 + revision*10 + (1 if -beta else 0)`.

## Build locally

```
build.bat
```

Builds both architectures. Outputs:
- 32-bit: `Unicode Release\FingerText2.dll`
- 64-bit: `x64\Unicode Release\FingerText2.dll`

To install a build for manual testing, copy the DLL to `<Notepad++>\plugins\FingerText2\FingerText2.dll` and restart Notepad++.

## Build via CI (without cutting a release)

Pushing to **any branch** triggers the **Test** workflow (`.github/workflows/test.yml`), which builds both architectures and runs smoke tests. A tag is the ONLY thing that creates a release, so a normal branch/`master` push is build-only.

To get the compiled DLLs without Visual Studio:
1. Push your commit.
2. Find the run and confirm it passed:
   ```
   gh run list --repo ultimatejimmy/FingerText2 --branch master --limit 1
   gh run watch <RUN_ID> --repo ultimatejimmy/FingerText2 --exit-status
   ```
3. Download the artifacts (`dll-Win32`, `dll-x64`):
   ```
   gh run download <RUN_ID> --repo ultimatejimmy/FingerText2
   ```

This is the required verification loop for anyone who cannot compile locally: **never tell the user a build "works" until the Test workflow is green.**

## Tests

- **Tier 1 — smoke** (`tests/smoke.py`): plugin loads, no exception dialog, clean exit. Runs in CI on every push. Env: `NPP_EXE`, `FT2_DLL`, optional `FT2_DB`.
- **Tier 2 — functional** (`tests/functional.py`): open-in-editor, tab expansion, .ftd import, DB migration. Env: `NPP_EXE`, `FT2_DLL`, `FT2_DB`, `FT2_FTD`.
- **Tier 3 — manual** (`tests/MANUAL_TESTING.md`): human QA checklist; run before publishing a release.

## Cut a release

A release is produced by pushing a tag matching `[0-9]*`. Use the helper so the version is bumped consistently:

```
python scripts/release.py 26.5.27          # or 26.5.27-beta for a prerelease
python scripts/release.py 26.5.27 --dry-run # preview without changing anything
```

The script requires a clean working tree (untracked files are OK) and a tag that does not already exist. It rewrites `Config/Version.h`, commits as `Release <version>`, creates an annotated tag, and pushes `master` plus the tag in one go.

The tag triggers the **Release** workflow (`.github/workflows/release.yml`), which:
1. Builds Win32 + x64,
2. packages `FingerText2_<version>_32bit.zip` and `_64bit.zip` (DLL at the zip root, round-trip verified),
3. creates a **draft** GitHub Release (marked prerelease if the tag ends in `-beta`).

Then, by hand: run the Tier 3 manual checklist, edit the release notes, and **publish** the draft.

## Submit to nppPluginList (after publishing a stable release)

Only after a **stable** (non-prerelease) release is published:

```
python scripts/prepare-plugin-list-pr.py                 # dry preview: downloads zips, prints SHA-256 + JSON
python scripts/prepare-plugin-list-pr.py --open-pr --validate
```

`--open-pr` clones your `nppPluginList` fork (default owner `ultimatejimmy`, override with `--fork-owner`), inserts the entry into `pl.x86.json`/`pl.x64.json` in alphabetical order, optionally runs `validator.py` (`--validate`), commits, and force-with-lease pushes a branch. It then prints the compare URL and a suggested PR title/body. Open the PR from that URL. The script fails fast if the latest release is a prerelease.

## Gotchas (lessons learned)

- **In headers, use `sptr_t`/`uptr_t`, never `intptr_t`.** `Scintilla.h` does not include `<stdint.h>`, so `intptr_t` is undefined there and breaks the build (`C3646`/`C4430`). `sptr_t` (= `LONG_PTR`) is signed and pointer-sized — use it for Scintilla position/length fields. `intptr_t` is only safe inside `.cpp` files.
- **Release = tag push. Branch push = build only.** Don't push a tag unless you intend to release.
- **No local Visual Studio = verify via CI.** A commit is not "building" until the Test workflow is green.
