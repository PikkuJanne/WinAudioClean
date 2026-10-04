# WAC-M0-02 - minimal test seams and local runners

Status: PASS. AC-004, AC-005 and AC-006 passed with the limits below.

Starting checkpoint: `d88c4fdcb2ccab445fe8b96636e42cf154138950` on
`codex/wac-m0-handoff`. At session start, the clean checkout, upstream, live
GitHub branch and open draft PR #1 matched this commit. Origin fetch and push
both resolve to `https://github.com/PikkuJanne/WinAudioClean.git`. Fetch succeeded.
The original source-only directory is unchanged; this task continues in the
separate Git checkout created for WAC-M0-01.

## Scope

`WinAudioClean.ps1` exposes three small helpers for filter selection, output
naming and command construction. Dot-sourcing returns before configuration,
console output, input, process launch or logging. Direct invocation still runs
the original workflow. The `.bat` launcher is unchanged. There is no new runtime
file or module dependency.

Pester and PSScriptAnalyzer are development-only dependencies, installed by an
explicit setup command. The local runners provide Quick, Targeted and Full
checks. Known fallback, naming-collision and overwrite behavior is labeled as
legacy characterization for later reliability tasks.

## Environment and source identity

Windows NT 10.0.26300.0; PowerShell 7.6.5; Windows PowerShell 5.1.26100.9444;
Python 3.14.6; Git 2.56.0.windows.1; GitHub CLI 2.97.0.
FFmpeg and ffprobe are absent from PATH. This task does not establish audio
processing or listening acceptance.

Pester 5.7.1 and PSScriptAnalyzer 1.24.0 were explicitly downloaded from the
official PowerShell Gallery and verified against the committed SHA512 pins.
`scripts/DevDependencies.psd1` records versions, hashes and source URLs.
`WAC-M0-02-source.json` records SHA256 identities for all tested product,
runner and test files. Original product CRLF bytes are retained.

## Commands and results

Commands ran from the repository root unless stated otherwise. Setup ran in
PS7; reuse of the installed modules also passed in PS5.1. Windows PowerShell
requires the process-only execution-policy flag on this machine, as used by
the original launcher. No persistent execution-policy change was made.

```powershell
pwsh -NoProfile -File scripts/Install-DevDependencies.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Install-DevDependencies.ps1
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Quick
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Tag EntryPoint
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

| Check | Exit | Result |
| --- | --- | --- |
| Explicit setup and PS5.1 reuse | 0 | Pinned modules available; original downloads verified. |
| Quick, PS7 and PS5.1 | 0 | 11 Pester passed in each shell. |
| Targeted, EntryPoint | 0 | 8 passed, 19 outside selected scope. |
| Full, PS7 | 0 | 27 Pester passed; 53 governance passed, 1 skipped. |
| Full, PS5.1 | 0 | Same counts. |

Logs: `WAC-M0-02-targeted.txt`, `WAC-M0-02-full-ps7.txt` and
`WAC-M0-02-full-ps51.txt`. The governance skip is the existing symlink test:
this session lacks Windows symlink privileges. Neither shell was skipped.
Parser/analyzer gates passed for all 11 maintained PowerShell files. Plan
validation retained all 30 tasks, 90 cases and 20 improvement groups.

### AC-004 - compatibility entry points

Four actual `-File WinAudioClean.ps1 -inputPath ...` subprocesses cover choices
1/2 in PS5.1/PS7. Four actual `.bat` subprocesses cover the same outer shells
and choices. Controlled stdin supplies the choice; a missing synthetic input
with spaces reaches the original preflight error. Tests assert the menu,
forwarded path, error and absence of processing/scratch writes. Every child
has a deadline and redirected streams.

The unchanged `.bat` always starts Windows PowerShell internally, including
when launched from PS7. Missing-input exit status is a known legacy issue,
not an assertion of successful processing.

Eight additional subprocess runs mock process launch, filesystem reads and log
writes. Both modes and native exit codes 0/7 run under both shells. They assert
the exact FFmpeg arguments, mode/filter log and SUCCESS/FAILED feedback without
launching FFmpeg or writing to Music. This establishes workflow wiring, not
encoded output correctness.

### AC-005 - import safety

A fresh current-shell subprocess dot-sources the real script, with prompt,
console, process, FFmpeg and file-write commands trapped. Import emits no
stream output, invokes no trapped command and creates no scratch file. A
completion sentinel proves import did not exit the host; all three helpers
are then available. The Full runs establish this separately in PS5.1 and PS7.

### AC-006 - checks detect a real defect

An isolated detached worktree started from the recorded checkpoint. Exact final
product/scripts/tests were copied into it; pinned modules were reused through
`-ModuleRoot`. Only that worktree's source was mutated. Each phase ran:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .wac-local/WAC-M0-02-mutation/scripts/Invoke-Tests.ps1 -Level Quick -ModuleRoot .wac-local/Modules
```

| Phase | Exit | Pester result |
| --- | --- | --- |
| Before mutation | 0 | 11 passed |
| Get-WacOutputPath suffix changed from _Cleaned_ to _Broken_ | 1 | 8 passed, 3 failed |
| Original bytes restored | 0 | 11 passed |

`WAC-M0-02-mutation.json` records before/broken/restored SHA256 hashes.
`WAC-M0-02-mutation-before.txt`, `-broken.txt` and `-restored.txt` hold sanitized
logs. Restored bytes matched the main source exactly. The disposable worktree
was removed after verifying its absolute path. Independent output-name
expectations detected the defect; no analyzer suppression was involved.

Runner negative checks also exited 1 for Targeted without a filter, a missing
module root, and `-Level Targeted -Tag NoSuchWacTag`. Missing dependencies do not
trigger installation; empty selections cannot appear green.

## Static findings and stabilization

All default analyzer rules run. Every Error, compatible-syntax finding and
listed safety finding gates. There are no rule exclusions or suppression
attributes. Both final Full runs report 48 advisories; the PS7 log prints them.
They concern legacy console output/trailing spaces, the plural argument helper
name, Pester scope assignments, and test doubles replacing commands or using
only some parameters. The new `scripts/` files have zero findings. This initial
gate does not claim all advisory findings are fixed.

Review corrected missing-shell skip evaluation and a README tag mismatch, and
made compatible syntax gate at every severity before the final Full runs.
No product regression or task blocker remains. Runtime files keep original
CRLF; `git -c core.whitespace=cr-at-eol diff --check` checks whitespace without
treating every retained CR as a defect.

## Audio and remaining work

Raw/Zoom strings and order match `BASELINE.json` exactly. FFmpeg arguments and
encoding behavior remain unchanged; the launcher and product README are
unchanged. No real FFmpeg/ffprobe, listening, audio-quality or large-file
acceptance is claimed. FFmpeg availability and the listening-corpus checklist
belong to WAC-M0-03. Known validation, collision/overwrite and process-status
issues remain scheduled for M1; characterization names/comments identify them.

## Delivery

This commit's exact SHA and live synchronization result belong in the PR/final
response after pushing. The preceding verified checkpoint is recorded above.
Next task after accepted, synchronized delivery: **WAC-M0-03**.
