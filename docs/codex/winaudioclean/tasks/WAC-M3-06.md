# WAC-M3-06 — Workflow and automation gate

Milestone: M3 | Initial status: todo | Improvement groups: 2, 11, 12, 13, 14, 15

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M3-05

## Small-change scope

End-to-end local workflow review and thread checkpoint.

## Implementation

1. Exercise the original single-file workflow alongside multi-file, folder, preview and noninteractive flows.

2. Run cumulative targeted tests once, focusing on launcher boundaries, cancellation and configuration migration.

3. Document remaining platform constraints, push the checkpoint and update the exact next task.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-064 — Original workflow

Drop a typical interview file, select 1/2 and inspect the result/report.

Expected: Same simple front-door experience remains; new settings do not overwhelm the default menu.

### AC-065 — Automation workflow

Invoke unattended batch with explicit parameters and examine process codes/files/reports.

Expected: No prompt, missing file, misleading aggregate result or timing change.

### AC-066 — Reentry workflow

Restart in a new thread or clean checkout with recorded settings intentionally absent.

Expected: Built-in defaults suffice; state and remaining tasks are recovered from Git, not hidden machine settings.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
