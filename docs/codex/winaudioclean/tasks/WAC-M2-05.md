# WAC-M2-05 — Audio gate with honest listening status

Milestone: M2 | Initial status: todo | Improvement groups: 7, 8, 9, 10, 16

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M2-04

## Small-change scope

Listening review, measurement evidence, decisions and compatibility checkpoint.

## Implementation

1. Run numeric/audio-format regressions and complete a permission-cleared listening review when material is available.

2. Do not block unrelated reliability delivery solely because optional gentle-preset/default promotion lacks a listening corpus. Keep candidates opt-in/experimental and defaults unchanged.

3. Any proposal to change default sound requires explicit owner approval referencing settings, evidence and revision. Record pending reviews instead of inventing acceptance.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-046 — Objective audio gate

Run all applicable M2 numeric and structural checks.

Expected: Mandatory implemented-mode checks pass; ineligible/undefined metrics are explicitly classified.

### AC-047 — Human gate integrity

Inspect listening template, corpus consent and approval records.

Expected: Real reviewer results are attributable; missing listening approval prevents default promotion, not a fabricated pass.

### AC-048 — Reproducible settings

Recreate an output from the report using the same build/input/settings and push the checkpoint.

Expected: Preset/format choices are traceable and the exact accepted revision is recoverable from GitHub.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
