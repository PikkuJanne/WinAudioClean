# Data contracts to implement incrementally

These are design notes, not a promise of currently supported flags or fields. Adapt names to the inspected repository but preserve semantics and document any decision.

## Settings JSON

Use a schemaVersion integer and typed allowlisted fields for mode, preset ID, target loudness/peak, Fast/Accurate, sample rate, bit depth, output directory, channels policy and selected stream. Store under an appropriate per-user application data folder. Do not execute .ps1 configuration or accept arbitrary FFmpeg option/filter text. CLI overrides saved preferences, which override built-in values. Validate all fields before executing, preserve old valid config on save failure, and define unknown-version migration/reset behavior.

A persisted default-sound change still requires the user's own explicit settings action; new application versions must not silently retune Original.

### Implemented preferences — WAC-M3-01 (2026-10-02)

Preference schema version `1` is separate from ordinary/preview report schema
version `1` and the then-internal application `2.3`. The current public application
version is `1.0.0`; this does not change the saved-settings schema. The default local path is the current user's
ApplicationData folder plus `WinAudioClean\settings.json`. `-SettingsPath`
selects an isolated local file. Reading never saves; only `-SaveSettings` or
`-ResetSettings` writes preferences. The optional Settings sibling is needed
for a present saved file, explicit path or management action. Dot-source imports
return before reading preferences and retain their IO-only dependency contract.

The root object contains exactly `schemaVersion` and `settings`. The latter is
an object with these optional, case-sensitive fields:

| Field | JSON type and allowed values |
| --- | --- |
| `mode` | String `Raw` or `Zoom`; omission retains interactive mode selection or an unattended missing-mode error. |
| `preset` | String `Original` or `Gentle`; the existing CLI names identify the supported versioned base presets. |
| `loudnessMode` | String `Fast` or `Accurate`. |
| `bitDepth` | Integer `16` or `24`. |
| `mono`, `rf64` | Boolean; explicit CLI false overrides saved true. |
| `outputDirectory` | Nonempty supported local filesystem path; saving canonicalizes it to an absolute path without creating the audio output directory. |
| `audioStreamIndex` | Nonnegative integer through Int32 maximum, an absolute ffprobe index. Omission retains automatic single-track selection. |
| `cleaningOptions` | Object of the existing PascalCase typed cleaning override keys and bounds. It stores overrides rather than an expanded base profile. |

No target/sample-rate knobs are introduced. Input paths, executable paths,
NonInteractive, preview/actions/ranges and diagnostic choices are not preferences.
There is no script configuration, arbitrary filter string or executable option.
Read the complete file with strict bounded UTF-8/JSON validation before applying
precedence. Reject unknown keys/versions, duplicate decoded keys, wrong scalar
types, nonfinite/out-of-range values and invalid preset/mode combinations.
Invalid files fail with configuration exit `2`, even if CLI choices would hide
their invalid fields. No implicit migration occurs; `-IgnoreSavedSettings`
bypasses the file and `-ResetSettings` explicitly recovers it.

Actual bound CLI parameters override saved preferences, which override built-ins.
An explicit cleaning dictionary replaces the entire saved override dictionary,
including an empty `@{}`. Validate the resulting combination too. A saved mode
or selected index resolves the corresponding unattended omission; execution
context is never saved. Original/Fast/PCM16 and the existing channel policy
remain the built-ins. Processing reports continue recording effective choices
and exact graphs; saved preferences select existing choices without retuning
their graphs or changing report schema.

`-ShowSettings`, `-SaveSettings` and `-ResetSettings` run without input, media
tools, prompting or audio output. Show may accompany either write action; Save
and Reset are mutually exclusive. Reset rejects processing choices and writes
`{"schemaVersion":1,"settings":{}}`, preserving the built-in menu behavior.
The management JSON displays resolved preferences and per-field origins, plus
expanded `effectiveCleaning` and `effectiveFilterChain` when a mode is selected.
Otherwise they are null with `effectiveProfileReason: mode_not_selected`.
These display-only fields are not part of stored JSON. Ordinary runs display
effective choices and expanded cleaning before rendering.

