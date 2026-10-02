# WAC-M2-03 listening candidates — NOT PERFORMED

Record prepared: 2026-10-02. Acceptance case: **AC-042**.

**Listening review: UNAVAILABLE / NOT PERFORMED.** No owner-supplied,
permission-cleared speech corpus was supplied or selected. No speech renders
or A/B assets were produced for this record. Reviewer, playback setup,
comparison-specific exact settings and results remain pending. The existing
[M0 corpus record](WAC-M0-03-listening.md) remains the privacy/procedure baseline.
Synthetic mechanics or loudness checks do not establish intelligibility,
voice quality, preference or listening approval.

**Default-sound promotion: NOT APPROVED.** Original stays default. Any future
promotion requires explicit owner approval of the exact settings and revision,
recorded in [APPROVALS.md](../APPROVALS.md).

## Registered base candidates

These are implementation settings to compare when cleared material becomes
available. They are not reviewed speech renders.

| Setting | Original Raw | Gentle Raw (experimental) |
| --- | --- | --- |
| Base ID / version | `original` / `1.0.0` | `gentle` / `0.1.0` |
| Declip / Declick / Denoise / Gate | true / true / true / true | false / false / true / false |
| HighpassHz | 80 | 60 |
| NoiseFloorDb / NoiseReductionDb | -25 / 12 | -35 / 6 |
| GateThresholdDb / GateRangeDb | -45 / -25, nominal legacy values | -45 / -25, inactive |
| Leveling / loudness targets | `dynaudnorm=f=200:g=11:p=0.85:m=20:s=12`, I=-12 / TP=-1.5 | Same |
| Cleaning overrides | None | None |
| Listening results / approval | Pending; not performed | Pending; not performed |

Exact Original Raw Fast graph:

```text
adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5
```

Exact Gentle Raw Fast graph:

```text
highpass=f=60,afftdn=nf=-35:nr=6,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5
```

Original's 12 dB reduction is implicit in this graph; its gate dB labels
describe nominal settings with preserved rounded linear values. The exact
graph and installed FFmpeg build are required for reproduction. Accurate
comparison runs must retain their actual analysis/render graphs and common
192 kHz pre-normalization step, plus measured values and fallback/type fields.
Custom candidates keep their base ID/version, customization flag and every
effective cleaning value; they need separate comparison records.

## Pending local comparison record and checklist

| Field | Current record / required review |
| --- | --- |
| Reviewer ID / date | Pending |
| Cleared neutral clip IDs / permission status | Pending; no clips admitted |
| Source duration / format / selected stream / excerpt boundaries | Pending |
| Application revision or source content hash / FFmpeg build | Pending for speech comparisons |
| Exact effective cleaning settings / filters / loudness mode | Pending for speech comparisons; registered base values above |
| Channel conversion / sample rate / bit depth / container | Pending; match across compared runs |
| Source / Original / Gentle asset IDs and time alignment | Pending |
| Playback device / software / processing / volume / comparison order | Pending |
| Level-matching method / levels / gain / peaks | Pending; use separate comparison copies |
| Words | Pending: preserve quiet words and endings; record losses or benefits |
| Consonants | Pending: audibility and changes to attacks/sibilants |
| Breaths | Pending: naturalness and whether useful breaths disappear |
| Voice character | Pending: tone, texture, speaker character and spatial changes |
| Artifacts | Pending: pumping, metallic/musical noise, clicks and gate transitions |
| Per-clip preference / regressions / uncertainty / coverage gaps | Not performed |
| Default-sound approval reference | None |

Process and audition only cleared clips locally. Keep audio, source mappings,
permission records and detailed logs outside Git or under ignored
`.wac-local/listening/`; use neutral IDs in shared evidence. Local permission
does not permit uploads. Compare the same excerpt on the same playback setup,
account for stateful-filter warmup/delay and level-match separate copies without
altering full-render settings. Record actual settings and gains, not merely a
preset name. Missing coverage stays pending; do not substitute synthetic tones
for any reviewer row above.

## Parameter-source checks (not listening evidence)

On 2026-10-02, checked the primary [FFmpeg afftdn](https://ffmpeg.org/ffmpeg-filters.html#afftdn),
[agate](https://ffmpeg.org/ffmpeg-filters.html#agate) and
[highpass](https://ffmpeg.org/ffmpeg-filters.html#highpass) documentation [S01].
Also ran these read-only commands against the installed
`ffmpeg version 9.0.2-essentials_build-www.gyan.dev`:

| Sanitized command | Exit | Observed option support |
| --- | --- | --- |
| `& <local-ffmpeg.exe> -hide_banner -h filter=afftdn` | 0 | `nf` -80 to -20; `nr` 0.01 to 97, default 12 |
| `& <local-ffmpeg.exe> -hide_banner -h filter=agate` | 0 | `range` and `threshold` 0 to 1 |
| `& <local-ffmpeg.exe> -hide_banner -h filter=highpass` | 0 | `f` 0 to 999999 |
| `& <local-ffmpeg.exe> -version` (first banner inspected) | 0 | Build identity above |

The application's bounded allowlist is recorded in [AUDIO_CONTRACT.md](../AUDIO_CONTRACT.md).
Its narrower limits are engineering policy, not FFmpeg's full option ranges
or an audition result. Task validation, source hashes and staged-file privacy
inspection belong to the main [WAC-M2-03 evidence](WAC-M2-03.md).
