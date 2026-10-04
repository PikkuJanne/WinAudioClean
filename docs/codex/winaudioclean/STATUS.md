# Current status

Date: 2026-10-04. **WAC-M5-02 is in progress.** Canonical 27 done / 1 in_progress / 2 todo; 81 AC pass / 9 not_run. AC-082..084 remain not_run until actual reconstruction, candidate, privacy/rollback and cumulative checks pass.

Starting checkpoint `7b7edc46247172874ca2a9a66e9ba4160e5b899b` is clean and live-synchronized on `codex/wac-m5-release-readiness`; draft PR #6 stays based on `codex/wac-m4-regression`. Its own CI was observed pending at session start and is distinct from the passed M5-01 implementation CI. Recover the live state before relying on cached refs.

A fresh GitHub clone on this active machine recovered the exact starting revision in detached HEAD. Fresh checkout-local pinned developer setup is in progress; it does not reuse the maintained checkout's tool/module caches. Narrow documentation fixes add safe separate-folder prior-source rollback and correct the stale website sentence. The draft stays download-disabled; screenshots/audio remain pending.

Read the task brief, RECONSTRUCTION.md, PORTABLE_PACKAGE.md, CI.md and tests/README.md. Push and freeze the documented source checkpoint before fetching it into the rehearsal clone. Stabilize selected package/metadata tests, build four actual candidates, inspect source/manifest/checksum/provenance, reject altered checksum/version inputs, and review privacy and protected-byte rollback. Run each required actual local Full gate once on the stable clean clone; preserve the resulting exact source/tool/hash/count evidence and any failures/skips.

Evidence: [in-progress record](evidence/WAC-M5-02.md). Preserve all eight broader coverage gaps, the source-only original, runtime/BAT/default filters and package allowlist. No main push, merge, release/tag, settings/security change, bundling, publication or sound promotion. Stop after M5-02; next only M5-03 when this task is accepted and synchronized.

## Historical accepted M5-01 checkpoint

# Current status

Date: 2026-10-04. **WAC-M5-01 is complete.** Canonical 27 done / 3 todo / 0 blocked; 81 AC pass / 9 not_run. **Next: WAC-M5-02 — Rehearse clean-checkout and release-candidate reconstruction**, unlocked and not started.

The portable static website draft, versioned release metadata/schema, MIT asset
registry, validator and 20 regressions are implemented. Source `11fe377c5fd05624dcc280d89fd119741c6fde9e` passed both actual local Full gates: ps51: Pester 1483 passed/1 skipped, Python 162 ran/1 skipped; ps7: Pester 1483 passed/1 skipped, Python 162 ran/1 skipped. Every gate exited 0, with zero outside-scope cases and unchanged source/website contents. Retain local privilege skips and all eight broader gaps.

All 15 actual browser metadata fixtures, 17 independent VM vectors, selected
palette contrast and keyboard/desktop/mobile checks pass within their recorded
scopes. Only a temporary actual-package fixture enables its local download.
Committed metadata remains draft with null release fields. Screenshots/audio and
consent inventories remain pending; no listening or publication is inferred.
The verified package fixture remains the earlier accepted source 1f10940,
438904 bytes / SHA256 d543ab046e9b1c5330552038f4eaa9eea794b2392ced079e620ed2f65cf04bf7.

Tested-source CI is **passed**: [observed run](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37187177111). Actual final closure PR/CI/live synchronization must be inspected separately at its own SHA. Source/host/hash/count evidence: [accepted record](evidence/WAC-M5-01.md), [ledger](evidence/WAC-M5-01-validation.json).

Read AGENTS, STATUS, DECISIONS, TASKS, ACCEPTANCE, SYNC_PROTOCOL, COVERAGE and
tasks/WAC-M5-02. Use maintained WinAudioClean-governance on
codex/wac-m5-release-readiness with exact origin
https://github.com/PikkuJanne/WinAudioClean.git. Draft PR #6 remains stacked on
codex/wac-m4-regression. Recover actual branch, HEAD and live PR; do not use a cached
tracking ref as delivery proof. Preserve the source-only original and runtime,
BAT/script/default sound and package allowlist.

