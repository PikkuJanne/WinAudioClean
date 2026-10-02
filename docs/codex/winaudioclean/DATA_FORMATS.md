# Data contracts to implement incrementally

These are design notes, not a promise of currently supported flags or fields. Adapt names to the inspected repository but preserve semantics and document any decision.

## Settings JSON

Use a schemaVersion integer and typed allowlisted fields for mode, preset ID, target loudness/peak, Fast/Accurate, sample rate, bit depth, output directory, channels policy and selected stream. Store under an appropriate per-user application data folder. Do not execute .ps1 configuration or accept arbitrary FFmpeg option/filter text. CLI overrides saved preferences, which override built-in values. Validate all fields before executing, preserve old valid config on save failure, and define unknown-version migration/reset behavior.

A persisted default-sound change still requires the user's own explicit settings action; new application versions must not silently retune Original.

## Run JSON

Include schemaVersion, jobId, toolVersion, presetVersion, sourceRevision when known, start/end timestamps, status, warning/reason codes, native/application exit codes, dependency versions, stream selection, input media duration, elapsed processing time, effective settings, exact filters, output audio format, requested targets, measured metrics and paths to local diagnostics. JSON numbers must be finite; undefined metrics are null plus reason. Separate export validity from loudness-target compliance. Do not put credentials in command strings.

Local detailed logs may contain user paths/media metadata. Redacted support export is a separate explicit action with path/metadata minimization and a warning to inspect before sharing. No automatic telemetry or uploading. Per-run file names avoid concurrent appends; a summary index must not be the sole detailed record.

## Website release metadata

Use schemaVersion, status (draft/published), version, releasedAt, repository, sourceCommit, archiveName, downloadUrl, sha256, requirements, dependencyPolicy and changelog reference. Draft status uses null publication URL/date/hash when not known and disables the download button. Only actual approved artifact output may populate published fields. Validate metadata against the package manifest; reject version/checksum mismatch. Do not use an executable runtime auto-update manifest.

## Acceptance and task records

TASKS.yaml uses JSON-compatible YAML for a standard-library validator. Valid task states: todo, in_progress, blocked, done, deferred. Deferred work needs a reason plus owner approval reference. Done work needs existing evidence paths and completed dependencies. Acceptance states: not_run, pass, fail, blocked, not_applicable; not_applicable requires a reason and approval/disposition. Record deliberate exceptions rather than silently skipping cases.
