# WAC-M4-01 Preview report release faults

Date: 2026-10-03. The inherited `Write-WacPreviewReports` close loop could let
the first throwing `Dispose` skip the next writer and replace a primary report
write exception. After successfully flushed rendering it returned a reporting
warning while already persisted reports still described successful completion.

The small Preview-only change attempts each writer close independently and emits
a nonterminating release advisory with explicit `WarningAction Continue`.
Successfully durably flushed reports retain their terminal outcome, following
the existing ordinary-report contract. A primary write/open error remains the
error returned by the reporting helper. No filter, preset, launcher, sound,
output ownership or cancellation default changed.

The [ledger](WAC-M4-01-preview-close.json) records sanitized commands, shell and
Pester versions, source and transcript hashes, exact case names and exit codes.
The [capture runner](WAC-M4-01-preview-close-runner.ps1) is the exact helper used;
the task's reusable Targeted/Full runner certifies the broader scope separately.
Each focused capture discovers 164 tests, runs nine selected `ReportCloseFault`
cases and leaves 155 outside its filter. Those 155 were not passed by this capture.

| Scope | PS5.1 | PS7 | Harness exit |
| --- | --- | --- | --- |
| Corrected FileStream fixture against frozen inherited Preview | 0 pass / 9 fail | 0 pass / 9 fail | 1 |
| Current Preview and corrected fixture | 9 pass / 0 fail | 9 pass / 0 fail | 0 |

Six direct cases cover first/second/both close faults, the actual caller warning
preference `Stop`, preservation of a primary text-write error with owned rollback,
and a second-writer collision with foreign bytes preserved. Three orchestration
cases keep SUCCESS/0, FAILED/4 and CANCELLED/130 consistent across returned and
persisted reports, verify both real handles are released, and preserve source,
prior output and foreign partial bytes. Existing Preview transaction cleanup
still prevents implicit full exports and removes only owned pending assets.

The initial PSCustomObject wrapper could not pass into the typed native owned
deletion API. Its failed preliminary transcripts are retained. The corrected
fixture derives FileStream, so actual identity checks, durable flush and
identity-checked owned deletion execute. It closes the real OS handle before
raising the injected exception; this establishes continued close attempts and
advisory/error handling, not recovery from a stream refusing actual release.

A separate evidence publisher incorrectly joined absolute JSON paths and
produced four empty derivatives. Both frozen trees and all raw transcripts
survived. Separate recovery captures restored valid case/hash JSON on those
unchanged trees. The ledger labels the correction, retains original transcript
hashes, and references only valid public JSON; empty derivatives remain private.
Passing focused captures were intact and were not repeated for publication.

Manual picker gesture, subjective listening or default-sound promotion,
console-close/crash/power-loss behavior, actual >4 GB output and long-path,
storage or memory stress remain outside these nine cases. Existing named manual
reviews and explicit unperformed scopes must remain visible in task coverage.
