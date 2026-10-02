# WAC-M3-05 — Polish output organization and simple local interaction

Milestone: M3 | Initial status: todo | Improvement groups: 2, 15

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M3-04

## Small-change scope

Music default, optional per-job destination and explicit open-folder action.

## Implementation

1. Keep Music as default; allow chosen output and optional job folders with media/report separation.

2. Provide no-input usage and an optional file picker without adding a mandatory desktop framework; all functions remain accessible through the console.

3. Offer opening the destination only interactively/explicitly; never auto-open files or start external playback in noninteractive runs.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-061 — Destination choices

Run Music/default, custom, per-job and unavailable redirected Music-folder scenarios.

Expected: Predictable paths with safe fallback/error; no writes to unexpected current directories.

### AC-062 — No-GUI operation

Run from a terminal/redirected session without desktop interaction.

Expected: Processing and diagnostics work with no file-picker or Explorer dependency.

### AC-063 — Explicit follow-up actions

Complete success/failure runs and exercise optional open-folder/cancel-picker actions.

Expected: Only requested safe actions occur; failures do not falsely offer a completed output.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
