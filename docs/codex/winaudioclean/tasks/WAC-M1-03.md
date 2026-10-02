# WAC-M1-03 — Resolve dependencies and probe/map audio streams

Milestone: M1 | Initial status: todo | Improvement groups: 5, 6

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M1-02

## Small-change scope

Dependency discovery, ffprobe JSON inspection and explicit -map construction.

## Implementation

1. Retain sibling and PATH FFmpeg resolution; add an explicit-path override with known precedence and ffprobe discovery.

2. Log full resolved executable paths and versions; check selected-mode filters without quietly downloading or installing tools.

3. Inspect audio streams and choose explicitly. For multiple streams prompt interactively; require explicit selection unattended. Scope local-media protocols to prevent unexpected remote media fetching.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-019 — Dependency resolution

Test explicit, sibling and PATH locations; missing, incompatible and selected-mode-filter-deficient builds.

Expected: Precedence is deterministic, failures are actionable, and no download happens without consent.

### AC-020 — Stream choice

Use a container with two distinguishable tracks and a video-only container.

Expected: Selected absolute stream index maps to the expected audio; no-audio fails before cleaning; unattended ambiguity fails.

### AC-021 — Probe safety

Test malformed JSON, timeout, nonzero probe exit and local playlist referencing an external URL.

Expected: No false metadata or unbounded hang; unsupported network references are rejected/blocked and documented.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
