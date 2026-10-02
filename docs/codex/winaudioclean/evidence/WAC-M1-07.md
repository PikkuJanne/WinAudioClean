# WAC-M1-07 evidence — reliability regression gate

Date: 2026-10-02. Starting synchronized checkpoint:
`ca82376ae60560541fb0985c7c565c7872e3bba4` on `codex/wac-m1-reliability`.
The runtime, launcher, test code and harnesses remain byte-for-byte unchanged
from that checkpoint. Changes are test instructions, the safety/compatibility
review, sanitized validation evidence and the next-task handoff.

## Gate results

**AC-031 and AC-032 pass. Both Full gates completed without failures.**
AC-033 is finalized by clean live synchronization and PR verification after
pushing this checkpoint; the exact delivered SHA is recorded in the PR/final
response. Do not advance before that verification succeeds.

Windows 11 / NT 10.0.26300; PS5.1.26100.9444 and PS7.6.5; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0; existing FFmpeg/ffprobe 9.0.2 essentials.
No dependencies were downloaded and no machine security settings changed.
Fresh PowerShell children omitted inherited `PSModulePath`. Python remains a
development-only tool.

| Check | Windows PowerShell 5.1 | PowerShell 7 |
| --- | --- | --- |
| Quick | 332 passed; 0 failed/skipped | 332 passed; 0 failed/skipped |
| Targeted: Transaction, RunReports, OutputSafety, Launcher | 158 passed; 0 failed/skipped | 158 passed; 0 failed/skipped |
| Full Pester | 543 passed; 0 failed/skipped | 543 passed; 0 failed/skipped |
| Full Python governance | 61 passed; 1 privilege skip | 61 passed; 1 privilege skip |

Every runner exited 0. Parser: 25 maintained PowerShell files; 112 visible
non-gating analyzer advisories. The only skip is Python
`test_symlink_rejected`: symlink creation privileges were unavailable.
One Full run per shell was sufficient; no failures required correction.

Quick intentionally leaves 211 cases outside scope; Targeted leaves 385 outside
scope. These are filters, not skipped tests. Full has no scope filter. Parser,
static safety and plan validation run at every level. Exact commands, exits,
environment, source hashes and sanitized-log hashes belong to
`WAC-M1-07-source.json`. Logs normalize newlines/trailing whitespace and omit
ANSI formatting and machine-specific paths; outcomes are preserved.

## Fresh real-media checks

- [Transaction harness](WAC-M1-07-real-transactions.json): **30/30 cases**, 32
  application invocations across PS5.1/7. MP3/AAC input, selected tracks, rapid
  repeats, equal stems, concurrency, invalid/truncated output, injected encoder
  and disk failures, rename collision and crash/recovery passed. Sources and
  prior exports remain intact; later runs preserve unrelated crash leftovers.
- [Reporting harness](WAC-M1-07-real-reports.json): **24/24 cases**, 24 render
  invocations plus four diagnostic CLI invocations. Success/native/validation
  outcomes, permission/partial-write failures, summary rollback, concurrent
  reports, redaction and no-overwrite diagnostic export passed.
- Both harnesses reported stable before/after runtime hashes matching the
  source manifest. Tool hashes and full command arrays are in their records.
  The scripts retain their originating task labels (M1-04 and M1-06); these
  are fresh M1-07 invocations, not renamed historical runs.

Synthetic audio, raw diagnostics and reports remain under ignored `.wac-local`.
Injected disk-full/permission failures use isolated application copies; they do
not claim actual volume exhaustion or recovery from arbitrary hardware failure.
Earlier M0/M1 evidence, including encoding/channel/timing measurements and the
M1-02 application-control failure/resumption history, remains unchanged.

## AC-032: safety and compatibility review

[The review](WAC-M1-07-review.md) maps every runtime write, rename and cleanup
boundary to source and fault tests. Two independent read-only reviews and the
main review found no known source/prior-export overwrite, broad cleanup,
ambiguous publication or false-success defect requiring a runtime change.

Held source/destination identities, exclusive partial/report creation,
validated no-replace rename, owned-only cleanup and serialized summary rollback
remain in place. Surviving reports are corrected after failures; successful
audio with incomplete reporting returns 7, while prior processing codes remain
primary. No protection was weakened to obtain passing tests.

Original Raw/Zoom filters, positional/`-inputPath` entry, Music default, both
script filenames and PS5.1 support remain. The launcher tests cover actual
CMD/PS5.1 forwarding, both outer shells, punctuation/Unicode, path boundaries
and pause-preserved exits. Default single-file handoff uses a controlled
application stub; no fresh Explorer interactive drag/drop render is claimed.

Intentional M1 behavior changes are reconciled in the review. Legacy README/
help audio claims remain scheduled for **WAC-M2-01**, which explicitly owns
claims correction and Original preset identity/versioning. This reliability
gate does not endorse those old claims or certify independent loudness results.

## Commands and reproducibility

From the established checkout, in fresh child processes:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/Invoke-Tests.ps1 -Level Targeted -Tag @('Transaction','RunReports','OutputSafety','Launcher')"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/Invoke-Tests.ps1 -Level Targeted -Tag @('Transaction','RunReports','OutputSafety','Launcher')"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-OutputTransactions.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M1-07/real-transactions
python -X utf8 scripts/Test-RunReports.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M1-07/real-reports
```

Use new real-harness output directory names for subsequent runs. The manifest
records the resolved shell paths with personal path components sanitized.

## Limits and next task

No speech listening, full >4 GB render, real disk exhaustion, long-file/memory
stress or running-render Ctrl+C validation occurred. Capture remains in memory.
Reports lack multi-file atomicity and power-loss guarantees; unrecoverable I/O
can leave incomplete artifacts. Space checks do not reserve capacity against
other writers. The Original Raw marker delay of about 25 ms is preserved.
These limits remain visible rather than being counted as successful tests.

After successful gate and synchronized delivery, the exact next task is
**WAC-M2-01 — Correct audio claims and name the Original preset**. No M2 feature,
sound change, merge, tag/release or deployment is included in this checkpoint.

## AC-033: recoverable remote checkpoint

At start, checkout inspection and fetch confirmed the intended feature branch
and exact effective fetch/push origin `https://github.com/PikkuJanne/WinAudioClean.git`.
The first noninteractive sync helper could not authenticate `ls-remote` with
the default Git helper. A process-only `credential.helper=!gh auth git-credential`
override using the existing authenticated GitHub CLI resolved it; live remote,
local and draft PR #2 then matched the starting SHA above. No credentials or
persistent Git configuration were written into the repository.

Draft PR #2 is stacked on `codex/wac-m0-handoff`; PR #1 is open and unmerged.
There is no CI workflow/check run. Local test results must not be described as
CI success. Commit only intended text files after content/privacy/staged review,
push this feature branch, run clean-worktree live `sync-check`, and inspect
the live PR head. The exact resulting commit and final local/live/PR equality
are recorded in the PR and final response, avoiding a self-referential commit.
