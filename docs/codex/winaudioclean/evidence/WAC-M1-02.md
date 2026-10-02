# WAC-M1-02 — Native execution, launcher status and diagnostics

Date: 2026-10-02. **Implemented; blocked at the cumulative validation gate.**
Do not advance to M1-03. This checkpoint preserves implementation and evidence;
it does not claim complete engineering acceptance.

## Starting checkpoint and changes

The source-only starting folder was preserved. The established Git checkout was
clean on `codex/wac-m1-reliability` at
`116380c0f6f722e5ff116b6aafc348c0fabdd9e5` (accepted M1-01). Fetch succeeded;
local/upstream/live branch and draft PR #2 heads matched. Effective fetch/push
origin was `https://github.com/PikkuJanne/WinAudioClean.git`. PR #2 is stacked on
`codex/wac-m0-handoff` while M0 draft PR #1 is unmerged. No CI checks exist.

- `WinAudioClean.ps1`: individual argument construction and Windows CRT quoting;
  direct resolved `.exe` launch; concurrent independent stdout/stderr reads;
  closed stdin, FFmpeg `-nostdin`, bounded cleanup and explicit reader/process
  disposal; structured startup/native/capture/cleanup results. Reporting errors
  retain native status and audio, and show useful diagnostics.
- `WinAudioClean.bat`: fixed PowerShell code reads paths as environment data;
  system Windows PowerShell is pinned. Status is saved before interactive pause.
  `/unattended Raw|Zoom` takes environment paths and skips pause. Positional CMD
  percent/exclamation limitations have a clear direct/environment fallback.
- Native, launcher, reporting and expanded entry-point tests use a benign C#
  executable compiled with the installed Windows Framework compiler. This is
  development-only; no binary is committed. Obsolete mocked native fixture
  `Invoke-ControlledApplication.ps1` was removed. Test harnesses use child-only
  environment overrides and preserve trailing separators.
- README, test instructions, native contract, D21, task/acceptance state and
  next-model handoff describe the behavior and the validation blocker.

Application exits: **0** native success/report complete; **2** input/config;
**3** dependency/start; **4** native/capture/cleanup failure; **7** native success
with incomplete reporting; **130** menu cancellation. Native exit and both
diagnostic streams remain separate. Code 130 is not a tested running-render
cancellation contract. Exit 0 does not independently validate output media.

Exact Raw/Zoom filters, unspecified encoding and `-y`/timestamp collisions remain
unchanged. Probing is M1-03; safe output publication is M1-04; encoding is M1-05.
No runtime Python, cloud, telemetry or dependency download was introduced.

## Environment and commands

Windows NT 10.0.26300.0; Windows PowerShell 5.1.26100.9444; PowerShell 7.6.5;
Python 3.14.6; checkout-local Pester 5.7.1 and PSScriptAnalyzer 1.24.0.
Fixture compiler: installed .NET Framework csc 4.8.9221.0
(NET481REL1LAST_25H2). No dependency installation or persistent policy change.

From the repository root:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Helpers.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.EntryPoints.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Launcher.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Reporting.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Native.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Native.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

Targeted results: helpers 13 passed; entry points initially 46, then 64 passed
after adding the direct filename matrix; launcher 58 passed; reporting 8 passed;
native 21 passed per shell before two rejection cases were added. Passing runs
returned 0. Native targeted output is summarized from the tool transcript in
the policy JSON; a separate raw targeted native log was not retained. Launcher
and reporting targeted counts also come from observed tool results. Full logs
retain the later complete case listing. These are distinct observations, not a
substitute for a successful cumulative gate.

### Full results and policy investigation

Both Full runs executed 227 Pester cases on the same runtime/launcher source:

| Host | Passed | Failed | Skipped | Runner exit |
| --- | ---: | ---: | ---: | ---: |
| PS5.1 | 167 | 60 | 0 | 1 |
| PS7 | 220 | 7 | 0 | 1 |

The runs did not reach their Python stage. All 23 Native tests passed in each
run. Parser, static and plan gates passed in both; 53 analyzer advisories remain
visible. No rule was suppressed. Advice concerns console output, helper naming,
Pester setup variables and test fixture command parameters.

Read-only event inspection correlated the 2026-10-02 13:10:51–13:13:45
Europe/Berlin validation interval:

- **44 distinct launcher fixture copies** matched all 44 PS5.1 launcher
  failures: 76 Code Integrity event 3077 records, each paired with event 3033.
- **Seven reporting fixture copies** matched all seven PS7 failures: seven
  event 3077 records, each paired with 3033.
- All 83 events of each type concerned compiled test `ffmpeg.exe` copies, not
  the existing real FFmpeg distribution. Windows reported enterprise signing
  level/code integrity policy violations. The original assertions omitted the
  wrapper error text, so that text cannot be recovered from these Pester logs.
- The remaining **16 PS5.1 failures** were test-side JSON parsing: wrapping
  `ConvertFrom-Json` in `@(...)` nested the returned array and produced Count 1
  instead of 12. The direct assignment was corrected in EntryPoints/Launcher;
  recorder JSON is explicitly UTF-8. Child failure assertions now include
  stdout/stderr; Native assertions include `result.Error`.