Do not repeat stable Full solely for closure metadata. New source, failures or
unresolved concerns justify additional gates. No merge/main push/tag/release,
bundling, settings changes, deployment or sound promotion is authorized. Start
only M5-02 when requested, after fresh checkpoint synchronization.

## Historical M5-01 implementation checkpoint (superseded)

# Current status

Date: 2026-10-04. WAC-M5-01 implementation and validation are in progress.
Canonical 26 done / 1 in_progress / 3 todo; 78 AC pass / 12 not_run.
The isolated static page and release schema are draft. No release or website
is published. Actual browser, local package metadata and stable cumulative
gates are required before AC-079..081 acceptance.

Use the maintained WinAudioClean-governance checkout on
codex/wac-m5-release-readiness; exact origin
https://github.com/PikkuJanne/WinAudioClean.git. Parent
ea5d53d91ff2c035a50b9808fda18ceba38d3b61 was live-synchronized and all four
parent PR jobs passed in run 37182880390. Inspect current Git/live PR state
separately. Read AGENTS, task brief, STATUS, DECISIONS, TASKS, ACCEPTANCE,
SYNC_PROTOCOL, COVERAGE and evidence/WAC-M5-01.md before continuation.

No real screenshots or permission-cleared audio have been admitted. Downloads
stay unavailable in draft metadata; synthetic/local fixtures do not establish
publication or speech-quality evidence. Preserve all eight broader gaps and
unchanged runtime sound, BAT/script entries and tool-only package allowlist.
No merge/main push/tag/release, deployment, bundling, settings changes or sound
promotion is authorized. Start no later task before this checkpoint is complete
and freshly verified on the live feature branch.

## Historical M4-04 closure (superseded)

# Current status

Date: 2026-10-04. **WAC-M4-04 is complete.** Canonical 26 done / 4 todo / 0 blocked; 78 AC pass / 12 not_run. **Next: WAC-M5-01 — Prepare static website assets and release metadata**, unlocked and not started.

Final packaged documentation/controller source `1f10940ee970ebe719c21ba0e7290830beeb7123` passed all 64 actual cases. ZIP: 438904 bytes, SHA256 `d543ab046e9b1c5330552038f4eaa9eea794b2392ced079e620ed2f65cf04bf7`; controller SHA256 `3cf5cd6fd7d24c4633e4163372e7b194a5840219a6b2534fc394f245b4a5266b`.

Both local Full gates used the earlier frozen source `047aefe906ca7954a225d81f53286eb1275723dc`: ps51: Pester 1483 passed/1 skipped, Python 142 ran/1 skipped; ps7: Pester 1483 passed/1 skipped, Python 142 ran/1 skipped; zero failures/outside-scope cases. These are distinct source scopes; Full was not repeated for later documentation/controller-only edits. Retain the initial long-path/controller failures and successful shorter-path replays separately. Short local extraction/output paths are the remedy; no universal path limit or global security change is claimed.

CI at `1f10940ee970ebe719c21ba0e7290830beeb7123` is pending (0/4 observed jobs); [observed run](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37182513533). Pending/unavailable/not-run CI is not a passed gate. Live branch synchronization and actual post-push PR/CI must be verified separately.

All eight broader gaps remain. Original/Fast/default sound and BAT/script entry points stay unchanged; no publication or machine-security changes are authorized. Website draft metadata remains uncreated future M5-01 work.

[Evidence](evidence/WAC-M4-04.md), [ledger](evidence/WAC-M4-04-validation.json).

## Historical M4-04 implementation checkpoint (superseded)

# Current status

WAC-M4-04 final package walkthrough is in progress on 2026-10-04. Both local Full gates and all four code CI jobs passed at `047aefe906ca7954a225d81f53286eb1275723dc`. Canonical 25 done/5 todo and 75 pass/15 not_run remain unchanged. Final 64-case clean-ZIP examples/support/defaults validation is required after the reviewed documentation/controller corrections. Retain all initial failures, path replays, privilege skips and eight broader gaps. [Evidence](evidence/WAC-M4-04.md).

