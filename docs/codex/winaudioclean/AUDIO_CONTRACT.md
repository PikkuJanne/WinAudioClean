# Audio behavior contract

This combines preserved behavior and proposed later test contracts. Sections
marked implemented describe current behavior; later preview and listening
requirements remain pending.

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

## Listening gate

Owner-approved local speech material is needed to judge voice quality. Review quiet words, consonants, breathing, pumping, musical/noisy artifacts and voice character on the same playback setup, with level-matched A/B samples. Synthetic tones test mechanics, not intelligibility. Keep private recordings out of Git and CI. No default-sound promotion without explicit owner approval of exact preset/settings/revision.
