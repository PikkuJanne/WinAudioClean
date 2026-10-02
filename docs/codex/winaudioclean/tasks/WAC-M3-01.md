# WAC-M3-01 — Add noninteractive parameters and saved settings

Milestone: M3 | Initial status: todo | Improvement groups: 12

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M2-05

## Small-change scope

Backward-compatible parameters, local JSON settings and help.

## Implementation

1. Add -Mode, -Preset, -OutputDirectory and -NonInteractive while retaining -inputPath. Avoid a breaking positional-parameter redesign.

2. Use typed versioned JSON under the user profile; precedence is explicit CLI > saved settings > built-in defaults. Show effective settings and provide reset.

3. Validate and atomically save configuration; do not treat it as executable PowerShell or pass arbitrary filter strings. Unattended mode never calls Read-Host or pauses.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-049 — Precedence matrix

Set conflicting built-in, saved and CLI values then reset settings.

Expected: Documented precedence wins; legacy input invocation remains valid.

### AC-050 — Unattended behavior

Run with all required values; omit a required mode/stream or supply invalid settings with redirected stdin.

Expected: No prompt/pause or hang; valid jobs run and invalid jobs fail with a useful exit code.

### AC-051 — Config durability

Test malformed JSON, unknown schema, wrong types, interrupted save and German/Finnish decimal culture.

Expected: Safe diagnostics, previous valid config preserved and invariant FFmpeg serialization; no arbitrary code execution.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