## Historical M4-04 initial implementation progress (superseded)

# Current status

Date: 2026-10-04. **WAC-M4-04 implementation and validation are in progress.**
Canonical 25 done / 5 todo, 75 AC pass / 15 not_run remain unchanged. README,
complete parameter help, support/security and their package inclusion are
implemented. Exact clean-ZIP example/failure walkthroughs and cumulative
checks remain required. All eight broader gaps and default sound are retained.
[Current evidence](evidence/WAC-M4-04.md). Next remains completion of M4-04.

Parent `33efc4a2f589927203997d65f76096f46bfe3c65` is live-synchronized; its four
PR CI jobs passed in run 37152237090. No publication/merge/deployment occurs.

## Historical M4-03 closure (superseded)
# Current status

Date: 2026-10-03. **WAC-M4-03 is complete.** Canonical 25 done / 5 todo / 0 blocked;
75 AC pass / 15 not_run. **Next: WAC-M4-04 — Finish user-facing help, setup and
troubleshooting**, unlocked and not started. All eight broader gaps remain.

Clean code `4609265b1ed40da08897d7d816196ec466adaef0` produced four identical tool-only version 2.3 ZIPs
(447048 bytes, SHA256 `e72fce6cae5d0e94473bde1b94657e778a472c6ff17aa6a2065c795438bf604c`). The 15 committed payload files plus generated
manifest, checksum and provenance agree; MIT bytes are preserved. Eight real
BAT/PowerShell and four separately scoped builtin-only fresh-package cases pass.
FFmpeg remains supplied separately and bundling unapproved.

Both local Full gates passed Pester 1483 / 1
privilege skip, Python 142 ran / 1 privilege skip;
zero outside scope and stable seven source digests. Four code PR CI jobs passed:
[run 37150442388](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37150442388). Closure metadata CI is distinct and must be
read at its actual future SHA. Runtime/defaults/source-only original stay intact.
[Evidence](evidence/WAC-M4-03.md), [ledger](evidence/WAC-M4-03-validation.json).

## Historical M4-03 implementation checkpoint (superseded)

# Current status

Date: 2026-10-03. **WAC-M4-03 implementation and validation are in progress.**
Canonical24 done/6 todo,72 AC pass/18 not_run remain unchanged. Build tooling,
portable instructions and tool-only dependency notices are being validated.
Clean-revision repeated packages, extracted-package processing and both local
Full gates are required before acceptance. Next remains completion of M4-03;
M4-04 has not started. All eight retained gaps and runtime defaults remain.
Parent f32cf159 PR run37148623973 completed all four jobs successfully;
this does not stand in for M4-03 evidence.

[Current evidence](evidence/WAC-M4-03.md).

## Historical M4-02 closure (superseded)

# Current status

Date: 2026-10-03. **WAC-M4-02 is complete.** Canonical24 done/6 todo/ 0 blocked;
72 AC pass/18 not_run. **Next: WAC-M4-03 — Build a versioned portable release
package**, unlocked and not started. Coverage retains all eight broader gaps.

Tested code `c5a107e825bfa087f6b21f96dd54e91e538b1890` passed both local Full gates (Pester 1467 passed/1 skipped; Python 134 ran/1 skipped) and
all four Windows2022/2025 PS5.1/PS7 PR jobs (Pester 1468 passed/0 skipped; Python 134 ran/0 skipped): [PR run 37147112528](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37147112528).
Every Full has zero outside-scope cases; hashes, pinned versions and sanitized
seven-day artifacts agree. Missing shells/API errors/unrun CI cannot pass.
Earlier failed captures and their separate source identities remain retained.