Writes validate first, create/flush a same-directory owned temporary file, then
atomically replace the existing file or publish without replacing a newly
appeared destination. Failed publication preserves prior bytes and cleans only
the owned temporary file. Settings storage rejects reparse files/directories
and reparse parents; the reader also rejects files with multiple filesystem
links. This is a complete-file publication contract, without a
claim of power-loss durability, configuration migration or a multi-file commit.

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
| `presetId`, `presetName`, `presetVersion` | Base preset from the selected processing profile: default `original`, `Original`, `1.0.0`; optional Raw `gentle`, `Gentle (experimental)`, `0.1.0` since M2-03. `presetVersionReason` is `null`. Older M1 reports have a null version with `not_versioned`. |
| `presetExperimental`, `presetCustomized` | Since M2-03, typed booleans: Gentle is experimental; a nonempty cleaning-options override marks the run customized. |
| `sourceRevision` | `null` with `not_embedded`; no revision is inferred from the machine. |
| `status`, `applicationExitCode` | Final `SUCCESS`, `WARNING` or `FAILED` outcome, including loudness and reporting warnings. |
| `processingStatus`, `processingExitCode`, `nativeExitCode` | Processing/publication/owned-cleanup result kept separate from loudness/report warnings and the actual native exit. |
| `reasonCodes`, `warningCodes`, `reporting` | Machine-readable cause labels, report completeness and local error messages. |
| `timing`, `input` | UTC processing start and post-processing/cleanup end; elapsed analysis, rendering, validation and publication seconds; selected recording duration, size, path and stream metadata. |
| `settings`, `dependencies` | Raw/Zoom mode, `loudnessMode` (`Fast` or `Accurate`), bit depth, mono/RF64 choices, typed effective cleaning settings since M2-03, exact effective filter chain, executable paths and version banners. |
| `output`, `space` | Published state, validity, requested format, verified PCM parameters, paths/size, and pre-render capacity estimates. Requested format alone is not proof of a valid export. |
| `requestedTargets`, `measurements`, `loudnessCompliance` | Requested integrated LUFS, true-peak dBTP and `loudnessRangeLu`; final-file measurement availability and compliance status. |
| `loudnessTolerances`, `normalization` | Integrated/peak tolerances; requested processing mode, actual normalization type, fallback and analysis/render/final-measurement stage records. |
| `diagnostics`, `privacy` | Separate native stdout/stderr, processing/output/cleanup errors, local report paths and a privacy notice. |

Preset identity is additive in schema version 1. It names the base filter values
and order, separately from `toolVersion` (currently `1.0.0`), mode and export
format. Since M2-03, customized renders also require their effective settings
and exact graph; the base identity alone is insufficient. JSON, text and the
summary carry the identity and customization flag. Redacted
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

### Implemented cleaning fields — WAC-M2-03 (2026-10-02)

Schema version 1 gains additive `presetExperimental`, `presetCustomized` and
`settings.cleaning`. Earlier reports remain readable with these fields absent;
no historical report is rewritten. `presetExperimental` is true for Gentle,
false for Original. `presetCustomized` is true whenever a nonempty
`-CleaningOptions` dictionary was supplied, including values equal to defaults.
Identity remains the selected base candidate rather than a new preset ID for
each override. Local text/summary reports also mark experimental/customized
state and retain the exact filter chain.

For Raw, `settings.cleaning` is a typed object with these exact field names:

| Field | Type / meaning |
| --- | --- |
| `schemaVersion` | Integer `1` for this cleaning-settings contract. |
| `Declip`, `Declick`, `Denoise`, `Gate` | Boolean effective stage toggles. |
| `HighpassHz` | Finite number, 20 through 200 Hz. |
| `NoiseFloorDb` | Finite number, -80 through -20 dB. |
| `NoiseReductionDb` | Finite number, 0.01 through 20 dB. |
| `GateThresholdDb` | Finite number, -80 through -20 dBFS. |
| `GateRangeDb` | Finite number, -60 through 0 dB. |

