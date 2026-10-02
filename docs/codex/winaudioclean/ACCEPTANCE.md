# Acceptance matrix

Initial state: all 90 cases are NOT RUN for the application. Bundle-helper tests and Linux filter characterization are separate evidence, not completed application acceptance.

Case state lives in ACCEPTANCE.json. Update it and attach revision-specific evidence while implementing; do not mark a whole feature passed because a helper test passes.

## WAC-M0-01 — Reconcile and install the handoff without changing runtime behavior

### AC-001: Wrong checkout / dirty worktree

Procedure: Try the helper against a different origin, a dirty tree, and a detached HEAD.

Expected: Apply fails without modifying existing files or changing branches.

### AC-002: Preview and collision safety

Procedure: Preview then apply on a clean feature branch; repeat. Introduce an existing different AGENTS.md in a separate fixture.

Expected: Preview is read-only; repeat is idempotent; differing files are reported, not overwritten.

### AC-003: Initial checkpoint

Procedure: Compare runtime files before/after governance import; commit and push only intended handoff files. Run live sync-check.

Expected: Runtime content is unchanged; clean worktree, matching local/live-remote branch HEAD, and a real PR reference or explicit API blocker are recorded.

## WAC-M0-02 — Create minimal test seams and local PowerShell test runners

### AC-004: Compatibility entry points

Procedure: Invoke the original -inputPath call and the .bat entry point with controlled input in both available Windows shells.

Expected: Existing modes and entry points remain; unavailable shell runs are marked not-run, not passed.

### AC-005: No import side effects

Procedure: Load test helpers in a fresh process with FFmpeg/process-start mocked.

Expected: No menu, process, writes, or exit on import; tests can run unattended.

### AC-006: Useful checks

Procedure: Run the new Quick runner, deliberately break a tested helper in an isolated worktree, then restore it.

Expected: The runner fails for the deliberate defect and passes after restoration; no broad analyzer suppressions hide it.

## WAC-M0-03 — Capture synthetic and permission-cleared audio baselines

### AC-007: Legacy filter identity

Procedure: Compare built filter strings for Raw and Zoom with BASELINE.json.

Expected: Parameter values and order match exactly; output-container changes are recorded separately.

### AC-008: Reproducible synthetic baseline

Procedure: Run characterization twice using the same local build and inputs.

Expected: Versions, commands, fixture hashes and output format are recorded; variation is investigated rather than masked.

### AC-009: Private corpus handling

Procedure: Check ignore rules and staged files before adding the listening-review record.

Expected: No private recordings or identifying local paths are staged; missing listening material is explicitly pending.

## WAC-M0-04 — Baseline gate and continuation checkpoint

### AC-010: Baseline completeness

Procedure: Check source identities, filters, runnable test commands and environment inventory.

Expected: Each exists with actual evidence; unexecuted Windows/listening checks remain distinguishable.

### AC-011: Plan consistency

Procedure: Run the plan validator after changing task status.

Expected: No unknown dependency, duplicate ID, missing acceptance link, or done task without evidence.

### AC-012: Thread restart

Procedure: Start from a fresh Codex thread reading NEXT_MODEL_START_HERE.md and git.

Expected: The next task and unverified checks are clear without reconstructing prior chat or repeating the entire audit.

## WAC-M1-01 — Validate local input, mode and destination before prompting

### AC-013: Literal path matrix

Procedure: Use files with spaces, square brackets, apostrophes, ä/ö/Å, ampersands, percent signs, exclamation marks and parentheses.

Expected: Each resolves to one intended file; no wildcard expansion or unexpected command execution.

### AC-014: Validation order

Procedure: Try no input, directory, nonexistent input, URL, unwritable destination and zero-byte corrupt media.

Expected: Clear preflight diagnostics; no mode prompt for invalid paths and no misleading successful export.

### AC-015: Menu correctness

Procedure: Enter empty, invalid, valid and cancel choices. Run missing mode with noninteractive semantics.

Expected: Invalid input cannot silently select Zoom; cancellation/noninteractive failure is explicit.

## WAC-M1-02 — Harden native process execution, exit codes and diagnostics

### AC-016: Argument fidelity

Procedure: Use a benign argv-echo test executable or equivalent recorder with the filename matrix through both the direct script and actual launcher.

Expected: The child receives exact arguments; command-like filenames cannot become commands; any CMD limitation gets a safe fallback and explicit notice.

