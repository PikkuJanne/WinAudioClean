# WAC-M0-02 — Create minimal test seams and local PowerShell test runners

Milestone: M0 | Initial status: todo | Improvement groups: 16

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M0-01

## Small-change scope

WinAudioClean.ps1, small internal helper file only when useful, tests/, scripts/Invoke-Tests.ps1.

## Implementation

1. Add Pester and PSScriptAnalyzer as development-only dependencies with pinned versions and explicit setup, not runtime installation.

2. Extract only path/filter/command/report helpers needed to test existing behavior. Dot-sourcing testable code must not prompt, launch FFmpeg, clear a console, or exit the test host.

3. Create Quick, Targeted, and Full runners. Characterization tests describe known bugs without treating them as desirable product requirements.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-004 — Compatibility entry points

Invoke the original -inputPath call and the .bat entry point with controlled input in both available Windows shells.

Expected: Existing modes and entry points remain; unavailable shell runs are marked not-run, not passed.

### AC-005 — No import side effects

Load test helpers in a fresh process with FFmpeg/process-start mocked.

Expected: No menu, process, writes, or exit on import; tests can run unattended.

### AC-006 — Useful checks

Run the new Quick runner, deliberately break a tested helper in an isolated worktree, then restore it.

Expected: The runner fails for the deliberate defect and passes after restoration; no broad analyzer suppressions hide it.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
