# Rehearse a clean release candidate locally

This is a developer checklist for a temporary checkout on the active Windows
machine. It uses the existing setup, tests, builder and package inspector; it is
not an application dependency or a packaged payload file. A successful rehearsal
does not publish a release, website or tag. Keep all downloads, candidate ZIPs,
synthetic fixtures and raw logs local and ignored. Export only reviewed source
identities, hashes, versions, fixed case codes and test counts as evidence.

Read [development prerequisites](../../../tests/README.md), [pinned setup and
local parity](CI.md) and [portable package verification](../../PORTABLE_PACKAGE.md)
first. These checks
need Git, Windows PowerShell 5.1, development Python, Pester and PSScriptAnalyzer.
Native test fixtures also use the installed Windows .NET Framework `csc.exe`.
The explicit setup supplies pinned Python 3.14.6, PowerShell 7.6.5, Pester 5.7.1
and PSScriptAnalyzer 1.24.0 into ignored checkout-local directories. FFmpeg is
supplied separately for actual processing; building and inspecting a candidate
does not require it. Never copy private audio or ordinary user reports into this
rehearsal.

The scope is a fresh source checkout and fresh checkout-local developer downloads
on this same Windows machine. Git, built-in PS5.1, installed Framework `csc.exe`
and the normal OS are existing documented prerequisites. An application smoke
check additionally uses separately verified user-supplied FFmpeg/ffprobe; neither
is bundled. This is not a clean Windows reinstall, another-machine check,
general portability guarantee or published candidate.

## Recover an exact pushed source

Replace the revision placeholder with the user-chosen, live-verified full
lowercase forty-character commit. Choose a new short folder. Do not reset, clean,
stash or change the maintained checkout or the source-only original.

```powershell
$wacRevision = '<approved-full-lowercase-40-character-commit>'
$wacClone = 'C:\projects\wac-m5-02-a'
if ($wacRevision -cnotmatch '^[0-9a-f]{40}$') { throw 'Supply the exact approved commit.' }
if (Test-Path -LiteralPath $wacClone) { throw 'Choose a new clone folder.' }
git clone --no-checkout 'https://github.com/PikkuJanne/WinAudioClean.git' $wacClone
if ($LASTEXITCODE -ne 0) { throw 'Clone failed.' }
git -C $wacClone fetch --prune origin
if ($LASTEXITCODE -ne 0) { throw 'Fetch failed.' }
git -C $wacClone checkout --detach $wacRevision
if ($LASTEXITCODE -ne 0) { throw 'Exact detached checkout failed.' }
if ((git -C $wacClone rev-parse HEAD) -cne $wacRevision) { throw 'Revision mismatch.' }
if ((git -C $wacClone status --porcelain=v1 --untracked-files=all)) { throw 'Checkout is not clean.' }
Set-Location -LiteralPath $wacClone
git remote -v
git rev-parse HEAD
git rev-parse 'HEAD^{tree}'
```

Verify the effective fetch/push origin is the exact repository and compare the
chosen commit with the live feature branch before accepting recovery. Record
commit/tree and clean status. A cached tracking ref is not live delivery proof.
Authentication or network failure remains a failed/unavailable reconstruction;
do not substitute the maintained checkout's uncommitted files.

## Run explicit setup and the focused checks

Run setup in the new clone, using a fresh process. Downloads occur only through
these explicitly invoked developer scripts. Their committed manifests verify
SHA256 for portable tools and SHA512 for Gallery modules before extraction.
No global/user installation, profile or persistent execution-policy change is
needed. A fresh clone starts without module caches; preserve setup failures and
do not call an unchecked copied module directory a fresh installation.

```powershell
$wacPs51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$wacCapture = Join-Path $wacClone '.wac-local/reconstruction'
if (Test-Path -LiteralPath $wacCapture) { throw 'Choose a new capture folder.' }
$null = New-Item -ItemType Directory -Path $wacCapture
$wacSetupPath = Join-Path $wacCapture 'setup-tools.ps1'
if (Test-Path -LiteralPath $wacSetupPath) { throw 'Setup helper already exists.' }
$wacSetup = @'
$ErrorActionPreference = 'Stop'
$wacCheckout = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$wacToolJson = Join-Path $PSScriptRoot 'tools.json'
if (Test-Path -LiteralPath $wacToolJson) { throw 'Tool-path record already exists.' }
Set-Location -LiteralPath $wacCheckout
$wacInstalled = & (Join-Path $wacCheckout 'scripts/Install-CIDependencies.ps1')
$wacJson = $wacInstalled | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText($wacToolJson, $wacJson, [Text.UTF8Encoding]::new($false))
'@
[IO.File]::WriteAllText($wacSetupPath, $wacSetup, [Text.UTF8Encoding]::new($false))
& $wacPs51 -NoProfile -ExecutionPolicy Bypass -File $wacSetupPath
if ($LASTEXITCODE -ne 0) { throw 'Portable tool setup failed.' }
$wacTools = Get-Content -Raw -LiteralPath (Join-Path $wacCapture 'tools.json') | ConvertFrom-Json
& $wacPs51 -NoProfile -ExecutionPolicy Bypass -File scripts/Install-DevDependencies.ps1
if ($LASTEXITCODE -ne 0) { throw 'Module setup failed.' }
```