Bounds are inclusive. Numeric fields retain the validated effective values
even when denoise or gate is disabled; their toggles determine whether the
stage is present. Zoom has `settings.cleaning: null`, because it applies no
cleaning. It accepts only Original and no nonempty override.

Original Raw has all toggles true, 80 Hz, -25/12 dB noise settings and nominal
-45/-25 dB gate settings. Gentle Raw has declip/declick/gate false, denoise
true, 60 Hz and -35/6 dB noise settings; its dormant gate settings remain
-45/-25 dB. Nominal gate defaults preserve the rounded legacy linear literals
`threshold=0.0056` and `range=0.056`. Other gate values use `10^(dB/20)`.
Original's baseline graph leaves `afftdn nr` implicit; 12 dB is the default
of the tested build. Reproduction needs the base identity, customization flag,
typed settings, `settings.exactFilters`, processing mode, FFmpeg build and
output/channel policy together. Accurate additionally retains its actual
analysis/render graphs under `normalization`. These flags record selection;
they do not certify listening approval or processing success.

### Explicit redacted diagnostic export

`-ExportDiagnostic <raw-json> -DiagnosticOutputPath <new-json>` is a separate
local action; it requires no media dependencies and rejects audio-processing
options. Input must be an ordinary full-run version 1 JSON object of at most
16 MiB with a supported processingStatus. Actual preview JSON and queue JSONL
are not accepted. Its file stays
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

M2-03 keeps this projection unchanged: cleaning settings, preset identity,
`presetExperimental` and `presetCustomized` are omitted, even if arbitrary
values are injected into a source report. The redacted export is insufficient
to reproduce a cleaning candidate; the detailed original stays local.

## Preview JSON

### Implemented preview report — WAC-M2-04 (2026-10-02)

Preview has a separate detailed schema-1 record, `reportType: preview`,
written as `WinAudioClean_Preview_<jobId>.json` and a matching text file.
It does not append an ordinary full-render summary entry. Record application
version, status/exit, selected source stream, dependencies/build, preset base
identity and candidate/customization flags. `settings` retains effective
cleaning values, channel/encoding choices, Fast/Accurate and the unchanged
`fullProfileFilters`. Asset measurements describe encoded excerpts; Accurate's
Analysis measurement separately describes the bounded input context. Neither
establishes full-program compliance.

`range` contains requested/default duration information plus quantized
`startSeconds`, `durationSeconds`, `startSamples`, `durationSamples`,
`windowStartSeconds`, `windowDurationSeconds`, `trimStartSamples`,
`trimEndSamples`, `preRollSeconds` and `postRollSeconds`. `alignment` records
zero `compensationSamples`, `filterDelayPolicy: preserved`, the known graph's
approximate reference delay or null for uncalibrated custom graphs, a fixed
reference reason and a disclosed interval limitation. `boundaryNotice`
explains bounded warmup, EOF and normalization differences.

`timeline` carries `streamIndex`, `streamStartSeconds`, nullable
`formatStartSeconds`, `originReason`, `absoluteSeekSeconds` and
`seekTimestamp: true`. The source-relative window uses an absolute seek to
the selected stream's origin plus its window start, including tracks that
begin later than another container track. Full-render probe/argument policy
remains separate.

The timeline also records sample rate, rational `timeBase` (or null for a
WAV fallback), `timestampResolutionSeconds`, `seekToleranceSamples`,
`seekToleranceSeconds`, a fixed `resolutionReason` and `positionNote`.
The seek bound is `ceil(48000 * timeBaseSeconds) + 1`, at most 480 samples;
unknown/coarse non-WAV clocks fail closed. The development evidence records
actual source-frame differences within that bound. These fields disclose
container seek uncertainty separately from the unchanged graph delay.

`assets` has exactly Original, Processed, CompareOriginal and CompareProcessed
keys. Each carries its path, format, duration/frame count, gain, exact graph,
encoded-file `{ value, reason }` metrics and `measurementStage`. `stages`
records actual arguments, input source and native results for each render,
plus Analysis for Accurate. Original/Processed use `bounded_file_window`;
comparison renders use `held_excerpt_stream`; all asset meters use
`held_output_stream`. Native diagnostics and paths stay local.

