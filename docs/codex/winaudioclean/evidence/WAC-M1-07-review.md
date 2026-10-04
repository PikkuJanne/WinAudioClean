# WAC-M1-07 — file safety and compatibility review

Date: 2026-10-02. Reviewed source: `ca82376ae60560541fb0985c7c565c7872e3bba4`.
Two independent read-only reviews and the main review found no known source or
prior-export overwrite, broad cleanup, ambiguous publication or false-success
defect requiring a runtime change. Fresh test results and source identities are
recorded in [the gate evidence](WAC-M1-07.md). This is a bounded M1 review, not
a claim that every filesystem or hardware failure is recoverable.

## AC-032: every runtime write, rename and cleanup boundary

References below are repository-relative and refer to the reviewed source.

| Boundary | Safeguard reviewed | Regression coverage |
| --- | --- | --- |
| `WinAudioClean.ps1:162`, `Get-WacOutputDirectory` | Directory creation plus a unique CreateNew/DeleteOnClose write probe. Existing files survive; created directories intentionally remain. | `Preflight.Tests.ps1:121`: literal paths, existing content, occupied destination, denied creation and restored disposable ACL. |
| `WinAudioClean.IO.ps1:217`, `New-WacOutputTransaction`; main `:242`, FFmpeg arguments | Read-only source pin, canonical pinned destination, CreateNew partial. FFmpeg `-y` addresses only this reserved partial. | `Transaction.Tests.ps1:35`: ownership, collisions, aliases, equal stems, rapid names and junction changes. |
| IO `:267`, `Freeze-WacOutputTransaction`; main `:408`, `Assert-WacWaveOutput` | Recheck ownership after reopening; hold exact bytes against writing/deletion. Validate complete PCM, requested encoding/layout, selected-track duration and RIFF/RF64 lengths. | `Transaction.Tests.ps1:103`; `Validation.Tests.ps1:75`; actual malformed-output cases in `EntryPoints.Tests.ps1:69`. |
| IO `:291`, `Publish-WacOutputTransaction`; native `RenameNoReplace` | Rename the validated held object with replacement disabled. No release/reopen move. Existing final names and hardlink targets survive. | `Transaction.Tests.ps1:141` and `:154`; real rename-race cases. |
| IO `:312` and `:353`, `Complete/Close-WacOutputTransaction`; native `DeleteOwned` | Delete only matching unpublished ownership. Preserve foreign replacements and crash leftovers. Settle owned-output cleanup before serializing outcome, retaining source/destination pins through reporting. | `Transaction.Tests.ps1:187`, `:200`, `:226`; `ReportIO.Tests.ps1:259`; real crash/recovery cases. |
| IO `:401`, `Open-WacReportWriter`; `:472`, `Set-WacOwnedReportContent`; `:516`, `Remove-WacOwnedReport` | CreateNew per-run files, held identity, reparse/multiple-link refusal. Rewriting and deletion require newly created ownership. Flush before success. | `ReportIO.Tests.ps1:34`: exclusive creation, prior-summary protection, aliases and owned removal. |
| IO `:484` and `:496`, `Reset/Add-WacSummaryReport` | Exclusive writer spans append/flush/rollback. Rollback cannot remove bytes predating ownership. Preserve existing BOM/encoding and fail on unrepresentable text. | `ReportIO.Tests.ps1:72`, `:91`, `:148`, `:157`, `:167`, `:206`: encodings, partial writes, bounded contention and concurrent entries. |
| Main `:952`, `Write-WacRunReports`; `:780`, outcome mapping | Retire failed writers, remove or roll back only owned content, correct survivors. Preserve primary processing codes 3/4/5; successful published audio with incomplete reporting is WARNING/7. | `RunReports.Tests.ps1:139`, `:209`, `:260`; `Reporting.Tests.ps1:24`; real report permission/write/rollback cases. |
| Main `:1066`, `Export-WacDiagnostic` | Hold raw source read-only and destination parent; CreateNew export, typed allowlist, owned failed-output removal; failure exits 2. | `RunReports.Tests.ps1:321`: export-only, privacy, input validation and existing-output refusal; real diagnostic CLI checks. |
| IO `:374` and `:392`, retained `Open/Close-WacReportGuard` | Legacy helper inspects the leaf, rejects unsafe aliases and holds report identity. | `Transaction.Tests.ps1:311`: held append guard, prior-audio hardlink refusal and junction change. |

Test filenames in the table are under `tests/WinAudioClean.`; for example,
`ReportIO.Tests.ps1` means `tests/WinAudioClean.ReportIO.Tests.ps1`.
Native launch/capture/exit handling is also covered by `Native.Tests.ps1`,
`Media.Tests.ps1`, actual entry-point tests and the full gate. No global process
kill, user-directory sweep or automatic dependency download is introduced.

## Compatibility and intentional changes

The Raw/Zoom filter text and order still match baseline `7dfe433` and
`BASELINE.json`. `WinAudioClean.Helpers.Tests.ps1:13` checks both strings.
Positional input, `-inputPath`, Music default, Raw/Zoom selection, original
`.ps1`/`.bat` names and Windows PowerShell 5.1 remain supported.

M1 intentionally adds literal validation, explicit unattended mode and ambiguous
track selection, FFmpeg/ffprobe inspection, file-only media restrictions, the
required IO sibling, unique validated exports, explicit 48 kHz PCM16/24,
optional mono/RF64, structured reports and explicit diagnostic export. These
changes are documented in the README and D20–D25; no behavior is added here.

The batch launcher uses system PS5.1 and fixed command text with environment
path values, saving exit status before pause (`WinAudioClean.bat:13`). Fresh
launcher tests exercise both outer shells, actual native argument forwarding,
Unicode/punctuation, the 240-character path case and preserved exits. Default
single-file handoff uses a controlled application stub; this is not a fresh
Explorer drag/drop interactive render or a speech-listening check.

Earlier CMD expansion of positional `%`/`!` names cannot be reconstructed.
Direct PowerShell or the documented environment route remains the supported
alternative. The original Raw marker delay of approximately 25 ms is retained.
The intentional encoder change does not establish legacy bit-identical files.

## Remaining work and evidence limits

Legacy README/help claims about exact loudness, broadcast suitability and
percentage success remain assigned to **WAC-M2-01**, which explicitly owns
claims correction and naming/versioning the Original preset. They are not
endorsed by this reliability gate. Reports correctly keep independent loudness
measurements unavailable; successful export is not sound-quality certification.

Reports have no multi-file atomicity or power-loss guarantee. Crashes and
unrecoverable rollback failures can leave incomplete artifacts; console exits
and diagnostics remain necessary. Capacity checks do not reserve space against
other writers. Full >4 GB output, actual volume exhaustion, running-render
Ctrl+C, long-file/memory stress and speech listening remain unverified. Native
capture remains in memory, and early pre-render errors remain console-only.
