# WAC-M0-04 — Baseline gate and continuation checkpoint

Milestone: M0 | Initial status: todo | Improvement groups: 16, 17

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M0-03

## Small-change scope

Baseline evidence, task state, decisions and next-model handoff.

## Implementation

1. Reconcile all M0 evidence once and resolve actual characterization blockers.

2. Record approved implementation contracts and pending human decisions. Test on the active machine; CI is supplementary.

3. Push the complete checkpoint, verify live remote HEAD, update the draft PR and choose WAC-M1-01 as the exact next task.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-010 — Baseline completeness

Check source identities, filters, runnable test commands and environment inventory.

Expected: Each exists with actual evidence; unexecuted Windows/listening checks remain distinguishable.

### AC-011 — Plan consistency

Run the plan validator after changing task status.

Expected: No unknown dependency, duplicate ID, missing acceptance link, or done task without evidence.

### AC-012 — Thread restart

Start from a fresh Codex thread reading NEXT_MODEL_START_HERE.md and git.

Expected: The next task and unverified checks are clear without reconstructing prior chat or repeating the entire audit.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
