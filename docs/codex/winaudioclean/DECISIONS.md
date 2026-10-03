# Decisions and constraints

## Frozen by the owner request

D01. Incremental improvement of the existing WinAudioClean repository, not a rewrite.
D02. Local PowerShell + FFmpeg processing; the website only presents/distributes downloads.
D03. Preserve .ps1/.bat entry points, simple Raw and Zoom choices, and Windows PowerShell 5.1 support.
D04. Preserve originals, prior exports and recording timing; no automatic silence removal/downmix.
D05. Work locally on the active Codex machine; GitHub holds the pushed continuity checkpoints. Do not require another hardware test setup.
D06. One task-oriented thread per coherent slice, staged testing, checkpoint pushes and exact next-thread handoff.
D07. No default-sound retuning without explicit listening/evidence-based owner approval.
D08. No automatic uploads, cloud audio processing, telemetry, credential collection or silent dependency/self-update downloads.

## Engineering choices proposed by the reviewed improvements

D09. Name Original/Legacy presets retaining exact baseline filter strings. Fast remains the default; Accurate is opt-in.
D10. Explicit 48 kHz / 16-bit PCM WAV is the proposed standard export; offer 24-bit. This changes encoder output, not the filter settings, and must be release-noted and tested. Do not claim bit-identical legacy files after this change.
D11. Preserve the selected track's channels; mono is explicit. Ambiguous multi-track unattended input fails unless a stream was specified.
D12. Unique same-volume temporary WAV, validation, no-clobber rename and run-owned cleanup. No deleting originals or global temp sweeps.
D13. Sequential queues first. No job server, background service, multi-machine agent or needless parallelism.
D14. Versioned typed JSON config/report data; invariant numeric filter serialization. CLI > saved > built-in.
D15. Start with a tool-only portable release. Third-party bundling, default-sound promotion, merges/releases/settings/deployment require specific approval.
D16. One canonical TASKS.yaml (JSON syntax); 90 acceptance contracts are tracked in ACCEPTANCE.json. Machine-readable IDs may not be silently dropped.
D17. Ordinary feature commits, verified pushes and draft PRs are authorized. Main is not automatically the delivery branch. Use stacked PRs where needed until merges are approved.
D18. Claims of “exact -12 LUFS”, “-12 dB RMS”, “85% leveling”, “95% success” and universal broadcast compliance must not be recycled as evidence or marketing.

## Changes to decisions

Add dated entries with task ID, rationale, evidence and owner approval where required. Preserve earlier entries and record supersession; do not silently edit away history. Numeric audio tolerances are engineering acceptance proposals in AUDIO_CONTRACT.md, not universal standards.

### 2026-10-02 — WAC-M0-04 baseline gate

D19. Continue the already authorized implementation plan from the verified M0
checkpoint. D01–D08 remain owner constraints; D09–D18 and the audio, process and
data contracts guide their scheduled implementation. This gate records no new
owner approval and does not certify future behavior as implemented. Evidence:
`evidence/WAC-M0-04.md` and `evidence/WAC-M0-04-reconciliation.json`.

The implementation contracts carried into M1 are:

- Keep the original Raw/Zoom filter text and order in `BASELINE.json`, the
  `.ps1 -inputPath` and `.bat` entry points, and Windows PowerShell 5.1 support.
  Continue local processing with no runtime Python or automatic downloads.
- M1-01 validates literal file input and a writable destination before asking
  for a mode. Invalid choices must reprompt; cancellation and unattended
  failure must be explicit. Music remains the default destination. A useful
  no-input usage route is sufficient; a picker is optional. Reject URL input.
  If UNC paths are supported, document them as network shares and test them;
  do not equate filesystem paths with physically offline storage.
- Keep paths as argument data, capture native exits/diagnostics, and verify
  actual Windows argument forwarding in M1-02. Its application exit-code and
  warning/logging-failure policy remains an engineering decision to finalize
  there, using `NATIVE_PROCESS_CONTRACT.md`.
- Preserve originals and prior exports with run-owned temporary output,
  validation and a no-overwrite final move in M1-04. Current collision and
  overwrite characterizations are defects to replace with regression tests.
- Implement D10's explicit 48 kHz PCM16 export and optional PCM24 in M1-05,
  separately from filter tuning. The present application still leaves encoding
  unspecified; M0-03 measured 192 kHz PCM16 and compared 48 kHz PCM16. The future
  export change needs format/timing/channel checks and release notes. RF64 and
  disk-size behavior need their scheduled evidence before acceptance.