CI uses verified Action/checksum pins, contents:read and the existing local
runner. The necessary native-start fix prevents an injected stdin BOM and
preserves intended input bytes/restores encoding. A bounded PID-ready fixture
handshake preserves ownership and deadline assertions. Source-only original,
BAT entry points, filters/defaults and settings remain unchanged. Local privilege
skips and all broader listening/manual/stress/crash gaps retain their scope.

[Evidence](evidence/WAC-M4-02.md), [validation ledger](evidence/WAC-M4-02-validation.json).

## Historical M4-02 implementation checkpoint (superseded)

# Current status

Date: 2026-10-03. **WAC-M4-02 implementation validation is in progress.**
Windows CI and its pinned setup/parity/status tooling are implemented. Both
actual local Quick gates passed 1075/0/1; the five setup tests are included.
53 focused Python cases and an actual unavailable-shell simulation passed
their stated scopes. Both local Full gates at `fd56b84` passed 1461 Pester,
one privilege skip and 128 Python cases with one privilege skip. Initial PR
run 37143282084 at that exact SHA passed both PS7 jobs but failed both PS5.1
jobs. Diagnostic run 37144796506 at `8af62ff` identifies three stdin assertions
failing on both PS5.1 hosts; both PS7 jobs pass. An owned local reproduction
confirms .NET Framework injects a UTF-8 BOM into redirected stdin, including
empty input. A narrow native-start fix passes all six fresh-process encoding
cases in both shells. The broader native-tagged Targeted run passed 203 on PS7
and failed one cancellation fixture case on PS5.1 (202 passed). Its timer could
cancel before the PID file was written; a seven-case unchanged recovery passed.
A bounded, deterministic fixture readiness correction passed exact-path Targeted
63/0/0 on each shell, with20 outside scope and stable source hashes.
Fresh local and hosted Full gates are still required; all failed evidence is retained.
WAC-M4-02 remains todo and AC-070..072 not_run until those results are reconciled.
The implementation checkpoint does not advance to packaging. Source-only
original/defaults remain unchanged. The runtime change is limited to preventing
the confirmed stdin prefix. See [evidence](evidence/WAC-M4-02.md).

## Historical M4-01 status (superseded by current progress above)

# Current status

Date: 2026-10-03. **WAC-M4-01 is complete.** Canonical 23 done/7 todo/ 0 blocked;
69 AC pass/21 not run. Coverage maps 69 cases, 35 command scopes, eight named
reviews and eight retained broader-scope gaps. **Next: WAC-M4-02 only.**

Both PS5.1/PS7: Quick 1070/0/1, selected Targeted 290/0/0,
one Full 1456/0/1; Python 75 discovered successful with one privilege skip.
Parser/static/plan/coverage gates pass; non-gating advisories remain. Three
baseline passes and three intended mutant failures per host plus five cleanup
safety cases certify isolated representative faults. Source is stable across
accepted gates. Preview close-fault tests pass9/0 per host; old loop fails0/9.

Only Preview report close handling changed; all other runtime/BAT LF contents,
filters/defaults/ownership/configuration/cancellation contracts match M3 closure.
Preserved initial harness/fixture/publication corrections and truthful scopes
are in [evidence](evidence/WAC-M4-01.md) and its source/gate/fault ledgers.
Saved settings remain absent; no user audio or personal logs are published.
Listening/picker/platform/stress/crash/power-loss/real unreleased-writer and
privileged-symlink gaps remain visible. No CI/package/merge/release/deployment.

## Historical M3-06 closure (superseded by current status)

# Current status

Date: 2026-10-03. **WAC-M3-06 is complete.** AC-064 now passes: user-reported
actual Explorer drops/menu/playback in modes 1/2 and independent verification of
both local SUCCESS/exit-0/complete reports and published WAV headers. Canonical:
22 done/8 todo/ 0 blocked; 66 AC pass, 24 not run. **Next: WAC-M4-01**, unlocked
but not started. AC-065/066 retain their earlier evidence.

