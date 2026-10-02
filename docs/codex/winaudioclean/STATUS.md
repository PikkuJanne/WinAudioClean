# Current status

Date: 2026-10-02. **WAC-M1-01 is complete.** M0-01 through M0-04 remain complete;
AC-001 through AC-015 pass with evidence. The other 25 tasks remain todo and
AC-016 through AC-090 remain not_run.

**Next: WAC-M1-02 in a fresh thread — harden native process execution, exit codes
and diagnostics.** Stop after synchronizing this M1-01 checkpoint.

## Current behavior

- Literal filesystem preflight checks readable, nonempty input and a writable
  destination before prompting. Music remains the default; -OutputDirectory
  can create a chosen folder. URL/provider/UNC/device/ADS forms are rejected.
- Empty/invalid menu choices reprompt, Q cancels, and invalid profile choices
  cannot silently select Zoom. -Mode Raw|Zoom and -NonInteractive supply the
  minimal unattended seam. Redirected stdin and host noninteractive switches
  also require an explicit mode. See D20 for the precise policy.
- Direct preflight failures exit 2; menu cancellation exits 130. Native command,
  output encoding, launcher and exact Raw/Zoom filter strings remain unchanged.

## Checks actually run for M1-01

Windows NT 10.0.26300.0; PS5.1.26100.9444; PS7.6.5; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0. No new dependency installation.

- Targeted helper suite: 61 Pester passed in PS7. Targeted entry points: 34 passed
  including actual child processes in both shells.
- Full in each shell: **108 Pester passed, zero skipped; 61 Python passed and
  one symlink-privilege skip**. Both runner exits were 0.
- Parser/static/plan gates passed. The 49 analyzer advisories were inspected;
  no rules are suppressed. New findings are console/test-fixture advice.
- Actual console checks in both shells: empty and invalid answers reprompt;
  Q/q cancels with exit 130. Abbreviated host -nonin with attached stdin fails
  without a menu and exits 2. The copied script hash equals the tested source;
  these checks use synthetic bytes and a dependency-presence sentinel, no audio.
- AC-013 literal filename/destination matrix and AC-014 locked-input/ACL-denied
  destination checks passed on both shells. No owned write-probe files remain.

See [M1-01 evidence](evidence/WAC-M1-01.md), source identities and sanitized logs.
The initial entry-point run had four assertions affected by PS5.1 line wrapping;
stable diagnostic-prefix checks fixed those test failures before the full gate.

## Evidence and limitations carried forward

M0-03's two same-build reports remain historical: five fixtures and 20 Raw/Zoom
variants per run; legacy WAV output measured 192 kHz PCM16, explicit comparison
48 kHz PCM16. No audio rerender or sound/encoding change occurred in M1-01.
M0-04's reconciliation and all prior evidence remain intact.

Native argument fidelity through CMD, native launch/failure/stream handling and
launcher pause/exit propagation are M1-02 work. Media probing/external references
are M1-03; transactional export/collision safety is M1-04; explicit encoding is
M1-05. Current preflight does not prove media decodability or release readiness.
Speech listening, real audio through the application, channel isolation, impulse
alignment, long recordings and >4 GB exports remain unverified. Default sound
promotion remains unapproved. CI does not exist yet (scheduled for M4-02).

## Checkout and delivery

The source-only starting folder remains preserved. Use its sibling established
Git checkout WinAudioClean-governance, then verify repository identity.
Effective fetch/push origin: https://github.com/PikkuJanne/WinAudioClean.git.
M1 branch: codex/wac-m1-reliability, created from the verified M0 completion
329852555170c5e58be3db92c18634b5341eb138 after fetch and live sync checks.

M0 [draft PR #1](https://github.com/PikkuJanne/WinAudioClean/pull/1) remains open
against main. The M1 draft PR stacks on codex/wac-m0-handoff while #1 is unmerged;
find it by its exact head branch. The post-push M1-01 SHA, PR URL and live-head
verification belong in the PR/final response. Recheck live state before advancing;
task done means engineering acceptance, not an independent synchronization claim.
