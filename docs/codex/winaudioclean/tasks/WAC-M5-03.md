# WAC-M5-03 — Final acceptance and approval-ready handoff

Milestone: M5 | Initial status: todo | Improvement groups: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M5-02

## Small-change scope

Final traceability, evidence summary and narrowly scoped pending approvals.

## Implementation

1. Reconcile all 20 improvement groups and 90 acceptance cases. Every unmet or optional/unavailable check has a concrete disposition and risk.

2. Require mandatory safety/compatibility gates; do not silently remove requirements or call untested listening/platform checks passed.

3. Push all intended code/docs/test evidence and prepare the release/merge/deployment proposal with exact revision/assets. Leave actual publication pending approval.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-085 — Complete traceability

Audit TRACEABILITY.md, TASKS.yaml, evidence and release checklist once.

Expected: All improvements are implemented/verified or explicitly deferred with owner approval; no placeholder is reported as complete.

### AC-086 — Safe acceptance

Review mandatory safety tests and all pending subjective/platform checks.

Expected: Known data-loss/security/false-success regressions block acceptance; unreviewed sound changes stay opt-in/experimental.

### AC-087 — Delivery checkpoint

Verify clean worktree, live remote SHA, PR/check status and candidate artifact manifest.

Expected: Owner receives a recoverable, approval-ready checkpoint, not a claim that unapproved release/deployment already occurred.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
