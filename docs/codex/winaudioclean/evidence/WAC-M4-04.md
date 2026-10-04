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