`normalization.scope` is `bounded_context_window`, with requested mode,
analysis/prechain/render strings and observed normalization type/fallback.
`matching` records availability/reason/status, `commonTargetLufs`, the two
attenuation gains, `headroomTargetDbtp: -1.7`, `peakCeilingDbtp: -1.5`,
`toleranceLu: 0.2` and observed `pairDifferenceLu` or null. Unmeasurable
matching has no invented common LUFS target. A complete report can coexist
with WARNING/7 for unavailable/nonmatching comparison or normalization
fallback. Keep the four-asset space estimate and report-writing completeness
separate from audio matching.

No preview state is saved and no report/audio uploads automatically. The
existing redacted diagnostic projection accepts ordinary full-run reports only.
Actual preview records lack its required processingStatus and are rejected;
they are not projected into full-render measurements. Review or summarize
preview diagnostics manually before sharing. Failed preview
processing/publication requests use console diagnostics and owned rollback.
Once all four valid assets are published, report-writing failure preserves
them with WARNING/7, `reporting.complete: false`, errors and null report paths.
Owned incomplete reports are retired/removed where possible; the console
remains authoritative when no corrected report could be written. A crash/storage fault
can leave incomplete artifacts, so this is no multi-file atomicity guarantee.

## Explicit input lists and local batch journal — WAC-M3-02

The existing positional `inputPath` remains a single string. `InputPaths` accepts
an ordered explicit array through a PowerShell call; `InputListPath` accepts a
local UTF-8 JSON manifest. They are mutually exclusive with each other and
`inputPath`. Lists are ordinary full-render requests; settings management,
support export and preview actions remain separate. The Batch and Settings
siblings are needed only for explicit lists. Imports and legacy single-file
installations retain their existing component contract.

The manifest is exactly `{"schemaVersion":1,"inputs":["recording.wav"]}`.
Require an integer version 1, exact keys and an array of 1 through 1024 nonempty
path strings. Reject duplicate decoded keys, wrong types, invalid UTF-8, unknown
versions, arbitrary extra fields and more than 1 MiB including optional UTF-8
BOM. Read the file through the ordinary held settings-reader policy, including
reparse/hardlink rejection; no JSON text executes. Relative entries are anchored
to the manifest directory, with root-relative entries on that directory's drive.
Invalid/missing media paths become ordinary per-item failures. A malformed list
is a global exit 2 before jobs. Explicit repeats retain their order. These
schema-1 explicit lists do not acquire folder traversal or deduplication;
the separate WAC-M3-03 route below builds a folder snapshot.

Resolve and validate preferences once, choose an omitted interactive mode once,
then supply those same existing choices to every ordinary child invocation.
Child invocations ignore saved configuration so an external settings change
cannot silently change a running list. Each input retains the existing source,
native process, output ownership and full-render report contracts. Stream
selection can still be per-item when interactive; no universal index is inferred.

`BatchResultPath` optionally selects a new journal in an existing parent;
otherwise use `WinAudioClean_Batch_<id>.jsonl` in the resolved audio destination.
CreateNew prevents replacement of inputs, manifests or previous results. The
writer and parent directory remain held during the list. The UTF-8 no-BOM file
contains one compact JSON object per line:

| `type` | Fields |
| --- | --- |
| `batch` | `schemaVersion:1`, `batchId`, UTC `startedAt`, `inputCount`, lowercase typed `settings` using the preference field schema, and per-choice `origins`. An interactively chosen mode has origin `Interactive`. |
| `item` | One-based `index`, `inputPath`, `status`, nullable integer `exitCode`, bounded string-array `diagnostics`, nullable UTC `finishedAt`. |
| `summary` | `status`, `exitCode`, UTC `finishedAt`, `reportingComplete:true`, and `counts` with `success`, `warning`, `failed`, `cancelled`, `notStarted`. |

