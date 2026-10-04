# WAC-M1-02 — Successful validation resumption

Date: 2026-10-02. **Engineering acceptance is complete.** This record supersedes
the blocked outcome in [the initial evidence](WAC-M1-02.md). The earlier failed
logs, policy correlation and source manifest remain unchanged historical records.
Post-push synchronization must be verified separately; record the completion SHA
in the PR/final response rather than inside its own commit.

## Authorization, environment and source identity

The owner explicitly reported: "Smart App Control is off—rerun M1-02."
A read-only check of
`HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy\VerifiedAndReputablePolicyState`
returned **0** before and after the runs. The preceding investigation had tied
the rejecting policy to Smart App Control (`VerifiedAndReputableDesktop`).
Codex made no security-setting changes. These results establish fixture execution
with Smart App Control Off, not compatibility of unsigned fixtures with it On.

The established Git checkout was clean on `codex/wac-m1-reliability` at
`0d02cf48dcede1196024039294e9316f4624b50a`. Effective fetch/push origin:
`https://github.com/PikkuJanne/WinAudioClean.git`. Fetch and live sync-check passed;
local, upstream, live branch and draft PR #2 heads matched. The source-only folder
was preserved. PR #2 remains stacked on `codex/wac-m0-handoff`; no merge occurred.

All **26** runtime/development file SHA256 values match the blocked checkpoint's
manifest. No runtime or test source was edited during this resumption. The exact
working-tree hashes, environment, commands and sanitized log hashes are in
`WAC-M1-02-resume-source.json`. Git text normalization may change line endings.

Environment: Windows NT 10.0.26300.0; Windows PowerShell 5.1.26100.9444;
PowerShell 7.6.5; Python 3.14.6; Pester 5.7.1; PSScriptAnalyzer 1.24.0;
Windows Framework compiler 4.8.9221.0. Existing local tools were reused.

## Required cumulative gate

Commands from the repository root, each in a fresh shell:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
```

| Host | Pester passed / failed / skipped | Python passed / skipped | Runner exit |
| --- | --- | --- | ---: |
| Windows PowerShell 5.1 | 227 / 0 / 0 | 61 / 1 | 0 |
| PowerShell 7 | 227 / 0 / 0 | 61 / 1 | 0 |

The sole Python skip in each run is `test_symlink_rejected`, because Windows
symlink privileges are unavailable. Nothing was skipped due to application
control. Both runners parse all 18 maintained PowerShell files and pass the
static and plan gates. All 53 analyzer advisories remain visible; no suppression
or gate weakening was added. Complete sanitized logs:
`WAC-M1-02-resume-full-ps51.txt` and `WAC-M1-02-resume-full-ps7.txt`.

## Acceptance reconciliation

| Case | Result | Evidence |
| --- | --- | --- |
| AC-016 | pass | Direct script and actual batch/native boundaries preserve the filename matrix in both shells. Wrapper tests cover empty arguments, embedded quotes and backslashes. The launcher environment route covers percent/exclamation paths; default handoff/pause uses the documented managed application stub and actual recorder. CMD's earlier positional expansion limitation remains explicit. |
| AC-017 | pass | Full suites cover startup/missing/invalid executable failures, native nonzero exits, success, report-write failures, output-metadata failures under caller Continue/Stop, primary-failure retention and batch pause/exit propagation. The corrected PS5 JSON assertions now pass in the cumulative gate. |
| AC-018 | pass, retained | All 23 native-wrapper cases pass again in each shell, including simultaneous 512 KiB stdout/stderr with end markers, stdin EOF, UTF-8, timeout/reaping and command rejection. Four previously successful real FFmpeg Raw/Zoom application runs remain valid on identical runtime bytes. |

The current script SHA256 remains
`292fb01ec4ea7a4a48849cc49f37aa6f4218c2be5a8033d34639fb74212107ef`, matching
`WAC-M1-02-real-process.json` and its retained application copy. No audio rerun
was needed. Those four historical runs produced readable three-second mono
192 kHz PCM16 WAVs and reports with unchanged inputs. They are synthetic checks,
not speech listening or default-sound approval.

## State, limits and delivery

M1-02 changes from blocked to done; AC-016/017 change to pass; AC-018 remains pass.
Prior failures remain recorded. The owner changed the execution environment;
the tests were neither skipped nor rewritten to seek a passing result.
Plan validation reports 30 tasks, 90 cases and 20 improvement groups, with only
**WAC-M1-03** ready. See `WAC-M1-02-resume-plan.txt`.

Current limitations remain unchanged: positional CMD expansion, untested running
render Ctrl+C semantics, capture held in memory, and legacy overwrite/collision
behavior. M1-03 owns dependency/stream probing, M1-04 transactional outputs and
M1-05 explicit encoding. Speech listening, channel isolation, impulse alignment,
long recordings and >4 GB exports remain unverified. No CI workflow exists yet.

This completion checkpoint changes governance, evidence and test documentation
only. Staged review covers 13 intended text files. All 26 source identities and
both log hashes match; earlier failed-run artifacts remain unchanged. Whitespace,
privacy and staged-content checks pass, with no audio/binaries or unstaged work.
Independent review found no evidence/state issue. Commit/push the M1 feature branch and verify
the clean local, live branch and draft PR heads. Do not begin M1-03 in this turn.
