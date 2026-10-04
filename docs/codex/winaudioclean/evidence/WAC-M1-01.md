# WAC-M1-01 — Input, destination and menu preflight

Date: 2026-10-02. Engineering acceptance: complete. Post-push synchronization
must be checked separately; the completion SHA belongs in the PR/final response.

## Starting checkpoint and scope

The original source-only folder has no Git metadata and was preserved. The
established sibling Git checkout was clean on `codex/wac-m0-handoff` at
`329852555170c5e58be3db92c18634b5341eb138`. Effective fetch and push origin both
resolved to `https://github.com/PikkuJanne/WinAudioClean.git`. Fetch succeeded;
local/upstream/live branch and open draft PR #1 matched. No CI checks were listed.
Created `codex/wac-m1-reliability` from that verified tip for a stacked draft PR
based on `codex/wac-m0-handoff`. No existing M1 PR was found at initial inspection.

Changed implementation files:

- `WinAudioClean.ps1`: literal path resolution; input read/size checks;
  create/write destination probe; minimal parameters; mode retry/cancel and
  unattended behavior; literal output-size/log operations.
- `tests/WinAudioClean.Preflight.Tests.ps1`: 61 path, readability, permissions,
  menu and host-interactivity cases. Unicode source retains UTF-8 BOM for PS5.1.
- `tests/WinAudioClean.EntryPoints.Tests.ps1`: 34 direct/launcher/runtime cases,
  including the invalid-input/destination/mode matrix in both Windows shells.
- `tests/WinAudioClean.Helpers.Tests.ps1`: replace invalid-choice-to-Zoom defect
  characterization with rejection assertions; exact filters remain locked.
- `tests/fixtures/Invoke-ControlledApplication.ps1`: real disposable filesystem
  preflight plus process/report doubles; explicit mode and unattended switch.
- Product/test READMEs, D20, task/acceptance/status/handoff and these evidence files.

The launcher, native command/argument builder, filter text/order and output
encoding are unchanged. A small importable helper boundary keeps tests from
starting the application. No runtime Python, download, telemetry or cloud work
was introduced. Preflight proves access only; nonempty corrupt media still needs
M1-03's probe. Existing native-status/collision defects remain scheduled work.

## Exact validation and environment

Windows NT 10.0.26300.0; Windows PowerShell 5.1.26100.9444; PowerShell 7.6.5;
Python 3.14.6; checkout-local Pester 5.7.1 and PSScriptAnalyzer 1.24.0.
No tools were installed. Bypass applies only to each launched process.