Item statuses are `SUCCESS` (0), `WARNING` (7), `FAILED` (other failure),
`CANCELLED` (130) or `NOT_STARTED` (null exit/time). A cancelled child stops new
jobs; remaining entries are recorded as NOT_STARTED. Cancelling the initial
mode selector starts no item. Flush the header and every item before advancing,
then flush the terminal summary. These records include early per-item failures
that precede existing detailed render reports. Detailed reports remain separate;
the journal does not infer report ownership by scanning the destination.

One explicit item retains its ordinary application exit. For several items,
any failed item gives 6; warnings alone give 7; all success gives 0. Cancellation
gives 130 and stops the list. Journal creation/append failure gives 5 and starts
no further jobs. Roll back only an attempted append's new suffix where possible,
preserve earlier result bytes and audio exports, and disclose incomplete reporting.
A terminal summary is required to claim complete reporting. This is incremental
local recording, without a crash/power-loss guarantee or a multi-file commit.
No upload, automatic re-cleaning, sound retuning or saved batch/action flag occurs.

## Frozen local folder queues — WAC-M3-03

Direct PowerShell `InputDirectories` selects 1 through 64 nonempty local folder paths,
mutually exclusive with `inputPath`, `InputPaths` and `InputListPath`. `Recurse`
is an opt-in switch valid only with InputDirectories, including bound false.
Preview/settings management/support export remain separate. Queue, Batch and
Settings siblings are optional for legacy single-file use. The BAT keeps its
existing explicit-file transport; it does not automatically convert folders.

Materialize all selection records before starting media jobs. Seed one breadth-
first traversal with supplied roots in order, sorting each folder's immediate
entries with StringComparer.Ordinal. Without Recurse, ordinary nested folders
produce one skipped record each; descendants are not counted as selected files.
Supported extension candidates (case insensitive) are `.aac`, `.aif`, `.aiff`,
`.avi`, `.flac`, `.m4a`, `.mkv`, `.mov`, `.mp3`, `.mp4`, `.ogg`, `.opus`, `.wav`,
`.webm`, `.wma`. They remain subject to ordinary probe/decode validation; an
extension does not certify media. Unsupported entries receive an explanation.

Open ordinary directory ancestors without following reparse points and retain
those handles through discovery. A missing/inaccessible root, reparse root or
ancestor, unsupported path, or enumeration error rejects the entire selection
with exit2 before jobs. Encountered reparse entries are skipped without descent,
so junction/symlink loops and outside targets cannot enter this traversal. Dedup
ordinary visited directories and candidate files by volume/file identity.
Hardlink aliases and overlapping/case/relative folder selections do not create
additional jobs. Explicit lists still preserve deliberate repeats.

Exclude exact current generated names: Cleaned WAVs with the 8-digit date,
4/6/9-digit time and 32-hex job ID; four Preview WAV roles with 32-hex ID;
ordinary/Preview JSON/text reports; Batch ID JSONL; WinAudioClean_Log.txt;
`.wac-ID.partial`, `.wac-write-check-ID.tmp`, `.wac-settings-ID.tmp`.
Candidate aliases sharing an identity with a recognized generated filename
anywhere in the snapshot are also excluded. Near-miss names remain candidates.
Arbitrarily renamed exports without a recognized alias cannot be identified.
A destination encountered as a proper descendant of a selected root produces
one skipped directory record without scanning its subtree. An explicitly
supplied destination root can still select its ordinary sources; generated
markers remain excluded. Newly created files never enter this frozen queue.

Reject incomplete selections rather than truncate: at most 1024 emitted entries
including skips/failures, 1024 immediate entries per folder, 1024 visited
directories, 2048 unique held ancestor directories, and 1 MiB cumulative UTF-8
entry path bytes. Split larger selections. No native job starts on these errors.
Capture each readable candidate's canonical path, 48-hex volume/file identity,
length and UTC last-write time. A candidate that cannot be held is a per-entry
FAILED/2, so other entries continue. Release discovery handles before processing.
Before each pending job, reopen its ordinary ancestors and source without
following reparse points; compare captured identity, size and modification time.
Retain the read/share-read source lease and ancestor handles through the child
invocation, then release them. Missing/changed sources fail2 and others continue.
This is a bounded filesystem snapshot check, not a full content hash or a crash,
power-loss or adversarial metadata-restoration guarantee.

