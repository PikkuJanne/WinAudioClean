# Data contracts to implement incrementally

These are design notes, not a promise of currently supported flags or fields. Adapt names to the inspected repository but preserve semantics and document any decision.

## Settings JSON

Use a schemaVersion integer and typed allowlisted fields for mode, preset ID, target loudness/peak, Fast/Accurate, sample rate, bit depth, output directory, channels policy and selected stream. Store under an appropriate per-user application data folder. Do not execute .ps1 configuration or accept arbitrary FFmpeg option/filter text. CLI overrides saved preferences, which override built-in values. Validate all fields before executing, preserve old valid config on save failure, and define unknown-version migration/reset behavior.

A persisted default-sound change still requires the user's own explicit settings action; new application versions must not silently retune Original.

## Run JSON

Include schemaVersion, jobId, toolVersion, presetVersion, sourceRevision when known, start/end timestamps, status, warning/reason codes, native/application exit codes, dependency versions, stream selection, input media duration, elapsed processing time, effective settings, exact filters, output audio format, requested targets, measured metrics and paths to local diagnostics. JSON numbers must be finite; undefined metrics are null plus reason. Separate export validity from loudness-target compliance. Do not put credentials in command strings.

Local detailed logs may contain user paths/media metadata. Redacted support export is a separate explicit action with path/metadata minimization and a warning to inspect before sharing. No automatic telemetry or uploading. Per-run file names avoid concurrent appends; a summary index must not be the sole detailed record.

### Implemented in WAC-M1-06: local run report version 1

After a render attempt, write `WinAudioClean_<jobId>.json` and the corresponding
`.txt` beside the audio. Preserve the shared `WinAudioClean_Log.txt` as a human
summary. Early pre-render input, dependency, probe, selection and space failures
remain console-only. New per-run files use CreateNew and UTF-8 without a BOM.

| Fields | Meaning |
| --- | --- |
| `schemaVersion`, `jobId`, `toolVersion` | Integer schema version `1`, the unique transaction ID and the application version. |
| `presetId`, `presetName`, `presetVersion` | Since M2-01, `original`, `Original`, `1.0.0` from the selected processing profile; `presetVersionReason` is `null`. Both Raw and Zoom use this preset. Older M1 reports have a null version with `not_versioned`. |
| `sourceRevision` | `null` with `not_embedded`; no revision is inferred from the machine. |
| `status`, `applicationExitCode` | Final `SUCCESS`, `WARNING` or `FAILED` outcome, including reporting failures. |
| `processingStatus`, `processingExitCode`, `nativeExitCode` | Processing/publication/owned-cleanup result kept separate from report warnings and the actual native exit. |
| `reasonCodes`, `warningCodes`, `reporting` | Machine-readable cause labels, report completeness and local error messages. |
| `timing`, `input` | UTC rendering start and post-processing/cleanup end; elapsed native rendering seconds; selected recording duration, size, path and stream metadata. |
| `settings`, `dependencies` | Mode, bit depth, mono/RF64 choices, exact effective filter chain, executable paths and version banners. |
| `output`, `space` | Published state, validity, requested format, verified PCM parameters, paths/size, and pre-render capacity estimates. Requested format alone is not proof of a valid export. |
| `requestedTargets`, `measurements`, `loudnessCompliance` | Requested LUFS/true-peak targets, measurement availability and independent compliance status. |
| `diagnostics`, `privacy` | Separate native stdout/stderr, processing/output/cleanup errors, local report paths and a privacy notice. |

Preset identity is additive in schema version 1. It describes the filter values
and order, separately from `toolVersion` (currently `2.3`), mode and export
format. JSON, text and the summary carry the effective identity. Redacted
diagnostic exports continue to omit all preset/application version fields,
including arbitrary values supplied in a report.

Recording duration and elapsed rendering time are finite numbers or `null` with
companion reason fields. Each loudness measurement uses `{ value, reason }`;
unavailable values are `null` with `not_measured`, invalid numeric values use
`not_numeric`, and NaN/infinity use `nonfinite`. The application currently takes
no independent loudness measurements, so compliance is `NOT_MEASURED` with
`no_independent_measurement`. PCM validation does not establish loudness compliance.

Keep a primary processing failure and its exit code when reporting also fails.
Published audio with successful processing but incomplete reporting uses
`status: WARNING`, `processingStatus: SUCCESS` and application exit `7`.
Report writers correct surviving artifacts after a companion or summary failure
where storage permits. Owned-output cleanup finishes before this outcome is
serialized. Later release of already-flushed report handles or read-only safety
handles produces a console advisory without rewriting the persisted outcome.
A crash or unrecoverable write/rollback failure can leave incomplete artifacts;
the console exit and diagnostics identify those cases. No multi-file atomicity
or power-loss durability is claimed.

The summary has one exclusive writer at a time, with bounded sharing/lock
retries. Its prior bytes are preserved. A BOM selects UTF-8, UTF-16 LE/BE or
UTF-32 LE/BE; without a BOM, strict UTF-8 is used when valid, otherwise the
current Windows ANSI code page is used. Unrepresentable new text fails reporting
rather than silently substituting characters. A failed append is rolled back to
the previously held file length where storage permits.

### Explicit redacted diagnostic export

`-ExportDiagnostic <raw-json> -DiagnosticOutputPath <new-json>` is a separate
local action; it requires no media dependencies and rejects audio-processing
options. Input must be a version 1 JSON object of at most 16 MiB. Its file stays
read-only; the destination parent must exist and a CreateNew output never
replaces an existing file, including a source alias.

The exported object has `schemaVersion: 1` and `diagnosticExport: redacted`.
It is a deliberately smaller diagnostic schema, not another complete run report.
It retains typed numeric/boolean values and allowlisted status/mode/output-format
labels. Duration/elapsed measurements use `{ value, reason }`. It drops all
free-form source strings, including paths, names, stream labels, timestamps,
job IDs, revision/version banners, exact filters, raw diagnostics and arbitrary
error/reason text. Invalid or unsupported values become `null` or a fixed
availability reason. The original report remains local and unchanged.
The export carries a review warning; the application never uploads it.

## Website release metadata

Use schemaVersion, status (draft/published), version, releasedAt, repository, sourceCommit, archiveName, downloadUrl, sha256, requirements, dependencyPolicy and changelog reference. Draft status uses null publication URL/date/hash when not known and disables the download button. Only actual approved artifact output may populate published fields. Validate metadata against the package manifest; reject version/checksum mismatch. Do not use an executable runtime auto-update manifest.

## Acceptance and task records

TASKS.yaml uses JSON-compatible YAML for a standard-library validator. Valid task states: todo, in_progress, blocked, done, deferred. Deferred work needs a reason plus owner approval reference. Done work needs existing evidence paths and completed dependencies. Acceptance states: not_run, pass, fail, blocked, not_applicable; not_applicable requires a reason and approval/disposition. Record deliberate exceptions rather than silently skipping cases.
