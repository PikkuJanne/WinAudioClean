# WAC-M5-01 — Prepare static website assets and release metadata

Milestone: M5 | Initial status: todo | Improvement groups: 20

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M4-04

## Small-change scope

An isolated static product-page draft and schema; no deployment or other tools changed.

## Implementation

1. Prepare a portable static page/content package for the future tools website, not a new hosting platform. Reuse existing branding where rights are clear.

2. Show real screenshots and permission-cleared audio samples only; unfinished assets remain explicitly unavailable, not invented.

3. Use versioned release metadata with status, version, date, URL, checksum and requirements; draft status must disable download claims. No uploads/accounts/processing backend or automatic local updater.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-079 — Architecture boundary

Inspect page code, browser requests and runtime script behavior.

Expected: Website only presents/distributes; tool never needs the website to process audio; no upload endpoint/telemetry is introduced.

### AC-080 — Metadata correctness

Validate draft and published-like fixture metadata against packaging output.

Expected: No fabricated release link/hash; draft/unpublished assets cannot appear as a working stable download.

### AC-081 — Accessible presentation

Test keyboard navigation, meaningful labels, readable layout and sample consent records.

Expected: Page is usable and honest; missing real assets are marked pending without fake screenshots/reviews.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