### AC-017: Error propagation

Procedure: Simulate startup failure, FFmpeg nonzero exit, failed reporting, and successful execution.

Expected: Script and launcher return documented codes and retain useful diagnostic details without claiming success.

### AC-018: Output and stream handling

Procedure: Have a test child write large stdout/stderr streams, then exit; repeat with a known synthetic FFmpeg job.

Expected: No deadlock or truncation of essential errors; all handles are closed and completion is accurately observed.

## WAC-M1-03 — Resolve dependencies and probe/map audio streams

### AC-019: Dependency resolution

Procedure: Test explicit, sibling and PATH locations; missing, incompatible and selected-mode-filter-deficient builds.

Expected: Precedence is deterministic, failures are actionable, and no download happens without consent.

### AC-020: Stream choice

Procedure: Use a container with two distinguishable tracks and a video-only container.

Expected: Selected absolute stream index maps to the expected audio; no-audio fails before cleaning; unattended ambiguity fails.

### AC-021: Probe safety

Procedure: Test malformed JSON, timeout, nonzero probe exit and local playlist referencing an external URL.

Expected: No false metadata or unbounded hang; unsupported network references are rejected/blocked and documented.

## WAC-M1-04 — Make output publication transactional and collision safe

### AC-022: Collision and concurrency

Procedure: Run same input twice rapidly and two inputs with the same stem; run concurrent jobs targeting one destination.

Expected: Every completed output is unique and prior results/source hashes remain unchanged.

### AC-023: Failure before publication

Procedure: Inject encoder failure, disk-full simulation, invalid output, and a crash before rename.

Expected: No normal-looking final export is published; originals/prior exports remain untouched; partial files are identifiable.

### AC-024: Rename race / validation

Procedure: Create the intended final filename after name selection; simulate exit 0 with an empty or truncated output.

Expected: No existing file is replaced; validation blocks invalid output and reports the true failure.

## WAC-M1-05 — Specify PCM output, channel policy and large-file behavior

### AC-025: Explicit output matrix

Procedure: Process 44.1/48 kHz mono and stereo fixtures in both modes and 16/24-bit choices; inspect with ffprobe.

Expected: Selected sample rate/codec/channels are correct; no accidental 192 kHz default export.

### AC-026: Timing and channels

Procedure: Use stereo channels with different signals and known impulses; compare start/end and duration before/after.

Expected: No unintended downmix, channel swap, silence removal, leading offset or unexplained timing drift.

### AC-027: Large-file and space policy

Procedure: Unit-test estimates around the WAV size boundary and inject low-space conditions; exercise an RF64 header with a small supported fixture.

Expected: Policy is deterministic and documented; full >4 GB stress is run only when risk warrants it, or clearly not claimed as tested.

## WAC-M1-06 — Produce readable, structured, privacy-aware run reports

### AC-028: Report fidelity

Procedure: Run success, encoder failure and validation failure; compare console, JSON, human log and process exit.

Expected: Statuses agree; recording duration differs from wall time; unsupported/nonfinite measurements become null plus reason.

### AC-029: Privacy export

Procedure: Generate a report containing user-directory names, filenames, container title and potential sensitive diagnostic text.

Expected: Redacted output omits sensitive values and warns about review; raw report remains local only.

### AC-030: Concurrent and failed logging

Procedure: Run concurrent exports and inject a log destination permission failure.

Expected: Reports do not overwrite/interleave incorrectly; audio is not deleted solely because reporting failed; outcome is unambiguous.

## WAC-M1-07 — Reliability regression gate

### AC-031: Cumulative regression

Procedure: Run the documented M0+M1 suite on the active Windows machine in available supported shells.

Expected: All mandatory local checks pass, or the milestone remains blocked with exact failures.

### AC-032: Non-destructive review

Procedure: Inspect all file-writing, rename and cleanup paths alongside fault-injection results.

Expected: No source/prior export overwrite, broad cleanup, silent output ambiguity or false-success path remains known.

### AC-033: Remote checkpoint

Procedure: Run live sync-check after pushing the implementation/evidence commit and inspect PR state.

Expected: Clean worktree and identical local/live remote HEAD; CI state is accurately separated from local results.

## WAC-M2-01 — Correct audio claims and name the Original preset

### AC-034: Claims audit

Procedure: Search all shipped docs/help/website drafts for old claims and compare parameter descriptions to official docs.