The setup helper and returned tool paths stay in the new ignored capture folder.
The process-only policy does not override an enforced organization restriction;
follow that policy without changing machine-wide restrictions. Existing installed Python/pinned PS7
and an explicit `-ModuleRoot` are documented alternatives, but record that cache
reuse separately from a fresh setup, with origin, versions and integrity checks.

Use the fresh pinned Python and checkout-local modules for the selected Release
Pester tests on both hosts. This small launcher clears inherited `PSModulePath`
only in each child, so a PS7 parent cannot hide PS5.1's built-in modules.

```powershell
$wacSelected = @'
import os, subprocess, sys
child = os.environ.copy()
child.pop("PSModulePath", None)
command = [sys.argv[1], "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
           "scripts/Invoke-Tests.ps1", "-Level", "Targeted", "-Path",
           "tests/WinAudioClean.Release.Tests.ps1", "-PythonPath", sys.executable]
raise SystemExit(subprocess.call(command, env=child))
'@
$wacSelectedPath = Join-Path $wacCapture 'run-release.py'
if (Test-Path -LiteralPath $wacSelectedPath) { throw 'Release helper already exists.' }
[IO.File]::WriteAllText($wacSelectedPath, $wacSelected, [Text.UTF8Encoding]::new($false))
& $wacTools.Python -B -X utf8 $wacSelectedPath $wacPs51 2>&1 |
    Tee-Object -FilePath (Join-Path $wacCapture 'release-ps51.log')
if ($LASTEXITCODE -ne 0) { throw 'PS5.1 Release checks failed.' }
& $wacTools.Python -B -X utf8 $wacSelectedPath $wacTools.PowerShell 2>&1 |
    Tee-Object -FilePath (Join-Path $wacCapture 'release-ps7.log')
if ($LASTEXITCODE -ne 0) { throw 'PS7 Release checks failed.' }
& $wacTools.Python -B -X utf8 -m unittest discover -s docs/codex/winaudioclean/tests -p test_release_package.py -v
if ($LASTEXITCODE -ne 0) { throw 'Package inspector regressions failed.' }
```

Capture actual commands, exits, versions, counts and skips; an unrun or skipped
case is not a pass. Stabilize failures before building. For the required
cumulative gate, use the unchanged wrapper on both hosts after focused checks
are stable and retain each sanitized parity JSON before the next invocation:

```powershell
& $wacTools.Python -B -X utf8 scripts/Invoke-CIChecks.py --shell-path $wacPs51 --shell-family ps51 --level Full
if ($LASTEXITCODE -ne 0) { throw 'PS5.1 Full gate failed.' }
& $wacTools.Python -B -X utf8 scripts/Invoke-CIChecks.py --shell-path $wacTools.PowerShell --shell-family ps7 --level Full
if ($LASTEXITCODE -ne 0) { throw 'PS7 Full gate failed.' }
```

## Build four new candidates and inspect the actual bytes

The builder requires clean exact HEAD and reads committed Git blobs, preserving
their bytes regardless of checkout line endings. It never replaces an artifact.
Build twice per host into four new ignored destinations. Record clean HEAD/tree
and maintained source hashes before and after the rehearsal.

