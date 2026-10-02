# WAC-M4-02 — Add GitHub CI that supplements local validation

Milestone: M4 | Initial status: todo | Improvement groups: 17

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M4-01

## Small-change scope

.github/workflows, development dependency lock/manifest and local parity.

## Implementation

1. Pin tool/module versions and third-party Actions to verified full commit SHAs; verify downloaded binaries against trusted checksums.

2. Use least-privilege read-only checks on PR/push, safe triggers and no secret access for untrusted PR code. Avoid pull_request_target execution of contributed code.

3. Exercise supported shells/builds on Windows CI and upload only synthetic/redacted artifacts with retention limits. CI must call the same local test runners.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-070 — CI/local parity

Compare workflow commands and versions to local runners; run a PR check.

Expected: Same checks are invoked, versions recorded, real green/failure status linked to the tested SHA.

### AC-071 — Workflow permissions

Review permissions, triggers, pinned actions, downloads and secrets exposure.

Expected: Untrusted PR tests cannot publish releases/access private recordings/secrets; no broad write token by default.

### AC-072 — Truthful fallback

Simulate unavailable CI or one unsupported local shell.

Expected: Local and CI results remain distinct; neither an API outage nor an unrun job becomes a passed gate.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
