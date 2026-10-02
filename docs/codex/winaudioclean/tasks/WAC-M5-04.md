# WAC-M5-04 — Execute only explicitly approved merge and publication actions

Milestone: M5 | Initial status: todo | Improvement groups: 17, 18, 20

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M5-03

## Small-change scope

Approved GitHub merge/tag/release and approved website deployment only.

## Implementation

1. Before any action obtain the owner’s approval specifying action, revision, target and artifact. A request to build this handoff is not publication approval.

2. Re-read live PR/branch status and approved artifact hashes; carry out only the approved subset. Rebuild/revalidate if a merge changes source contents.

3. Verify published release files/metadata or deployed page as applicable; record URLs and hashes. Leave unapproved actions blocked without pretending the project failed.

## Guardrails

Never merge, tag, publish, change repository settings, delete branches, rewrite history, or deploy without explicit owner approval for that action.

## Acceptance

### AC-088 — Approval boundary

Attempt to plan merge/tag/release/settings change/deployment without a matching approval record.

Expected: Action stays blocked; no side effect. Ordinary feature commits/pushes/draft PR updates remain permitted.

### AC-089 — Exact target check

Compare approved SHA/artifact/target to the live candidate immediately before action.

Expected: Mismatch stops publication and returns an updated proposal; no force push or surprise main push.

### AC-090 — Post-action verification

For each approved action, check actual remote state and downloaded asset hash/site metadata.

Expected: Recorded result matches what was published; outstanding approvals and rollback route are explicit.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
