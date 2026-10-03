# WAC-M4-03 — Portable release package evidence

Accepted AC-073..075 at clean code `4609265b1ed40da08897d7d816196ec466adaef0` on 2026-10-03. Only M4-03 advances:
25 tasks done / 5 todo, 75 AC pass / 15 not_run. The next task is **WAC-M4-04 —
Finish user-facing help, setup and troubleshooting**; it has not started.
[Validation ledger](WAC-M4-03-validation.json) retains actual commands, source
identities, tool versions, case IDs, counts and integrity results.

## Package contents and repeatability — AC-073

`scripts/Build-Release.ps1` requires an explicit full lowercase revision equal
to clean HEAD. It reads ordinary committed Git blobs and preserves their bytes,
including the binary icon and MIT notice. The existing literal
`scriptVersion = "2.3"` remains the sole application version authority.

The fixed payload has eight PowerShell files, BAT, the existing icon, LICENSE,
README, portable instructions, dependency notices and the report-format document
linked by README. The generated manifest makes 16 ZIP entries. Tests, build tools,
handoff records, settings, logs, recordings and dependency binaries are excluded.
Manifest/source commit/tree, payload lengths/SHA256 and external checksum/
provenance all agree. Creation uses new files and refuses dirty sources, missing
or nonordinary Git entries, reparse ancestry and any existing output name.

Framework and Core emitted different NoCompression methods/flags in the first
in-memory probe. The canonical Stored ZIP writer fixes order, UTF8 headers,
1980 timestamp, CRC32, attributes and ZIP32 bounds. Four actual clean builds,
two each on PS5.1.26100.9444 and PS7.6.5, are byte-identical: 447048 bytes,
SHA256 `e72fce6cae5d0e94473bde1b94657e778a472c6ff17aa6a2065c795438bf604c`. Same-host and cross-host claims are scoped to those observed
versions and source inputs. Independent ZIP CRC/layout/blob checks passed.

## Fresh extracted use — AC-074

The actual ZIP was extracted to a NEW user-writable folder with spaces and
Unicode. Eight unmodified entry-point runs covered direct PowerShell -File and
BAT /unattended, Raw and Zoom, on PS5.1 and PS7. Four separate builtin-module-only
bootstrap cases invoked the same extracted application after constraining module
lookup. All 12 cases exited 0 with successful schema 1 reports, zero warnings and
valid stereo 48 kHz 16-bit RIFF WAVs of 8 seconds. Input, complete package inventory,
controller source and approved tools stayed unchanged; isolated settings stayed
absent. Report sourceRevision is null/not_embedded; package provenance supplies
the exact build identity without adding a runtime Git dependency.

`Get-Command python` and `Get-Command git` found neither executable in the child
PATH. Normal PS5.1 startup can see
system Pester 3.4.0, and normal startup adds shared/user module roots. The separate
bootstrap cases had only builtin module roots, no visible test modules and zero
loaded Pester/PSScriptAnalyzer modules. This verifies dependency independence
on the shared development machine; it does not claim physical uninstallation
of its other software. The eight broader listening/UI/stress/crash gaps remain.

## Licensing and integrity — AC-075

The included MIT LICENSE remains 1070 bytes with its 2025 Janne Vuorela notice,
SHA256 `714ffa7a21614e637d7dbb17a2e86e4575d7ecd2b6d36b5b67ab3fdcc4193477`.
The icon is the original tracked repository asset; no external asset was added.
No third-party binary is included. Approved external FFmpeg/ffprobe 9.0.2 hashes
and successful -version/-L probes are recorded in the ledger. That observed
essentials build reports GPL version 3 or later and gpl/version3/static flags;
the notices direct users to the exact build's obligations and
[official FFmpeg licensing guidance](https://ffmpeg.org/legal.html). Bundling
remains unapproved. The archives are local artifacts; no tag/release/publication
or deployment occurred. A checksum is an integrity comparison, not a signature.

## Regression and synchronization

The initial exact-path Targeted run passed 16 fixtures per host with zero skips
and seven unchanged source digests over the in-progress parent f32cf159 contents.
Eight reusable offline controller cases passed, including rejection of hidden
ZIP data, mismatched local headers, added extracted files and invalid WAV policy.
Their scoped loader avoids introducing untracked script bytecode in Full.

Both actual local Full gates at `4609265b1ed40da08897d7d816196ec466adaef0` passed Pester 1483
/ 1 privilege skip / 0 outside scope and Python
142 ran / 1 privilege skip.
Pester 5.7.1, PSScriptAnalyzer 1.24.0 and Python 3.14.6 are observed pins. All seven
source digests match before/after and between hosts. Four exact-code Windows
PR jobs also succeeded: [code CI run](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37150442388). Hosted artifacts and their
scope are recorded separately from local privilege skips.

Closure-only coverage tests passed 13 cases and the discovered canonical-plan
test passed 1. Two direct module-name plan-test invocations could not import the
module with the pinned embedded interpreter; corrected discovery ran the actual
test successfully. Validators confirm only M4-03/AC-073..075 changed, 75 mapped
cases, eight retained gaps and only M4-04 ready.

Parent `f32cf1591a288ff356f69aa3a2320adf62959808` was synchronized; its metadata-only
CI run 37148623973 completed all four jobs. The code checkpoint was pushed and
clean local/upstream/live equality verified before building. This closure changes
acceptance/handoff evidence only. Its future SHA/live CI belongs in the PR/final
response, avoiding a self-referential commit loop. Runtime, defaults, source-only
original and all eight broader gaps remain preserved.
