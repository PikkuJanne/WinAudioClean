# WAC-M1-06 evidence — structured local run reports

Date: 2026-10-02. AC-028, AC-029 and AC-030 pass. Starting synchronized
checkpoint: `cbe732c10bf815e57936fc8ddce50f1c86aa1559` on
`codex/wac-m1-reliability`. This task ends before WAC-M1-07.

## Delivered behavior

- Unique `WinAudioClean_<jobId>.json` and `.txt` reports accompany attempted
  renders. Retain the human `WinAudioClean_Log.txt`, legacy labels and separate
  native stdout/stderr. Version 1 records tool/preset/revision availability,
  stream, exact effective filters, settings, format, recording duration,
  rendering wall time, requested targets, validation and reporting outcome.
- Independent LUFS, true peak and loudness range remain `null/not_measured`.
  Invalid/nonfinite measurement values become null with a reason. Unknown
  preset version/source revision are explicit; no runtime Git dependency.
- Finish owned-output cleanup before composing terminal reports, retaining
  source/destination protection. Keep codes 3/4/5 primary; successful published
  audio with report errors uses WARNING/7. Correct surviving reports after
  a companion write failure. Later release of flushed/read-only handles is
  a console advisory, not a contradictory change to the persisted outcome.
- CreateNew per-run reports never replace existing files. One summary writer
  holds the file through append/rollback, retries contention up to 3 seconds,
  rejects reparse/multiple-link leaves, and preserves prior bytes. New reports
  are UTF-8; BOM encodings and legacy ANSI summaries are handled explicitly.
- Explicit `-ExportDiagnostic <raw.json> -DiagnosticOutputPath <new.json>`
  projects only typed numeric/boolean values and fixed labels. Paths, names,
  titles, timestamps, job IDs, version banners, filters and raw diagnostic text
  are omitted. The raw report stays unchanged, the output cannot overwrite an
  existing file, and the export warns to review before sharing. No upload.

Existing entry points, 48 kHz PCM16/24/RF64 policy and exact Raw/Zoom filters
remain unchanged. Early pre-render failures remain console-only.

## Environment and commands

Windows 11 / NT 10.0.26300; Windows PowerShell 5.1.26100.9444; PowerShell
7.6.5; Python 3.14.6; Pester 5.7.1; PSScriptAnalyzer 1.24.0; existing local
FFmpeg/ffprobe 9.0.2 essentials build. No downloads or security-setting changes.
Python is a development-only test tool. Fresh PS5 children omit inherited
PSMODULEPATH so that Windows PowerShell initializes its own defaults.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.RunReports.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.RunReports.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.ReportIO.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.ReportIO.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
python -X utf8 scripts/Test-RunReports.py --ffmpeg .wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe --ffprobe .wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin/ffprobe.exe --output .wac-local/WAC-M1-06/reports-final-1
```

Final Full: **543 Pester passed, zero failed/skipped; 61 Python passed and one
symlink-privilege skip per shell**, runner exits 0. Parser: 25 maintained
PowerShell files. Static/plan gates pass; 112 non-gating analyzer advisories
remain visible. Full and real checks used identical runtime bytes with stable
before/after hashes. Main CRLF and IO LF are preserved.

Evidence: [PS7 Full](WAC-M1-06-full-ps7.txt), [PS5 Full](WAC-M1-06-full-ps51.txt),
[source/command manifest](WAC-M1-06-source.json),
[real report cases and exact commands](WAC-M1-06-reports.json).

## Acceptance results

| Case | Evidence and result |
| --- | --- |
| AC-028 | RunReports targeted 33/33 each shell and final Full. Success, encoder exit 17/app 4, validation exit 5, metadata/report faults: JSON, text, shared log, console and exit agree. Real three-second recordings show 0.394–0.754 s render time. Unsupported, NaN, positive/negative infinity and `-inf` measurements serialize as null with reason. Metadata line breaks cannot forge labeled human-report lines. |
| AC-029 | Seeded directory/file/title/container metadata, version/filter and diagnostic secrets disappear from redacted output. Real and fixture export-only runs succeed without media dependencies; source hashes stay unchanged; an existing destination is refused. Int/long JSON values round-trip across shells, invalid root arrays are rejected, and review warnings appear. |
| AC-030 | Concurrent processes create distinct reports/audio and contiguous summary entries. Permission and partial-write/append faults cover JSON/text/summary and success/native/validation outcomes. Surviving reports are corrected, failed owned files are removed, previous summary bytes are restored, and sources/prior exports remain unchanged. ReportIO 23/23 per shell covers exclusive contention, ownership, aliases, encoding and rollback; existing Transaction 27/27 per shell remains green. |

Real harness: **24/24 report cases**, 24 rendering invocations and four diagnostic
CLI invocations across both shells; exit 0. The harness uses synthetic audio and
isolated copies for injected native results, truncated output, permissions and
partial report writes. These are controlled faults, not claims about real ACL
configuration, volume exhaustion or hardware failure. Raw audio/reports remain
under ignored `.wac-local`; committed evidence contains case observations,
commands and hashes with machine paths sanitized.

## Development corrections and limits

Initial Quick passed 322/322 while coverage was being added; existing metadata
report tests passed 8/8. Initial new reporting tests passed 30/30 per shell,
expanded to the final 33/33. The first BOM/ANSI expansion exposed PS5 accepting
an incomplete trailing UTF-8 sequence; explicit decoder flushing and a buffer
boundary regression corrected it. Final ReportIO passed 23/23 per shell.
Review also resolved int64 JSON fields, array roots, metadata control characters,
and nonfatal handle-release diagnostics before the final frozen-source gates.

Report files are not an atomic multi-file transaction. A crash or unrecoverable
storage/rollback failure can leave incomplete artifacts; consult console exits
and inspect before sharing. Native capture remains in memory; diagnostic export
is capped at 16 MiB and requires an existing destination parent. No independent
loudness measurement or speech-quality claim is added. Prior limits remain:
full >4 GB output, real disk exhaustion, speech listening, long-file/memory
stress and running-render Ctrl+C are unverified. The original Raw marker delay
of about 25 ms remains unchanged.

The post-push SHA and live local/remote/PR equality are recorded in the PR/final
response. Draft PR #2 stays stacked on `codex/wac-m0-handoff`; CI has no workflow.
No merge, release, deployment or default-sound promotion is part of this task.
