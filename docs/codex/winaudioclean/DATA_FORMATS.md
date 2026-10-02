# Data contracts to implement incrementally

These are design notes, not a promise of currently supported flags or fields. Adapt names to the inspected repository but preserve semantics and document any decision.

## Settings JSON

Use a schemaVersion integer and typed allowlisted fields for mode, preset ID, target loudness/peak, Fast/Accurate, sample rate, bit depth, output directory, channels policy and selected stream. Store under an appropriate per-user application data folder. Do not execute .ps1 configuration or accept arbitrary FFmpeg option/filter text. CLI overrides saved preferences, which override built-in values. Validate all fields before executing, preserve old valid config on save failure, and define unknown-version migration/reset behavior.

A persisted default-sound change still requires the user's own explicit settings action; new application versions must not silently retune Original.

## Run JSON

Include schemaVersion, jobId, toolVersion, presetVersion, sourceRevision when known, start/end timestamps, status, warning/reason codes, native/application exit codes, dependency versions, stream selection, input media duration, elapsed processing time, effective settings, exact filters, output audio format, requested targets, measured metrics and paths to local diagnostics. JSON numbers must be finite; undefined metrics are null plus reason. Separate export validity from loudness-target compliance. Do not put credentials in command strings.

Local detailed logs may contain user paths/media metadata. Redacted support export is a separate explicit action with path/metadata minimization and a warning to inspect before sharing. No automatic telemetry or uploading. Per-run file names avoid concurrent appends; a summary index must not be the sole detailed record.

### Implemented in WAC-M1-06: local run report version 1

After a processing attempt, write `WinAudioClean_<jobId>.json` and the corresponding
`.txt` beside the audio. Preserve the shared `WinAudioClean_Log.txt` as a human
summary. Early pre-render input, dependency, probe, selection and space failures
remain console-only. New per-run files use CreateNew and UTF-8 without a BOM.

| Fields | Meaning |
| --- | --- |
| `schemaVersion`, `jobId`, `toolVersion` | Integer schema version `1`, the unique transaction ID and the application version. |
| `presetId`, `presetName`, `presetVersion` | Since M2-01, `original`, `Original`, `1.0.0` from the selected processing profile; `presetVersionReason` is `null`. Both Raw and Zoom use this preset. Older M1 reports have a null version with `not_versioned`. |
| `sourceRevision` | `null` with `not_embedded`; no revision is inferred from the machine. |
| `status`, `applicationExitCode` | Final `SUCCESS`, `WARNING` or `FAILED` outcome, including loudness and reporting warnings. |
| `processingStatus`, `processingExitCode`, `nativeExitCode` | Processing/publication/owned-cleanup result kept separate from loudness/report warnings and the actual native exit. |
| `reasonCodes`, `warningCodes`, `reporting` | Machine-readable cause labels, report completeness and local error messages. |
| `timing`, `input` | UTC processing start and post-processing/cleanup end; elapsed analysis, rendering, validation and publication seconds; selected recording duration, size, path and stream metadata. |
| `settings`, `dependencies` | Raw/Zoom mode, `loudnessMode` (`Fast` or `Accurate`), bit depth, mono/RF64 choices, exact effective filter chain, executable paths and version banners. |
| `output`, `space` | Published state, validity, requested format, verified PCM parameters, paths/size, and pre-render capacity estimates. Requested format alone is not proof of a valid export. |
| `requestedTargets`, `measurements`, `loudnessCompliance` | Requested integrated LUFS, true-peak dBTP and `loudnessRangeLu`; final-file measurement availability and compliance status. |
| `loudnessTolerances`, `normalization` | Integrated/peak tolerances; requested processing mode, actual normalization type, fallback and analysis/render/final-measurement stage records. |
| `diagnostics`, `privacy` | Separate native stdout/stderr, processing/output/cleanup errors, local report paths and a privacy notice. |

Preset identity is additive in schema version 1. It describes the filter values
and order, separately from `toolVersion` (currently `2.3`), mode and export
format. JSON, text and the summary carry the effective identity. Redacted
diagnostic exports continue to omit all preset/application version fields,
including arbitrary values supplied in a report.

Recording duration and elapsed processing time are finite numbers or `null` with
companion reason fields. Each loudness measurement uses `{ value, reason }`;
unmeasured values are `null` with `not_measured`, invalid numeric values use
`not_numeric`, and NaN/infinity use `nonfinite`. Fast retains `NOT_MEASURED`
with `no_independent_measurement`. Accurate supplies final encoded-file metrics
when available and explicit reasons for undefined or failed measurements.
Recognizing an undefined result never permits malformed measurement JSON to
be treated as successful analysis. PCM validation alone does not establish
loudness compliance.

Keep a primary processing failure and its exit code when reporting also fails.
Published audio with successful processing but incomplete reporting uses
`status: WARNING`, `processingStatus: SUCCESS` and application exit `7`.
Since M2-02 the same warning outcome also covers normalization fallback,
undefined/out-of-tolerance loudness and render/final measurement diagnostic
failure on valid PCM.
`reporting.complete` and `reporting.errors` still describe only report writing;
a loudness warning can coexist with complete reports.
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