```powershell
$wacBuilds = @()
foreach ($wacShell in @(@{name='ps51'; path=$wacPs51}, @{name='ps7'; path=$wacTools.PowerShell})) {
    foreach ($wacPass in 1, 2) {
        $wacOutput = Join-Path $wacClone ('dist/reconstruction/' + $wacShell.name + '-' + $wacPass)
        if (Test-Path -LiteralPath $wacOutput) { throw 'Choose new build destinations.' }
        & $wacShell.path -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Release.ps1 -Revision $wacRevision -OutputDirectory $wacOutput
        if ($LASTEXITCODE -ne 0) { throw 'Candidate build failed.' }
        $wacBuilds += $wacOutput
    }
}
$wacName = (Get-ChildItem -LiteralPath $wacBuilds[0] -File -Filter 'WinAudioClean-*-tool-only.zip' | Select-Object -ExpandProperty Name)
if (@($wacName).Count -ne 1) { throw 'Expected exactly one archive.' }
$wacArchives = @($wacBuilds | ForEach-Object { Get-Item -LiteralPath (Join-Path $_ $wacName) })
$wacFacts = @($wacArchives | ForEach-Object {
    [pscustomobject]@{bytes=$_.Length; sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()}
})
if ($wacFacts.Count -ne 4 -or @($wacFacts.sha256 | Select-Object -Unique).Count -ne 1 -or
    @($wacFacts.bytes | Select-Object -Unique).Count -ne 1) { throw 'Candidates differ.' }
$wacInspect = @'
import importlib.util, json, sys
from pathlib import Path
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("wac_package", Path.cwd() / "scripts/Test-ReleasePackage.py")
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)
expected, blobs = check.expected_source(sys.argv[1])
for name in sys.argv[2:]:
    _, facts = check.inspect_archive(Path(name), expected, blobs)
    print(json.dumps(facts, sort_keys=True))
'@
$wacInspectPath = Join-Path $wacCapture 'inspect-candidates.py'
if (Test-Path -LiteralPath $wacInspectPath) { throw 'Inspector helper already exists.' }
[IO.File]::WriteAllText($wacInspectPath, $wacInspect, [Text.UTF8Encoding]::new($false))
& $wacTools.Python -B -X utf8 $wacInspectPath $wacRevision @($wacArchives.FullName)
if ($LASTEXITCODE -ne 0) { throw 'Candidate identity check failed.' }
if ((git rev-parse HEAD) -cne $wacRevision -or (git status --porcelain=v1 --untracked-files=all)) {
    throw 'Source changed during reconstruction.'
}
```

The existing inspector checks each ZIP against its exact commit/tree/version,
all 17 committed payload files and generated manifest, entry layout/order,
checksums and provenance sidecar. It excludes developer modules/tools, website,
recordings, preferences and raw logs. Four equal hashes establish equality only
for the observed source and host versions, not universal reproducibility.

Candidate verification uses the independent tool-only package inspector. The
superseded standalone website, website metadata fixtures and dedicated validator
were removed on 10 October 2026. Historical browser and metadata acceptance
records remain dated evidence; they do not describe the new multi-tool website.

## Reject invalid package layouts

The focused `test_release_package.py` suite above exercises corrupt layout,
hidden data and altered payload fixtures against the maintained inspector.
Keep actual archives and matching checksum/provenance files together; follow
[portable verification](../../PORTABLE_PACKAGE.md) before extracting or running.

Review candidate inventory and tracked/staged changes before acceptance. Exact
allowlisted Git-blob equality is the package-content check; separately review
those source/doc files for confidential content, personal paths and secrets.
Keep raw setup/test output, failed fixtures, archives and extracted dependencies
ignored. Preserve failures and successful recovery as distinct evidence. Never
stage the entire checkout or export private logs merely to prove a test ran.

## Rehearse safe rollback

Rollback means selecting a verified earlier complete package or source in a
separate new folder. No published release or tag is presumed. If a trusted prior
tag exists, resolve it to its exact commit and record that identity; otherwise
use an explicitly chosen verified prior source commit. Clone and detach using
the recovery steps above with a different new folder and the prior forty-character
revision, then build/verify from that clean HEAD. For an existing prior package,
follow [checksum and provenance verification](../../PORTABLE_PACKAGE.md) before
extracting into another new short folder. Do not mix old/new component files or
overwrite the current working package.

Keep original recordings, exports, the newer tool and normal per-user settings.
Use explicit isolated `-SettingsPath` during any rehearsal invocation; use
`-IgnoreSavedSettings` when testing built-in defaults. Never use `-ResetSettings`
or `-SaveSettings` as an implicit rollback step. Older settings support is not
assumed: an unsupported settings schema should fail, not be silently migrated or
discarded. If an actual settings file needs inspection/restoration, choose it
deliberately and preserve a copy first, as described in [support guidance](../../SUPPORT.md).

For a local rollback check, keep synthetic recording/settings sentinels outside
both tool folders, hash them before and after side-by-side package selection and
a read-only isolated settings/help invocation, and record unchanged hashes.
This demonstrates that this procedure preserves those files; it does not claim
automatic migration, crash recovery or protection against unrelated user actions.
Stop after recording reconstruction/integrity/privacy evidence and the required
gates. Publication, merge, tags/releases and deployment remain separate approved
actions.
