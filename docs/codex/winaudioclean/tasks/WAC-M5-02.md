# WAC-M5-02 — Rehearse clean-checkout and release-candidate reconstruction

Milestone: M5 | Initial status: todo | Improvement groups: 17, 18, 20

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M5-01

## Small-change scope

Temporary clean clone/worktree on the same active machine and release-candidate evidence.

## Implementation

1. Recover from the exact pushed revision using a temporary clean checkout on this machine, not another machine or a hosted processing service.

2. Run documented development setup, selected tests and build; compare content manifest and website metadata.

3. Check staging and artifacts for secrets, personal paths, private audio and accidentally included binaries; do not publish anything.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-082 — GitHub reconstruction

Fetch the checkpoint and create a clean detached worktree/clone for the explicit SHA.

Expected: Project builds/tests using documented prerequisites; no hidden local edits or untracked runtime dependencies are required.

### AC-083 — Candidate integrity

Compare candidate contents, hashes and version across packaging and website metadata.

Expected: All artifacts identify the same source revision/version; invalid checksum/version inputs fail validation.

### AC-084 — Privacy and rollback

Review candidate files and documented rollback to a prior release/source tag.

Expected: No confidential content ships and rollback does not erase source recordings/settings without consent.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
