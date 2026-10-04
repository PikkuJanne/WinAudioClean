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
