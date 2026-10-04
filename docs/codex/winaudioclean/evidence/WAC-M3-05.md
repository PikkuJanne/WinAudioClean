# WAC-M3-05 — output organization and optional local interaction

Completed 2026-10-03 from synchronized M3 checkpoint
`83e41830a3b2a7f15ece4efa972f2d824ab716c6` on `codex/wac-m3-settings`.
AC-061/062/063 accept the recorded Windows engineering scopes below.

## Change

- Music remains the default, with chosen/saved destinations retaining their
  precedence. Unavailable or unsupported redirected Music fails with explicit
  local-output guidance; no current-directory fallback is introduced.
- Optional `-JobFolder` groups one invocation, including a queue, in a new
  `WinAudioClean_Job_<32hex>` under the chosen base. Audio and owned partials
  use `media`; JSON/text reports, the summary and default journal use `reports`.
  Explicit BatchResultPath retains its override. The legacy flat layout remains
  default, and these actions are never saved preferences.
- Optional Output creates each generated child atomically with `NtCreateFile`
  FILE_CREATE relative to a held parent. Canonical ordinary ancestors and
  directory identities remain pinned through all media/report work. Existing
  local base junctions resolve canonically; generated child names are never
  reused. Media permits the write sharing required by the unchanged publication
  operation; root/reports/ancestor pins share read only. No pin shares delete.
  Failure cleanup releases handles and leaves partial empty directories rather
  than deleting by name. Sequential children borrow one parent-owned layout.
- No-input use prints console usage and returns 2 before settings/destination
  work. `-PickFile` explicitly loads an optional single-file Windows Forms dialog
  only in an interactive STA host. A cancelled selection returns 130 before
  destination/native work. All ordinary routes remain console-accessible.
- `-OpenOutputFolder` explicitly requests one directory action after published
  success/warning. Unattended requests fail before processing; failed/cancelled,
  empty and mixed-failed queues do not open a destination. A held reopened
  directory must match the completed identity before the shell directory verb.
  Action failure warns while preserving the audio exit/outcome. No playback or
  audio-file opening is automatic.
- Detailed schemas retain their versions and add organization only to organized
  runs. Folder selection skips exact known job directories. Explicit-list repeats,
  queue aggregates, held writers/source leases, owned rollback and cancellation
  remain intact. Redacted exports omit the organization paths.

## Validation actually run

- Final OutputInteraction: **48 passing cases** per host
  within the final cumulative Targeted scope, with controlled picker/open helpers
  and actual isolated console/native-fixture execution. The dedicated PS 7 capture
  passed 48/0. Dedicated PS 5.1 passed 47/failed 1 at the unchanged 30-second
  helper-less child deadline; that row then passed 1/0 in isolation, and the final
  same-source Targeted passed all 48 per host. Contention is a possible explanation,
  not a demonstrated cause; neither runtime nor deadlines were changed for it.
  The coverage includes defaults/custom/layouts, no-input and no-GUI rejection,
  per-invocation sharing, cancelled/unavailable picker, explicit follow-up gates,
  unchanged exit on open failure and canonical destination identity checks.
- OutputLayout focused: **10/10** per host on helper 8EBDFC/test 6B9746, parser and
  analyzer gate 0. Real Windows native directory/IO checks prove exclusive
  ordinary/file/junction collisions, canonical base-junction resolution, blocked
  foreign rename/delete, read-only parent write-open denial, media publication,
  held report writing, assertion failure cleanup and disposal diagnostics.
- Added Preview layout-report regressions: **2/2 selected**, 153 outside filter,
  155 discovered, per host on test A4CE/main 728B/Preview 3DBF. Real layout/IO
  leases and controlled native/report faults prove retained four assets with
  WARNING 7, primary cancellation 130/owned rollback, incomplete reporting and
  unconditional transaction-pin release while the borrowed layout stays held.
  These earlier focused hashes are not substituted for final cumulative source.
  [Focused ledger](WAC-M3-05-focused.json).
- Final cumulative Targeted: **222 pass** per host, exit 0.
  Required final Full: **1442 pass/1 file-symlink privilege skip Pester** per host; Python **61 pass/1 separate privilege skip** per host (62 discovered).
  Parser/static/plan pass, with non-gating advisories retained. Windows
  PS 5.1.26100.9444/PS 7.6.5, Pester 5.7.1/PSScriptAnalyzer 1.24.0 and Python 3.14.6;
  exact commands, physical hashes, scopes and raw/sanitized log digests remain in
  the [gate ledger](WAC-M3-05-gates.json) and [source manifest](WAC-M3-05-source.json).
- Final real-media matrix: **44/44** on pinned FFmpeg/ffprobe 9.0.2 in both
  hosts, **38 PCM comparisons** and
  **38 published WAV assets** within its recorded scope.
  Source/tool/copied-build guards, paths, media/report separation, ordinary and
  Preview results, queue journal/report placement and exact same-build graph/PCM
  checks are recorded in the [media ledger](WAC-M3-05-media.json).
  The known Music-folder OS read is controlled in the copied application;
  picker/open eligibility uses labeled spies while held directory identities and
  media processing are real. Queue cancellation requests the actual context just
  before Rendering admission; this is separate from active native console signals.
