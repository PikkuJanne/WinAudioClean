# Audio behavior contract

This combines preserved behavior and proposed later test contracts. Sections
marked implemented describe current behavior; speech listening and later
milestone requirements remain pending.

## Preserved baseline

Raw prechain:
`adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056`

Both-mode leveling chain:
`dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5`

Zoom uses only the leveling chain. Naming a preset must not change its values/order. Do not claim bit-identical output across FFmpeg builds or after changing sample format/rate.

### Implemented preset identity — WAC-M2-01 (2026-10-02)

Both existing Raw and Zoom choices use **Original**, ID `original`, version
`1.0.0`. The version names the exact legacy filter values/order above; no
filter was retuned. The application version remains separately `2.3`. Menu,
console and local reports identify Original; JSON also records its ID/version.
No preset selector, saved settings or Accurate option is introduced here.

Preset identity excludes the explicit output encoding policy and optional
channel conversion described below. Equal-filter output comparisons require
the same FFmpeg build and output settings. Omitted FFmpeg options still use
that build's defaults. Single-pass output remains independently unmeasured;
-12 LUFS and -1.5 dBTP are requested settings. Speech listening remains pending.

### Implemented optional cleaning — WAC-M2-03 (2026-10-02)

`-Preset Original` remains default. `-Preset Gentle` is an opt-in experimental
Raw candidate, ID `gentle`, version `0.1.0`. Its Fast graph is:

```text
highpass=f=60,afftdn=nf=-35:nr=6,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5
```

Gentle disables declip, declick and gate, retains denoise, and changes only
the high-pass cutoff/noise settings. Leveling and loudness targets remain as
above. "Gentle" names this candidate; no speech-quality advantage is established.
Zoom accepts only Original and an empty cleaning-options dictionary; it never
adds cleaning stages. The two-choice menu and launcher retain their defaults.
No saved settings or automatic preset selection is implemented here.

Raw accepts `-CleaningOptions` as a PowerShell hashtable. The allowlist is:

| Key | Type / inclusive bounds |
| --- | --- |
| `Declip`, `Declick`, `Denoise`, `Gate` | Boolean |
| `HighpassHz` | Finite numeric scalar, 20 through 200 |
| `NoiseFloorDb` | Finite numeric scalar, -80 through -20 |
| `NoiseReductionDb` | Finite numeric scalar, 0.01 through 20 |
| `GateThresholdDb` | Finite numeric scalar, -80 through -20 |
| `GateRangeDb` | Finite numeric scalar, -60 through 0 |

Reject unknown keys, numeric strings, booleans in numeric fields, null,
nonfinite values, collections and scriptblocks before constructing filters.
Validate dormant values too. Overrides affect only this run; they do not admit
FFmpeg option/filter text. Preserve stage order: optional adeclip, highpass,
optional adeclick, optional afftdn, optional agate, then unchanged leveling.
Highpass always remains in Raw. Accurate repeats this validated selected
prechain in both passes before its existing measured normalization workflow.

Original's effective Raw defaults are all four stages enabled, 80 Hz,
noise floor -25 dB, noise reduction 12 dB, and nominal gate threshold/range
-45/-25 dB. Gentle uses 60 Hz, -35/6 dB, with the same dormant gate values.
Keep the original literal `0.0056` threshold and `0.056` range when the nominal
gate defaults are selected; rounding them anew would change the baseline.
Other gate values use `10^(dB/20)` and invariant decimal serialization.
Original's baseline afftdn omits `nr`; 12 dB is the tested build's default.
The exact graph and FFmpeg build remain required for reproducibility.

