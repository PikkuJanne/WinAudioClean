# WAC-M2-03 — Add optional gentle cleaning with validated parameters

Milestone: M2 | Initial status: todo | Improvement groups: 9

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M2-02

## Small-change scope

Preset schema, bounded advanced options and listening candidates.

## Implementation

1. Add a conservatively named optional gentle preset with documented settings, not a promise that it is objectively better.

2. Make declip/declick/denoise/gate toggles optional and validate numeric ranges; keep original Raw/Zoom as defaults.

3. Track candidate settings and permission-cleared listening results; do not infer speech quality from tones or automatically detect the best preset.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-040 — Parameter validation

Test valid bounds, invalid values, unknown settings and filter-like injected strings.

Expected: Only typed allowlisted settings construct the graph; no arbitrary filter/command injection through configuration.

### AC-041 — Defaults unchanged

Run the existing no-extra-options Raw and Zoom paths after adding presets.

Expected: Original filters remain the default; Zoom does not accidentally enable cleaning stages.

### AC-042 — Listening candidate record

Compare original/gentle on the approved local corpus or record why unavailable.

Expected: Reviewer evaluates words, consonants, breaths, voice character and artifacts; synthetic checks are not presented as listening approval.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
