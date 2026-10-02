# WAC-M3-04 — Add stage-aware progress and controlled cancellation

Milestone: M3 | Initial status: todo | Improvement groups: 13

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M3-03

## Small-change scope

Process progress parser, queue cancellation and cleanup.

## Implementation

1. Use FFmpeg structured progress output rather than scraping human statistics; keep logs on the separate diagnostic stream.

2. Show stage labels and per-file position; Accurate analysis/render/verification have separate ranges. Use indeterminate progress when duration is unknown.

3. Implement cancellation against this run’s owned child process only, with bounded cleanup and no global kill-by-name command.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-058 — Progress semantics

Run fast/accurate/preview jobs, variable-speed data and unknown duration.

Expected: Progress is bounded, stage labels correct, and 100% is not shown before validation/publication.

### AC-059 — Owned-process cancellation

Run two independent jobs, cancel one at analysis/render/verification in separate tests.

Expected: Only the cancelled run stops; no new queued job starts; originals/other exports remain intact.

### AC-060 — Abnormal child / console

Force unexpected child exit, truncated progress lines and closed/redirected console.

Expected: No deadlock, misleading success or unbounded wait; final status remains in the report.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
