# WAC-M0-03 — Capture synthetic and permission-cleared audio baselines

Milestone: M0 | Initial status: todo | Improvement groups: 9, 16

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M0-02

## Small-change scope

Fixture generator, tests/fixtures metadata, baseline reports; private audio stays untracked.

## Implementation

1. Reuse or adapt the bundled standard-library synthetic generator; it is development tooling, not a new application dependency.

2. Characterize both original filter chains on the active Windows machine, recording FFmpeg build, rates, channels, duration and metrics. Preserve the exact legacy filter strings.

3. Prepare an owner-supplied listening corpus checklist without uploading interview audio. Reproduce the 192 kHz behavior rather than copying prior chat claims as test evidence.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-007 — Legacy filter identity

Compare built filter strings for Raw and Zoom with BASELINE.json.

Expected: Parameter values and order match exactly; output-container changes are recorded separately.

### AC-008 — Reproducible synthetic baseline

Run characterization twice using the same local build and inputs.

Expected: Versions, commands, fixture hashes and output format are recorded; variation is investigated rather than masked.

### AC-009 — Private corpus handling

Check ignore rules and staged files before adding the listening-review record.

Expected: No private recordings or identifying local paths are staged; missing listening material is explicitly pending.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