Folders use journal schema2, retaining schema1's header/item/summary contract
and held CreateNew/flush/error behavior, with these additions:

| Record | Additional fields |
| --- | --- |
| `batch` | `schemaVersion:2`, `selection:{kind:"folders",directories,recurse,extensions,capturedAt}`; UTC capturedAt; inputCount counts every selected record. |
| `item` | nullable `reasonCode`, `sourceIdentity`, `sourceLength`, `sourceLastWriteTimeUtc`; `SKIPPED` has null exitCode and a reason; unavailable/changed sources FAILED/2. |
| `summary` | `counts.skipped` in addition to success, warning, failed, cancelled, notStarted. |

Reason codes are `recursion_disabled`, `output_directory`, `reparse_point`,
`duplicate_directory`, `duplicate_file`, `unsupported_extension`,
`generated_artifact`, `source_unavailable`, `source_changed`. Static skipped
and selection-failed records remain truthful after cancellation; only pending
jobs become NOT_STARTED. No re-clean/retry occurs. Folder aggregation gives
cancel130, otherwise any failed6, warnings alone7, success/empty/all-skipped0.
The one-item explicit-list code exception does not apply to folders. Empty or
all-skipped folders still write a complete zero-job summary without selecting
mode or invoking native tools. Preferences are fully validated first. Journal
failure5 stops future jobs and preserves earlier audio/records with incomplete
reporting disclosed. Progress/active Ctrl+C handling belongs to WAC-M3-04.

## Optional output organization — WAC-M3-05

The legacy flat layout remains the default. `JobFolder` is an explicit
per-invocation switch and is never a saved preference. One generated
`WinAudioClean_Job_<32 lowercase hex>` directory groups a single file, one
Preview or an entire queue under Music or the chosen output base. `media`
contains audio/owned partials; `reports` contains per-run JSON/text reports,
the ordinary summary and default queue journal. An explicit `BatchResultPath`
still selects its own existing parent. Failures can leave empty job directories;
there is no directory reuse, recovery sweep or deletion by filename.

Report schemas stay at their existing versions. Only organized invocations
add a layout object: ordinary `output.organization`, Preview
`outputOrganization` and queue header `outputOrganization`. Its fields are
`jobId`, `rootDirectory`, `mediaDirectory`, `reportDirectory`; the grouping ID
is distinct from each audio/run ID and a queue's batch ID. Detailed paths remain
private local diagnostic data. Redacted diagnostic exports omit the layout.
Flat reports have no added layout field.

`PickFile` and `OpenOutputFolder` are unsaved explicit interactive actions.
No-input use prints console usage and returns `2` without reading settings,
opening a picker or creating output. Picker cancellation returns `130` before
destination/native work. Unattended/input-redirected picker/open requests return `2`
before processing. Only a published success/warning (`0`/`7`) is eligible for
the requested directory action; empty, failed, mixed-failed or cancelled queues
do not open it. An open failure warns without changing the persisted audio
outcome or exit. No playback or output file opens automatically.

## Implemented progress and cancellation records — WAC-M3-04

Ordinary and preview run schema `1` gain additive `progress`; older reports
remain readable without it. Cancellation adds `CANCELLED` to ordinary `status`
and `processingStatus`, with processing/application code `130` and
`user_cancelled` among ordinary reason codes. A cancelled run does not acquire
SUCCESS/WARNING merely because report writing succeeds or fails. Accurate
`normalization.analysis`, `render` and `final` can have stage `status:
"CANCELLED"`, null measurement and an explicit stage error. In particular,
cancelled final verification prevents publication; it is distinct from a
failed final meter that permits a retained valid export with warning 7.