An earlier PS5 native targeted run also had 19 policy-blocked child starts and
two passing structured-failure cases. Before the policy diagnosis was complete,
later fresh fixtures executed; a separate test-array correction then gave 21
passing cases per shell. This was not a demonstrated policy fix. No blocked
fixture execution was retried after the Full-run diagnosis. No security policy,
trust, exclusion, signing or persistent environment setting was changed.

The sanitized correlation is in `WAC-M1-02-policy.json`. Raw event records include
machine paths/identifiers and remain ignored locally. The failed full logs are
committed with private paths and terminal formatting removed. Failures were not
converted to skips, and acceptance is not inferred from earlier passing runs.

### Checks after the test-only corrections

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
python -X utf8 -m unittest discover -s docs/codex/winaudioclean/tests -v
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
```

Quick passes 74 Pester cases in each shell, with 153 outside scope, exit 0.
It parses all 18 maintained PowerShell files and passes static/plan checks;
it does not execute the blocked native integration cases. Independent Python:
61 passed, one symlink-privilege skip, exit 0. A direct PS5.1 check confirms the
corrected JSON assignment returns 12 elements. No green Full is claimed for
the corrected tests. Source identities describe the final checkpoint bytes;
post-Full changes are confined to test assertions/parsing/diagnostics and docs.
Exact pre-correction integration test hashes were not retained.

## Acceptance observations

| Case | State | Evidence and remaining requirement |
| --- | --- | --- |
| AC-016 | blocked | Earlier direct/launcher runs preserve spaces, brackets, apostrophe, ä/ö/Å, ampersand, percent, exclamation, parentheses and command-looking names. Wrapper cases also preserve empty arguments, quotes and backslashes. Environment launcher route exercises the actual app; default drop route uses a controlled application stub to avoid a menu, then the real recorder. Percent expansion is tested with a defined token and decoy. Corrected integration must still pass the Full gate under permitted fixture execution. |
| AC-017 | blocked | Earlier actual-script/launcher cases cover success, native nonzero, missing/invalid executable, blocked report writes, primary failure retention, and pause/exit propagation. Reporting cases simulate output metadata failure under caller Continue/Stop. The corrected cumulative gate remains blocked by fixture startup policy. |
| AC-018 | pass | All 23 wrapper tests pass in both Full runs: simultaneous 512 KiB stdout/stderr with end markers, UTF-8 separation, EOF on stdin, native exit 7, structured start failure, timeout and owned-child reaping, NUL/command-length rejection. Explicit stream disposal was reviewed. Four real FFmpeg synthetic app runs below pass. This establishes bounded test cases, not a long-recording memory benchmark or descendant-process lifecycle guarantee. |

CMD can expand positional `%NAME%` and `!NAME!` before the batch file sees them.
The launcher rejects observable cases with a safe fallback; an already-expanded
path cannot be reconstructed. These names must use direct PowerShell or the
documented environment `/unattended` route. Automated launcher tests exercise
actual CMD/batch parsing and PS5.1 invocation, not Explorer drag gestures.

## Real FFmpeg application smoke

Ignored `.wac-local/m1_02_real_process.py` made a byte-identical application copy
and reused existing verified FFmpeg/ffprobe 9.0.2 executables. It reused the
M0-03 three-second mono mix fixture after checking its recorded SHA256. Exact
application/probe argument arrays, binary/input/output hashes and results are
in `WAC-M1-02-real-process.json`; raw logs, binaries and WAVs remain ignored.

Command: `python -X utf8 .wac-local/m1_02_real_process.py` (exit 0).
Each shell ran Raw and Zoom with explicit noninteractive mode and destinations
containing brackets, percent and exclamation. All four application exits were 0,
each wrote one WAV and report, and input hashes remained unchanged. ffprobe
returned 0 and confirmed three-second mono 192000 Hz `pcm_s16le` output in all
four cases. This is the existing encoding behavior, not promotion of a new
encoding or speech-quality result. Application source SHA256:
`292fb01ec4ea7a4a48849cc49f37aa6f4218c2be5a8033d34639fb74212107ef`.

## Blocked checkpoint and next action

Preserve the current machine policy. Resume both Full gates only after test
fixture execution is permitted through normal machine administration. Do not
recompile/rename/copy repeatedly to seek an allowed hash, add exclusions, or
reinterpret the failed gate as accepted. Reconcile tests/evidence and acceptance
after successful validation. **The exact next task remains WAC-M1-02.**

This checkpoint must be committed/pushed to the feature branch and live branch
and PR heads verified. Record the resulting SHA in PR/final output to avoid a
self-referential evidence commit. No merge, release or deployment occurred.
Staged review covers 34 text files and one intended obsolete-fixture deletion.
All 26 source identities and seven sanitized log hashes match; staged content
matches working-tree content after Git newline normalization. Whitespace and
privacy checks pass, and no audio or binary is staged. Independent review found
no additional code or evidence issue. Only M1-02 and AC-016/017/018 changed state.
Human listening, channel isolation, impulse alignment, long recordings, >4 GB
exports and runtime memory stress remain unverified. No CI workflow exists.
