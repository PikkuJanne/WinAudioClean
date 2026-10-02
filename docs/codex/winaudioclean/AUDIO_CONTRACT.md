# Audio behavior contract

This is a proposed implementation/test contract, not evidence that the application already complies.

## Preserved baseline

Raw prechain:
`adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056`

Both-mode leveling chain:
`dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5`

Zoom uses only the leveling chain. Naming a preset must not change its values/order. Do not claim bit-identical output across FFmpeg builds or after changing sample format/rate.

## Correct definitions [S01]

`loudnorm I` targets integrated LUFS, not RMS. `dynaudnorm p` is a peak-amplitude target, not an Adobe percentage. `afftdn nf` describes the noise floor; `nr` controls reduction. A nonzero gate range is limited attenuation, not guaranteed silence. Dynamic loudnorm uses 192 kHz internally; specify the export rate. Two-pass processing can fall back to dynamic normalization when linear constraints are not met.

## Fast and Accurate

Fast preserves the existing single-pass filter behavior and remains default. Accurate is opt-in. Compose a common deterministic prechain: selected audio stream -> explicit channel policy -> cleaning where selected -> dynamic leveling. Pass 1 measures that signal with the target normalization measurement stage; pass 2 repeats exactly that prechain and applies valid measured_I, measured_TP, measured_LRA, measured_thresh and target_offset-to-offset mapping. Do not append a second full loudnorm to a chain already normalized to the target.

Pass 1's discarded render is not an input for pass 2 unless an explicitly documented, tested lossless staging design replaces the repeated prechain. Compare both command structures. Unit-test measurement JSON extraction amid stderr text; handle strings such as -inf safely. Parse invariant decimals and serialize only finite allowed values.

Set target I/TP/LRA consistently across passes. Record requested mode and FFmpeg's actual normalization type, including fallback. No unbounded retry loop. Preserve duration and selected channels; any mono conversion must occur before both measurements.

## Final-file verification

Probe the final PCM file after output resampling/quantization, not only loudnorm's internal output. Validate stream, nonempty samples, sample rate, codec/bit depth, channel count and duration. For eligible program-length fixtures, initial engineering targets are integrated loudness within 0.5 LU of the requested target and measured true peak no more than target + 0.2 dB measurement tolerance. These tolerances are proposed tests, not an industry specification or a guarantee of exact equality. Establish stricter margins after measurement, not by silently weakening tests.

The peak ceiling takes precedence over claiming a loudness target. Out-of-tolerance results must be reported as warnings/failures according to a documented target-compliance policy, not labeled compliant. Log requested vs achieved values. Default target remains -12 LUFS / -1.5 dBTP for Original; do not invent a platform-specific standard.

Silent/very short/unmeasurable inputs receive metric value null plus an explicit reason and status. They may still produce a valid audio export under a documented policy, but never a false “target achieved” claim. Do not hide failed processing behind an undefined-loudness exception.

## Timing and preview

No trim, silence removal, pitch/speed change, stereo folding or timing rewrite by default. Compare known impulses and boundaries; target duration tolerance for PCM regression fixtures is <=10 ms with no unexplained leading offset. Measure filter delay and test short files rather than pad/trim blindly.

Preview ranges are validated. Account for stateful-filter warmup using pre-roll/post-roll then trim to a matched excerpt; disclose preview edge differences. Level-match A/B excerpts in separate comparison assets without altering full-render settings. Preview integrated loudness is not full-recording integrated loudness.

## Listening gate

Owner-approved local speech material is needed to judge voice quality. Review quiet words, consonants, breathing, pumping, musical/noisy artifacts and voice character on the same playback setup, with level-matched A/B samples. Synthetic tones test mechanics, not intelligibility. Keep private recordings out of Git and CI. No default-sound promotion without explicit owner approval of exact preset/settings/revision.