The initial unquoted-parentheses drop rejection and neutral-name copy/retry are
recorded; no punctuation guard, runtime, test, filter or default changed. All nine
manual runtime copies match a30e235; all 66 tested physical source hashes remain
unchanged. The manual runs used ordinary Music output. Raw reports, interview
paths/metadata and audio remain private/local; saved preferences remain absent.
No formal sound promotion, picker gesture, broad stress/crash/power-loss or
inherited Preview writer-close fault acceptance is added. The previous cumulative
gate was not repeated; closure used report/header/source/privacy and plan checks.

[Current evidence](evidence/WAC-M3-06.md),
[manual outcomes](evidence/WAC-M3-06-manual.json).

## Historical M3-06 blocked checkpoint (superseded on 2026-10-03)

# Current status

Date: 2026-10-03. **WAC-M3-06 engineering checks are complete; the task remains
blocked on AC-064's manual interview drag-and-drop workflow.** AC-065 automation
and AC-066 fresh clean-checkout/absent-preference reentry pass. Canonical:
21 done/8 todo/1 blocked; 65 AC pass, AC-064 blocked, 24 not run. M4-01 is locked.

Runtime, tests, sound/defaults, launcher and product contracts are unchanged.
Cumulative Targeted once per host: 749 pass/0 fail/1 file-symlink privilege skip;
parser/static/plan pass, 273 non-gating advisories remain. Full/Python unittest
suite were not rerun. Actual synthetic BAT/PTY modes 1/2 passed 4/4 across both
hosts with four PCM matches. Combined automation accepts ten cases (eight initial
plus two corrected manifest probes); fresh detached-clone reentry passes 2/2.
Initial menu-host and harness-only report-count/path/prompt corrections remain
recorded. Explicit isolated SettingsPath is required: APPDATA alone does not
relocate the Windows known folder. No actual user Music/settings writes.

No cleared interview/manual Explorer result was supplied; synthetic console
proof does not waive that acceptance. No human listening/default promotion,
picker gesture, broad stress/crash or inherited Preview writer-close fault
recovery is claimed. **Next: finish WAC-M3-06/AC-064 only.**

[Evidence](evidence/WAC-M3-06.md), [gates](evidence/WAC-M3-06-gates.json),
[source](evidence/WAC-M3-06-source.json), [menu](evidence/WAC-M3-06-menu.json),
[automation](evidence/WAC-M3-06-automation.json), [reentry](evidence/WAC-M3-06-reentry.json).

## Prior M3-05 checkpoint

Date: 2026-10-03. **WAC-M3-05 is complete.** Canonical 21 done/9 todo;
AC-001..063 pass their recorded engineering scopes. **Next: WAC-M3-06 only.**

Music/default and explicit chosen destinations remain. Optional JobFolder groups
one invocation with held atomic new media/report directories. No-input console
usage, explicit optional STA picker and identity-checked destination opening
preserve ordinary unattended operation. Cancelled picker/unattended action/failure
gates avoid processing or false completion. Flat reports retain the canonical
held destination; explicit journal overrides and queue contracts remain.

Interaction 48 cases pass per host within final Targeted;
dedicated PS 5.1 capture's 47/1 timeout and isolated 1/0 recovery remain recorded. Layout 10
and new Preview 2 selected pass per host. Final Targeted 222; required Full 1442 pass/1 file-symlink privilege skip Pester
and Python 61 pass/1 separate privilege skip per host, exit 0 and frozen source guards.
Real media 44/44, 38 PCM comparisons/38 WAVs; precise scopes/hashes
and preliminary runtime/fixture/harness failures are retained. Original audio,
native cancellation and launcher contracts remain. No actual user Music/settings
writes, manual picker/Explorer gesture or listening approval is claimed.
The prior M3-04 native-console proof was not rerun; crash/stress limits remain.

[Evidence](evidence/WAC-M3-05.md), [source](evidence/WAC-M3-05-source.json),
[gates](evidence/WAC-M3-05-gates.json), [focused](evidence/WAC-M3-05-focused.json),
[media](evidence/WAC-M3-05-media.json), [preservation](evidence/WAC-M3-05-preservation.json).