Commands from the repository root:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Preflight.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.EntryPoints.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
```

Final targeted helper: 61 passed. Final targeted entry points: 34 passed. Both
exits 0. Full in each shell: **108 Pester passed, 0 failed/skipped; 61 Python
passed and 1 skipped** (Windows symlink privileges unavailable). Both exits 0.
All 12 maintained PowerShell files parse. Static and plan gates pass; 49 analyzer
advisories remain visible. Inspected advice covers console output, Pester setup
variables, test command doubles/unused parameters and the existing plural helper
name; no suppressions or rule downgrades were added. The final plan reports
30 tasks, 90 cases and 20 improvement groups; only WAC-M1-02 is ready.

Sanitized complete logs: `WAC-M1-01-full-ps51.txt`, `WAC-M1-01-full-ps7.txt`;
targeted entry log: `WAC-M1-01-entry.txt`. `WAC-M1-01-source.json` records SHA256
of all 19 tested runtime/development files plus log hashes and the starting
commit. Identities describe tested working-tree bytes, including line endings;
Git's text normalization may differ. Private paths/terminal formatting are removed
from committed logs. No recordings, synthetic audio or dependency binary is staged.

The first entry-point run had 30 passes and four failures because Windows
PowerShell wrapped long diagnostic strings mid-word. Assertions were narrowed
to meaningful stable prefixes; actual error exits/order were already correct.
The rerun and full gates passed. Review found a host-switch abbreviation gap;
prefix handling, boundary tests and attached-console checks resolved it.

## Acceptance evidence

| Case | Result | Evidence and limits |
| --- | --- | --- |
| AC-013 | pass | Input and destination matrix: spaces, brackets, apostrophe, ä/ö/Å, ampersand, percent, exclamation, parentheses. Full paths/length/bytes stay exact; a bracket decoy is never selected. Relative paths normalize against PowerShell location. No shell commands are built by preflight. This does not certify the later CMD/native argv boundary (AC-016). |
| AC-014 | pass | Real child scripts reject missing/no input, directories, URL, zero bytes, invalid destinations and invalid modes before menu/processing; exit 2, no success/report. Exclusive input lock is rejected and released. A test-owned ACL denies output creation; the test verifies OS enforcement, failure and ACL restoration. Successful probes leave no files and preserve pre-existing content. Both shells ran every Pester case without skips. |
| AC-015 | pass | Unit menu tests cover both valid modes, empty/invalid retries, q/cancel, EOF and read failure. Controlled actual scripts cover both explicit modes and both process-status doubles. Actual consoles confirm empty/invalid retries and cancellation exit 130; host -nonin without mode exits 2 without menu. Redirected/explicit/host unattended failures are also tested through real child processes. |

## Actual console checks

A byte-identical copy of `WinAudioClean.ps1` was placed in ignored
`.wac-local/WAC-M1-01/interactive/`, with three synthetic input bytes, a zero-byte
`ffmpeg.exe` presence sentinel and a run-owned output directory. This setup
allows real mode interaction without a working native tool. Source/copy SHA256:
`fd36ac2270df7f130794ad376852c9c0fadbfb2f1c2365e14e9c3897b9be4b0b`.

Run in a real terminal, replacing SHELL with `powershell.exe` and then `pwsh`:

```powershell
SHELL -NoLogo -NoProfile -ExecutionPolicy Bypass -File .wac-local/WAC-M1-01/interactive/WinAudioClean.ps1 -inputPath .wac-local/WAC-M1-01/interactive/input.wav -OutputDirectory .wac-local/WAC-M1-01/interactive/output
exit $LASTEXITCODE
```

In each shell: Enter -> invalid-selection message and another prompt;
`invalid` -> same retry; `q` (PS5.1) / `Q` (PS7) ->
`Cancelled. No audio was processed.` and exit **130**. The first PS5.1 console
trial's outer shell did not explicitly forward LASTEXITCODE, so it reported 1;
the corrected invocation above confirmed the actual 130. Both confirmed trials
used the same source copy. No processing ran and no log, export or probe file remained.

Repeat the command with host `-nonin` before `-File`, with stdin still attached:
both shells emit the missing-mode diagnostic, show no menu and exit **2**.
The output directory remains empty. These checks establish menu/host behavior;
they do not exercise FFmpeg, valid media rendering or launcher argument fidelity.

## Remaining limits and delivery

M1-02 owns exact native argv/stream draining/start failure, -nostdin, native and
report status handling and launcher exit propagation. M1-03 owns probing/streams
and external-media references; M1-04 owns collision/transactional output safety;
M1-05 owns explicit PCM encoding. Saved configuration remains M3-01. The product
README states the current preflight and automation limits.

Listening and default-sound promotion remain pending. Real audio through the
application, channel isolation, impulse alignment, long recordings and >4 GB
exports were not run. The unchanged M0-03 audio reports remain the comparison
baseline; no audio rerender was needed for these access/menu changes. No CI
workflow exists. No merge/release/deployment or permission change is authorized.

Staged review covered 18 intended text files. Whitespace and privacy checks
passed; all 19 tested source identities and three sanitized log hashes match.
Only WAC-M1-01 and AC-013/014/015 advanced, and no unstaged change remained.
Independent review found no code/test blocker; two evidence wording corrections
were applied and restaged. No audio, binaries or private paths are staged.

Commit with WAC-M1-01, push the exact feature branch and verify local HEAD equals
the live branch and draft PR head. Record the post-push SHA in the PR/final response
without a self-referential evidence commit. After that verified delivery, the
exact next task is **WAC-M1-02**, in a separate thread.
