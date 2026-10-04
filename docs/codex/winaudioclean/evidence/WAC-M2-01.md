# WAC-M2-01 evidence — Original preset identity and accurate claims

Date: 2026-10-02. Starting verified checkpoint:
`f1ad9de795b74acef5b932223c38eedfba24cee6`, the live M1 branch and draft PR #2
head. Created `codex/wac-m2-audio` from that clean checkpoint after fetch and
plan validation. Exact effective fetch/push origin:
`https://github.com/PikkuJanne/WinAudioClean.git`.

## Change and acceptance

- AC-034: README, actual comment-based Get-Help and menu descriptions correct
  loudness/parameter claims. [Claims review and primary references](WAC-M2-01-claims-review.md)
  cover all shipped text/artwork and the absent website draft. Installed filter
  help is preserved in WAC-M2-01-filter-options.json. Historical audit records
  remain intact. No unsupported broadcast/equivalence/exact-result claim remains.
- AC-035: Both Raw/Zoom profiles retain every frozen filter value and its order.
  [Same-build comparison](WAC-M2-01-original-compatibility.json) compares decoded
  PCM bytes at zero lag against direct independent BASELINE.json renders using
  identical 48 kHz PCM16/24 settings. All 20 application cases and 10 references
  pass. This is not a claim about files made with the old implicit encoder.
- AC-036: Both existing choices select Original, ID original, version 1.0.0.
  JSON/text/summary record the effective profile separately from tool version
  2.3 and schema 1. Nine new Pester cases cover profiles, menu/direct invocation,
  persisted reports and legacy/current/arbitrary-version redaction. Two real
  unmodified application menus through PTY selected Raw in PS5.1 and Zoom in PS7;
  both published audio with the expected report identity. See
  [help/menu evidence](WAC-M2-01-help-console.json).

## Validation

Windows NT 10.0.26300; PowerShell 5.1.26100.9444 and 7.6.5; Python 3.14.6;
Pester 5.7.1, PSScriptAnalyzer 1.24.0 and existing FFmpeg/ffprobe 9.0.2.
No dependencies were downloaded or machine security settings changed.

| Check | Windows PowerShell 5.1 | PowerShell 7 |
| --- | --- | --- |
| Final focused preset gate | 9 passed; zero failures/skips | 9 passed; zero failures/skips |
| Full Pester | 552 passed; zero failures/skips | 552 passed; zero failures/skips |
| Full Python governance | 61 passed; one symlink-privilege skip | 61 passed; one symlink-privilege skip |
| Final real-media matrix | 10/10 app cases | 10/10 app cases |

All final runners exited 0. Full parsed 26 PowerShell files and passed static
safety and plan checks. Its 117 non-gating analyzer advisories remain recorded.
Review removed one new test-only automatic-variable assignment by renaming
`$profile` to `$presetProfile`; final focused gates pass with 116 advisories.
Application source is unchanged after Full. The assertion logic is unchanged;
only that local test name and separately tested harness cleanup changed.

The initial PS5.1 targeted invocation failed before tests because the local
Python runner removed PSModulePath case-sensitively from an uppercase Windows
environment dictionary. The corrected runner removes keys case-insensitively;
its focused rerun passes. The initial failure log is retained. No application,
machine security policy, installed module or persistent environment change was
needed. Both Full gates use corrected fresh child environments.

Get-Help review found prose parsed as example code in PS7. Three blank comment
lines fixed it; fresh checks in both shells confirm three command examples with
remarks. The PS5.1 real-menu check predates only those comment blank lines;
all executable bytes are identical, and the exact before/after hashes are kept.
The final compatibility matrix uses the corrected full script hash.

The new development comparison harness uses Python 3.10-compatible chunked
SHA-256 and bounds native calls. Review found parent-only timeout cleanup could
leave a child running; the corrected helper terminates only the owned PID tree.
A live synthetic parent/child test verifies both exits, drained streams and
preservation of an unrelated sentinel. The final comparison run validates this
harness revision. This harness-only correction does not change the application.

## Commands and source identity

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Preset.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Preset.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-OriginalPreset.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M2-01/original-compatibility-reviewed
```

The source manifest records exact resolved/sanitized commands, log hashes,
source hashes at the gates and final delivery, and the narrowly tested
harness cleanup and test-variable rename after Full. Application source remains
unchanged; fresh final focused gates cover the test rename. The final
compatibility and timeout evidence identify the delivered
harness. No Full repeat is needed for that separately checked development tool.
Initial successful media runs remain local; final committed evidence matches
the delivered sources. Raw generated media/reports and diagnostics remain
ignored. No private speech, tool binary or personal path is committed.

## Limits and synchronization

No speech listening, independent final loudness, full >4 GB render, actual disk
exhaustion, long-file/memory stress or running-render Ctrl+C claim is made.
Native capture remains in memory; capacity is not reserved against other writers;
reports have no multi-file atomicity/power-loss guarantee. Early pre-render
failures stay console-only. Original Raw delay (~25 ms) is retained. Existing
launcher regressions do not establish a fresh Explorer drag-and-drop render.

Stage only intended changes, inspect the staged diff, commit/push the M2
feature branch and verify clean local/live/PR equality. Completion SHA and
point-in-time verification belong in the draft PR and final response to avoid
self-referential evidence commits. Stack the M2 draft on M1 while PR #2 is
unmerged. No CI workflow/checks exist; local success does not imply CI success.
No merge, release, default-sound promotion, setting change or deployment occurs.

**Next: WAC-M2-02 — Add measured loudness without changing the default fast path.**
Stop after synchronized M2-01; do not begin that next task in this session.
