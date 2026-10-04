# WAC-M4-03 — Build a versioned portable release package

Milestone: M4 | Initial status: todo | Improvement groups: 17, 18

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M4-02

## Small-change scope

scripts/Build-Release.ps1, allowlisted payload, checksums and dependency notices.

## Implementation

1. Build locally from an explicit clean revision with one authoritative version; zip only allowlisted runtime files/docs/icons.

2. Produce a tool-only ZIP first. Do not bundle FFmpeg until exact-build license/source/notice obligations and owner approval are satisfied.

3. Generate checksums/provenance and validate install from a fresh extracted ZIP; keep development assets, logs, recordings and handoff tests out of runtime packages.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-073 — Package contents

Build twice from the same inputs; inspect archive entries and metadata/checksums.

Expected: Version and content manifest agree; reproducibility claims match actual results; no private/development-only files.

### AC-074 — Fresh package use

Extract into a clean user-writable folder with spaces/Unicode; supply approved local dependencies.

Expected: The documented .bat and PowerShell paths work without a repo, Python or test modules installed.

### AC-075 — Licensing and integrity

Review included notices, dependency provenance and generated hashes.

Expected: MIT notice is preserved; bundled third-party build obligations are checked or bundling remains explicitly blocked.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