- Preserve selected channels and timing. Later optional Accurate processing,
  presets, preview, queues and typed settings follow their own task gates;
  synthetic loudness observations do not establish speech-quality approval.

Pending human decisions and evidence:

| Item | Current status | Effect on continuation |
| --- | --- | --- |
| Permission-cleared speech corpus and listening review | No clips admitted; no review performed. Use `evidence/WAC-M0-03-listening.md`. | M1 reliability work can proceed. Speech-quality claims remain unverified. |
| Change the default sound | No exact settings/revision approved. | Preserve Original; any promotion needs the explicit approval required by D07. |
| Bundle third-party binaries | No redistribution choice approved. | D15's tool-only portable package remains the planned starting point. |
| Merge, tag/release, settings changes or website deployment | No action/revision/target approved in `APPROVALS.md`. | Feature pushes and draft PR updates continue under D17. Publication is a later decision. |

The local full gate and same-build reports support proceeding to **WAC-M1-01**,
not release readiness. `BASELINE.json` and bundle Linux reports remain historical
anchors; the current Windows evidence and its limits are in M0-03/M0-04 records.
No earlier decision is superseded by this entry.

### 2026-10-02 — WAC-M1-01 preflight policy

D20. Input and output accept ordinary Windows drive and relative filesystem
paths, resolved literally against the PowerShell location. Reject URLs,
provider-qualified syntax, non-filesystem providers, UNC/device namespaces,
alternate data streams, asterisks, question marks and invalid/control characters. UNC support is not
implemented. Mapped drives, junctions and redirected folders can still use
network storage; this policy does not certify physical offline storage.

Require an existing readable, nonempty FileInfo input and verify destination
creation/write access with a unique CreateNew/DeleteOnClose probe. Music remains
the default. These are access checks, not media validation or a durable guarantee
against later filesystem changes. Existing/new destination folders remain after
cancellation; only the owned write probe is removed.

Introduce only the needed CLI seams now: -Mode Raw|Zoom, -OutputDirectory and
-NonInteractive, preserving positional input and -inputPath. Saved settings,
presets and the broader CLI remain M3-01. Empty/invalid menu choices reprompt;
Q/cancel and EOF cancel explicitly. Redirected stdin, a noninteractive OS session,
the app switch or a host noninteractive switch require an explicit mode.

Direct script preflight/read failures currently exit 2 and menu cancellation
exits 130. M1-02 must finalize the complete process/dependency/report exit map,
add -nostdin to the native command and preserve exit status across the launcher
pause. The legacy native command, encoding and exact filter strings are unchanged.
Evidence: `evidence/WAC-M1-01.md`. No default-sound or publication approval is added.

### 2026-10-02 — WAC-M1-02 native execution and reporting

D21. Use one tested Windows CRT encoder and direct ProcessStartInfo launch in
PS5.1/PS7, with separate concurrent UTF-8 stdout/stderr readers, closed stdin,
explicit stream/process disposal and -nostdin. Resolve sibling/PATH ffmpeg.exe
to its absolute executable path; M1-03 still owns full dependency discovery.
Render timeout defaults to unlimited; finite test/probe timeouts stop only the
owned child. Capture is in memory and no long-file/memory-stress claim is made.

Finalize current exit codes: 0 native success/report complete; 2 input/config;
3 missing/start dependency; 4 native/capture/cleanup failure; 7 native success
with incomplete reporting; 130 menu cancellation. Preserve native exits and both
diagnostic streams, and preserve an earlier processing failure if reporting also
fails. Report failures do not delete audio. Output validation/code 5, batches/
code 6 and running-render cancellation remain later tasks.

The original .bat remains a single-file launcher and preserves status across
pause. An explicit /unattended Raw|Zoom route takes WAC_LAUNCH_INPUT and
WAC_LAUNCH_OUTPUT_DIRECTORY from environment values set in PowerShell. Fixed
PowerShell code treats them as data. Default positional percent/exclamation
paths get a fallback diagnostic when observable; earlier CMD expansion cannot
be reconstructed, so those names need direct PowerShell or the environment route.

Exact Original filters, encoding and the legacy overwrite/collision behavior
remain unchanged; safe publication is M1-04. Evidence: `evidence/WAC-M1-02.md`.
No sound promotion, release, merge, security-policy change or deployment approved.

