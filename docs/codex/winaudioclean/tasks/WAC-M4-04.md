# WAC-M4-04 — Finish user-facing help, setup and troubleshooting

Milestone: M4 | Initial status: todo | Improvement groups: 6, 7, 19

Canonical status lives in TASKS.yaml, not this initial task brief.

## Read first

Read applicable AGENTS.md, STATUS.md, NEXT_MODEL_START_HERE.md, DECISIONS.md and SYNC_PROTOCOL.md. Inspect the current checkout; the bundle baseline is not permission to reset it.

## Dependencies

WAC-M4-03

## Small-change scope

Product README, comment-based Get-Help, examples, support/security documentation.

## Implementation

1. Write a short first-run guide with modes, requirements, dependency resolution, privacy and clear no-admin installation.

2. Document options, reports, exit codes, limits, track extraction, timing preservation, RF64 compatibility and download verification.

3. Test examples exactly as written; do not tell users to disable security globally or promise unsupported operating-system/build compatibility.

## Guardrails

No unrelated refactor, default-sound change, or publication.

## Acceptance

### AC-076 — Examples execute

Follow installation and commands from a clean release ZIP on the active machine.

Expected: Examples run without hidden setup; help contains valid parameter descriptions and actual defaults.

### AC-077 — Support and privacy

Walk through missing dependency, corrupt media, permissions, output collision and redacted-report guidance.

Expected: User can diagnose without uploading private audio or changing machine-wide security settings.

### AC-078 — Claims consistency

Compare README/Get-Help/preset labels/reports and website draft metadata.

Expected: Versions, LUFS/peak units, local-processing statement and limitations agree.

## Evidence and completion

Run the smallest relevant tests first, stabilize failures, then the required cumulative gate. Record the exact command, exit code, tool versions, tested source revision/content hash, case IDs and concise result in a sanitized evidence file. Never replace an unrun case with a claim of success.

Update TASKS.yaml and ACCEPTANCE.json with real status and evidence paths; update STATUS.md and NEXT_MODEL_START_HERE.md. Stage explicitly, inspect the staged diff, commit/push the task checkpoint and verify live remote HEAD. Record the exact post-push commit in the PR/comment or final response to avoid a self-referential commit loop.

Stop after this coherent task and give the next unlocked task ID. Do not start a broad new audit or carry the entire milestone in one thread.
