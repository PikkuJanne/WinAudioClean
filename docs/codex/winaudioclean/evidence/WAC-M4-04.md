# WAC-M4-04 — Accepted user help, setup and troubleshooting

Accepted AC-076..078 on 2026-10-04 within the recorded active-machine/synthetic scopes. Final packaged documentation/controller source `1f10940ee970ebe719c21ba0e7290830beeb7123` passed all 64 cases: 30 README commands, 12 Get-Help examples, two literal ZIP-checksum commands and 20 support cases. Both PS5.1 and PS7 tokens were non-elevated. Every public parameter (31) has help; actual defaults are PCM16, Fast, Original, empty cleaning overrides, preview start 0/duration 45. Help and option descriptions are compared with the parsed actual parameter declarations.

Two clean host builds are identical: 438904 bytes, SHA256 `d543ab046e9b1c5330552038f4eaa9eea794b2392ced079e620ed2f65cf04bf7`, application 2.3, 17 committed payload files plus manifest. Commit/tree, committed bytes, MIT bytes, fixed archive metadata and sidecars agree. FFmpeg/ffprobe 9.0.2 essentials are separately supplied; their exact hashes are in the ledger. No release/download/website publication is inferred.

## Executed commands and scopes

- `python -X utf8 scripts/Invoke-CIChecks.py --shell-path <actual-system-PS5.1-or-pinned-PS7-exe> --shell-family <ps51-or-ps7> --level Full`: both exit 0 at clean `047aefe906ca7954a225d81f53286eb1275723dc`; Pester 1483 passed/1 privilege skip, Python 142 ran/1 privilege skip per host, zero outside scope and seven stable source digests. Windows build 26300, PS5.1.26100.9444/7.6.5, Python 3.14.6, Pester 5.7.1 and PSScriptAnalyzer 1.24.0 are recorded. These Full scopes remain attached to their actual earlier source.
- `scripts/Build-Release.ps1 -Revision 1f10940ee970ebe719c21ba0e7290830beeb7123 -OutputDirectory <new-absolute-local-folder>` ran once on each host from that clean HEAD; both exit 0 and actual archives match.
- `python -B -X utf8 scripts/Test-Documentation.py --zip <absolute-clean-ZIP> --commit 1f10940ee970ebe719c21ba0e7290830beeb7123 --ffmpeg <absolute-approved-ffmpeg> --ffprobe <absolute-approved-ffprobe> --ps51 <absolute-system-host> --ps7 <absolute-pinned-host> --output <new-absolute-short-ignored-folder>`: exit 0. README/portable fenced bytes and Get-Help command content are executed unchanged from fresh spaces/Unicode packages with a disclosed eight-second stereo 48 kHz synthetic `recording.wav`. The manifest/first-run setup is supplied exactly as documented; no Git/Python is available on the application PATH, and startup module visibility is recorded separately.

The final checker verifies requested options/cleaning/layout/container, selected track 0, exact three-second Preview at start 1, four PCM assets, attenuation/matching meters, Accurate native stage/filter/measurement/compliance evidence, journal preferences/routes, every save/show/reset action and old-summary append prefix. Input, payload, copied/original tools, archive/sidecars, controller source and actual Windows known-folder preferences stayed unchanged.

Missing dependency returns 3, corrupt media 4, invalid destination 2; owned ACL denial returns 2 with empty output, exact descriptor restoration and successful recovery 0. Repeated runs retain prior exports/reports. Ordinary redacted export succeeds, existing diagnostic destination is preserved/rejected 2, and actual Preview export is rejected 2. Existing Full transaction tests additionally force no-replace audio publication collisions. Raw SID/ACL, paths, logs and audio remain ignored/local; only fixed facts/hashes reach this record. No machine-wide security settings change.

## Retained failures and review

The initial 58-case ZIP capture at 047aefe had 57 passes and one PS7 list exit 5 before rendering (journal 261 characters). Shorter exact replays succeeded on both hosts at journal 241/media 254; native-only PS7 repeated the long-path failure independently of an initial module-remoting harness issue. README/portable/support now recommend short extraction/output bases. This is a host limitation, not a universal path bound or stress guarantee. The final walkthrough records actual maximum generated path lengths numerically.

Initial Targeted selections passed 16/0/0 per host but source changed during capture; they are retained development evidence, not accepted stable gates. Early controller relative arguments were rejected before execution and replaced with an absolute-path invocation. Initial plan/next calls omitted --plan-root; a later coverage invocation named an absent helper. Corrected canonical tools passed; failure scopes are not promoted.

Independent bounded reviews checked versions (application 2.3; Original original/1.0.0; Gentle gentle/0.1.0), -12 LUFS/-1.5 dBTP targets, timing/RF64/CMD/host limits, privacy/local processing and ordinary/Preview/journal formats. The current redacted exporter accepts ordinary schema 1 reports only. Website download metadata is absent future M5-01 work. Main runtime body after comment help and all other PS/BAT components match the parent under existing newline normalization; default sound is unchanged. Builder/release tests match the Full source. Later changes are documentation/comment-help/controller only; unchanged Full is not repeated for those edits.

The revised controller guard accepted 36 actual retained reports and two valid projections, and rejected 21 wrong-evidence counterexamples. An eight-case fresh settings/owned-permission smoke passed separately on both hosts. Guard and final-controller SHA256 `3cf5cd6fd7d24c4633e4163372e7b194a5840219a6b2534fc394f245b4a5266b` agree.