M1-02 remains blocked at the cumulative gate: Windows Code Integrity rejected
51 test-fixture copies across the two Full runs. Earlier passing recorder cases
and four successful real-FFmpeg checks remain evidence, but do not replace the
required green Full gate. Preserve the policy and record the failures; do not
retry compilation/copying to seek an allowed hash or convert blocked cases to
skips. Resume validation after fixture execution is permitted through the normal
machine administration process. Do not advance to M1-03 yet.

### 2026-10-02 — WAC-M1-02 validation resumption (D21 addendum)

The owner reported Smart App Control Off and explicitly requested the rerun.
Read-only checks returned VerifiedAndReputablePolicyState=0 before and after it;
Codex did not change security settings. On the unchanged 0d02cf48 source,
both Full gates passed: 227 Pester cases, 61 Python cases and one documented
symlink-privilege skip per shell. All 26 recorded source hashes match.

M1-02 and AC-016/017/018 are accepted. This supersedes the blocked continuation
restriction above; the next task after synchronized delivery is WAC-M1-03.
Keep the initial failed logs and policy history. This is no claim that unsigned
fixtures work with Smart App Control On and adds no approval for future security
changes, sound changes, merges, releases or deployment. Evidence:
`evidence/WAC-M1-02-resume.md`.

### 2026-10-02 — WAC-M1-03 dependency and stream policy

D22. FFmpeg resolves from a bound `-FfmpegPath`, the script directory, then
PATH. FFprobe resolves from a bound `-FfprobePath`, the resolved FFmpeg directory,
then PATH. Invalid explicit or present sibling candidates fail without fallback.
Require nonempty Windows executables, recognized tool version responses and the
selected mode's exact required filter names. Accept both two- and three-column
filter flags, as the installed FFmpeg 9.0.2 uses two. Record paths and versions
in console output and successful/failed rendering reports. Do not impose a
numeric minimum version in place of capability checks or download dependencies.

Version, filter and media inspections each have a 15-second process deadline
plus the wrapper's bounded cleanup. Media JSON must be an object with a streams
array (at most 256 entries and 1 MiB of JSON), unique nonnegative integer stream
indexes, and usable audio codec/channel/rate fields. Reject failed probes even
when stdout looks valid. Missing optional labels/layout remain unknown. The
wrapper still captures output in memory; these checks are not a memory sandbox.

Use a single available audio stream automatically. Ambiguous interactive files
show absolute indexes and accept a choice or cancellation. Unattended ambiguity
requires `-AudioStreamIndex`; invalid/non-audio indexes fail with code 2. Map the
selected index as `-map 0:N` in rendering and retain its channels. Dependency
inspection failures use code 3; probe/metadata/no-audio failures use code 4;
either menu cancellation uses 130. Early failures appear in console diagnostics;
the legacy report is written only after rendering has been attempted.

