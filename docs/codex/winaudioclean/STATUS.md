# Current status

Date: 2026-10-02. **WAC-M1-06 is complete.** M0-01 through M0-04 and M1-01
through M1-05 remain complete. AC-001 through AC-030 pass. Ten tasks are done;
20 remain todo.

**Next: WAC-M1-07 — Reliability regression gate.** Stop after synchronizing
this M1-06 checkpoint.

## Current behavior

- Each attempted render produces a unique version 1 JSON and human text report;
  the retained shared log serializes complete entries. Recording duration and
  rendering elapsed time are distinct. Settings, exact filters, tool/stream
  information, validated format, native diagnostics and outcome are recorded.
- Processing and reporting statuses are separate. Code 7 means published audio
  with incomplete reporting; earlier failures stay primary. Surviving reports
  are corrected after write failures. Owned output cleanup settles before
  reporting while source/destination protection remains held.
- Reports use no-overwrite file creation and exclusive summary append/rollback,
  preserving prior bytes and rejecting unsafe aliases. UTF-8, BOM-based Unicode
  and legacy ANSI summary behavior are documented.
- Explicit `-ExportDiagnostic` with `-DiagnosticOutputPath` creates a smaller
  typed support JSON and warns to review. Paths, metadata and free-form diagnostic
  text are omitted. No uploads; raw reports remain local. See DATA_FORMATS.md.
- Existing Raw/Zoom filters, 48 kHz PCM16/24, mono/stereo/RF64 policy, stream
  selection, literal paths, native wrapper and held-object publication remain.

## Validation

Windows NT 10.0.26300; PS5.1.26100.9444 / PS7.6.5; Python 3.14.6;
Pester 5.7.1 / PSScriptAnalyzer 1.24.0; FFmpeg/ffprobe 9.0.2.

- Full **543 Pester passed with zero failures/skips; 61 Python passed plus one
  symlink-privilege skip per shell**, both runner exits 0. Parser 25 files;
  static/plan gates pass; 112 analyzer advisories are non-gating.
- RunReports 33/33, ReportIO 23/23 and existing Transaction 27/27 per shell.
- Real reporting **24/24 cases** across both shells: 24 renders plus four
  diagnostic CLI invocations. Source, prior audio and summary bytes survive
  tested failures. Runtime/harness hashes remain stable and match Full.
- [Evidence and exact source/commands](evidence/WAC-M1-06.md). Earlier evidence
  is unchanged. Main retains CRLF; IO retains LF; no post-gate runtime changes.

## Remaining boundaries

Report files have no multi-file atomicity guarantee; crashes or unrecoverable
I/O can leave incomplete artifacts. Inspect console diagnostics and review
exports before sharing. Diagnostic export accepts version 1 JSON up to 16 MiB.
Early pre-render failures remain console-only. Native capture remains in memory.
Independent loudness measurements and speech quality are not certified.

Prior limits remain: full >4 GB output, real disk exhaustion, speech listening,
long-file/memory stress and running-render Ctrl+C are unverified. Capacity is
not reserved against competing writers. The original Raw marker delay of about
25 ms is preserved. There is no CI workflow.

## Checkout and delivery

Use WinAudioClean-governance on `codex/wac-m1-reliability`; preserve the original
source-only folder. Exact fetch/push origin:
https://github.com/PikkuJanne/WinAudioClean.git.
Starting checkpoint: `cbe732c10bf815e57936fc8ddce50f1c86aa1559`.
[Draft PR #2](https://github.com/PikkuJanne/WinAudioClean/pull/2) remains stacked
on `codex/wac-m0-handoff`; draft PR #1 is open/unmerged. The completion SHA and
fresh local/live/PR equality belong in PR/final response, avoiding a recursive
evidence commit. Do not start M1-07 before synchronization is verified.
