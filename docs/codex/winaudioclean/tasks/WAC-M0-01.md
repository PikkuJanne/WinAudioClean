# WAC-M0-01 — Reconcile and install the handoff without changing runtime behavior

Milestone: M0 | Initial status: todo | Improvement groups: 16, 17

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

None; begin with reconciliation.

## Small-change scope

AGENTS.md and docs/codex/winaudioclean; inspect the existing checkout and GitHub before installing.

## Implementation

1. Inspect all applicable AGENTS.md files, git status, branch, origin fetch/push URLs, current HEAD, and open PRs. Reconcile drift from BASELINE.json; do not reset to the reviewed commit.

2. Preview the importer. Work on codex/wac-m0-handoff or an already established matching work branch. Merge existing governance additively; never replace the product README, live tasks, or decisions.

3. Record the active machine tools and baseline; install governance only, add narrowly scoped generated-file ignores, commit/push, verify remote HEAD, and open or update one draft milestone PR. End the session before runtime changes.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-001 — Wrong checkout / dirty worktree

Try the helper against a different origin, a dirty tree, and a detached HEAD.

Expected: Apply fails without modifying existing files or changing branches.

### AC-002 — Preview and collision safety

Preview then apply on a clean feature branch; repeat. Introduce an existing different AGENTS.md in a separate fixture.

Expected: Preview is read-only; repeat is idempotent; differing files are reported, not overwritten.

### AC-003 — Initial checkpoint

Compare runtime files before/after governance import; commit and push only intended handoff files. Run live sync-check.

Expected: Runtime content is unchanged; clean worktree, matching local/live-remote branch HEAD, and a real PR reference or explicit API blocker are recorded.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