All four CI jobs passed at the frozen Full revision in [run 37180768822](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37180768822). At the final documentation revision the observed CI state is **pending**, 0/4 completed-success jobs: [observed run](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37182513533). This is a point-in-time observation; inspect future closure CI separately. Pending/cancelled/unavailable CI is not a pass.

All eight broader coverage gaps remain, including listening/UI/storage/meter/crash scopes and local file-symlink privilege. Closure should produce 26 done/4 todo and 78 pass/12 not_run, leaving only **WAC-M5-01 — Prepare static website assets and release metadata** ready. Commit/push/live branch equality and PR status are verified after closure outside its own commit. No merge, main push, tag/release, repository setting, third-party bundling, sound promotion or deployment occurs.

Detailed sanitized results: [validation ledger](WAC-M4-04-validation.json). Raw captures remain local. Historical progress below is superseded by this accepted record.

Closure checks passed: validate-plan, structural coverage (78 cases / 42 commands / 9 reviews / 8 retained gaps), next (only M5-01 ready), 13 coverage regressions and one actual canonical-plan test. Two module-name test invocations could not locate the test module before executing it; the explicit file loader passed. Those failures remain in the ledger.

## Historical implementation/validation progress

# WAC-M4-04 — Help, setup and troubleshooting

Implementation and validation are in progress on 2026-10-04. Canonical
WAC-M4-04 / AC-076..078 remain todo / not_run pending exact clean-package
examples and the relevant cumulative gate. Parent checkpoint
`33efc4a2f589927203997d65f76096f46bfe3c65` was clean and live-synchronized;
its actual PR CI run 37152237090 completed all four required jobs.

## Intended scope

README first-run path and relative runnable examples; all public comment-help
parameters; normal-user setup, dependency verification, support/privacy and
security docs. Correct diagnostic export scope to ordinary full-run JSON;
actual preview reports and queue journals are rejected by the current exporter.
Keep all runtime code after the comment-help boundary byte-equivalent under
existing line-ending normalization. Original/Gentle/Fast choices, application
2.3, eight runtime components and BAT behavior are unchanged.

Support and security guides join the fixed runtime-doc allowlist (17 committed
files plus manifest). Corresponding builder/controller fixtures change only
that inventory. Historical M4-03 counts, package hash and tested code remain
historical. No third-party binary is added to the release ZIP.

## Verification plan and captured initial checks

Execute exact README/Get-Help examples from clean ZIPs on PS5.1 and PS7 using
synthetic 8-second media, existing approved external FFmpeg/ffprobe, isolated
example settings and writable spaces/Unicode paths. Run portable checksum
commands literally. Exercise missing tool, corrupt media, invalid destination,
repeat/no-clobber and redacted support recovery separately. Raw recordings,
reports and paths remain ignored; publish only fixed summarized results.

Eight offline release-controller regression cases passed after the expected
payload/entry count update. Initial exact-path Targeted runs are retained
separately: source editing during initial capture can invalidate its before/
after identity, even if the Pester test gate itself passes. Rerun final checks
only after implementation stabilizes; do not label an unstable capture accepted.
Initial validate-plan/next omitted the required --plan-root argument and failed;
corrected calls passed with only M4-04 ready. No failure is converted to a pass.
Default Git diff --check interprets existing CRLF additions as trailing CR;
scoped core.whitespace=cr-at-eol correctly verifies the retained file convention.

## Remaining limits

All eight broader COVERAGE gaps remain: no listening/default-sound promotion,
new manual UI observation, >4 GB/disk-exhaustion/long-memory stress or crash/
power-loss guarantee is inferred. Website release/download metadata does not
yet exist; compare its absence/contracts without implementing the future M5 task.
No merge, main push, tag/release, repository setting or deployment occurs.

### Stable Full and documentation follow-up checkpoint

Both actual local Full gates at clean `047aefe906ca7954a225d81f53286eb1275723dc` passed Pester 1483 / 1 privilege skip and Python 142 ran / 1 privilege skip; zero outside scope and all seven source digests stable. Exact PR run 37180768822 completed all four Windows 2022/2025 PS5.1/PS7 jobs successfully. These scopes remain tied to that revision.

The initial clean ZIP walkthrough ran 58 cases: 57 passed; the PS7 explicit-list example failed before rendering while opening a 261-character journal. Retain it separately. Fresh exact-command replays at journal 241 / media 254 characters passed PS5.1 and PS7. Native-only module lookup removed an independent harness remoting issue without fixing the long-path failure. No universal path-length guarantee is inferred. Short extraction/output guidance is added; application runtime is unchanged.

The checker now validates requested settings/cleaning, exact Preview 1..4 seconds, Accurate stage/filter/meter/compliance claims, queue preferences/routes, every settings action, append-only old summaries and normalized local containment. Root split the published settings fence into save/show/reset. Independent review and 36 retained reports plus 21 deliberately wrong-evidence counterexamples passed their stated scopes; synthetic valid warning/reset projections also passed. A separate eight-case settings/owned-permission smoke passed on both non-elevated hosts, including actual write denial, empty blocked output, exact permission restoration and successful recovery. The complete final 64-case walkthrough remains pending.

Current Windows OS build is 26300 (verified from CIM and the Full wrapper); PS5.1 remains 5.1.26100.9444. README/comment-help tested-build notes are corrected. Clean candidate rebuild and 64 exact final package checks are pending. Only documentation/comment-help/controller change after the frozen Full source; no runtime body, builder/test or default-sound change is needed. Canonical M4-04 / AC-076..078 remain todo/not_run until those checks pass.
