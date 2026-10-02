# WAC-M1-04 — Make output publication transactional and collision safe

Milestone: M1 | Initial status: todo | Improvement groups: 1, 4

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M1-03

## Small-change scope

Output naming, run-owned temporary files, validation and final rename.

## Implementation

1. Use unique job identifiers, a temporary WAV on the destination volume, and exclusive creation/no-clobber semantics; do not rely on minute/second timestamps alone.

2. Require a successful process plus a nonempty readable audio stream and plausible timing before publishing. Ensure the input can never equal any output/temp destination.

3. Rename without replacing an existing final file. On failure remove only this job’s owned partial files; handle abrupt-crash leftovers explicitly without broad cleanup.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-022 — Collision and concurrency

Run same input twice rapidly and two inputs with the same stem; run concurrent jobs targeting one destination.

Expected: Every completed output is unique and prior results/source hashes remain unchanged.

### AC-023 — Failure before publication

Inject encoder failure, disk-full simulation, invalid output, and a crash before rename.

Expected: No normal-looking final export is published; originals/prior exports remain untouched; partial files are identifiable.

### AC-024 — Rename race / validation

Create the intended final filename after name selection; simulate exit 0 with an empty or truncated output.

Expected: No existing file is replaced; validation blocks invalid output and reports the true failure.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
