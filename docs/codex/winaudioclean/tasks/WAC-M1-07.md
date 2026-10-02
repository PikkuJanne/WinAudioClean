# WAC-M1-07 — Reliability regression gate

Milestone: M1 | Initial status: todo | Improvement groups: 1, 2, 3, 4, 5, 6, 14, 15, 16

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M1-06

## Small-change scope

M1 test reconciliation, compatibility review and synchronization evidence.

## Implementation

1. Run cumulative Quick and M1 targeted tests; run one Full gate rather than restarting the whole suite after every cosmetic change.

2. Review all intentional behavior changes and preserved command-line/drag-drop entry points; resolve known data-loss or false-success defects.

3. Update task evidence and checkpoint; push the matching branch and refresh the draft PR with exact tested revision and environment.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-031 — Cumulative regression

Run the documented M0+M1 suite on the active Windows machine in available supported shells.

Expected: All mandatory local checks pass, or the milestone remains blocked with exact failures.

### AC-032 — Non-destructive review

Inspect all file-writing, rename and cleanup paths alongside fault-injection results.

Expected: No source/prior export overwrite, broad cleanup, silent output ambiguity or false-success path remains known.

### AC-033 — Remote checkpoint

Run live sync-check after pushing the implementation/evidence commit and inspect PR state.

Expected: Clean worktree and identical local/live remote HEAD; CI state is accurately separated from local results.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
