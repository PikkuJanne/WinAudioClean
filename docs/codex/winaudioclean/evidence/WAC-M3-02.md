# WAC-M3-02 evidence — ordered explicit lists through the existing BAT

Date: 2026-10-03. Started from clean, live-synchronized `33dc8b1dde8bb957fc221442e027991a895a85f6` on
`codex/wac-m3-settings`, open draft PR#4. Exact fetch/push origin is
`https://github.com/PikkuJanne/WinAudioClean.git`; PR#4 remains stacked on
`codex/wac-m2-audio` (draft#3), itself on unmerged M1/M0. The source-only
original checkout is untouched. The accepted commit/live/PR SHA is verified
and recorded after push outside this commit.

## Engineering acceptance and actual transport scope

AC-052: real fresh CMD/BAT/PowerShell boundary checks preserve one/many typed,
ordered inputs, including spaces, Unicode, brackets, ampersands, apostrophes and
parentheses. Both default inner PS5.1 and explicitly selected PS7 are exercised.
Literal percent/exclamation names take the exact environment/manifest route.
Observable positional `%`/`!`, count/token disagreement and ambiguous/nested
frames reject before application work with actionable guidance. A controlled
outer-CMD percent expansion can execute a sentinel before any BAT starts; its
failure proof remains recorded. Capturing the raw line cannot undo that earlier
expansion. The engineering acceptance includes the explicit safe fallback
required by the task's command/special-character guardrail; **no manual Explorer
gesture or universal positional-shell safety is claimed**.

AC-053: explicit typed arrays and strict bounded schema-1 UTF-8 manifests use
ordinary single-file processing in original list order. Missing and invalid
paths produce persistent item failures and subsequent valid items run.
PS5.1 pipe/NUL relative-path validation now occurs per item, retaining the exact
text after manifest-directory anchoring, rather than aborting the whole list.
Resolve saved/CLI/built-in preferences once and choose omitted mode once; children
ignore saved reads. Explicit repeats are retained. Single-file routes remain
compatible. Folder discovery, recursion, deduplication and generated-output
exclusion remain WAC-M3-03.

The held CreateNew JSONL writer flushes header, each item, and terminal summary.
It never replaces an input/manifest/prior journal and never scans for or claims
foreign detailed reports. Bound diagnostics include native-failure context.
One-item lists preserve the ordinary code; multi-item failure gives6, warnings
alone7, all success0, cancellation130. Cancellation stops future starts and
records NOT_STARTED. Journal failure gives5, stops later jobs, preserves prior
exports/records and rolls back only an attempted suffix where possible. Storage/
crash or active interruption does not establish multi-file atomicity.

AC-054: real many/long-path CMD cases and no-input guidance pass. The raw frame
budget is below7600 characters:7599 accepts,7600 rejects. A9000-character probe
hits CMD's own limit without running the application;1024/1025 item boundaries
are checked. The manifest limits are1..1024 entries and1MiB including optional
UTF8BOM, strict keys/integer-version/types/duplicate/UTF8 validation. A manifest
with120 long entries exceeds8191 aggregate path characters yet arrives exactly,
through a short environment control route. Original Microsoft CMD8191 limit:
[documentation](https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/command-line-string-limitation).
Interactive pause occurs once after saving the application code, including130
and selected-worker startup3; unattended routes do not pause. Helper-less prior
single/environment compatibility is retained.

## Required gates on final frozen source

- Batch Pester-only final73/73 per host; after a narrow anchoring review fix,
  four additional invalid-path regressions pass per host. Full uses77 cases.
- Launcher transport focused33/33 per host. Prior32-case initial scope had
  two Pester data-name failures; every real CMD case passed then. The added
  worker-start regression proves3 plus one pause/no application.
- Cumulative legacy Launcher targeted58/58 per host, exit0, including unchanged
  helper-less entry contracts and isolated settings fixture.
- Required Full: **1251 Pester passed per host**, zero failures/skips; **62 Python
  discovered per host**,61 pass and one symlink-privilege skip. Parser/static/plan
  gates pass; exact file/advisory counts appear in the logs/manifest. PS7 prints
  all non-gating analyzer advisories. Both wrappers exit0 and all maintained
  code/test bytes remain stable across the captured scopes.

Windows PowerShell5.1.26100.9444, PowerShell7.6.5, Python3.14.6, Pester5.7.1,
PSScriptAnalyzer1.24.0 and existing pinned FFmpeg/ffprobe9.0.2 were used. Python
children remove inherited PSMODULEPATH. No install/security setting changed.
Full does not run the separate real-media matrices. Post-canonical plan
validation is captured separately. [Source/commands/log hashes](WAC-M3-02-source.json),
[Batch scopes](WAC-M3-02-batch-evidence.json),
[launcher scopes](WAC-M3-02-launcher-evidence.json),
[smoke history and harnesses](WAC-M3-02-smoke.json).

## Real synthetic audio and retained development history

Final API matrix on C2CF:28/28 actual invocations pass,32 assets,6 direct
single-file references and26 exact decoded PCM/frame/graph comparisons.
Actual exits:10x0,2x6,6x7,6x2,2x130,2x5. It covers Raw/Zoom, Original/Gentle,
PCM16/24, saved false/empty overrides, stream selection, relative/repeated/
literal-name manifests, default/explicit journals, valid-missing-valid,
Accurate warnings and foreign-result protection in PS5.1/PS7. Cancellation
uses a labeled copied-helper dispatch simulation after a real completed item;
active-render Ctrl+C is unverified. Config, fixture, tool, copies and maintained
product-source immutability guards pass.

Final full-application BAT integration on C2CF/0FAC/6E27:6/6 launcher calls and
4/4 actual direct Raw/Zoom references pass,20 assets and16 exact PCM/frame/graph
comparisons. Each inner host covers saved-mode positional two-file input,
manifest literal punctuation/percent/exclamation input, and unattended
valid-missing-valid continuation. BAT exits4x0/2x6; reference exits4x0. All
source/tool/config/fixture/copy guards pass. [API metadata](WAC-M3-02-media-api.json),
[BAT metadata](WAC-M3-02-media-launcher.json),
[preliminary scopes](WAC-M3-02-media-preliminary.json),
[reproducible harnesses](WAC-M3-02-media-harnesses.json).

Retained corrections: the initial bound-dictionary overload bug; two held-reader
test-sharing failures and one real missing failure-diagnostic case (initial
Batch70/73 per host); reserved PSHOST relay rejection (corrected Batch68/73 and
corrected real-media12/26); corrected relay Batch73/73 and media28/28; transport
unit `$Input` collision; worker-start pause ownership; and final PS5.1 relative
invalid-path anchoring. Earlier green API/BAT scopes captured DA98 and are kept
as preliminary after the C2CF fix. Preliminary probe encoding/framing mistakes
and outer-CMD sentinel execution are recorded honestly; no successful count is
substituted for a failed or unrun scope. Raw local hashes are distinct from
sanitized public derivative hashes; private full reports/audio remain ignored.

## Preservation, limits and delivery

Normalized pre-existing main helper region and full processing suffix exactly
equal M3-01; IO/Settings/Preview bytes stay unchanged. Original original/1.0.0,
opt-in experimental Raw Gentle gentle/0.1.0, application2.3/report1, Fast default,
Accurate checks/warnings, output ownership/encoding and bounded explicit preview
remain. Exact PCM parity is same-input/build evidence, not listening approval.
Actual default user settings were absent and never written; all fixtures/configs
are isolated. No private audio or personal paths are published.

Manual Explorer gesture, speech listening/default promotion, active-render Ctrl+C,
power-loss durability, disk exhaustion/>4GB, long-file memory stress and universal
codec seeking remain unverified. Preserve inherited M2 seek/latency/formatter and
unsupported positive integrated/threshold meter limits. No workflow/check result
is invented; live PR/CI and clean local/upstream/live equality are verified after
push. No merge/release/security/repository-setting/deployment/default promotion.
Update only M3-02 and AC052..054 canonical status/evidence; preserve all prior
history, especially M1-02 policy/resumption and M2/M3 preliminary failures.
Next is **WAC-M3-03**, separately synchronized.
