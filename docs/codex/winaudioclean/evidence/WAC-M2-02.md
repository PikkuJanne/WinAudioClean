# WAC-M2-02 evidence — optional measured loudness

Date: 2026-10-02. Starting clean, live-synchronized checkpoint:
`eafb6144cc3f2e2b1167a7d03e91654bdfb4fc20` on `codex/wac-m2-audio`, matching
draft PR #3. Exact effective fetch/push origin:
`https://github.com/PikkuJanne/WinAudioClean.git`. M2 remains stacked on M1.

## Change and acceptance

- AC-037: opt-in `-LoudnessMode Accurate` captures actual arguments for analysis,
  rendering and final measurement. Both first passes select the same absolute
  stream and repeat channel conversion, cleaning and dynamic leveling once.
  Accurate pins the shared prechain to 192 kHz before terminal loudnorm.
  Validated invariant measurements map to measured_I/TP/LRA/thresh and offset.
  Tests cover Raw/Zoom, mono/stereo/downmix and en-US/de-DE/fi-FI formatting.
- AC-038: final measurements come from encoded 48 kHz PCM16/24, streamed from
  the immutable validation handle before publication. An independent harness
  reopens each published file and verifies its measurements. Compliance uses
  -12 LUFS +/-0.5 LU and a true-peak ceiling of -1.3 dBTP. LRA is informational.
  Fast retains its original filters/arguments, with no extra analysis process.
- AC-039: real silence, 0.2-second input, high LRA and peak-constrained fixtures
  exercise unavailable measurements and observed dynamic fallback. Strict
  parser tests reject malformed/duplicate/nonfinite data. Runtime fault cases
  check fatal analysis failure, warning-only render diagnostics/final failure,
  primary native codes, no retry, retained valid audio and owned-partial cleanup.

## Validation

Windows 11 build 26300; PowerShell 5.1.26100.9444 and 7.6.5; Python 3.14.6;
Pester 5.7.1, PSScriptAnalyzer 1.24.0, existing FFmpeg/ffprobe 9.0.2.
No dependency download or machine security change was made.

The final focused runners each pass 123 Pester tests (98 helpers/report tests,
10 stage fault cases, 6 native-input cases and 9 existing preset cases).
Both exit 0 with no failures/skips and pass parser/static/plan checks.
The local runner's aggregate source-stability check reports a development
harness edit during that run: only Test-MeasuredLoudness.py changed to assert
Accurate's new -nostats argument. No tested PowerShell source changed. The
subsequent Full gates and final media matrix use the completed harness.

Cumulative Full gates both exit 0: **666 Pester tests and 61 Python tests pass
per shell**, with one Python symlink-privilege skip and zero failures. Each
parses 29 PowerShell files and passes static/plan checks. The 126 non-gating
analyzer advisories are retained in the PS7 log; no suppression was added.
All maintained code hashes remain unchanged during and after Full. The
[PS5.1 log](WAC-M2-02-full-ps51.txt) and [PS7 log](WAC-M2-02-full-ps7.txt)
cover all existing reliability/launcher/encoding/report regressions as well
as the new tests. Get-Help also renders the new Accurate example correctly.

## Real encoded-file results

The [complete matrix](WAC-M2-02-measured-loudness.json) runs eight cases in each shell, en-US in PS5.1 and de-DE
in PS7. Every corresponding decoded PCM hash matches across shells/locales.
The same FFmpeg loudnorm implementation meters the application and independent
checks; this proves file/command consistency, not independent meter calibration.

| Fixture (both shells) | Final LUFS | Final dBTP | Actual render type | Compliance / application |
| --- | ---: | ---: | --- | --- |
| Raw, selected stream 1, stereo PCM16 | -12.00 | -2.80 | linear | PASSED / 0 |
| Zoom, stereo PCM24 | -11.99 | -2.97 | linear | PASSED / 0 |
| Raw, mono PCM24 | -12.14 | -1.50 | dynamic | PASSED / WARNING 7 |
| Raw, explicit stereo downmix PCM16 | -12.78 | -1.49 | dynamic | OUT_OF_TOLERANCE / 7 |
| Zoom, high LRA PCM16 | -12.54 | -1.50 | dynamic | OUT_OF_TOLERANCE / 7 |
| Zoom, sparse peaks PCM24 | -14.66 | -1.45 | dynamic | OUT_OF_TOLERANCE / 7 |
| Raw, digital silence | null | null | dynamic | UNMEASURABLE / 7 |
| Zoom, 0.2 seconds | null | -1.50 | linear | UNMEASURABLE / 7 |