- Original sound helpers, native process/cancellation machinery, IO and launcher
  preservation are individually scoped in the
  [preservation record](WAC-M3-05-preservation.json). No sound was retuned.

Media assets comprise 38 case exports plus 12 separately rendered baseline references (50 application WAVs total), with 38 exact decoded PCM/frame comparisons. Independent read-only reviews verified projections, runtime/tool/fixture hashes and all 651 manifest records; one review also checked the 50 decoded PCM artifacts. All recorded application failure/cancellation outcomes remain distinct from harness pass results.

Read-only review observed an inherited unguarded writer-close loop in Write-WacPreviewReports: a throwing first writer Dispose could skip later writer closes. This unchanged helper was not fault-injected here; recovery for that exceptional close-error case remains unverified. The added Preview layout regressions certify their explicit report/organization faults and transaction-pin cleanup only.

## Retained corrections and limits

The initial root Targeted selected 264 and passed 258/failed 6 per host. No-input
stdout-only guidance and changed missing-mode/output-preflight precedence broke
legacy diagnostics assertions; runtime restored stderr/precedence while keeping
usage. Initial layout PS 5.1 did not start because of host execution policy; the
subsequent developer gates used their existing per-process bypass, without a
persistent policy change. Initial PS 7 layout 9/1 caught read-only media sharing
blocking RenameNoReplace with Win32 32. The next layout 9/1 per host caught a
test reopening files while their immutable validation/report handles were held;
the test now settles owned output/closes its writer before ordinary readback.
Minimal/final layout 10/10 use write sharing only where publication requires it.

Initial Interaction units passed 21 with 23 outside the 44-case discovery. Later
48-case captures were source-unstable and contained inherited generated-path
length and PS 5.1 nested-array fixture failures; their logs/hashes remain separate
from final certification. Fixtures were corrected without introducing extended
path support or weakening native argv/output checks. The first media Preview
case incorrectly required an ordinary summary; its assertion was corrected for
the existing Preview contract and the preliminary capture remains retained.
Its initial Python digest has no retained matching complete source bytes;
copied applications, raw events/logs and commands remain identified. A later
five-case smoke passed four and missed cancellation admission because its hook
did not receive the implicit context; the corrected two-host admission smoke
passed separately before the final unfiltered media matrix.
Later corrected 49 Interaction captures passed 48/failed 1 per host: the shared
NativeProcessFixture could not model Preview null-sink/stdin measurement and
returned native 97. The associated completed Targeted selected 214 and passed 213/
failed 1 per host. Only that unsupported redundant Interaction case was removed;
the dedicated 155-case Preview suite includes the two layout/report regressions,
and actual-media Preview coverage retains four-asset path/PCM checks. The owned
Full wrapper/tree was stopped before this test-only correction, without a Full
completion count. Its interrupted capture remains separate from the fresh
required Full and the final 48-case Interaction scope certified
within cumulative Targeted. The later dedicated PS 5.1 timeout capture and its
isolated/Targeted recovery remain separately recorded rather than relabeled green.
The earlier completed Targeted 213/0 per host remains a passing historical scope.
The next required Full completed 1440 pass/2 fail/1 privilege skip per host with
exit 1 and did not reach Python. Both failures were Preset menu fixtures whose
Test-WacInteractive override was injected at the old CONFIGURATION marker after
the newly earlier interactive-state capture. Only the fixture insertion marker
was moved before that capture; runtime and assertions were unchanged. The final
Targeted 222 scope adds nine Preset cases to the earlier 213
and certifies all 48 Interaction cases per host. Only the fresh required Full
after this fixture correction supplies the final cumulative pass/Python counts.
Independent review canonicalized flat reports, verified follow-up identity after
pin reacquisition, and kept organization/report faults inside existing outcome
and unconditional cleanup boundaries. No preliminary scope is relabeled as a
passed Full or as final-current-source media.

Picker/open helper doubles verify requested-action contracts; no manual file
dialog, Explorer window or audio playback gesture was performed. Prior M3-04's
four private native-console signal cases remain historical evidence and were
not rerun for M3-05. Human listening/default promotion, window-close/crash/power
loss and long storage/memory/long-path stress remain outside this scope. Existing
meter-domain/seek uncertainty and no-overwrite/reporting limits remain.
Actual user Music/settings were not used for test writes; fixtures/preferences
were isolated, and all media was synthetic. Public derivatives contain no
recordings, credentials or personal paths. No merge/release/default promotion,
persistent settings/security policy change or deployment is approved here.

TASKS/AC retain all 30/90 IDs and earlier rows/history. Only M3-05/AC-061..063
advance: canonical 21 done/9 todo. **WAC-M3-06** is the sole next unlocked task;
its separate workflow/automation gate has not been performed by this task.
Exact post-push commit/live-branch/PR verification belongs in the final delivery
message or PR comment rather than a self-referential manifest.
