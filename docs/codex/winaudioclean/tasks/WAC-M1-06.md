# WAC-M1-06 — Produce readable, structured, privacy-aware run reports

Milestone: M1 | Initial status: todo | Improvement groups: 14

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M1-05

## Small-change scope

Per-run text/JSON report writer and retained summary log.

## Implementation

1. Keep a human summary and add versioned per-run JSON with status, versions, stream, settings, exact filters, input duration, processing elapsed time, output format and metrics availability.

2. Retain native diagnostics on failure, keep job IDs unique, and distinguish processing success from report-write warnings using documented policy.

3. Provide an explicit redacted diagnostic export that removes user paths and sensitive metadata; never upload logs automatically.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-028 — Report fidelity

Run success, encoder failure and validation failure; compare console, JSON, human log and process exit.

Expected: Statuses agree; recording duration differs from wall time; unsupported/nonfinite measurements become null plus reason.

### AC-029 — Privacy export

Generate a report containing user-directory names, filenames, container title and potential sensitive diagnostic text.

Expected: Redacted output omits sensitive values and warns about review; raw report remains local only.

### AC-030 — Concurrent and failed logging

Run concurrent exports and inject a log destination permission failure.

Expected: Reports do not overwrite/interleave incorrectly; audio is not deleted solely because reporting failed; outcome is unambiguous.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
