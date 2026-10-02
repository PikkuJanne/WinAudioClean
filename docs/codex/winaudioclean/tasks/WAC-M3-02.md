# WAC-M3-02 — Support multiple dropped files through the existing launcher

Milestone: M3 | Initial status: todo | Improvement groups: 11

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M3-01

## Small-change scope

.bat launcher and compatible file-list handoff; not a replacement GUI.

## Implementation

1. Preserve single-drop behavior and extend to ordered multi-file input, choosing mode once.

2. Test actual CMD-to-PowerShell forwarding in PS5.1/PS7; a naive %* or -File array handoff is not assumed correct. Use a safe structured handoff only when required.

3. Handle command-line length and special-character limitations explicitly, provide folder/manifest fallback, and preserve exit status around interactive pause.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-052 — Real drag/drop matrix

Drop one and several files, including spaces, Unicode, brackets, %, !, &, apostrophes and parentheses, onto the actual launcher.

Expected: Each intended input appears once in the queue without truncation, corruption or command execution.

### AC-053 — Aggregate result

Process a list containing valid and invalid items.

Expected: Per-item results persist; overall exit code reflects failure; single-file behavior remains compatible.

### AC-054 — Boundary handling

Test many/long paths and double-click with no files.

Expected: No silently lost inputs; actionable safe fallback for launcher limits and clear no-input guidance.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
