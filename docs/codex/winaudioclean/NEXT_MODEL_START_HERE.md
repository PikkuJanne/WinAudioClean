# Next model: WAC-M1-06

**M1-05 is complete. Start only WAC-M1-06: readable, structured, privacy-aware
run reports.** Read AGENTS.md, STATUS.md, DECISIONS.md, TASKS.yaml,
SYNC_PROTOCOL.md, tasks/WAC-M1-06.md, DATA_FORMATS.md, NATIVE_PROCESS_CONTRACT.md
and evidence/WAC-M1-05.md. Preserve earlier evidence.

## Inspect and synchronize

Use the established WinAudioClean-governance checkout on
`codex/wac-m1-reliability`. Preserve the source-only starting folder. Exact
fetch/push origin: https://github.com/PikkuJanne/WinAudioClean.git.
M1-05 started at `afbf25aa8f935517a2a14b0f5fa655cb8a8c6e7e`; derive its completion
SHA from the live branch/PR, not the starting SHA.

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
git fetch --prune origin
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
gh pr view 2 --repo PikkuJanne/WinAudioClean --json url,isDraft,state,baseRefName,headRefName,headRefOid,statusCheckRollup
```

Only M1-06 should be ready. Reuse draft PR #2, stacked on `codex/wac-m0-handoff`
while draft PR #1 is unmerged. Recheck live base/CI. Feature commits/pushes and
draft PR updates are authorized; merges/releases/deployment require exact approval.

## Narrow next task

- Keep a human summary and add versioned per-run JSON with status, tool versions,
  selected stream, settings, exact effective filters, recording duration,
  processing elapsed time, output format and metrics availability/reasons.
- Retain native diagnostics and unique job IDs. Preserve primary processing
  failures and published audio when report writes fail. Concurrent reports must
  not overwrite or interleave incorrectly. Keep existing report-alias protection.
- Provide an explicit redacted diagnostic export removing paths, filenames,
  metadata and sensitive diagnostic text. Raw logs remain local; never upload
  automatically. Cover AC-028/029/030 with success/encoder/validation failures,
  null/nonfinite metrics, concurrent runs and injected logging failures.
- Preserve exact filters/format policy, transaction guarantees, entry points and
  PS5.1. No new sound tuning, broad CLI/queue work or publication.

## Current seams and invariants

Main script and required `WinAudioClean.IO.ps1` import without running the app;
native declarations compile lazily. Copy both into sandboxes/distribution.

`Get-WacOutputPolicy` builds fixed 48 kHz PCM16/24, standard mono/stereo, optional
mono prechain and explicit RF64 policy. CLI `-BitDepth 16|24`, `-Mono`, `-Rf64`;
invalid bits/layouts use code 2. `FilterPrefix` is empty except requested stereo
mono (`pan=mono|c0=0.5*c0+0.5*c1,`). Exact Original Raw/Zoom profiles are unchanged.
Reports must record prefix plus profile, actual verified output and requested
format. Source metadata/chapters are omitted from exports. Batch launcher uses
defaults; advanced export settings use PowerShell.

`Get-WacOutputSpaceEstimate` uses selected-track duration + 101 ms, 1 MiB header
allowance, and the greater of 64 MiB or 10% reserve. RIFF estimates above uint32 max fail with
RF64 guidance. `Get-WacAvailableOutputBytes` calls GetDiskFreeSpaceExW using the
held destination handle's canonical path, including quota effects. Space failure
is code 5 before render. Checks do not reserve capacity against other writers.

`New-WacOutputTransaction` pins input/destination identities and owns CreateNew
`.wac-<GUID>.partial`. Bounded output probing precedes freeze; the same identity
is validated and renamed through a held handle with replacement disabled. The
validator now requires requested PCM/rate/layout/container, complete samples and
selected-track timing; RF64 ds64 supports one data chunk, no extra table, exact
64-bit sizes/frame counts. Cleanup removes only owned partials; crash leftovers
and foreign replacements survive. Never replace this with release/reopen rename.

Input remains locked through reporting. Existing report guard uses write access
without delete sharing and rejects reparse/multiple-hardlink files. PS5
Add-Content is incompatible with a read/write guard; metadata-only handles do
not prevent replacement. Current text log is shared and appended; concurrency
and per-run structure belong to M1-06. Early pre-render failures use console
messages. Existing report DURATION is elapsed render time; selected recording
duration is available separately. No measured LUFS/true-peak values exist yet.

Exits: 0 validated/published/report complete; 2 preflight/settings/selection;
3 dependency/start; 4 probe/native/capture/cleanup; 5 output/space/validation/
publication/owned cleanup; 7 published audio with incomplete report; 130 menu
cancel. Preserve prior failures and native diagnostics when reporting fails.

## Tests and tools

Final Full: 487 Pester per shell, zero failures/skips; 61 Python passed plus one
symlink-privilege skip per shell, runner exits 0. Parser: 23 files; 98 non-gating
analyzer advisories. Encoding 48, Validation 70 and entry subset 16 pass per shell.
Real encoding 40/40; transaction regression 30/30 (32 app invocations), stable
runtime hashes. Full/source/evidence identities are recorded in the manifest.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Reporting.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

Use fresh shells. Pinned modules are in ignored `.wac-local/Modules`. Python
wrappers omit inherited PSMODULEPATH per child so PS5 initializes its defaults;
keep the established transient runner flags. Do not alter persistent security
settings. Preserve earlier M1-02 policy/resumption history. PS5 New-Item Junction
treats bracketed target text as a wildcard; test setup uses an ordinary target.

Existing FFmpeg 9.0.2:
`.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin`.
`scripts/Test-OutputEncoding.py` covers format/channels/timing/small RF64;
`scripts/Test-OutputTransactions.py` retains publication/failure/compressed-input
checks; `scripts/Test-MediaPreflight.py` retains track/network policy. All use
installed tools, synthetic local media and ignored output; no runtime Python.

Raw's approximately 25 ms marker delay is measured in both the original 192 kHz
render and new 48 kHz output; residual change is under 0.009 ms. Preserve and report
this behavior. No speech listening, full >4 GB, real disk exhaustion, long-file/
memory stress or running-render Ctrl+C claim. Native capture remains in memory.

After M1-06, reconcile acceptance/evidence/status/handoff, stage/review intended
files, commit/push, verify local/live/PR heads, and stop before M1-07.

Delivery note: the main script and README retain their tracked CRLF line endings.
Main bytes equal the Full/real-tested source after newline normalization. Final
Quick passed 300/300 in both shells on delivery bytes; the source manifest retains
Full and delivery hashes separately. No logic changed after the Full gate.
