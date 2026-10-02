# Current status

Date: 2026-10-02. **M0 is complete: WAC-M0-01 through WAC-M0-04.**
AC-001 through AC-012 pass with evidence. The other 26 tasks remain todo;
AC-013 through AC-090 remain not_run. No M0 engineering blocker remains.

**Next: WAC-M1-01 in a fresh thread — validate local input, mode and destination
before prompting.** Stop this session at the synchronized M0 checkpoint.

## Baseline gate

WAC-M0-04 reconciled the existing evidence once. All 12 M0-03 source hashes,
seven historical baseline blobs, both report hashes, 50 retained synthetic
input/output files and both portable FFmpeg binaries match their records.
All prior task/acceptance evidence links exist. The current tested source list
contains 18 unchanged runtime/development files. No new audio render was needed.

M0-03's two Windows reports remain byte-identical: five synthetic fixtures,
20 Raw/Zoom variants per run. Legacy unspecified WAVs measured 192 kHz PCM16;
the separate explicit encoding comparisons measured 48 kHz PCM16. Channel counts
and reported durations match inputs. Undefined loudness is null with reasons.
These findings characterize this build; they do not establish speech quality.

D19 in DECISIONS.md records the implementation contracts and pending human
choices. Runtime source, launcher, filter settings and export behavior did not
change in M0-04. BASELINE.json and bundle audit/Linux reports remain historical.

## Checks actually run for M0-04

Active Windows NT 10.0.26300.0; PS7.6.5; PS5.1.26100.9444; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0. Existing portable FFmpeg/ffprobe 9.0.2
identities match the M0-03 reports; neither executable is on PATH.

- Quick: 13 Pester passed.
- Full in each shell: 29 Pester passed; 61 Python tests passed and one skip for
  unavailable Windows symlink privileges. All commands exited 0.
- Parser/static gates passed; 49 existing analyzer advisories remain visible.
  No rules were suppressed and no new source was introduced.
- Final plan validation passed: 30 tasks, 90 acceptance cases, 20 improvement
  groups. Only WAC-M1-01 is ready; it needs no additional implementation approval.

Evidence: [M0-04 gate](evidence/WAC-M0-04.md), source and reconciliation JSON,
sanitized test logs, and final plan/restart checks. M0-01/02/03 evidence remains
intact. Exact reproduction commands are in tests/README.md and the gate record.

## Validation still pending

- Human speech listening and speech-quality review: no cleared corpus admitted.
- Real audio through the application/launcher: controlled preflight and process
  doubles pass; direct FFmpeg synthetic rendering is a separate result.
- Complete filename/CMD argument matrix, error/cancellation/collision handling,
  stream selection, channel isolation, impulse alignment, long and >4 GB exports:
  their scheduled M1/later acceptance cases remain unrun.
- Default-sound promotion: unapproved. Explicit 48 kHz is still comparison-only.
- No CI exists yet. Local tests are the evidence; CI remains scheduled for M4-02.

Existing input-validation, overwrite/collision and process-status defects are
tracked M1 work. Passing this baseline gate does not certify release readiness.

## Checkout and delivery

The source-only starting folder has no Git metadata and remains preserved.
Use the established separate Git checkout. Branch: `codex/wac-m0-handoff`.
Effective fetch/push origin: `https://github.com/PikkuJanne/WinAudioClean.git`.
At this session's start, local HEAD, upstream, live remote and open draft PR #1
matched `e1bd07b96dc23ab7d84ac0f236ca599a866c73a3`; the tree was clean and fetch
succeeded. M0-04's post-push SHA and verification belong in the PR/final response.
Recheck live state before advancing; task `done` alone does not establish sync.

[Draft PR #1](https://github.com/PikkuJanne/WinAudioClean/pull/1) targets main.
For M1, start `codex/wac-m1-reliability` from the verified M0 completion tip and
stack its draft PR on `codex/wac-m0-handoff` while PR #1 remains unmerged.
Inspect live PR state first and reconcile the base if an approved merge occurred.