### Implemented Accurate fields — WAC-M2-02 (2026-10-02)

Schema version 1 gains additive fields; existing reports remain accepted.
`settings.loudnessMode` distinguishes the unchanged default Fast path from
opt-in Accurate. The Original preset ID/version remains separate from this
processing choice, Raw/Zoom selection and output encoding.

`requestedTargets` contains `integratedLufs: -12`, `truePeakDbtp: -1.5` and
`loudnessRangeLu: 7`. `loudnessTolerances` contains `integratedLufs: 0.5` and
`truePeakDbtp: 0.2`. LRA is informational in the final-file check; no LRA
compliance tolerance is implied by its normalization target.

The `normalization` object contains:

| Field | Meaning |
| --- | --- |
| `requestedMode` | `Fast` or `Accurate`. |
| `prechain`, `analysisFilter`, `renderFilter`, `finalMeasurementFilter` | Effective filter strings. Fast records its unchanged `renderFilter`; the other three are null. |
| `linearRequested`, `actualType` | Whether measured linear normalization was requested; the render's reported `linear` or `dynamic` type, or null when unavailable. |
| `fallbackReason` | Null, `too_short`, `silence`, `undefined_loudness`, `measurement_out_of_range` or `ffmpeg_dynamic_fallback`. |
| `analysis`, `render`, `final` | Stage objects, or null when that stage did not run. All three are null for Fast. |

If Accurate analysis fails, `normalization.renderFilter` and
`settings.exactFilters` are null because rendering was not attempted.

Each stage has `status` (`PASSED` or `FAILED`), `arguments` (the actual argument
array), `inputSource` (`file` or `held_output_stream`), `process` (the native
wrapper result), `measurement` and `error`. A parsed `measurement` has
`Available`, `Reason`, `InputI`, `InputTP`, `InputLRA`, `InputThreshold`,
`TargetOffset` and `NormalizationType`. A PASSED stage means the process and
JSON parsing succeeded; its measurements may still be unavailable. Malformed
render JSON after native exit 0 does not by itself invalidate valid PCM; it
adds `normalization_result_unavailable` to the published warning codes.
Keep the actual normalization type separate from a requested fallback.
Stage arguments, process output and errors may contain paths and native text.

The top-level `measurements` describe the encoded export using the final
analysis's input statistics. Never substitute that analysis's output statistics
or pass-2 internal measurements. Required integrated/peak values must be finite
and inside the declared tolerances for compliance to pass; an exceeded peak
takes precedence over undefined integrated loudness. Under one second, I/LRA
are null with `too_short`; any finite peak remains available. Other recognized
undefined results use `silence` or `undefined_loudness`. Failed final analysis
sets every metric to null with `measurement_failed`, has a FAILED diagnostic outcome
and warning 7 after valid publication, while failed/malformed first-pass
analysis or failed rendering prevents publication with processing code 4.
Failure to start the analysis/render process retains dependency code 3.
Warnings must survive later report outcome updates and report-write retries.

`loudnessCompliance.status` is `NOT_MEASURED`, `PASSED`, `OUT_OF_TOLERANCE`,
`UNMEASURABLE` or `FAILED`. The corresponding fixed reasons are
`no_independent_measurement`, `true_peak_exceeded`,
`loudness_out_of_tolerance`, `too_short`, `silence`, `undefined_loudness` or
`measurement_failed`; PASSED has a null reason. A normalization fallback can
produce overall WARNING/7 even when final compliance is PASSED.

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

M2-02 adds allowlisted loudness mode, actual normalization type, the boolean
`linearRequested`, the fixed fallback reasons listed above and loudness
compliance status/reason. Measurement reasons retain only the fixed availability
labels above, plus `unavailable`, `not_measured`, `nonfinite` and `not_numeric`.
Stage records, arguments, filters, stage measurements, native output and error
strings are omitted. Targets and tolerances are also omitted from this smaller
diagnostic schema. Earlier version 1 reports remain accepted; absent new labels
become null.

## Website release metadata

Use schemaVersion, status (draft/published), version, releasedAt, repository, sourceCommit, archiveName, downloadUrl, sha256, requirements, dependencyPolicy and changelog reference. Draft status uses null publication URL/date/hash when not known and disables the download button. Only actual approved artifact output may populate published fields. Validate metadata against the package manifest; reject version/checksum mismatch. Do not use an executable runtime auto-update manifest.

## Acceptance and task records

TASKS.yaml uses JSON-compatible YAML for a standard-library validator. Valid task states: todo, in_progress, blocked, done, deferred. Deferred work needs a reason plus owner approval reference. Done work needs existing evidence paths and completed dependencies. Acceptance states: not_run, pass, fail, blocked, not_applicable; not_applicable requires a reason and approval/disposition. Record deliberate exceptions rather than silently skipping cases.