Expected: Units and limitations are accurate; -12 LUFS is a chosen preset, not a universal broadcast standard.

### AC-035: Preset compatibility

Procedure: Compare Original Raw/Zoom filter strings and synthetic output with the baseline on the same build/output settings.

Expected: Filter values/order remain; any differences are explained by explicit encoder behavior rather than silent retuning.

### AC-036: Preset version report

Procedure: Select Original from existing interactive paths and a test invocation.

Expected: The effective preset ID/version appears in the report and is not confused with the application version.

## WAC-M2-02 — Add measured loudness without changing the default fast path

### AC-037: Pass consistency

Procedure: Capture both commands for Raw/Zoom, selected stream, mono/stereo and numeric locale variations.

Expected: Prechains, stream, channel policy and parameters match; second pass uses valid pass-1 measurements and invariant decimals.

### AC-038: Output measurements

Procedure: Run eligible full-length fixtures at -12 LUFS / -1.5 dBTP and verify final-file loudness/peak.

Expected: Achievable cases meet declared tolerances; constraints/fallbacks are reported and out-of-tolerance results are not called target-compliant.

### AC-039: Undefined and fallback cases

Procedure: Use silence, <1-second audio, restricted peak headroom, high LRA and malformed measurement output.

Expected: No unchecked nonfinite values, infinite retries, division errors, or false exact-target claims; fallback is logged.

## WAC-M2-03 — Add optional gentle cleaning with validated parameters

### AC-040: Parameter validation

Procedure: Test valid bounds, invalid values, unknown settings and filter-like injected strings.

Expected: Only typed allowlisted settings construct the graph; no arbitrary filter/command injection through configuration.

### AC-041: Defaults unchanged

Procedure: Run the existing no-extra-options Raw and Zoom paths after adding presets.

Expected: Original filters remain the default; Zoom does not accidentally enable cleaning stages.

### AC-042: Listening candidate record

Procedure: Compare original/gentle on the approved local corpus or record why unavailable.

Expected: Reviewer evaluates words, consonants, breaths, voice character and artifacts; synthetic checks are not presented as listening approval.

## WAC-M2-04 — Add safe excerpt preview and level-matched comparison

### AC-043: Range and alignment

Procedure: Preview from start, middle and near end of a known timed fixture plus a very short recording.

Expected: Valid matched intervals only; no unexplained offset, overwrite or out-of-range processing.

### AC-044: Comparison gain

Procedure: Measure the original/processed comparison pair with the documented matching method.

Expected: Level matching is separate from the mastering preset and does not introduce clipping; unmeasurable cases are clearly labeled.

### AC-045: No hidden processing

Procedure: Create/cancel a preview and inspect files, current settings and process state.

Expected: No full recording starts implicitly, source is unchanged and only run-owned preview files are cleaned up.

## WAC-M2-05 — Audio gate with honest listening status

### AC-046: Objective audio gate

Procedure: Run all applicable M2 numeric and structural checks.

Expected: Mandatory implemented-mode checks pass; ineligible/undefined metrics are explicitly classified.

### AC-047: Human gate integrity

Procedure: Inspect listening template, corpus consent and approval records.

Expected: Real reviewer results are attributable; missing listening approval prevents default promotion, not a fabricated pass.

### AC-048: Reproducible settings

Procedure: Recreate an output from the report using the same build/input/settings and push the checkpoint.

Expected: Preset/format choices are traceable and the exact accepted revision is recoverable from GitHub.

## WAC-M3-01 — Add noninteractive parameters and saved settings

### AC-049: Precedence matrix

Procedure: Set conflicting built-in, saved and CLI values then reset settings.

Expected: Documented precedence wins; legacy input invocation remains valid.

### AC-050: Unattended behavior

Procedure: Run with all required values; omit a required mode/stream or supply invalid settings with redirected stdin.

Expected: No prompt/pause or hang; valid jobs run and invalid jobs fail with a useful exit code.

### AC-051: Config durability

Procedure: Test malformed JSON, unknown schema, wrong types, interrupted save and German/Finnish decimal culture.

Expected: Safe diagnostics, previous valid config preserved and invariant FFmpeg serialization; no arbitrary code execution.

## WAC-M3-02 — Support multiple dropped files through the existing launcher

### AC-052: Real drag/drop matrix

Procedure: Drop one and several files, including spaces, Unicode, brackets, %, !, &, apostrophes and parentheses, onto the actual launcher.

