# Windows CI and local parity

The `Windows validation` workflow runs the existing local `Invoke-Tests.ps1
-Level Full` gate on Windows Server 2022 and 2025 with Windows PowerShell 5.1
and portable PowerShell 7.6.5. It checks out the exact PR head commit (rather
than the synthetic merge commit). A push checks its own commit. Hosted Windows
labels receive servicing updates; each artifact records actual Windows, image
and shell versions. This is supplementary evidence for the supported hosts.

Each job also builds the tool-only ZIP from its exact clean source and runs
`Test-HotfixPackage.py` on extracted bytes. The explicit development-only
`Install-HotfixTestEngine.ps1` fetches the versioned Gyan 9.0.2 essentials
archive pinned in `CIDependencies.json` and verifies SHA256. The harness stages
only the trusted pair in a separate directory with spaces, brackets and Unicode.
Every positive conversion must record those exact absolute executables and
retain their hashes; the process PATH contains only Windows system directories
except for the separate process-PATH regression case.

The package gate runs actual BAT Raw/Zoom conversions and direct PowerShell
routes on both shells, plus temporary `.lnk` shell activation with an unrelated
Start in directory, positional generated input, isolated saved preferences and
automated final pause. Independent probing verifies 48 kHz stereo PCM16 and
duration; source hashes remain unchanged. Decoded PCM is compared with public
v1.0.0 using the same engine. This is synthetic audio mechanics evidence.

On the disposable hosted runner only, separate real user-scope `FFMPEG`, quoted
Unicode `Path`, and persisted-only `%FFMPEG%` expansion cases exercise stale
launcher environments. Original values are restored in `finally` and reread for
exact equality. The owner account is never used for those writes. Machine
scope and complete absence use explicitly labeled controlled sources, while
missing explicit tools, inoperable binaries and missing filters execute the
unchanged packaged runtime. Failure checks require exit 3 and no completed WAV.
No private console captures, paths, environment values, recordings or detailed
reports are uploaded; the package gate prints only its fixed summary projection.

## Explicit development setup

The audio application still has no Python/test-module dependency or downloader.
Only an explicitly invoked developer setup installs the pinned tools:

```powershell
$tools = ./scripts/Install-CIDependencies.ps1
./scripts/Install-DevDependencies.ps1
& $tools.Python -X utf8 scripts/Invoke-CIChecks.py --shell-path $tools.PowerShell --shell-family ps7 --level Full
& $tools.Python -X utf8 scripts/Invoke-CIChecks.py --shell-path "$env:SystemRoot/System32/WindowsPowerShell/v1.0/powershell.exe" --shell-family ps51 --level Full
```

Existing installed Python and the pinned PS7 may also be supplied directly.
Local Python versions are reported; Actions requires the manifest's exact pin.
The tools manifest records official download URLs, trusted SHA256 values and
full Action commit IDs. The existing development manifest pins Gallery modules
with official SHA512 values. Setup verifies each archive before extraction.
New setup directories stay ignored and are retained for inspection; there is
no global install, automatic replacement or recursive cleanup. The upstream
embeddable Python `_pth` isolation stays intact.

The wrapper runs a fresh `-NoProfile` shell and removes `PSModulePath` from
its child environment so each shell reconstructs its module directories.
The invocation's execution policy applies only to that child. CI tokens are
removed from the test environment. The local runner is unchanged. A zero exit
without the expected completed test summaries cannot produce a passed result.
The wrapper records portable content hashes before and after the gate.

## Permissions and artifacts

Ordinary `pull_request` and `push` events have only `contents: read`.
Checkout does not persist credentials. There are no secret references, caches,
release/deployment jobs or privileged PR triggers. Fork PR code runs with no
repository secrets and may need GitHub's existing contributor approval.
The workflow does not change repository settings or permissions.

Only `artifacts/local/ci/<shell>.json` is uploaded, with seven-day retention.
Its fixed projection includes versions, source hashes and numeric test counts.
Failed gates also expose a fixed phase/category, bounded Pester totals and up
to 32 checked-in source filenames with validated line numbers. Source names
come from Git's maintained ASCII code inventory, not diagnostic text; external
paths and out-of-range lines are rejected. No audio filenames, personal paths,
environment contents, assertion messages or expanded test values are exported.
Locations may also appear in deliberately handled fixture errors. They and the
heuristic categories aid investigation; the completed test counts determine
failure scope.
Raw test output remains in ignored `.wac-local/ci/logs/` and is not uploaded.
Artifacts and GitHub console logs should be treated as publicly shareable
repository evidence. A setup failure may have no result artifact; it remains
a failed job, never an inferred pass.

## Read actual CI evidence

```powershell
python -X utf8 scripts/Get-CIStatus.py --commit <full-lowercase-40-hex-SHA>
python -X utf8 scripts/Get-CIStatus.py --commit <full-lowercase-40-hex-SHA> --event push
```

The reader uses read-only GitHub CLI/API operations, validates workflow name,
ID and path, then requires all four jobs at the exact SHA to finish successfully.
It works before the workflow is merged to the default branch. States and exit
codes are: passed 0, failed 1, pending 2, not_run 3, api_error 4, unavailable 5.
A newer pending run supersedes an earlier success. Skipped, absent or empty
jobs cannot pass. An API outage or unavailable shell is distinct from a local
test pass. Local and GitHub results are recorded separately.

CI exposed a .NET Framework stdin preamble defect. Native startup now selects
BOM-free UTF-8 through the child-specific property where available. On PS5.1,
the UTF-8-with-BOM case temporarily selects BOM-free UTF-8 with the same code
page only for process startup, then restores the caller's input encoding,
including on startup failure. The Console setter refreshes its cached input
reader in that case. Existing native calls are sequential; this does not change
the output encoding or the machine's console code page. Owned fresh-process
tests compare exact raw byte lengths/hashes, including an intended leading BOM.

Full uses synthetic native fixtures and the governance suite. The additional
package gate covers the real-tool launch routes above. Other standalone
real-FFmpeg matrices, formal speech listening, actual desktop gestures, broad
storage/host-crash tests and privilege skips retain their documented scopes.