Both probe and render allow only the `file` protocol and these demuxers:
`wav,mp3,flac,ogg,mov,matroska,webm,aac,aiff,asf,avi`. This intentionally excludes
playlists, concat lists, devices and network protocols regardless of extension.
It does not establish physical offline storage: mapped drives, junctions and
redirected folders retain their filesystem semantics. MOV external data
references remain disabled by FFmpeg's default; no option enables them here.
See the official [protocol](https://ffmpeg.org/ffmpeg-protocols.html),
[probe](https://ffmpeg.org/ffprobe.html), and
[stream mapping](https://ffmpeg.org/ffmpeg.html#Stream-selection) documentation.

The `.bat` is unchanged; advanced dependency/stream parameters use `.ps1`.
Filters and encoding are unchanged. Transactional publication remains M1-04;
explicit encoding remains M1-05. No sound promotion or publication approval is
added. Validation and its limits are in `evidence/WAC-M1-03.md`.

### 2026-10-02 — WAC-M1-04 owned output and publication

D23. Add a required sibling `WinAudioClean.IO.ps1` with lazy Windows handle
helpers. Pin input and destination identities; keep the source read-only through
reporting. Reserve `.wac-<128-bit-job-id>.partial` with CreateNew on the destination
volume. Hold it without delete sharing during FFmpeg, using `-f wav` and `-y`
only for this owned partial. Final names include millisecond timestamps and the
job ID; uniqueness does not depend on clock resolution.

Native exit 0 is necessary but insufficient. Bounded ffprobe inspection must
find one usable audio stream. Reopen the same identity for read/delete access
without write/delete sharing, validate RIFF lengths, PCM format, complete aligned
samples, channels and duration, then rename that held object with
ReplaceIfExists=false. A final filename created during the run must survive.
See Microsoft's [rename structure](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_rename_info)
and [file identity](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info)
contracts. Do not replace the held-object rename with a Test-Path check followed
by an overwrite operation or a release-and-reopen publication sequence.

Timing uses only the selected stream: positive finite duration, or Matroska's
DURATION end timestamp minus start time. Unknown timing fails before rendering.
The output sample count must agree within 10 ms for PCM and 100 ms for compressed
audio padding. These are completeness checks, not sound/loudness certification.
RIFF PCM8/16/24/32 and PCM extensible headers are structurally supported; the
actual default encoder remains unchanged. RF64 and early disk/size estimates
belong to M1-05 and are not claimed here.

Cleanup deletes only the owned identity by handle. Foreign replacements survive
with a warning. Crashes may leave `.wac-<id>.partial`; document manual inspection
after the job has stopped and never sweep old partials. Hold report filenames
against replacement and reject reparse files/multiple hardlinks before appending,
so the log cannot alias a prior export. A failed report retains published audio.
Use code 5 for allocation/validation/publication failures; preserve earlier native
codes 3/4 and separate diagnostics. No filters, launcher/CLI parameters, sound presets,
security settings or publication permissions change. Evidence is in
`evidence/WAC-M1-04.md`.

### 2026-10-02 — WAC-M1-05 explicit exports and capacity

D24. Implement D10 as 48 kHz signed PCM16 WAV by default and optional
`-BitDepth 24`. Preserve the exact Raw/Zoom profile strings; the encoder change
is release-noted and does not claim bit-identical legacy output. Support standard
mono/stereo only; infer a missing layout from one/two channels and reject
conflicting layouts or multichannel input. `-Mono` explicitly averages stereo
left/right before the original chain. Drop source metadata/chapters from exports.

Default RIFF fails before rendering when the conservative estimated file size
exceeds 4,294,967,295 bytes. `-Rf64` explicitly requests RF64, even for small files;
users need compatible readers. Support FFmpeg's single-data-chunk ds64 form and
validate 64-bit lengths/frame counts, requested PCM format and channel layout on
the existing held validation handle. Preserve no-clobber publication and owned
cleanup. Never truncate or split audio automatically.

Estimate frames at 48 kHz with 101 ms rounding/padding allowance plus 1 MiB for
headers; reserve max(64 MiB, ceil(10% of estimated file bytes)). One partial
becomes one final by rename. Query caller-available space on the pinned destination
so directory redirection and quotas are respected. Fail closed if capacity is
unknown; concurrent writers can still cause a later render failure. Duration
estimation accepts positive finite values through 1 billion seconds to bound
arithmetic. Invalid export/layout is code 2; space/size failure is code 5.

AC-025/026/027 evidence is in `evidence/WAC-M1-05.md`. Small RF64/size boundaries
and injected low space establish policy, not full >4 GB stress or real disk
exhaustion. No speech-quality approval, default filter promotion, merge, release,
security change or deployment is added.

M1-05 timing evidence also identifies the preserved Raw filter delay (about 25 ms).
A legacy unspecified-encoding render confirms it predates explicit 48 kHz output;
the marker difference is under 0.009 ms. AC-026 records unchanged channel/timing
behavior and no added offset; it does not approve a filter-delay correction.

### 2026-10-02 — WAC-M1-06 structured reports and local support export

D25. Add version 1 per-run JSON and text with unique transaction IDs; retain
the detailed human summary and exact filters/native diagnostics. Recording
duration and rendering wall time are separate. Unknown versions/revision and
unmeasured/nonfinite metrics have null values and explicit reasons. Valid PCM
output does not certify loudness compliance.

Create per-run files exclusively, serialize summary append/rollback under one
writer, preserve existing encoding/bytes and reject reparse/multiple-link leaves.
Complete owned-file cleanup before composing terminal outcomes while retaining
source/destination safety pins. Preserve primary processing codes; successful
published audio with incomplete reporting is WARNING/7. Correct surviving
reports after write failures where storage permits. Later release of already-
flushed or read-only handles is advisory, preventing stale terminal statuses.
Multi-file atomicity and recovery from arbitrary storage failures are not claimed.

Use explicit -ExportDiagnostic/-DiagnosticOutputPath to create a no-overwrite
typed projection, with no FFmpeg requirement. Omit free-form source strings,
paths, metadata, timestamps and raw diagnostics; retain local originals and
warn to review before sharing. Limit raw input to version 1 JSON objects up to
16 MiB. Nothing is uploaded. Evidence: evidence/WAC-M1-06.md. No filter, merge,
release, deployment or security-policy approval is introduced.

### 2026-10-02 — WAC-M1-07 reliability gate

D26. M1 reliability is accepted on the unchanged M1-06 source after cumulative
Quick, targeted and one Full gate in each supported shell on the active machine.
Fresh real transaction/report fault checks and the write/rename/cleanup review
found no known overwrite, ambiguous publication or false-success defect needing
a runtime correction. Evidence: `evidence/WAC-M1-07.md` and its source manifest.

Preserve exact Original filters and all M1 file/report contracts. This gate does
not certify speech quality, independent loudness, full >4 GB output, real volume
exhaustion, running-render Ctrl+C or long-file/memory stress. Keep reporting and
capacity limitations visible. Legacy README/help claims remain explicitly owned
by the next task, WAC-M2-01, together with Original preset naming/versioning.

After clean live synchronization, begin M2-01 separately on the inspected M2
feature branch, stacked on M1 while its draft PR is unmerged. No merge, release,
default-sound promotion, security change or deployment approval is added.

### 2026-10-02 — WAC-M2-01 claims and Original identity

D27. Name the existing Raw/Zoom filters Original, stable ID `original`, preset
version `1.0.0`. Preserve every baseline filter value and its order. Both
existing choices select Original; mode, optional mono and encoder format remain
separate settings. No new preset selector or default-sound promotion is added.

The selected processing profile supplies identity to version 1 JSON, human
reports and the retained summary. Application version `2.3` remains separate;
`presetVersionReason` is now null. Earlier M1 reports remain readable with their
null/not_versioned values. Redacted diagnostic exports continue to omit all
free-form identity/version fields. No report schema bump is needed for these
additive fields; no historical report is rewritten.

README, working comment-based help and menu descriptions use the official
FFmpeg parameter meanings. -12 LUFS/-1.5 dBTP are chosen targets; independent
loudness compliance remains NOT_MEASURED. No universal broadcast, exact-result,
Adobe-equivalence or percentage-success claim is supported. Original identity
does not promise identical output across builds or formats. Keep the separate
M1-05 encoder change and unreviewed speech quality explicit.

Evidence: `evidence/WAC-M2-01.md`. The next task is M2-02 measured loudness;
no new optional audio processing, merge, release or deployment is included.

### 2026-10-02 — WAC-M2-02 optional measured loudness

D28. Keep `-LoudnessMode Fast` as the default with the exact Original filter
strings and render arguments. `Accurate` measures the selected stream after
explicit channel conversion, Original cleaning where selected, and dynamic
leveling. Repeat that deterministic prechain for rendering. Accurate alone
pins its pre-normalization rate to 192 kHz so loudnorm mode negotiation cannot
change the input rate between passes. Use I=-12, TP=-1.5 and LRA=7 consistently,
validated invariant measured parameters, and target_offset as offset.

Record the render's actual normalization_type. Recognized undefined values or
valid measurements outside accepted parameter bounds use an explicit fallback;
malformed analysis stops processing. No arbitrary NaN/infinity reaches JSON or
filter arguments. No retry loop attempts to force target compliance.

Independently inspect encoded PCM through the existing held validation stream
before no-replace publication. Do not reopen its path or weaken its lock.
The wrapper copies binary input asynchronously, drains both output pipes,
closes child stdin at EOF, and retains caller ownership. Accurate stages use
finite duration-based deadlines; Fast retains its existing unlimited render.

Final input statistics determine compliance: integrated loudness within
0.5 LU, true peak <= -1.3 dBTP, with known peak violations checked first.
LRA remains informational. Subsecond I/LRA are null with `too_short`; retain
finite true peak. Silence and undefined loudness have separate fixed reasons.
Failed final measurement is FAILED, never merely unmeasurable or compliant.

Retain valid PCM with WARNING/7 for normalization fallback, unavailable render
diagnostics or a non-passing final check. Processing validity and report-writing
completeness stay separate. Add typed fields to schema 1; support export copies
only finite numbers, booleans and fixed enums/reasons. Fast stays NOT_MEASURED.
Evidence: `evidence/WAC-M2-02.md`. This does not approve a new default sound or
certify speech quality. The next task is optional gentle cleaning, WAC-M2-03.

### 2026-10-02 — WAC-M2-03 optional Gentle candidate and typed cleaning

D29. Keep Original `original`/`1.0.0` and the exact no-extra-options Raw/Zoom
graphs as defaults. Add explicit Raw-only `-Preset Gentle`, ID `gentle`, version
`0.1.0`, marked experimental: declip/declick/gate off, denoise on, highpass 60 Hz,
noise floor -35 dB and noise reduction 6 dB. Leveling, targets, export and
channel policy remain separate. The candidate name establishes no listening
advantage. Zoom rejects Gentle or any nonempty cleaning override.

Accept `-CleaningOptions` only as typed allowlisted Boolean toggles and finite
numeric scalars within the documented bounds. Reject unknown/injected keys,
strings, booleans in numeric fields, collections, scriptblocks and null values;
validate inactive values too. Compose the fixed stage order and invariant
numeric arguments. Preserve the rounded legacy `agate` literals at nominal
-45/-25 dB and Original's implicit `afftdn nr` default; reproduction still needs
the exact graph and FFmpeg build. Accurate repeats the validated selected
prechain in both passes while retaining its existing held-stream final check.

Report schema 1 adds `presetExperimental`, `presetCustomized` and typed
`settings.cleaning` (null for Zoom). A nonempty override marks customization
even if values match defaults; the ID/version continues to identify the base
candidate. Effective settings and exact filters describe the actual customized
run. The redacted diagnostic export omits these new settings and identity flags.
Hashtable CLI examples use a direct PowerShell call; no saved configuration or
new menu/launcher selector is included.

AC-042 records listening as unperformed because no owner-supplied,
permission-cleared corpus was supplied. The candidate record retains exact
base settings and a reviewer checklist; speech render settings, revision,
playback setup and results remain pending. Synthetic checks cannot approve
words, consonants, breaths, voice character or artifacts. Evidence:
`evidence/WAC-M2-03.md` and `evidence/WAC-M2-03-listening.md`.
No default-sound promotion, merge, release, deployment or security-policy
approval is added.

### 2026-10-02 — WAC-M2-04 bounded excerpts and comparison gain

D30. Add explicit local `-Preview` through an optional sibling helper,
retaining the full-render path and Original defaults. Start/duration default
to 0/45 seconds; the default clips to remaining selected audio, while an
explicit positive duration must fit and be <=60 seconds. Strict invariant
decimal ranges become exact 48 kHz sample positions. Process at most five
seconds of pre/post context, then trim both excerpts to matching positions
and frames. Accurate analyzes that bounded context rather than the whole
recording. No preview state is saved and no playback/full render starts
implicitly.

Ranges count from the selected audio's beginning, not the container's first
track. Use a separately probed selected-stream origin and absolute timestamp
seeks; WAV without timestamps uses sample zero. Negative or missing non-WAV
origins fail closed pending a separately verified seek policy.

Retain declared timestamp resolution and a conservative selection bound of
`ceil(48000*timeBaseSeconds)+1` samples, no more than 480 samples/10 ms;
unknown/coarse non-WAV clocks fail closed. Container source-frame selection
is verified within that bound rather than asserted universally exact. The
observed +8 sample middle-seek difference is recorded in preliminary/final
synthetic evidence, separately from preserved graph delay.

Preserve selected graph latency with zero compensation. Pinned 9.0.2 marker
checks show Original/Gentle Raw at +1200 samples (25 ms), Zoom and the tested
all-cleaning-stages-disabled Raw at zero. Keep known delay metadata and
uncalibrated custom-graph/boundary limits explicit. Exact bounded-window
reference comparisons establish no additional shift; they do not approve
source/processed waveform zero-lag or full-render equivalence.

Keep Original/Processed and CompareOriginal/CompareProcessed as four owned
assets. Measure held encoded excerpts, choose a common lower integrated
level constrained by -1.7 dBTP planning headroom, and apply only attenuation
to the comparison pair. Re-measure; allow <=0.2 LU difference and require
finite TP<=-1.5 dBTP. Undefined/short/silent integrated matching is explicitly
unavailable, with any known peak controlling attenuation. Peak failure rolls
back owned assets; matching/fallback warnings remain visible. No change to
mastering/full-render targets is implied.

Use exact sample-count validation, four-asset capacity estimates, retained
source/output handles, no-replace publication and owned rollback. Detailed
preview schema 1 records range/context/graphs/gains/stages and encoded-asset
metrics separately from ordinary full-render reports. Nothing is uploaded.
After all four valid assets are published, report-writing failure retains
them with WARNING/7 and explicit incomplete-report diagnostics.

Retain the existing measurement parser's integrated/threshold upper bound
of 0. The preliminary 0.97-amplitude square reported +0.51 LUFS/+1.80 dBTP
and failed closed; preserve that evidence. Use a 0.8-amplitude high-peak
fixture within the accepted domain for the final attenuation checks. This
is not support or certification of positive-integrated-loudness inputs;
carry the inherited limitation into subsequent edge-case validation.
Private speech listening remains unperformed; synthetic mechanics are not
approval to promote a default sound. No merge/release/deployment/security
approval is added. Evidence: `evidence/WAC-M2-04-latency.json` and the final
task evidence/media matrix.

### 2026-10-02 — WAC-M2-05 objective gate and pending human review

D31. Accept the implemented M2 mechanics/format gate and same-input/build
report-driven reproduction. Runtime, Original defaults and experimental Gentle
settings remain unchanged from M2-04. Fast unmeasured status, Accurate fallback,
target misses, short/silent/undefined metrics and positive-LUFS parser rejection
retain explicit classifications; numeric success is not universal target compliance.

No cleared speech corpus or attributable listening result was supplied. AC-047
accepts the integrity of that pending record, not an audition or owner approval.
Default promotion still requires exact settings/evidence/revision approval under
D07. Optional missing candidate review does not block M3 reliability/preferences.
The new reproduction utility proves selected recorded configurations with pinned
input/report/source/tool hashes and exact decoded PCM, not arbitrary cross-build
or high-precision formatter compatibility. Positive meter domain, codec seek,
calibration and manual/stress limits remain explicit. Preserve all earlier
evidence and M1-02 history; no merge/release/security/deployment approval is added.
Evidence: `evidence/WAC-M2-05.md`, source/classification/reproduction manifests
and `evidence/WAC-M2-05-listening.md`. Next: WAC-M3-01, separately synchronized.

### 2026-10-02 — WAC-M3-01 explicit local preferences

D32. Extend existing Mode/Preset/OutputDirectory/NonInteractive parameters and
retain positional inputPath, menu, launcher and PS5.1 support. Add optional
per-user ApplicationData JSON preferences, schema 1, with explicit bound CLI
values above saved preferences above built-ins. Persist only already-supported
processing choices; use existing preset names in the allowlist rather than
introducing target/sample-rate controls. Save is explicit and never automatic.
No application/report version bump or default audio change is required.

Keep the Settings sibling optional when no saved file/action/path is used.
Imports remain IO-only and return without configuration reads. Invalid complete
saved files fail closed before precedence; no automatic unknown-version migration.
Explicit IgnoreSavedSettings bypasses them and ResetSettings atomically writes
an empty supported settings object. Management has no audio input/native/prompt
side effects. Explicit false switches and an empty cleaning dictionary override
saved values; cleaning overrides replace as a unit, retaining base preset identity.

Typed bounded JSON never executes code or passes arbitrary FFmpeg options.
Validate before same-directory flushed atomic publication; retain previous bytes
on pre-publication failure and remove only owned temporary files. Reject reparse
settings storage. Complete-file replacement does not certify power-loss durability.
Human listening/default promotion remains pending under D07/D31. Feature-branch
delivery is authorized; no merge/release/settings/security/deployment approval
is added. Evidence: `evidence/WAC-M3-01.md`. Next: WAC-M3-02 only.

### 2026-10-03 — WAC-M3-02 ordered explicit file-list handoff

D33. Preserve the positional single-string input and existing BAT. Add optional
InputPaths/InputListPath through a narrow Batch sibling, using existing settings
validation and ordinary single-file execution. Materialize the explicit list,
resolve preferences once and choose an omitted interactive mode once. Supply
the frozen choices to children with saved reads disabled. Preserve explicit
repeats and order; folder discovery, recursion, deduplication and automatic
generated-output exclusion remain WAC-M3-03.

Use a strict schema-1 UTF-8 manifest (1 MiB, 1..1024 nonempty strings), with
relative paths anchored beside it. JSON is data; reject malformed/unknown/typed
schema failures before jobs. Legal percent/exclamation filenames and long lists
use direct PowerShell or a short manifest/environment handoff. A folder selection
example may generate an explicit manifest, without implementing folder traversal.

The optional Launcher sibling verifies a narrow fresh CMD /c frame against
independently captured numbered arguments. Reject observable percent/exclamation,
ambiguous quoting/count/provenance and a 7600-character positional budget before
application work. CMD's own earlier expansion cannot be repaired or prevented by
the BAT after it starts; retain the controlled expansion/sentinel proof and safe
fallback instructions. Preserve helper-less single/environment routes, default
inner PS5.1, optional explicitly selected PS7, and saved exit status around pause.
No path is interpolated into PowerShell command text.

Persist header, each item and terminal summary as flushed JSON Lines through
an exclusively created held writer. Keep existing detailed render reports.
Bound item diagnostics, including native-failure context; do not infer report
ownership by scanning a destination. One-item lists retain ordinary exit codes;
multi-item failure is 6, warnings alone 7, cancellation 130 and result-storage
failure 5. A cancelled child stops new jobs; journal append failure rolls back
only its new suffix where possible and preserves earlier results/exports.
Disclose incomplete journals and retain crash/storage/manual-cancellation limits.

Preserve the captured development failures and corrections rather than replace
them with final green history. Main's earlier helper bodies, IO/Settings/Preview,
application2.3/report1 and Original/Gentle versions remain unchanged. Engineering
CMD/queue checks do not establish a performed Explorer gesture, active-render
Ctrl+C test, power-loss guarantee or speech listening/default promotion. Evidence:
`evidence/WAC-M3-02.md`. Next: WAC-M3-03, separately synchronized; no merge,
release, default promotion, security change or deployment is authorized here.

### 2026-10-03 — WAC-M3-03 frozen folder selection

D34. Add an explicit direct-PowerShell folder route through optional Queue/Batch
helpers. Keep positional single input, explicit-list repeats/schema1 and BAT
transport intact. Recursion stays off; one ordered breadth-first snapshot uses
ordinary local directories without reparse descent, identity deduplication,
known generated-name/alias exclusions and proper descendant destination skips.
Bound selection before media jobs; reject incomplete scans rather than truncate.
Record skipped entries and unavailable sources with reasons. Revalidate each
pending source's identity, size and modification time and hold its ordinary
ancestors/read lease through the existing child job. Continue per-file failure,
retain prior audio/reports and stop pending starts on returned cancellation.

Use schema2 only for folder journals: selection provenance, source snapshot and
skip reasons/counts extend the existing held CreateNew, flushed incremental
records. Explicit folder roots equal to the destination can select ordinary
sources; newly created files never enter an existing snapshot. Empty/all-skipped
selections write truthful summaries without mode selection/native work. Folder
aggregate precedence is cancel130, failed6, warning7, success0; journal failure5
remains distinct. Static skips/preflight failures survive later cancellation.

Exact generated names cannot identify arbitrarily renamed exports without a
recognized alias. Extension selection does not replace native media validation;
metadata checks do not promise content hashing, crash recovery or resistance to
adversarial timestamp restoration. Controlled cancellation tests concern returned
item exit130; active-render Ctrl+C/progress belongs to WAC-M3-04. Preserve all
prior audio helpers, IO/Settings/Preview, launcher and filter versions/defaults.
Evidence: `evidence/WAC-M3-03.md`. No listening/default promotion, merge, release,
security/settings change or deployment approval is introduced.

### 2026-10-03 — WAC-M3-04 bounded progress and owned active cancellation

D35. Add structured FFmpeg stdout progress with bounded complete-block parsing,
separate diagnostic capture, explicit stage/file position and media-time ranges.
Only validated held publication reaches100; unknown stage duration is
indeterminate, while ordinary input timing requirements stay unchanged. Keep
existing sound/encoder/selection helpers and ownership mechanisms.

Use one instance cancellation flag per invocation, shared by sequential queue
children. A retained native Ctrl+C/Break handler marks it and leaves the main
pipeline available for bounded owned-child cleanup and reporting. Unregister in
finally and suspend interception during Read-Host. Cancellation130 prevents final
verification from becoming a retained-audio warning and stops pending starts;
earlier exports/static results remain. Add typed progress/CANCELLED outcomes and
compact failed-preview reports without inferring artifact ownership by filename.

Final focused77, cumulative Full, private-console OS signals4/4 and frozen real
media20/20 support AC-058/059/060. Preserve preliminary fixture/harness/runtime
corrections and exact content hashes. No UI typing/shared-console isolation,
console-close/crash/power-loss durability, diagnostic memory sandbox or speech
listening claim is added. Original/Gentle/Fast defaults, settings, launcher and
queue policies remain. Feature delivery is authorized; no merge/release/default
promotion, security/settings change or deployment is approved. Evidence:
`evidence/WAC-M3-04.md`. Next: WAC-M3-05 only.