Expected: Each intended input appears once in the queue without truncation, corruption or command execution.

### AC-053: Aggregate result

Procedure: Process a list containing valid and invalid items.

Expected: Per-item results persist; overall exit code reflects failure; single-file behavior remains compatible.

### AC-054: Boundary handling

Procedure: Test many/long paths and double-click with no files.

Expected: No silently lost inputs; actionable safe fallback for launcher limits and clear no-input guidance.

## WAC-M3-03 — Add sequential folder queues and batch summaries

### AC-055: Folder selection

Procedure: Process a mixed folder including output files, nested folders and a junction/symlink loop fixture.

Expected: Recursion is off by default; no loop or generated-output reprocessing; unsupported files are explained/skipped.

### AC-056: Queue stability

Procedure: Select duplicate paths and inputs with identical stems; place the destination inside the input folder.

Expected: Inputs are deduplicated, names remain collision-safe and newly generated output never enters the running queue.

### AC-057: Failure continuation

Procedure: Fail a middle item and process remaining items; repeat with cancellation.

Expected: Failure does not discard other results; cancellation stops new jobs and aggregate status is truthful.

## WAC-M3-04 — Add stage-aware progress and controlled cancellation

### AC-058: Progress semantics

Procedure: Run fast/accurate/preview jobs, variable-speed data and unknown duration.

Expected: Progress is bounded, stage labels correct, and 100% is not shown before validation/publication.

### AC-059: Owned-process cancellation

Procedure: Run two independent jobs, cancel one at analysis/render/verification in separate tests.

Expected: Only the cancelled run stops; no new queued job starts; originals/other exports remain intact.

### AC-060: Abnormal child / console

Procedure: Force unexpected child exit, truncated progress lines and closed/redirected console.

Expected: No deadlock, misleading success or unbounded wait; final status remains in the report.

## WAC-M3-05 — Polish output organization and simple local interaction

### AC-061: Destination choices

Procedure: Run Music/default, custom, per-job and unavailable redirected Music-folder scenarios.

Expected: Predictable paths with safe fallback/error; no writes to unexpected current directories.

### AC-062: No-GUI operation

Procedure: Run from a terminal/redirected session without desktop interaction.

Expected: Processing and diagnostics work with no file-picker or Explorer dependency.

### AC-063: Explicit follow-up actions

Procedure: Complete success/failure runs and exercise optional open-folder/cancel-picker actions.

Expected: Only requested safe actions occur; failures do not falsely offer a completed output.

## WAC-M3-06 — Workflow and automation gate

### AC-064: Original workflow

Procedure: Drop a typical interview file, select 1/2 and inspect the result/report.

Expected: Same simple front-door experience remains; new settings do not overwhelm the default menu.

### AC-065: Automation workflow

Procedure: Invoke unattended batch with explicit parameters and examine process codes/files/reports.

Expected: No prompt, missing file, misleading aggregate result or timing change.

### AC-066: Reentry workflow

Procedure: Restart in a new thread or clean checkout with recorded settings intentionally absent.

Expected: Built-in defaults suffice; state and remaining tasks are recovered from Git, not hidden machine settings.

## WAC-M4-01 — Complete regression and fault-injection coverage

### AC-067: Coverage traceability

Procedure: Map every implemented acceptance ID to a test command/report or a named manual review.

Expected: No implemented behavior relies solely on a roadmap checkbox; mandatory gaps remain visible.

### AC-068: Mutation / fault checks

Procedure: Inject representative overwrite, bad exit and wrong-sample-rate defects in an isolated test tree.

Expected: Relevant tests detect them; test fixture cleanup cannot remove real user files.

### AC-069: Efficient repeatability

Procedure: Run Quick and selected Targeted suites after a narrow change, then one Full gate.

Expected: Runners are reusable and evidence tied to revision; no repetitive all-project audit is required for every small edit.

## WAC-M4-02 — Add GitHub CI that supplements local validation

### AC-070: CI/local parity

Procedure: Compare workflow commands and versions to local runners; run a PR check.

Expected: Same checks are invoked, versions recorded, real green/failure status linked to the tested SHA.

### AC-071: Workflow permissions

Procedure: Review permissions, triggers, pinned actions, downloads and secrets exposure.

Expected: Untrusted PR tests cannot publish releases/access private recordings/secrets; no broad write token by default.

### AC-072: Truthful fallback

