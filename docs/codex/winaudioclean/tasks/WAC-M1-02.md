# WAC-M1-02 — Harden native process execution, exit codes and diagnostics

Milestone: M1 | Initial status: todo | Improvement groups: 4, 14

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M1-01

## Small-change scope

FFmpeg process wrapper and .bat exit-code propagation; NATIVE_PROCESS_CONTRACT.md.

## Implementation

1. Use a small tested native-process wrapper that captures stdout/stderr independently and drains both without deadlock.

2. Do not use Invoke-Expression, shell-built user commands, or assume Start-Process string arrays solve Windows quoting. Test the PS5.1 and PS7 paths explicitly.

3. Set -nostdin for unattended FFmpeg, handle start failures/exceptions, and define application exit codes. Preserve the script result before any interactive pause in the launcher.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-016 — Argument fidelity

Use a benign argv-echo test executable or equivalent recorder with the filename matrix through both the direct script and actual launcher.

Expected: The child receives exact arguments; command-like filenames cannot become commands; any CMD limitation gets a safe fallback and explicit notice.

### AC-017 — Error propagation

Simulate startup failure, FFmpeg nonzero exit, failed reporting, and successful execution.

Expected: Script and launcher return documented codes and retain useful diagnostic details without claiming success.

### AC-018 — Output and stream handling

Have a test child write large stdout/stderr streams, then exit; repeat with a known synthetic FFmpeg job.

Expected: No deadlock or truncation of essential errors; all handles are closed and completion is accurately observed.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
