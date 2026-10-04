# Dependency-checked roadmap

Work incrementally in the existing repository. Each task is a suitable new Codex thread; a milestone contains several threads. Preserve a coherent branch checkpoint after every task.

See TRACEABILITY.md for all 20 improvement groups. Do not jump directly to packaging or audio retuning.

## M0 — Baseline and governance

Suggested branch: `codex/wac-m0-handoff`. Gate: Governance-only checkpoint first, then a fresh implementation thread.

- `WAC-M0-01` — Reconcile and install the handoff without changing runtime behavior (after reconciliation).

- `WAC-M0-02` — Create minimal test seams and local PowerShell test runners (after WAC-M0-01).

- `WAC-M0-03` — Capture synthetic and permission-cleared audio baselines (after WAC-M0-02).

- `WAC-M0-04` — Baseline gate and continuation checkpoint (after WAC-M0-03).

## M1 — Reliability and safe exports

Suggested branch: `codex/wac-m1-reliability`. Gate: No known overwrite, false-success or unbounded process defect.

- `WAC-M1-01` — Validate local input, mode and destination before prompting (after WAC-M0-04).

- `WAC-M1-02` — Harden native process execution, exit codes and diagnostics (after WAC-M1-01).

- `WAC-M1-03` — Resolve dependencies and probe/map audio streams (after WAC-M1-02).

- `WAC-M1-04` — Make output publication transactional and collision safe (after WAC-M1-03).

- `WAC-M1-05` — Specify PCM output, channel policy and large-file behavior (after WAC-M1-04).

- `WAC-M1-06` — Produce readable, structured, privacy-aware run reports (after WAC-M1-05).

- `WAC-M1-07` — Reliability regression gate (after WAC-M1-06).

## M2 — Audio accuracy and optional refinements

Suggested branch: `codex/wac-m2-audio`. Gate: Original default sound preserved; objective evidence and honest listening status.

- `WAC-M2-01` — Correct audio claims and name the Original preset (after WAC-M1-07).

- `WAC-M2-02` — Add measured loudness without changing the default fast path (after WAC-M2-01).

- `WAC-M2-03` — Add optional gentle cleaning with validated parameters (after WAC-M2-02).

- `WAC-M2-04` — Add safe excerpt preview and level-matched comparison (after WAC-M2-03).

- `WAC-M2-05` — Audio gate with honest listening status (after WAC-M2-04).

## M3 — Local workflow polish

Suggested branch: `codex/wac-m3-workflow`. Gate: Original drag/drop plus reliable unattended and batch paths.

- `WAC-M3-01` — Add noninteractive parameters and saved settings (after WAC-M2-05).

- `WAC-M3-02` — Support multiple dropped files through the existing launcher (after WAC-M3-01).

- `WAC-M3-03` — Add sequential folder queues and batch summaries (after WAC-M3-02).

- `WAC-M3-04` — Add stage-aware progress and controlled cancellation (after WAC-M3-03).

- `WAC-M3-05` — Polish output organization and simple local interaction (after WAC-M3-04).

- `WAC-M3-06` — Workflow and automation gate (after WAC-M3-05).

## M4 — Testing, packaging and documentation

Suggested branch: `codex/wac-m4-distribution`. Gate: Local testable release candidate; CI supplementary; no publication.

- `WAC-M4-01` — Complete regression and fault-injection coverage (after WAC-M3-06).

- `WAC-M4-02` — Add GitHub CI that supplements local validation (after WAC-M4-01).

- `WAC-M4-03` — Build a versioned portable release package (after WAC-M4-02).

- `WAC-M4-04` — Finish user-facing help, setup and troubleshooting (after WAC-M4-03).

## M5 — Website assets and final delivery

Suggested branch: `codex/wac-m5-release-readiness`. Gate: Static distribution only; actual release/deployment is separately approval-gated.

- `WAC-M5-01` — Prepare static website assets and release metadata (after WAC-M4-04).

- `WAC-M5-02` — Rehearse clean-checkout and release-candidate reconstruction (after WAC-M5-01).

- `WAC-M5-03` — Final acceptance and approval-ready handoff (after WAC-M5-02).

- `WAC-M5-04` — Execute only explicitly approved merge and publication actions (after WAC-M5-03).

## Branch stacking instead of unauthorized merges

Create a new milestone branch from the verified preceding milestone tip. Until the owner approves merges, draft PRs can be stacked with the preceding milestone branch as the base. Never pretend that main contains work merely because a feature branch was pushed. Reconcile PR bases after an approved merge without rewriting shared history.

## Efficient gates

Quick tests after small changes, Targeted tests for the affected area and one Full run at meaningful gates. Fix concrete defects before advancing. Do not keep rediscovering the whole repository at every thread; inspect drift since the last checkpoint. Optional expensive stress runs need a risk justification.

## Completion boundary

M5-03 is the approval-ready engineering handoff. M5-04 contains separately approved side effects; it may legitimately remain blocked while all engineering work is delivered. Missing private listening material prevents default-sound promotion, not safe progress on unrelated features.