Procedure: Simulate unavailable CI or one unsupported local shell.

Expected: Local and CI results remain distinct; neither an API outage nor an unrun job becomes a passed gate.

## WAC-M4-03 — Build a versioned portable release package

### AC-073: Package contents

Procedure: Build twice from the same inputs; inspect archive entries and metadata/checksums.

Expected: Version and content manifest agree; reproducibility claims match actual results; no private/development-only files.

### AC-074: Fresh package use

Procedure: Extract into a clean user-writable folder with spaces/Unicode; supply approved local dependencies.

Expected: The documented .bat and PowerShell paths work without a repo, Python or test modules installed.

### AC-075: Licensing and integrity

Procedure: Review included notices, dependency provenance and generated hashes.

Expected: MIT notice is preserved; bundled third-party build obligations are checked or bundling remains explicitly blocked.

## WAC-M4-04 — Finish user-facing help, setup and troubleshooting

### AC-076: Examples execute

Procedure: Follow installation and commands from a clean release ZIP on the active machine.

Expected: Examples run without hidden setup; help contains valid parameter descriptions and actual defaults.

### AC-077: Support and privacy

Procedure: Walk through missing dependency, corrupt media, permissions, output collision and redacted-report guidance.

Expected: User can diagnose without uploading private audio or changing machine-wide security settings.

### AC-078: Claims consistency

Procedure: Compare README/Get-Help/preset labels/reports and website draft metadata.

Expected: Versions, LUFS/peak units, local-processing statement and limitations agree.

## WAC-M5-01 — Prepare static website assets and release metadata

### AC-079: Architecture boundary

Procedure: Inspect page code, browser requests and runtime script behavior.

Expected: Website only presents/distributes; tool never needs the website to process audio; no upload endpoint/telemetry is introduced.

### AC-080: Metadata correctness

Procedure: Validate draft and published-like fixture metadata against packaging output.

Expected: No fabricated release link/hash; draft/unpublished assets cannot appear as a working stable download.

### AC-081: Accessible presentation

Procedure: Test keyboard navigation, meaningful labels, readable layout and sample consent records.

Expected: Page is usable and honest; missing real assets are marked pending without fake screenshots/reviews.

## WAC-M5-02 — Rehearse clean-checkout and release-candidate reconstruction

### AC-082: GitHub reconstruction

Procedure: Fetch the checkpoint and create a clean detached worktree/clone for the explicit SHA.

Expected: Project builds/tests using documented prerequisites; no hidden local edits or untracked runtime dependencies are required.

### AC-083: Candidate integrity

Procedure: Compare candidate contents, hashes and version across packaging and website metadata.

Expected: All artifacts identify the same source revision/version; invalid checksum/version inputs fail validation.

### AC-084: Privacy and rollback

Procedure: Review candidate files and documented rollback to a prior release/source tag.

Expected: No confidential content ships and rollback does not erase source recordings/settings without consent.

## WAC-M5-03 — Final acceptance and approval-ready handoff

### AC-085: Complete traceability

Procedure: Audit TRACEABILITY.md, TASKS.yaml, evidence and release checklist once.

Expected: All improvements are implemented/verified or explicitly deferred with owner approval; no placeholder is reported as complete.

### AC-086: Safe acceptance

Procedure: Review mandatory safety tests and all pending subjective/platform checks.

Expected: Known data-loss/security/false-success regressions block acceptance; unreviewed sound changes stay opt-in/experimental.

### AC-087: Delivery checkpoint

Procedure: Verify clean worktree, live remote SHA, PR/check status and candidate artifact manifest.

Expected: Owner receives a recoverable, approval-ready checkpoint, not a claim that unapproved release/deployment already occurred.

## WAC-M5-04 — Execute only explicitly approved merge and publication actions

### AC-088: Approval boundary

Procedure: Attempt to plan merge/tag/release/settings change/deployment without a matching approval record.

Expected: Action stays blocked; no side effect. Ordinary feature commits/pushes/draft PR updates remain permitted.

### AC-089: Exact target check

Procedure: Compare approved SHA/artifact/target to the live candidate immediately before action.

Expected: Mismatch stops publication and returns an updated proposal; no force push or surprise main push.

### AC-090: Post-action verification

Procedure: For each approved action, check actual remote state and downloaded asset hash/site metadata.

Expected: Recorded result matches what was published; outstanding approvals and rollback route are explicit.
