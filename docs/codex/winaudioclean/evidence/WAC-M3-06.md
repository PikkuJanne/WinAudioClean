# WAC-M3-06 — workflow and automation gate

Checkpoint from synchronized `dfcbd559f91c1cf2adf09a9ff581a5dac359ea73` on `codex/wac-m3-settings`,
2026-10-03. **Engineering checks are complete; M3-06 remains blocked on AC-064.**
AC-065 and AC-066 pass the recorded scopes. No runtime, launcher, tests, runner,
filter, default or product contract changed. Canonical: 21 done, 8 todo, 1 blocked;
65 acceptance cases pass, AC-064 is blocked, 24 remain not run. M4-01 is locked.

## Acceptance actually established

- **AC-064 — blocked.** The brief requires dropping a typical interview file,
  selecting 1/2 and inspecting its result/report. No cleared interview/manual
  result was supplied. Supplementary engineering evidence uses the exact BAT,
  launcher and application copies in an actual interactive PTY, with real
  `Read-Host` selections and one pause, on PS 5.1 and PS 7. All four synthetic
  Raw/Zoom runs returned 0, retained the simple 1/2/Q menu and Original 1.0.0/Fast
  choices, wrote complete reports, and exported exactly 384000 frames/8 seconds.
  Four decoded PCM results match direct same-build report-filter renders exactly.
  This establishes console/menu behavior; it does not establish an Explorer
  drag-and-drop gesture or an interview review. [Menu ledger](WAC-M3-06-menu.json),
  [complete harness projections/manifest](WAC-M3-06-menu-harness.json).
- **AC-065 — pass.** [Automation](WAC-M3-06-automation.json) accepts ten cases,
  explicitly composed of eight passing cases in the first ten-case capture plus
  two corrected manifest-only recovery cases. The required flows are successful
  relative-manifest batches, valid/corrupt/valid explicit lists, recursive folder
  selection with explained skips, and bounded four-asset Preview, on both hosts.
  Commands use `-NonInteractive`, redirected stdin and finite harness deadlines;
  actual process codes, generated files, reports, schemas, timing and exact PCM
  comparisons are checked. A separate borrowed pre-requested cancellation
  controller proves aggregate 130, NOT_STARTED entries and no audio; this is
  controlled admission evidence, not a fresh active Ctrl+C event. Ordinary
  same-build references and fresh absent-settings ShowSettings calls are scoped
  separately from the ten cases. Final physical source/tool/copy/file guards pass.
- **AC-066 — pass.** A fresh detached no-hardlink local Git clone recovers exactly
  the parent-verified pushed revision above. Clean before/after, validate-plan
  30/90/20 and `next` recover M3-06 from Git. Two real synthetic Raw exports use
  built-in Original 1.0.0/Fast/PCM 16 stereo choices with no recorded preferences;
  explicit mode, dependency and destination paths keep this an unattended check.
  Each export has 384000 frames/8 seconds and identical cross-host decoded PCM.
  Settings stay absent. The clone is a same-machine local object copy; it is not
  a new remote fetch or final future-checkpoint reconstruction.
  [Reentry](WAC-M3-06-reentry.json), [harness](WAC-M3-06-reentry-harness.json),
  [raw manifest](WAC-M3-06-reentry-manifest.json).

## Cumulative gate actually run

Smallest readiness: nine existing Preset cases per host, all passed, with parser,
analyzer and plan checks. With unchanged product/test source and passing product
smoke, the cumulative Targeted runner ran **once per host** on thirteen files:
Launcher, LauncherTransport,
Settings, EntryPoints, Preset, Batch, FolderQueue, Progress, Native, NativeInput,
Preview, OutputInteraction and OutputLayout. **749 passed, zero failed, one
file-symlink privilege skip per host (750 discovered), exit 0.** Parser 49 files,
zero gating analyzer findings and plan 30/90/20 pass; 273 non-gating advisories
remain recorded. Full and the Python governance unittest suite were not run for
this task. Plan validation invokes Python, which remains development-only.

