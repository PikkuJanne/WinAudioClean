# WAC-M1-01 — Validate local input, mode and destination before prompting

Milestone: M1 | Initial status: todo | Improvement groups: 2

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M0-04

## Small-change scope

Existing input checks, menu and path-resolution helpers.

## Implementation

1. Use literal file paths; reject directories, nonexistent/unreadable files, URLs and unsupported nonlocal input forms before spawning tools.

2. Resolve the destination, check that it can be created/written, and only then request a mode. Reprompt on invalid input and provide cancellation.

3. For missing interactive input show a useful usage/picker route; automation must fail without prompting. Keep network-share policy explicit rather than claiming every path is offline storage.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-013 — Literal path matrix

Use files with spaces, square brackets, apostrophes, ä/ö/Å, ampersands, percent signs, exclamation marks and parentheses.

Expected: Each resolves to one intended file; no wildcard expansion or unexpected command execution.

### AC-014 — Validation order

Try no input, directory, nonexistent input, URL, unwritable destination and zero-byte corrupt media.

Expected: Clear preflight diagnostics; no mode prompt for invalid paths and no misleading successful export.

### AC-015 — Menu correctness

Enter empty, invalid, valid and cancel choices. Run missing mode with noninteractive semantics.

Expected: Invalid input cannot silently select Zoom; cancellation/noninteractive failure is explicit.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
