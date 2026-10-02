# WAC-M2-01 claims and compatibility review

Date: 2026-10-02. Scope: AC-034, plus independent review of preset reporting.

## Shipped claims

Reviewed README.md, WinAudioClean.ps1 help/menu/report text, launcher, test
instructions, fixtures documentation and RELEASE_WEBSITE.md. A repository-wide
search covered broadcast, RMS/LUFS, exact-result, 85%/95%, Audition, gate silence
and nf/nr wording. Poster/icon artwork was visually inspected. There is no
website implementation or public website draft in this checkout. Governance
history and baseline evidence retain old claims as historical audit data or
explicit cautions; they are not current product claims.

| Former claim | Current description | Primary source |
| --- | --- | --- |
| -12 dB RMS / universal broadcast / exact output | -12 LUFS integrated and -1.5 dBTP are chosen requested targets; final-file compliance remains independently unmeasured. | [loudnorm](https://ffmpeg.org/ffmpeg-filters.html#loudnorm) |
| 85% leveling / Adobe equivalence | dynaudnorm p=0.85 is the peak-amplitude target relative to full scale. No equivalence or success percentage is claimed. | [dynaudnorm](https://ffmpeg.org/ffmpeg-filters.html#dynaudnorm) |
| afftdn removes about 25 dB of noise | nf=-25 sets noise floor; nr controls reduction and remains at the tested build default of 12 dB. | [afftdn](https://ffmpeg.org/ffmpeg-filters.html#afftdn) |
| Gate silences the track | Nonzero range=0.056 bounds attenuation; threshold=0.0056 is linear. The approximate 25 dB attenuation and -45 dBFS threshold describe settings, not guaranteed cleanup. | [agate](https://ffmpeg.org/ffmpeg-filters.html#agate) |

Official references were read on 2026-10-02 and checked against the installed
FFmpeg 9.0.2 filter option help. Exact commands, exits and option text are in
WAC-M2-01-filter-options.json. README and working Get-Help cite FFmpeg. Filtering
may alter voice character; the user must listen. No speech-quality review has
occurred. Earlier M1-05 encoder changes remain explicitly separate from filters.

## Runtime and report review

The only executable application changes add selected-profile identity to
console, JSON and human reports and correct menu descriptions. Raw/Zoom filters
and their order match BASELINE.json; IO, launcher, native arguments, encoding,
output validation, cleanup and redaction code remain unchanged.

Both profile choices carry Original/original/1.0.0. The runtime passes that
selected profile to New-WacRunReport. The new JSON fields are additive in schema
1, presetVersionReason becomes null, and toolVersion stays 2.3. Text and shared
summary use the same PRESET label. Version 1 legacy reports remain supported by
the typed diagnostic projection, which still omits arbitrary identity/version
strings. This does not falsely identify old reports as Original 1.0.0.

One review finding was fixed: blank lines now separate each Get-Help example's
command and explanatory remarks. Fresh Get-Help checks in both shells verify
three single-line example commands with remarks. CRLF and unexpected-control-
character checks pass for main and README. Real unmodified PTY menu runs and
persisted report checks supplement mocked host-boundary integration tests.

The comparison script reads reference filters from BASELINE.json and renders
them directly with FFmpeg, independently of application profile construction.
Decoded bytes are compared without shifting/alignment or relaxed tolerance.
The Python hashing helper was corrected to retain Python 3.10 compatibility.
A separate timeout review/test covers only its owned process tree; no global
process-name termination is used. See task evidence for final validated hashes.