[Gate ledger](WAC-M3-06-gates.json) carries exact per-host commands, versions,
elapsed times, count lines, source maps and raw/sanitized transcript hashes.
[Source manifest](WAC-M3-06-source.json) preserves all 66 physical code hashes
before/after/current and distinguishes physical bytes, LF-normalized content
and Git index bytes. 30 files differ physically from their LF Git blobs only by
CRLF; do not claim physical clone equality from normalized-content comparison.
Pinned Pester 5.7.1/PSScriptAnalyzer 1.24.0 and FFmpeg/ffprobe 9.0.2 are reused;
host/tool executable hashes are recorded, not inferred from a version label.

Configuration coverage concerns absent settings, schema-1 precedence, strict
unknown-version rejection and explicit reset. No implicit migration exists or is
claimed. Reentry observed that changing APPDATA does not relocate .NET's Windows
ApplicationData known folder on these hosts. Explicit isolated SettingsPath
(present only for the menu's destination, absent in reentry) prevents personal
preferences from supplying hidden defaults. No test writes actual user Music
or settings; runtime/configuration/tool guards and isolated records support this.

## Corrections and scope limits

- The first PS 7 menu probe used multiple executable paths returned by
  Get-Command; the launcher returned 2 before processing. Root selected one host
  with Select-Object -First 1. The full failed PTY capture remains alongside the
  four passed captures. Runtime and menu assertions were unchanged.
- The first menu evidence publisher expected one text file. Ordinary processing
  also creates WinAudioClean_Log.txt; only the publisher assertion was corrected
  to distinguish the detailed text report and matching one-run summary. No app
  rerun was needed. Initial exact publisher bytes were not archived before this
  correction; final complete bytes/digests and every application capture remain.
- Independent privacy review removed three remaining truncated/repainted local
  path fragments from public menu logs without changing raw captures. All prior
  derivatives, refreshed hashes and the correction source are retained. Reentry's
  publisher also corrected a literal sanitizer-token privacy rejection without
  rerunning the application; its publication history remains separately recorded.
- Automation's first publisher token scan matched its own literal pattern in
  embedded source, rather than a credential. It now requires a token-length
  suffix. Complete prior publisher/partial derivatives and the later explicit
  exclusion of the old smoke from accepted prompt-absence claims are retained;
  no media recapture or application change followed these publication corrections.
- The automation smoke's prompt regex was tightened to actual menu literals
  before final capture, without runtime changes. Its exact earlier source remains.
  The first complete ten-case harness passed eight and failed two manifest-path
  assertions, although both app outcomes were correct. Anchored `..` segments
  are intentionally preserved in journals; the harness now resolves both sides
  before checking selected-path equivalence. Only those two cases were rerun.
  Failed counts/commands/complete harness bytes remain separate from the combined
  ten accepted cases. No initial failed run is relabeled as a green unfiltered run.

All media is synthetic. No manual interview/Explorer/picker gesture, human
listening/default promotion, console-close/crash/power-loss guarantee or long
storage/memory/path stress is claimed. The inherited untested Preview writer-close
error path, meter-domain, filter-delay and seek limits remain. Earlier M3-04
private-console Ctrl+C/Break evidence is historical and was not rerun here;
current targeted Progress/Native/NativeInput checks retain their exact scopes.

The user was asked for cleared interview/manual results while independent work
continued. Absence of a response is not approval to waive AC-064. Preserve its
procedure and expected result; do not mark it not_applicable or advance M4-01
without an explicit approved disposition or the missing result.

## Checkpoint and next work

Only M3-06, AC-064..066 and appended handoff/history/evidence change. Prior task
and acceptance rows/history remain intact. Feature-branch delivery and draft PR
updates are authorized. Record the exact post-push SHA/live equality and PR/CI
state in the final message or PR, avoiding a self-referential source manifest.
**Next: finish WAC-M3-06's AC-064 manual gate.** M4-01 remains locked; no merge,
release, security/settings change, default promotion or deployment is approved.
