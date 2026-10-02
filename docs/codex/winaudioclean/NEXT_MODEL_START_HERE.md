# Next model: WAC-M1-07

**M1-06 is complete. Start only WAC-M1-07: Reliability regression gate.**
Read AGENTS.md, STATUS.md, DECISIONS.md, TASKS.yaml, SYNC_PROTOCOL.md,
tasks/WAC-M1-07.md, NATIVE_PROCESS_CONTRACT.md, DATA_FORMATS.md and
evidence/WAC-M1-06.md. Preserve earlier evidence.

## Inspect and synchronize

Use the established WinAudioClean-governance checkout on
`codex/wac-m1-reliability`. Preserve the source-only starting folder. Exact
fetch/push origin: https://github.com/PikkuJanne/WinAudioClean.git.
M1-06 started at `cbe732c10bf815e57936fc8ddce50f1c86aa1559`; derive its final
SHA from the live branch and PR, not this starting SHA.

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
git fetch --prune origin
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
gh pr view 2 --repo PikkuJanne/WinAudioClean --json url,isDraft,state,baseRefName,headRefName,headRefOid,statusCheckRollup
```

Only M1-07 should be ready. Reuse draft PR #2, stacked on `codex/wac-m0-handoff`
while draft PR #1 remains unmerged. Verify the live base/CI. Feature commits,
pushes and draft PR updates are authorized; merges/releases/deployment require
exact approval.

## Narrow next task

- Run cumulative Quick and M1 targeted checks, then one Full gate after resolving
  any failures. Review intentional behavior changes and retained PowerShell/
  drag-and-drop entry points. Do not turn this into the next audio feature task.
- Review file writes, rename and cleanup paths with their fault evidence;
  resolve known source/prior-output overwrites, ambiguous outcomes or false success.
- Reconcile AC-031/032/033, record exact source/environment/commands, update state,
  commit/push and verify clean local/live/PR equality. Stop at that checkpoint.

## Reporting seams and invariants

Main and required sibling WinAudioClean.IO.ps1 dot-source without runtime
work; native declarations compile lazily. Keep both in sandboxes/distribution.
The main script owns New-WacRunReport, Format-WacRunReport, Write-WacRunReports,
ConvertTo-WacMeasurement and explicit redaction/export helpers. Version 1 JSON
and text use WinAudioClean_<jobId> filenames; the summary retains old labels.
Rendering duration is separate from selected recording duration. No independent
loudness measurements exist; null/reason values are intentional.

IO Open-WacReportWriter uses CreateNew for per-run files and exclusive writers
for summary append. Retry only sharing/lock errors up to 3 seconds. Reject
reparse/multiple-hardlink files, hold the canonical destination and source, flush
before success, and rollback only bytes appended under this writer. BOM/strict
UTF-8/current ANSI encoding detection preserves old logs. Preserve the older
Open/Close-WacReportGuard API/tests. Complete-WacOutputTransaction finishes
owned-file cleanup before reporting; Close releases the remaining safety pins.
Later release of flushed/read-only handles is advisory and cannot contradict
the persisted outcome. Unrecoverable I/O/crashes can leave incomplete reports.

Write-WacRunReports retires a failed writer, removes only its owned file (or
rolls back summary), then corrects surviving files to WARNING/7 where possible.
Earlier native/output failures retain 3/4/5. Raw diagnostics stay in local JSON/
text. Human metadata control chars are escaped to prevent forged field lines.

-ExportDiagnostic <raw-json> -DiagnosticOutputPath <new-json> bypasses media
dependencies, rejects processing flags and arrays/unknown versions, limits
input to 16 MiB, pins its source read-only and destination parent, and never
overwrites. Projection retains only typed numbers/booleans/fixed labels,
omitting all free-form strings. Review-before-sharing warning appears; no upload.

## Earlier safety and audio contracts

Keep exact Original Raw/Zoom strings and explicit 48 kHz PCM16/24 mono/stereo
exports. Mono is an explicit equal-weight prechain; RF64 is explicit. Metadata
and chapters are omitted from audio. Capacity includes 101 ms timing slack,
1 MiB headers and max(64 MiB, 10%) reserve, queried through the pinned directory.
No capacity reservation against competing writers. Unsupported layouts/settings
fail before render. Stream duration never substitutes container duration.

Transaction owns a CreateNew .wac-<GUID>.partial. Probe, freeze/check identity,
validate complete PCM/layout/container/timing, then rename the held object with
replacement disabled. Cleanup deletes only owned identities; preserve foreign
replacements and crash leftovers. Never replace this with a release/reopen move.
Native direct-process capture remains in memory, inspection deadline 15 seconds,
render has no total timeout. Exits: 0 complete, 2 input/settings, 3 dependency/
start, 4 probe/native/capture, 5 output/space/cleanup, 7 reporting, 130 menu cancel.
Early pre-render failures remain console-only.

## Tests and tools

Final M1-06 Full: 543 Pester passed, zero failures/skips; 61 Python passed plus
one symlink-privilege skip per shell. Parser 25 files; 112 non-gating advisories.
RunReports 33/33, ReportIO 23/23, Transaction 27/27 per shell. Real reporting
24/24 (24 renders and four diagnostic CLI invocations), stable runtime/harness
hashes matching Full. Earlier encoding/transaction/media evidence is preserved.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.RunReports.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

Use fresh shells and pinned modules under ignored .wac-local/Modules. Python
child launchers omit inherited PSMODULEPATH for PS5. Use existing FFmpeg/ffprobe
9.0.2 under .wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin.
Test-RunReports.py stores synthetic audio/raw reports locally; evidence carries
sanitized status observations/hashes. No runtime Python or security changes.
Preserve M1-02's policy/resumption history. Main/README tracked CRLF and IO LF
must stay intact; the current delivery bytes are the exact Full/real-tested ones.

No independent loudness/speech-quality claim. Preserve the original Raw marker
delay (~25 ms), measured against the legacy render in M1-05. Full >4 GB, real
disk exhaustion, speech listening, long-file/memory stress and running-render
Ctrl+C remain unverified. Do not convert these limits into passing evidence.