## Prior M3-04 checkpoint

Date: 2026-10-03. **WAC-M3-04 is complete.** Canonical20 done/10todo;
AC-001..060 pass their recorded engineering scopes. **Next: WAC-M3-05 only.**

FFmpeg structured progress, separate diagnostics, stage/file position and bounded
media-time ranges are implemented. Complete100 follows held publication only.
Owned active cancellation shares one controller through sequential queues,
preserves earlier outputs/static records, prevents pending starts and persists
CANCELLED130. Accurate verification cancellation prevents publication. Per-run
schema1 gains progress and failed-preview reports; journal schemas stay intact.

Final focused77 and required Full 1382 pass/ 1 privilege skip Pester
per host, Python61 pass/one separate privilege skip, parser/static/plan exit0.
Actual private-console native signals4/4 and final real media20/20 cover both
PS5.1/PS7 with exact hashes/commands and preserved corrections. Sound helpers and
IO/Settings/Queue/BAT/Launcher are unchanged; no user settings were written.
Unperformed UI typing/listening, window-close/crash and long-stress limits remain.

[Evidence](evidence/WAC-M3-04.md), [source](evidence/WAC-M3-04-source.json),
[media](evidence/WAC-M3-04-media.json), [console](evidence/WAC-M3-04-console.json),
[focused](evidence/WAC-M3-04-progress-focused.json).

## Prior M3-03 folder checkpoint


Date: 2026-10-03. **WAC-M3-03 is complete.** M0/M1/M2 remain complete;
AC-001 through AC-057 pass their engineering contracts. Nineteen tasks are
done;11 remain todo. Human listening/default promotion remain unperformed.

**Next: WAC-M3-04 — Add stage-aware progress and controlled cancellation.**
Start separately after fresh synchronization. No merge is required to unlock it.

## M3-03 frozen folder queue checkpoint

Direct PowerShell InputDirectories adds opt-in Recurse through optional Queue,
with a bounded snapshot before jobs. Local ordinary directory/file handles,
volume/file identity deduplication, strict generated-name/alias exclusions,
destination-subtree skips and source identity/size/mtime checks preserve queue
membership. Reparse entries are explained/skipped without descent; invalid roots,
enumeration failures or incomplete scans reject before native jobs. Explicit
lists retain repeats/schema1 and BAT/Launcher remain unchanged.

Folder schema2 adds selection provenance/source snapshot, skip reasons/counts.
Per-file failures continue; returned cancellation stops pending starts while
static skips/preflight failures remain. Aggregate cancel130/failed6/warning7/
success0; journal failure5 retains earlier audio/records and discloses incomplete
reporting. Empty/allskipped snapshots write summaries without mode/native work.

Final focused 156 pass/1 skip and cumulative
Full 1330 pass/1 skip Pester per host, exit0. Python62
discovered each:61 pass, one Windows symlink-privilege skip. Parser/static/plan
pass; non-gating advisories remain visible. Final real-media folder scope,
retained preliminary corrections and exact hashes/commands are linked below.
Default user settings were never written; audio/ownership/filter defaults stay
frozen. Returned-exit130 tests do not establish active Ctrl+C or listening.

[Evidence](evidence/WAC-M3-03.md), [manifest](evidence/WAC-M3-03-source.json),
[media](evidence/WAC-M3-03-media.json). Canonical19 done/11todo; nextM3-04 only.

## Prior M3-02 ordered launcher and list checkpoint

Existing BAT now captures ordered paths as environment data through an optional
Launcher sibling. Fresh CMD framing/count/token checks reject ambiguity and
observable percent/exclamation text; literal environment/manifest fallback
preserves those filenames. Default inner PS5.1 and selected PS7 are covered.
Single/unattended compatibility and exit-before-one-pause behavior remain.
No-input guidance, 7600-character budget, 1024-item cap and manifest fallback
are explicit; no manual Explorer gesture or universal CMD safety is claimed.

