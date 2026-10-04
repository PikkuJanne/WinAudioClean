# WAC-M3-04 — stage progress and controlled cancellation

Completed 2026-10-03 from synchronized M3 checkpoint
`0366f674d0c8921680179d9790044e4f01efac1a` on `codex/wac-m3-settings`.
This accepts AC-058/059/060 within the recorded Windows engineering scopes.

## Change

- FFmpeg uses structured `-progress pipe:1` stdout and separate stderr diagnostics.
  A bounded 4096-character/64-field pump consumes complete timestamp blocks,
  rejects malformed/truncated data and recovers at block terminators. Progress
  follows media time, with stage labels and queue file position. Inspection and
  unknown native duration are indeterminate; ordinary unknown input timing still
  fails closed before rendering.
- Fast rendering is 0-90; Accurate analysis 0-30, rendering 30-80 and independent
  verification 80-95. Validation/publication have their own labels. Preview splits
  its eight render/meter steps to95, following optional analysis to15. Only held
  publication (all four preview assets) permits Completed100.
- One run controller is shared by sequential queue children. Native Ctrl+C/Break
  interception sets its flag while PowerShell remains available for cleanup and
  reporting; the normal Read-Host handler is restored while prompts wait. Kill
  targets only the held child Process. Existing bounded exit/stream cleanup and
  caller-owned binary streams are preserved. Cancelled input pipe faults are
  disclosed separately from genuine cleanup errors.
- Active cancellation retains earlier exports, stops pending starts and records
  CANCELLED130. Verification cancellation prevents publication. Ordinary/preview
  schema1 gains progress; preview unsuccessful attempts can write compact reports
  after owned rollback. Reporting failure preserves primary failure/cancellation.
  Folder/list journal schemas and prior static skips remain intact.

## Validation actually run

- Final focused Progress + unchanged Native/NativeInput: **77 pass**, no failure,
  skip or outside-scope case, exit0 on Windows PS5.1.26100.9444 and PS7.6.5.
  It includes malformed, truncated, oversized/flooded streams, recovery, variable
  progress, unknown/nonfinite duration, display-fault injection, nonzero native
  exits, owned cancellation, early inspecting cancellation130 and retained caller
  streams. [Focused ledger](WAC-M3-04-progress-focused.json).
- Preview/Batch selection: **226 pass** per host. Its preliminary and green
  source-unstable captures remain labeled; the final cumulative gate certifies
  the frozen source after all corrections. [Gate ledger](WAC-M3-04-gates.json).
- Corrected EntryPoints/Reporting/RunReports/Preset/Preview selection:
  **283 pass/0 skip** per host, exit0 and stable source.
  Legacy monitored stdout fixtures now emit structured blocks and keep diagnostic,
  privacy and concurrent-run tokens on stderr. Four preview cases prove cleanup
  diagnostics are persisted before source/destination pins release, primary4/5/130
  survive cleanup faults and post-publication cancellation metadata stays truthful.
- Required final Full: **1382 Pester pass/1 privilege skip** per host,
  exit0; Python62 discovered/61 pass/one separate symlink-privilege skip.
  Parser/static/plan pass, with visible non-gating analyzer advisories.
  Pester5.7.1/PSScriptAnalyzer1.24.0 and Python3.14.6; exact commands,
  physical source hashes, durations and log hashes are in the gate/source ledgers.
- Actual native-console signals: **4/4**, PS5.1/PS7 x Ctrl+C/Ctrl+Break in
  private hidden consoles. The receiver persisted CANCELLED130 with no audio or
  partial; its independent survivor stayed alive and completed. A second event
  reached the lower observer after Dispose, proving removal. [Console ledger](WAC-M3-04-console.json).
- Final real-media scope: **20/20** on pinned FFmpeg/ffprobe9.0.2, both hosts.
  Fast/Accurate, both previews, variable speed, genuine unknown live-WebM native
  indeterminate progress plus app rejection4, three active Accurate cancellation
  stages with independent survivors, and unexpected owned-render exit4 are
  separately recorded. Detailed reports, complete queue journals, no target
  publication/100 on failure/cancel, retained sources/foreign/prior files,
  exact same-build PCM/frame/graph parity and source/tool/copied-build guards
  are verified. [Media ledger](WAC-M3-04-media.json).
  Final counts: 38 unique case/independent PCM comparisons, 64 published WAVs
  including references, 40 top-level app invocations and two native-only unknown
  utilities; eight queue journals, 18 child starts and six unstarted suffix items.
- Nine sound/argument helpers and IO/Settings/Queue/BAT/Launcher are unchanged
  from M3-03. [Preservation guard](WAC-M3-04-preservation.json).

## Retained corrections and limits

The initial root gate caught PS5.1 UTF8 punctuation parsing and an empty-catch
analyzer issue. The first runtime integration caught duplicate preview measurement
arguments. The next selection caught the historical no-report assertion; it now
checks the intentionally retained failed preview report. Focused records retain
Pester setup/capture and fixture environment failures, source-unstable captures,
the earlier green75 scope and final field-cap recovery regression. Console/media
records retain their import/invocation harness failures and corrected captures.
The first cumulative Full failed28 assertions in PS5.1 and30 in PS7: shared28
legacy monitored-stdout assumptions and two PS7 menu-fixture Clear-Host calls
without a console. All remain in the gate ledger; the latter has a bounded
[diagnosis](WAC-M3-04-preset-diagnosis.json). Independent review also narrowed
cancellation-input classification to the caught copy-task exception, retained130
at early inspection boundaries, and settled preview cleanup before failed reports.
The focused77/media20/console4 captures were repeated on those final runtime bytes;
earlier green captures remain explicitly scoped to their preceding hashes.
The final staged audit normalized trailing whitespace in selected public Pester
log derivatives. Their prior public hashes and original raw capture hashes remain
recorded; executed results and source bytes did not change.
No failed scope is relabeled as a passed Full or substituted for the final source.

Native events are actual OS signals, without a performed UI keystroke or shared
console isolation claim. The throwing display double is a unit fault; captured
redirected consoles are real. Console close/logoff, forced host termination,
power loss, long-duration memory/storage stress and human listening remain
outside these checks. Stderr and nonmonitored native capture remain in memory.
No default sound, settings/security policy, release/merge or deployment changed.
Default user preferences were absent and never written; all media/config cases
were synthetic and isolated. Privacy-audited derivatives contain no user audio,
credentials or personal paths.

TASKS/AC retain all30/90 IDs: only M3-04/AC-058..060 advance. Canonical20 done/
10todo; **WAC-M3-05** is the sole next unlocked task. The exact final Git commit
and point-in-time remote/PR verification belong in the post-push PR comment.
