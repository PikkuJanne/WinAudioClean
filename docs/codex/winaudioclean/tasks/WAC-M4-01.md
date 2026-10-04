# WAC-M4-01 — Complete regression and fault-injection coverage

Milestone: M4 | Initial status: todo | Improvement groups: 16

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M3-06

## Small-change scope

Pester suites, local runners and small repeatable native-process fixtures.

## Implementation

1. Consolidate tests developed with each feature; add missing edge/failure coverage from ACCEPTANCE.json.

2. Run PS5.1 and available PS7 locally on the active Windows machine; use deterministic synthetic fixtures for objective checks.

3. Separate subjective listening, platform/manual and stress results from unit tests. Record skips with reasons and gates; do not claim untested Windows releases.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-067 — Coverage traceability

Map every implemented acceptance ID to a test command/report or a named manual review.

Expected: No implemented behavior relies solely on a roadmap checkbox; mandatory gaps remain visible.

### AC-068 — Mutation / fault checks

Inject representative overwrite, bad exit and wrong-sample-rate defects in an isolated test tree.

Expected: Relevant tests detect them; test fixture cleanup cannot remove real user files.

### AC-069 — Efficient repeatability

Run Quick and selected Targeted suites after a narrow change, then one Full gate.

Expected: Runners are reusable and evidence tied to revision; no repetitive all-project audit is required for every small edit.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