Optional Batch supports typed InputPaths and strict schema-1 UTF8 InputListPath,
1MiB/1..1024 entries. Relative paths anchor beside the manifest, including invalid
strings that become per-item failures. Preferences resolve once and mode is chosen
once. Ordinary single-file jobs retain sound/report/ownership behavior. A held
CreateNew JSONL journal flushes header/items/summary, continuing ordinary failures,
stopping cancelled/persistence-failed lists and preserving prior outputs/results.
One-item exits remain compatible; multi failure6/warnings7/success0/cancel130,
journal failure5. Explicit repeats/order remain; its historical folder queue scope is now covered by M3-03.

- Final Batch focused73 and additional invalid-path4 per host, transport33,
  legacy Launcher targeted58; required Full1251 Pester +62 Python discovered
  each (61 pass, one symlink-privilege skip). Parser/static/plan pass; visible
  non-gating advisories remain recorded. Final wrappers exit0 and code is stable.
- Final API28/28 real calls,32 assets,26 exact PCM/frame/graph comparisons and
  six direct references. Final BAT6/6 calls plus 4/4 direct references,20 assets,
 16 exact comparisons. Both inner hosts, real pinned FFmpeg, isolated configs.
- Strict manifest/CLI checks, persistent valid-invalid-valid, relative pipe/NUL
  failures, settings freeze, one mode prompt, native diagnostics/append rollback,
  cancellation/not-started and worker startup3/one-pause pass bounded checks.

[Evidence](evidence/WAC-M3-02.md), [manifest](evidence/WAC-M3-02-source.json),
[Batch scopes](evidence/WAC-M3-02-batch-evidence.json),
[launcher scopes](evidence/WAC-M3-02-launcher-evidence.json),
[API media](evidence/WAC-M3-02-media-api.json),
[BAT media](evidence/WAC-M3-02-media-launcher.json).
Keep earlier bound-dictionary, diagnostic-relay, fixture, worker-pause and
invalid-path failures/scope corrections. Preserve canonical history, especially
M1-02 policy/resumption and all prior M2/M3 failures/limits.

## Prior M3-01 preferences checkpoint

Typed per-user schema1 preferences, CLI > saved > built-ins, origins/display,
explicit Save/Reset/Ignore, strict whole-file validation and held atomic storage
remain. Normal execution never autosaves; imports remain IO-only. The previous
123 Settings +80 EntryPoints focused/1141 Pester Full and real Original20/20,
settings68/68 with18 PCM pairs remain in [M3-01 evidence](evidence/WAC-M3-01.md).
Final current Full covers unchanged Settings/EntryPoints again.

## Preserved behavior and limits

Pre-existing main helper bodies and full processing suffix plus IO/Settings/
Preview remain unchanged from M3-01. Original original/1.0.0 stays built-in;
Gentle gentle/0.1.0 stays opt-in Raw-only experimental. Application2.3/report1,
Fast default, Accurate warnings/checks, PCM16/24/mono/RF64, owned publication and
bounded explicit preview remain. Actual user preferences were never written.

Real CMD boundary checks do not certify a manual Explorer drop. Earlier outer
CMD percent expansion can execute before the BAT starts; documented exact
manifest/environment fallback is required. Active-render Ctrl+C, crash/power-loss
atomicity, speech listening/calibration, >4GB/disk exhaustion, long-file/memory
stress and universal codec seeking remain unverified. Cancellation media uses
a labeled copied dispatch seam. Positive integrated/threshold values remain
unsupported meter failures; inherited M2 seek/latency/formatter limits persist.

## Checkout and delivery

Maintained WinAudioClean-governance, `codex/wac-m3-settings`; source-only original
untouched. Exact origin `https://github.com/PikkuJanne/WinAudioClean.git`.
Existing M3 draft#4 stacks on M2 `codex/wac-m2-audio` draft#3, itself on unmerged
M1#2/M0. Verify completion SHA/live draft/CI after push; no workflows/checks
currently exist. No merge/release/default promotion/security change/deployment.
