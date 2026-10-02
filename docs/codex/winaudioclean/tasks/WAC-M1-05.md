# WAC-M1-05 — Specify PCM output, channel policy and large-file behavior

Milestone: M1 | Initial status: todo | Improvement groups: 3, 15

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M1-04

## Small-change scope

Output encoder settings, disk estimation and RF64 choice.

## Implementation

1. Make 48 kHz / 16-bit PCM WAV the proposed explicit export default; document this intentional format change and retain the legacy filters unchanged.

2. Offer 24-bit PCM for editing; preserve the selected track’s channel count/layout, with explicit mono conversion only. Establish clear policy for unsupported layouts.

3. Estimate destination/temp space with safety headroom; offer/test RF64 for >4 GB, or fail early with guidance. Never silently cut duration or split tracks.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-025 — Explicit output matrix

Process 44.1/48 kHz mono and stereo fixtures in both modes and 16/24-bit choices; inspect with ffprobe.

Expected: Selected sample rate/codec/channels are correct; no accidental 192 kHz default export.

### AC-026 — Timing and channels

Use stereo channels with different signals and known impulses; compare start/end and duration before/after.

Expected: No unintended downmix, channel swap, silence removal, leading offset or unexplained timing drift.

### AC-027 — Large-file and space policy

Unit-test estimates around the WAV size boundary and inject low-space conditions; exercise an RF64 header with a small supported fixture.

Expected: Policy is deterministic and documented; full >4 GB stress is run only when risk warrants it, or clearly not claimed as tested.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
