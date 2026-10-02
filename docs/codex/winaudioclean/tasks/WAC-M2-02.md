# WAC-M2-02 — Add measured loudness without changing the default fast path

Milestone: M2 | Initial status: todo | Improvement groups: 8

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M2-01

## Small-change scope

Optional two-pass pipeline and final-file measurement; AUDIO_CONTRACT.md.

## Implementation

1. Keep Fast as the default. Accurate mode measures the exact post-cleaning/post-leveling/post-channel-conversion signal that the final normalization receives.

2. Re-run the identical deterministic prechain for pass 2, parse measured fields invariantly, apply validated values, and record linear versus dynamic fallback. Do not clean or normalize twice accidentally.

3. Inspect the final encoded file after final resampling/quantization. Report requested and achieved values separately; silence/short/unmeasurable audio is explicit, not NaN/Infinity JSON or fake success.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-037 — Pass consistency

Capture both commands for Raw/Zoom, selected stream, mono/stereo and numeric locale variations.

Expected: Prechains, stream, channel policy and parameters match; second pass uses valid pass-1 measurements and invariant decimals.

### AC-038 — Output measurements

Run eligible full-length fixtures at -12 LUFS / -1.5 dBTP and verify final-file loudness/peak.

Expected: Achievable cases meet declared tolerances; constraints/fallbacks are reported and out-of-tolerance results are not called target-compliant.

### AC-039 — Undefined and fallback cases

Use silence, <1-second audio, restricted peak headroom, high LRA and malformed measurement output.

Expected: No unchecked nonfinite values, infinite retries, division errors, or false exact-target claims; fallback is logged.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