These outcomes are expected acceptance results, including the warnings. High
LRA is measured at 21.4 LU before final normalization. The constrained cases
do not meet the integrated target and are not reported compliant. The short
case demonstrates why actual type cannot be inferred from `linear=false`.

The [Fast matrix](WAC-M2-02-fast-compatibility.json) also passes 20 application comparisons against 10 direct frozen-baseline
references: exact decoded PCM equality at zero lag on the same build/settings.
That matrix tested main SHA256
`6aa9266b7daf38896333755f05aec8271d5d0f07eaa994bd07f11d28b5cb42b0`.
The final main changes after it affect Accurate only: omit progress statistics
to keep diagnostics bounded, and leave render filters null when analysis fails
before any render. The final Accurate matrix and cumulative Pester gates cover
those refinements. Fast's render path and filter/argument builders are unchanged.
The reused Fast harness retains its originating WAC-M2-01 label inside JSON;
its invocation, source hashes and fresh output location identify this M2-02 run.

## Corrections and review

- A held-WAV experiment showed FFmpeg cannot reopen the validation handle's
  path (Permission denied). Binary stdin preserves the existing restrictive
  sharing and held-object publication contract.
- The first PS5.1 audio smoke exposed VoidTaskResult objects leaking from
  async input completion into the native result. Explicit void casts fix all
  three completion calls; native-input tests now require exactly one result.
  The repeated smoke and both full real-media matrices pass after this fix.
- An early helper run raced with three newly added range tests, producing
  68 passes/3 failures on the previous parser. Final parser/plan tests retain
  finite diagnostic values below -99 while excluding them from measured
  filter options, and pass 98/98 in both shells.
- A comma-delimited tag supplied through native -File selected no tests; the
  runner rejected that invocation. Final commands pass an actual PowerShell
  array through -Command. No zero-test result is counted as a pass.
- Read-only review verified pass ordering, selected-stream consistency,
  actual-type reporting, warning persistence and held-stream safety. It found
  the two final Accurate reporting/diagnostic refinements described above.

## Commands and provenance

Exact sanitized commands, source hashes and log hashes are in
[the source manifest](WAC-M2-02-source.json). The two real-media JSON records
include tool hashes/versions, actual commands, fixture hashes, per-case values
and independent checks. Generated audio and raw pathful reports remain ignored.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "./scripts/Invoke-Tests.ps1 -Level Targeted -Path @('tests/WinAudioClean.Loudness.Tests.ps1','tests/WinAudioClean.LoudnessRuntime.Tests.ps1','tests/WinAudioClean.NativeInput.Tests.ps1','tests/WinAudioClean.Preset.Tests.ps1')"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "./scripts/Invoke-Tests.ps1 -Level Targeted -Path @('tests/WinAudioClean.Loudness.Tests.ps1','tests/WinAudioClean.LoudnessRuntime.Tests.ps1','tests/WinAudioClean.NativeInput.Tests.ps1','tests/WinAudioClean.Preset.Tests.ps1')"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "./scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "./scripts/Invoke-Tests.ps1 -Level Full"
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-MeasuredLoudness.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M2-02/measured-final
python -X utf8 scripts/Test-OriginalPreset.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M2-02/fast-compatibility
```

## Limits and delivery

No speech listening, default-sound promotion, full >4 GB render, actual disk
exhaustion, long-file/memory stress or running-render Ctrl+C certification.
Raw's existing approximately 25 ms filter delay is preserved. Diagnostic
capture remains in memory; capacity is not reserved; reports lack multi-file
atomicity and power-loss guarantees. Synthetic signals do not certify speech
quality. Early preflight failures still use console-only diagnostics.

After explicit staging/review, commit/push the M2 feature branch and verify
clean local HEAD, live remote and draft PR #3 equality. Record the completion
SHA in the PR/final response to avoid a self-referential commit. No CI workflow
or checks exist. No merge, release or deployment is part of this checkpoint.
Next task: **WAC-M2-03 — optional gentle cleaning with validated parameters**.