These application bounds are deliberately narrower than some FFmpeg limits.
Parameter meanings were rechecked against [afftdn](https://ffmpeg.org/ffmpeg-filters.html#afftdn),
[agate](https://ffmpeg.org/ffmpeg-filters.html#agate) and
[highpass](https://ffmpeg.org/ffmpeg-filters.html#highpass), plus installed
FFmpeg 9.0.2 filter help. This substantiates option compatibility, not listening
approval. Candidate settings and the unavailable-corpus disposition are in
`evidence/WAC-M2-03-listening.md`.

## Correct definitions [S01]

`loudnorm I` targets integrated LUFS, not RMS. `dynaudnorm p` is a peak-amplitude target, not an Adobe percentage. `afftdn nf` describes the noise floor; `nr` controls reduction. A nonzero gate range is limited attenuation, not guaranteed silence. Dynamic loudnorm uses 192 kHz internally; specify the export rate. Two-pass processing can fall back to dynamic normalization when linear constraints are not met.

## Fast and Accurate

### Implemented processing policy — WAC-M2-02 (2026-10-02)

`-LoudnessMode Fast` preserves the existing single-pass filter behavior and remains default. Accurate is opt-in. Compose a common deterministic prechain: selected audio stream -> explicit channel policy -> cleaning where selected -> dynamic leveling. Pass 1 measures that signal with the target normalization measurement stage; pass 2 repeats exactly that prechain and applies valid measured_I, measured_TP, measured_LRA, measured_thresh and target_offset-to-offset mapping. Do not append a second full loudnorm to a chain already normalized to the target.

Pass 1's discarded render is not an input for pass 2 unless an explicitly documented, tested lossless staging design replaces the repeated prechain. Compare both command structures. Unit-test measurement JSON extraction amid stderr text; handle strings such as -inf safely. Parse invariant decimals and serialize only finite allowed values.

Both Accurate passes explicitly use I=-12 LUFS, TP=-1.5 dBTP and LRA=7 LU.
A common `aresample=192000` step follows the selected preset's dynamic leveling and precedes
terminal loudnorm so linear versus dynamic loudnorm negotiation cannot change
the rate of the signal being measured.
The exact same prechain, stream map and channel policy feed both passes. Fast's
no-extra-options Original filter strings and arguments receive no extra
resampling or analysis; optional cleaning changes only the selected Raw chain.
The M1 export policy still determines the final 48 kHz PCM encoding.
Each Accurate stage has a finite deadline of 20 times the selected duration
plus 60 seconds, with a 120-second minimum and an Int32-millisecond maximum,
followed by the native wrapper's bounded cleanup. Fast's render stays unlimited.

First-pass JSON must be complete and well formed; parse invariant
numbers and validate every value before placing it in a filter argument.
Recognized undefined measurements from a successful process receive explicit
null/reason fields and permit an unmeasured fallback, with a warning. Missing or
malformed JSON, unexpected nonfinite values and failed analysis processes are
processing failures, not unavailable measurements; they stop publication with
code 4. An analysis/render process that cannot start retains dependency code 3.
Never serialize NaN/infinity or invent a measured zero.

Valid finite statistics outside FFmpeg's accepted measured-parameter bounds
use `linear=false` with fallback reason `measurement_out_of_range`. This is
different from malformed or invalid measurement data, which fails the stage.

Record requested mode, measured parameters, fallback reason and the render's
actual `normalization_type`. A requested dynamic fallback is not proof of the
reported type: the installed FFmpeg can report linear for very short inputs
even when linear=false. `ffmpeg_dynamic_fallback`, `measurement_out_of_range`
and undefined-measurement fallbacks produce a published warning. Preserve
duration and selected channels; any mono conversion precedes both measurements.
No retry loop is introduced.

## Final-file verification

### Implemented export policy — WAC-M1-05 (2026-10-02)

The original profile strings above remain frozen. Exports explicitly request
48 kHz signed PCM16, or PCM24 with `-BitDepth 24`. This is an intentional encoding
change from the measured 192 kHz PCM16 legacy default. Mono/stereo channel counts
and ordering are preserved. Absent layout labels use the standard layout for
one/two channels; conflicting labels and multichannel input are unsupported.
`-Mono` explicitly averages stereo left/right before the original filter chain;
it does not admit multichannel input. Metadata/chapters are not copied to exports.

RIFF WAV is default; `-Rf64` requests RF64 even for small output. A conservative
size estimate includes 101 ms, 1 MiB of headers, and free-space reserve of the
greater of 64 MiB/10%. Reject a RIFF estimate above 4,294,967,295 bytes with RF64
guidance. Count one output allocation: the partial becomes the final by rename.
Read caller-available capacity on the held destination, including quota effects.
The check does not reserve space against competing writers.

The held-file validator requires the requested rate, PCM bit depth/codec,
channels/layout, container and complete timing before publication. RF64 support
is the FFmpeg single-data-chunk form: first 28-byte ds64, no extra table entries,
exact 64-bit RIFF/data/sample counts and sentinel fields. Unsupported or malformed
headers fail closed. Full >4 GB output, real disk exhaustion and speech listening
are not claimed. Detailed evidence: `evidence/WAC-M1-05.md`.

References: [FFmpeg WAV muxer](https://ffmpeg.org/ffmpeg-formats.html#wav),
[loudnorm output rate](https://ffmpeg.org/ffmpeg-filters.html#loudnorm),
[caller-available disk space](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getdiskfreespaceexw).

### Implemented final-file measurement — WAC-M2-02 (2026-10-02)

Accurate performs a third FFmpeg invocation after validating the encoded PCM
and before the existing no-replace publication. Keep the validation handle
open: read its exact WAV bytes from position zero into the child's binary
stdin, allow only the pipe protocol/WAV demuxer, and discard analysis output.
Do not release and reopen the path or rerun cleaning, leveling or mono conversion.
The native wrapper drains both diagnostic streams while copying input, closes
child stdin at EOF and retains caller ownership of the validation stream.
Input-copy errors cannot become successful measurements merely because the
child returned zero. Publication renames the same held object after this check.

Use the final-file analysis's `input_i`, `input_tp` and `input_lra` values.
Its `output_*` values describe a discarded normalized stream and are not the
export's measurements. This is a separate inspection of the encoded file,
using FFmpeg's loudnorm meter. Fast has no extra invocation and continues to
report NOT_MEASURED.

The declared tolerances are integrated loudness within 0.5 LU of -12 LUFS and
true peak at most -1.3 dBTP (-1.5 plus 0.2 dB measurement tolerance). These are
engineering acceptance limits, not an industry standard or exact-equality
promise. Do not weaken them silently. Evaluate a known peak violation first;
undefined integrated loudness must not hide an exceeded peak. Compliance can
pass only when required integrated and true-peak metrics are finite and within
these limits. Report LRA as information; it has no separate final tolerance.

For input shorter than one second, use `too_short` and null integrated loudness
and LRA, even if FFmpeg returned finite numbers; retain a finite true peak.
For longer input, undefined integrated loudness with undefined peak uses
`silence`; undefined integrated loudness with finite peak uses
`undefined_loudness`. These recognized cases use null plus a reason for
unavailable metrics. Failed/malformed final analysis is a FAILED measurement
diagnostic, not successful or merely unavailable analysis. A structurally valid
WAV may still be published with `status: WARNING`, `processingStatus: SUCCESS` and
application exit 7 for undefined/out-of-tolerance results, normalization
fallback or a render/final measurement diagnostic failure. `reporting.complete`
describes only report writing. Earlier analysis/render failure prevents
publication and keeps its primary failure code. Reports never call unmeasured
or failed results compliant.

## Timing and preview

No trim, silence removal, pitch/speed change, stereo folding or timing rewrite by default. Compare known impulses and boundaries; target duration tolerance for PCM regression fixtures is <=10 ms with no unexplained leading offset. Measure filter delay and test short files rather than pad/trim blindly.

Preview ranges are validated. Account for stateful-filter warmup using pre-roll/post-roll then trim to a matched excerpt; disclose preview edge differences. Level-match A/B excerpts in separate comparison assets without altering full-render settings. Preview integrated loudness is not full-recording integrated loudness.

### Implemented bounded preview — WAC-M2-04 (2026-10-02)

`-Preview` uses a separate optional sibling helper and returns before the
full-render path. Default start/duration are 0/45 seconds. Default duration
clips to available audio; explicit duration must fit, be positive and no more
than 60 seconds. Start is nonnegative and must precede the selected audio's
end. Reject nonfinite, signed/exponent/comma/whitespace or injected strings;
seconds use invariant decimal notation. Round to the nearest 48 kHz sample
with halfway values away from zero and reject zero-sample ranges. Selected
duration must be known and valid. Range flags without `-Preview` fail.

Take at most five seconds of pre-roll and five seconds of post-roll, clipped
at the selected stream's ends. Restrict both file inputs with input `-ss` and
`-t`; the requested filter/context window is at most 70 seconds. Accurate
seeking may decode/discard earlier packets, so this is no total-decoding-work
guarantee. Preview ranges are relative to the selected audio's first samples;
probe its timestamp origin and use absolute `-seek_timestamp 1` seeks to
`streamStart + windowStart`, rather than another track/container origin.
Negative selected origins and absent non-WAV origins are unsupported and
fail closed; RIFF/RF64 WAV without timestamps uses sample zero. Probe the
selected time base/sample rate and report timestamp resolution plus a
conservative seek bound `ceil(48000 * timeBaseSeconds) + 1` samples. Reject
unknown/nonpositive/coarse non-WAV clocks or a bound above 480 samples
(10 ms). WAV can derive its sample clock when no time base is supplied.
Container seeks can differ from a fully decoded source-frame slice within
that declared bound: the synthetic 1 ms Matroska clock yielded +8 samples
(0.167 ms) in one middle seek. Record measured offsets in the development
evidence; do not claim universal exact source-start selection. This seek
uncertainty is separate from preserved filter delay and adds no compensation.
Original
applies only the output channel policy, 48 kHz resampling and exact sample
trimming. Processed applies the selected profile to that bounded window,
then resamples/trims to the same sample positions. No silence removal or
padding is introduced. Exported assets require identical requested frame
counts. Accurate analyzes/repeats the deterministic prechain over the context
window, retaining observed normalization type and fallback semantics; this is
not full-program analysis or a promise that the excerpt reaches -12 LUFS.

Preserve existing filter delay, with zero compensation. On pinned FFmpeg
9.0.2, deterministic random-marker correlation measured Original Raw and
Gentle Raw at +1200 samples (25 ms); Zoom and the tested Original Raw with
Declip/Declick/Denoise/Gate all disabled had zero correlation lag. Highpass
phase can shift impulse peaks by a few samples. Those are approximate graph
references, not calibration of every custom graph or build. Record exact
filters, delay policy and context/edge limitations. Compare the bounded
processed output with its direct filtered-window reference to exclude added
shifts; do not claim source/processed waveforms align at zero lag. Five
seconds of context does not guarantee equivalence to a full-file render,
especially near EOF or with window-dependent leveling.

Create four separately owned assets: Original, Processed, CompareOriginal
and CompareProcessed. Validate/measure each encoded PCM through its held
stream. Comparison uses gain only after the original/processed excerpts
exist. For finite measurable I/TP, choose the lowest of the two integrated
values and the two peak-safe levels `I - TP - 1.7`. Set each gain to
`min(0, commonTarget - I)`. No gain boost or mastering retune is allowed.
For unmeasurable excerpts, integrated matching is unavailable; retain an
explicit reason and apply only any needed peak-safe attenuation.

Measure the comparison pair again. Available integrated values must differ
by at most 0.2 LU; each finite true peak must be <= -1.5 dBTP. The -1.7 dBTP
planning target leaves measurement/encoding headroom. A known exceeded peak
is fatal and rolls back owned preview assets; unmeasurable or nonmatching
integrated comparison uses a clearly labelled warning. Null integrated/LRA
under one second retain `too_short`; silence/undefined reasons remain fixed.
Preview measurements, including Accurate's context analysis, never stand
for full-recording integrated loudness. Playback remains an explicit user
action; no permission-cleared speech review has been performed.

Inherited parser limit: finite integrated/threshold measurements are accepted
only through 0 LUFS. The initial 0.97-amplitude square fixture reported
I=+0.51/TP=+1.80 and failed closed with code 4 before publication. This task
does not expand those existing bounds. The final 0.8-amplitude high-peak
fixture exercises comparison attenuation within the accepted meter domain;
it does not certify preview support for positive integrated loudness. Retain
the preliminary failure and this limitation for later edge-case work.

## Listening gate

Owner-approved local speech material is needed to judge voice quality. Review quiet words, consonants, breathing, pumping, musical/noisy artifacts and voice character on the same playback setup, with level-matched A/B samples. Synthetic tones test mechanics, not intelligibility. Keep private recordings out of Git and CI. No default-sound promotion without explicit owner approval of exact preset/settings/revision.


### Objective M2 checkpoint — WAC-M2-05 (2026-10-02)

The implemented M2 domain passes fresh numeric/structural/format regressions
and selected same-input/build report-driven reproduction. No runtime graph,
default, export or report behavior changes in this checkpoint. A valid export
and a passing mechanics test are separate from measured target compliance:
Fast remains NOT_MEASURED; Accurate misses/fallback and short/silent/undefined
results retain truthful warning classifications. Positive finite integrated/
threshold measurements remain rejected rather than treated as unavailable.

Human-gate integrity is accepted with listening explicitly unperformed and no
cleared corpus admitted. No speech-quality or default-promotion approval follows.
The reproduction utility retains input/report/source/executable hashes separately
from ordinary reports and requires exact reconstructed graphs/PCM on the tested
build. Its selected configurations do not certify every highly precise control,
codec seek, different build or full-program preview equivalence. Existing seek,
filter-delay, calibration, storage/cancellation/stress and privacy limits remain.
Evidence: `evidence/WAC-M2-05.md`, classifications/reproduction/source artifacts
and `evidence/WAC-M2-05-listening.md`.
