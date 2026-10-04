# WAC-M2-04 — Add safe excerpt preview and level-matched comparison

Milestone: M2 | Initial status: todo | Improvement groups: 10

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M2-03

## Small-change scope

Optional local preview path, excerpt selection and comparison metadata.

## Implementation

1. Accept an explicit start/duration with useful 30–60 second defaults where input length permits; validate ranges and short files.

2. Apply pre-roll/post-roll when needed for stateful filters and trim comparison outputs to matching positions; label edge limitations.

3. Create an original excerpt and a separately level-matched processed comparison without changing full-render settings. Playback is explicit; preview metrics never stand for full-program loudness.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-043 — Range and alignment

Preview from start, middle and near end of a known timed fixture plus a very short recording.

Expected: Valid matched intervals only; no unexplained offset, overwrite or out-of-range processing.

### AC-044 — Comparison gain

Measure the original/processed comparison pair with the documented matching method.

Expected: Level matching is separate from the mastering preset and does not introduce clipping; unmeasurable cases are clearly labeled.

### AC-045 — No hidden processing

Create/cancel a preview and inspect files, current settings and process state.

Expected: No full recording starts implicitly, source is unchanged and only run-owned preview files are cleaned up.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
