# WAC-M2-01 — Correct audio claims and name the Original preset

Milestone: M2 | Initial status: todo | Improvement groups: 7, 9, 19

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M1-07

## Small-change scope

README, comment-based help, preset metadata and exact legacy filters.

## Implementation

1. Correct LUFS versus RMS, dynaudnorm p, afftdn nf/nr and gate attenuation descriptions using SOURCES.md.

2. Name and version the Original/Legacy preset while retaining its exact filters; distinguish filter identity from encoder format changes.

3. Remove unsupported universal-broadcast, exact-result, Audition-equivalence and 95%-success claims. Do not replace them with invented benchmark percentages.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-034 — Claims audit

Search all shipped docs/help/website drafts for old claims and compare parameter descriptions to official docs.

Expected: Units and limitations are accurate; -12 LUFS is a chosen preset, not a universal broadcast standard.

### AC-035 — Preset compatibility

Compare Original Raw/Zoom filter strings and synthetic output with the baseline on the same build/output settings.

Expected: Filter values/order remain; any differences are explained by explicit encoder behavior rather than silent retuning.

### AC-036 — Preset version report

Select Original from existing interactive paths and a test invocation.

Expected: The effective preset ID/version appears in the report and is not confused with the application version.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