| `progress` field | Meaning |
| --- | --- |
| `stages` | Ordered stage snapshots for this file, including inspection/validation/publication where reached. |
| `completed` | Boolean audio-publication completion; it does not imply loudness compliance or complete report writing. |
| `cancellationRequested` | Boolean state of this invocation's controller when the report is constructed. |
| `cancellationStage` | The first requested stage label, or null if no stage was active/no request occurred. |

A request after completed publication does not roll back valid assets or
change the completed processing outcome. Its report can truthfully contain
`completed: true` and `cancellationRequested: true`, with the captured stage;
report-writing warnings remain independent.

Each progress-stage record contains `stage`, `fileIndex`, `fileCount`,
`percent`, `processedSeconds`, `durationSeconds`, `structuredEnd`, `updates`,
`processId` and `snapshot`. File position is one-based; queue children inherit
the enclosing selection's index/count. Unknown duration is `null` and percent
`-1`, indicating indeterminate progress. Known media time is nonnegative and
monotonic within a stage; percentages stay in its documented range. Only a
post-publication `Completed` stage reaches `100`. A `structuredEnd` flag means
FFmpeg emitted an accepted terminal block, not that validation/publication
succeeded. Snapshot fields retain native .NET names: `OutTimeMicroseconds`,
`End`, `Blocks`, `InvalidLines`, `TruncatedLines`. `OutTimeMicroseconds: -1`
means no accepted timestamp yet; counts explain rejected/truncated data rather
than synthesizing progress. Non-native stages can have null processId/snapshot.

Native wrapper results add `Cancelled` (boolean), `OwnedProcessId` (nullable
integer), `Progress` (nullable snapshot) and `CancellationInputError` (nullable
text for binary-input IOException following owned cancellation). The latter
does not suppress genuine `Error`/`CleanupError`. Monitored stdout is consumed
as bounded structured progress; diagnostics and loudnorm JSON remain in
`StandardError`. These process fields remain inside existing normalization or
preview stage records where those records include native results. The top-level
progress snapshots are concise observation records, not a full stdout log or
an additional loudness measurement.

After preview transaction creation, a failed/cancelled preview can write a
smaller schema-1 `reportType: "preview"` record: job/tool/timestamps,
`status`, `applicationExitCode`, input path, empty `assets`, attempted native
`stages`, incomplete progress, diagnostic error/owned cleanup errors and report
completeness. It does not describe four published comparison assets. Rollback
and partial cleanup settle before this record is serialized, with source and
directory pins held through report writing. Cleanup failures remain disclosed
and may leave owned artifacts. Failure before any
transaction can remain console-only. Report-writing failure preserves the
primary cancellation/failure result and may prevent a persisted report.

Batch schema `1` and folder schema `2` remain unchanged. Active cancellation
records the current attempted child as CANCELLED/130; remaining pending entries
are NOT_STARTED and known folder skips/failures retain their prior outcomes.
Earlier exports and flushed journal records remain. Independent runs do not
share a cancellation flag. Redacted support export continues its existing
allowlist and omits progress snapshots, native PIDs, arbitrary stage labels and
detailed native output; CANCELLED is an accepted terminal status. Review local
detailed records and journals before sharing.

## Website release metadata

The implemented `website/release.schema.json` uses `schemaVersion`, `application`, `status` (`draft`/`published`), `version`, `date`, `download` (`url`, `fileName`, `sha256`, `bytes`), `source` (`commit`, `tree`) and `requirements`. Draft status requires null publication fields and disables download. Published fields must come from the actual approved GitHub release and measured artifact; validate them against the package manifest, checksum and provenance. The filename binds version and source revision. Unknown fields, mismatched version/hash/source and unsupported URLs fail validation. Publication metadata describes the GitHub package; it does not certify website hosting. The application never reads it or performs automatic updates.

## Acceptance and task records

TASKS.yaml uses JSON-compatible YAML for a standard-library validator. Valid task states: todo, in_progress, blocked, done, deferred. Deferred work needs a reason plus owner approval reference. Done work needs existing evidence paths and completed dependencies. Acceptance states: not_run, pass, fail, blocked, not_applicable; not_applicable requires a reason and approval/disposition. Record deliberate exceptions rather than silently skipping cases.
