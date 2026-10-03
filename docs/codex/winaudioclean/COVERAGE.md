# Acceptance coverage and retained gates

[COVERAGE.json](COVERAGE.json) maps AC-001..069 and the current WAC-M4-02
AC-070..072 to concrete commands, existing reports or named reviews. It keeps
historical evidence in place rather than duplicating its detailed case logs.
The map contains 72 cases, 38 command scopes, eight named reviews and eight
retained gaps.

Canonical acceptance remains [ACCEPTANCE.json](ACCEPTANCE.json). A command in
this inventory means runnable coverage is available. It does not mean the
command ran during M4, that a human review happened, or that every part of the
original procedure passed. Referenced evidence identifies the tested revision,
content hashes, host/tool versions, actual commands/exits and engineering scope.
[WAC-M4-01 evidence](evidence/WAC-M4-01.md) retains regression/fault results;
[WAC-M4-02 evidence](evidence/WAC-M4-02.md) records CI/local parity separately.

The named reviews distinguish record completion from audition. AC-009 checks
private corpus handling; AC-042 allows an explicit unavailable-corpus record;
AC-047 checks human-gate integrity. Their engineering passes do not establish
speech quality. AC-064 now has the user's actual two-mode Explorer/menu/playable
output observations plus independent report/header/source checks. Its first
unquoted parentheses input was rejected and its neutral-name retries passed.
That workflow evidence does not promote a preset or certify the larger
punctuation/multiple-file Explorer gesture matrix.

## Reusable validation

Run from the repository root:

```powershell
python -X utf8 scripts/Test-Coverage.py --repo .
python -X utf8 -m unittest discover -s docs/codex/winaudioclean/tests -p test_coverage.py -v
```

The validator is read-only. It requires coverage for every canonical completed
task and the current map task, rejects unknown/duplicate IDs, stale titles/task
associations, missing command files/reports, unsafe references, empty support
and undisclosed gap links. Named reviews must state scope and status. Retained
gaps require a reason and a concrete future acceptance gate. The validator
does not run native/audio tests, infer pass from a file's existence or substitute
for reviewing the relevance of the evidence.

`scripts/Invoke-Tests.ps1` invokes this check after plan validation for Quick,
Targeted and Full. Full also discovers the validator's unit tests. The unit
tests deliberately reject missing/stale/malformed evidence and hidden gaps in
disposable directories; they verify validation itself writes no files.

Command strings beginning with `&` are PowerShell script expressions, including
literal arrays for multiple Pester paths. Run them inside a fresh supported
host, with process-only policy where needed:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/Invoke-Tests.ps1 -Level Quick"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/Invoke-Tests.ps1 -Level Quick"
```

Look up a case's command IDs in `commands`; each command identifies the exact
runner/suite files. `m4-targeted` selects PreviewReportClose, Preview, FaultChecks,
Native, Transaction, Encoding and ReportIO. `mutations` invokes the separate
isolated overwrite/bad-exit/wrong-sample-rate check. `full` has no filters.
PS5.1 and available PS7 results must be recorded separately.

The media commands use the already installed pinned FFmpeg/ffprobe 9.0.2 path
recorded by earlier tasks. They require a new ignored output directory on each
run; change the supplied output path for a rerun. They do not download tools.
Full Pester/Python regression does not run these standalone real-media matrices.
Their existing historical reports remain the evidence unless a new scoped
matrix actually runs. Parser/help inspection verifies the inventory's option
names without claiming new processing results.

## Mandatory gaps that remain visible

These are required gates before the corresponding broader claim or action.
They remain unrun rather than waived; they do not erase the narrower recorded
engineering results. Inspect each gap's affected AC IDs and evidence in the map.

| Gap | Required disposition before a broader claim |
| --- | --- |
| Formal speech listening | Cleared level-matched Original/Gentle/custom comparisons, attributable per-clip observations, exact settings/revision and explicit approval before default-sound promotion. AC-064 user playback accepts its own workflow only. |
| Explorer filename/multiple-file matrix | Actual gestures and truthful CMD punctuation limitations. Native/launcher transport checks are not all manual Explorer gestures. |
| Picker and open-folder gestures | Actual selection/cancellation and requested Explorer follow-up on the active host. Controlled helper tests establish policy only. |
| Large/storage/memory stress | Extended >4 GB exports, actual volume exhaustion, long recordings and the specific long-path/UNC/storage claims sought. Small RF64 headers and simulated low space do not certify full-size behavior. |
| Host crash/console close/power loss | Specific console-window close/logoff/forced-host-kill and durability evidence. Actual private-console Ctrl+C/Break establishes only its recorded cancellation scope. Owned crash leftovers may remain; there is no accepted multi-file atomicity guarantee. |
| Privileged file symlink | Record the real privilege skip separately; only a performed supported fixture can establish its result. Existing junction/hardlink/reparse coverage remains available. |
| Meter/seek/reproduction domain | Independent meter/domain and arbitrary-codec/cross-build evidence before broadening current claims. Positive integrated LUFS remains outside the parser domain, selected container seeking has documented sample uncertainty, and bounded preview context may differ from a full render. |
| Unreleased Preview report writer | Actual OS/uncooperative-stream refusal to release a writer handle needs separate recovery evidence. Post-dispose fault doubles release the real inner stream before throwing. |

The former Preview writer-close fault is now explicitly exercised by
`WinAudioClean.PreviewReportClose.Tests.ps1` under AC-030/045/068. Its actual
fault and cleanup outcomes belong to the current M4 evidence, not this
inventory. Those doubles prove later close attempts and truthful outcomes;
the real unreleased-handle recovery gap remains explicit. OS version support is limited to the recorded active host;
another Windows release or unavailable shell never becomes passed by analogy.
Analyzer advisories and fixture privilege skips remain distinct from failures.

For later tasks, extend the map when canonical implementation advances and
retain relevant gaps until there is specific evidence or an explicit approved
disposition. Keep raw audio, full diagnostics, private paths and source mappings
local/ignored. Do not update this inventory during a frozen-source gate; reconcile
new documentation/evidence after preserving the tested content hashes.
