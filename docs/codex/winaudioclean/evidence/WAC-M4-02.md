# WAC-M4-02 — Windows CI and local parity

Implementation checkpoint in progress, 2026-10-03. Parent is freshly verified
clean local/upstream/live `codex/wac-m4-regression`
`42cf8f24a9b1886b5a807bb74e7b299d9de9cb29`, on draft PR #5 stacked on
`codex/wac-m3-settings`. Only the maintained governance checkout is used.

The workflow adds four Windows OS/shell combinations, exact verified Action
commits, checksum-verified portable Python 3.14.6 and PowerShell 7.6.5, and
existing pinned Gallery modules. It calls the same local Full runner. Read-only
permissions, no persisted checkout credentials/secrets/caches/publication,
ordinary PR/push events and one sanitized JSON artifact with seven-day retention
establish the reviewed boundaries. [CI instructions](../CI.md) record parity,
provenance and result semantics. No runtime, BAT, sound/default or setting changed.

Focused setup tests passed 5/5 on PS7; policy 9/9, status-reader 20/20 and wrapper
controlled-process tests 24/24 passed. Actual Quick on both shells passed
1075 Pester / 0 failed / 1 privilege skip / 386 outside scope, with observed
Pester 5.7.1/PSScriptAnalyzer 1.24.0 and Python 3.14.6. PS5.1 is 5.1.26100.9444;
PS7 is 7.6.5; active Windows build26300. The later Full-only outside-scope
guard refinement passed the focused Python suite; the Quick source hashes
retain their pre-refinement identity. Quick was not repeated for that guard.
Official archive bytes downloaded/extracted
locally match committed SHA256 pins. Unsupported shell/API simulations are
covered explicitly and cannot become passes. An actual nonexistent-shell
invocation returned nonzero/not_run/shell_unavailable. Live reading the parent
SHA correctly returned not_run/exit3, with no GitHub workflow run. The initial
capture redirection failed before invoking gh because its ignored destination
was absent; after explicit directory creation the actual reader ran. No failed
capture was claimed as evidence. The initial status lookup's
default-branch filename restriction was corrected before remote validation.

Full local gates and actual PR runs must be recorded before acceptance. At this
implementation checkpoint WAC-M4-02 remains todo; AC-070..072 remain not_run.
Coverage availability is not execution evidence. No packaging, merge, release,
repository setting, default promotion or deployment is performed.
