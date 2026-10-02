# WAC-M3-03 — Add sequential folder queues and batch summaries

Milestone: M3 | Initial status: todo | Improvement groups: 11

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M3-02

## Small-change scope

Queue builder, optional recursion and per-file result aggregation.

## Implementation

1. Default to sequential processing, with explicit recursion and supported local file selection.

2. Materialize and deduplicate the queue before processing; exclude this tool’s outputs/temp files and avoid symlink/junction traversal loops.

3. Continue after per-file failure, preserve per-file reports and emit a final successful/failed/skipped/cancelled summary. No automatic audio re-cleaning.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-055 — Folder selection

Process a mixed folder including output files, nested folders and a junction/symlink loop fixture.

Expected: Recursion is off by default; no loop or generated-output reprocessing; unsupported files are explained/skipped.

### AC-056 — Queue stability

Select duplicate paths and inputs with identical stems; place the destination inside the input folder.

Expected: Inputs are deduplicated, names remain collision-safe and newly generated output never enters the running queue.

### AC-057 — Failure continuation

Fail a middle item and process remaining items; repeat with cancellation.

Expected: Failure does not discard other results; cancellation stops new jobs and aggregate status is truthful.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
