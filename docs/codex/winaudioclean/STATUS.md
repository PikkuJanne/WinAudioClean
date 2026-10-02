# Current status

Programme created: 2026-10-02. Reviewed remote baseline:
`7dfe43361395908a277d7b513b1c9a4fd3cd192a`.

Completed: **WAC-M0-01 and WAC-M0-02**. AC-001 through AC-006 pass with evidence.
The remaining 28 tasks are todo; AC-007 through AC-090 remain not_run.
Next task: **WAC-M0-03 in a fresh thread**.

## Latest changes

`WinAudioClean.ps1` exposes three pure helpers and supports safe dot-sourcing.
Original `.ps1 -inputPath` and `.bat` entry points remain. Raw/Zoom filter strings
and command behavior are preserved. `scripts/` supplies explicit, hash-verified
development setup and Quick/Targeted/Full runners. `tests/` adds 27 Pester tests
and development instructions. No runtime module is added.

The source-only starting folder is preserved. Discover the separate Git checkout
established by WAC-M0-01 before continuing. Branch: `codex/wac-m0-handoff`.
Origin fetch/push: `https://github.com/PikkuJanne/WinAudioClean.git`.

## Actual validation

Windows NT 10.0.26300.0; PowerShell 7.6.5; Windows PowerShell 5.1.26100.9444;
Python 3.14.6; Pester 5.7.1; PSScriptAnalyzer 1.24.0.

- Quick: 11 Pester passed in each shell.
- Full: 27 Pester passed in each shell. Each run also passed 53 governance
  tests with one skipped for unavailable Windows symlink privileges.
- Targeted entry points: 8 passed, covering both choices and available shells.
- Isolated helper mutation: Quick exits 0/1/0 before/broken/restored, with
  three meaningful failures under the deliberate defect.
- Parser/static/plan gates passed. 48 analyzer advisories remain visible;
  no rules are suppressed. New runner/setup scripts have zero findings.

Evidence: `evidence/WAC-M0-02.md`, source hashes, mutation record and logs.
Actual entry-point checks exercise missing-input preflight; separate process/log
mocks verify Raw/Zoom success/failure wiring. The `.bat` still uses Windows
PowerShell internally, including when launched from PS7.

## Delivery and remaining limits

Preceding verified checkpoint: `d88c4fdcb2ccab445fe8b96636e42cf154138950`.
Clean local tree, upstream, live branch and [open draft PR #1](https://github.com/PikkuJanne/WinAudioClean/pull/1)
matched at this session's start; fetch succeeded. This WAC-M0-02 completion
update must also be committed, pushed and verified. Its exact SHA is recorded
in the PR/final response to avoid self-reference. Always derive live sync again.

No WAC-M0-02 engineering blocker remains. FFmpeg/ffprobe are absent from PATH;
real processing, encoding, listening and large-file checks are unrun. Input,
collision/overwrite and process-status fixes remain M1 work. No CI exists yet;
local tests are the evidence. Development modules are ignored checkout-local
files. PS5.1 checks use process-only execution-policy Bypass as the launcher
does; persistent policy is unchanged.

Feature pushes can use the existing command-scoped GitHub CLI credential helper
if the default helper stalls. Merge/release/deployment approvals remain separate.
Done records engineering acceptance; fresh live sync is required before advancing.
