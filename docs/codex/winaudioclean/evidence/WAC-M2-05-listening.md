# WAC-M2-05 human gate integrity — LISTENING NOT PERFORMED

Record prepared: 2026-10-02. Acceptance case: **AC-047**. Repository audit
anchor: `ca512d08bdb806d5c1900ecd9b6d8ba0c1e7037d` on `codex/wac-m2-audio`.
This is a consent, template and approval-record audit, not a human audition.

**Cleared corpus: UNAVAILABLE. Listening review: NOT PERFORMED.** No
owner-supplied, permission-cleared speech material was supplied in this chat.
The known repository records admit no cleared clip IDs or attributable human
results. No speech was selected, rendered or played for this record. Reviewer,
review date, speech comparison settings and playback observations remain
pending. This does not assert that no private recordings exist elsewhere.

**Default-sound promotion: NOT APPROVED.** Original remains the preserved
default, `original` / `1.0.0`. Gentle remains an opt-in experimental Raw
candidate, `gentle` / `0.1.0`, with no demonstrated speech-quality advantage.
Neither numeric checks nor this integrity record authorize changing defaults.
Missing optional candidate approval does not block unrelated reliability
delivery; promotion still requires explicit owner approval of exact settings,
evidence and revision in [APPROVALS.md](../APPROVALS.md).

## Audit scope and disposition

Only repository guidance and existing sanitized evidence were inspected. No
user profile, private media directory or permission document was searched.
No tests, media renders or playback were run for this record.

| Record inspected | Observed human-gate status |
| --- | --- |
| [Listening template](../templates/LISTENING_REVIEW.md) | Reviewer, revision/build/settings, corpus and playback remain pending; missing samples cannot become a listening pass. |
| [M0 corpus record](WAC-M0-03-listening.md) | No admitted clips; local processing/audition consent and a private source mapping remain required. |
| [M2-03 candidate record](WAC-M2-03-listening.md) | Base settings are registered; listening is unavailable/unperformed and default promotion is not approved. |
| [Approval register](../APPROVALS.md) | No default-sound promotion approval is recorded. Ordinary planned implementation/checkpoints do not supply that approval. |
| [Audio contract](../AUDIO_CONTRACT.md) and [M2-04 evidence](WAC-M2-04.md) | Synthetic mechanics, measured excerpts and preserved defaults do not establish intelligibility, preference or human listening approval. |

AC-047 integrity is represented by the explicit missing-review disposition
and pending attributable fields below. There is no fabricated reviewer pass,
consent, per-clip observation or preference. Objective checks and reproduction
results belong to the separate M2-05 task evidence; this record supplies no
new AC-046 or AC-048 execution result.

## Pending attributable review record

Use one sanitized record per actually cleared clip and comparison. Populate
the exact values from the real render/report; a preset name alone is insufficient.

| Required field | Current disposition / information to record |
| --- | --- |
| Human reviewer ID, review date and method | Pending; no reviewer results attributed. Use a stable non-identifying reviewer ID. |
| Neutral clip IDs and consent | Pending; no clips admitted. Record `cleared`, `pending` or `excluded`; process/audition only cleared material covering all audible participants. Keep supporting consent private. |
| Input identity and format | Pending. Preserve original input, its private hash/source mapping, duration, codec, rate, channels/layout and selected absolute stream. Shared evidence uses neutral IDs only. |
| Revision and dependencies | Pending for speech renders. Record exact application commit/content hashes, FFmpeg/ffprobe build/version and executable hashes. The audit anchor above is not an approved listening revision. |
| Candidate identity and effective settings | Pending for speech comparisons. Record mode, base ID/version, experimental/customized flags and every typed effective cleaning value. Original Raw, Original Zoom, Gentle Raw and each custom candidate require their actual settings. |
| Exact processing and output | Pending. Retain exact filters/arguments, Fast/Accurate, channel conversion, output rate/bit depth/container, and Accurate analysis/render values, observed type and fallback reasons where applicable. Preserve implicit Original `nr` and rounded gate values through the actual graph/build. |
| Excerpt, context and timeline | Pending. Record requested and quantized start/duration/sample counts, pre/post roll, stream origin, absolute seek, time base/resolution and declared seek tolerance. Distinguish source-position uncertainty, preserved graph delay and boundary differences. |
| Assets and comparison identity | Pending. Relate neutral source/processed/comparison asset IDs to their private hashes and exact interval. Keep comparison copies separate from full-render outputs. |
| Level matching and peaks | Pending. Record meter/build, original and processed integrated loudness/true peak, common target, gain dB for each comparison copy, final measured values and reasons. Use attenuation only and the recorded -1.7 dBTP planning/-1.5 dBTP comparison ceiling; do not invent LUFS for silence or subsecond excerpts. |
| Playback setup and order | Pending. Record a non-identifying device/software description, playback processing, volume and A/B order or shuffle method. Use the same setup and volume for each comparison. |
| Quiet words and endings | Not reviewed. Record audibility, intelligibility, any missing words/endings, benefits and failures. |
| Consonants | Not reviewed. Record attacks, sibilants, clarity and any loss or distortion. |
| Breaths and pauses | Not reviewed. Record naturalness, removed useful breaths and distracting noise/gate behavior. |
| Voice character and channels | Not reviewed. Record tone/texture, speaker character, spatial/channel changes and uncertainty. |
| Artifacts | Not reviewed. Record pumping, metallic/musical noise, clicks, clipping and gate transitions. |
| Preference, regressions and coverage | Not reviewed. Attribute reasons and unacceptable regressions per clip; keep unavailable categories and uncertain observations explicit. |
| Owner approval | None. Any proposed promotion needs an explicit instruction referencing the exact settings, evidence, accepted revision and target action; record it in the approval register. |

Keep recordings, outputs, source mappings, consent and detailed logs outside
Git or under the existing ignored local listening directory. Permission for
local work does not authorize upload of audio, transcripts, identifying metadata
or permission records. The prior M0 privacy procedure remains applicable.
No private filenames, paths, identifying quotations or participant details
belong in the shared review.

## AC-046 limitations independently inspected

These are current eligibility/interpretation limits, not new test passes or
human judgments. The code inspection and prior evidence support the following
classification without changing runtime behavior.

**Positive integrated loudness.** `ConvertFrom-WacLoudnormJson` in
`WinAudioClean.ps1` bounds finite input/output integrated and threshold values
at 0. A finite value above that bound is rejected as out of range before the
`too_short`, `silence` or `undefined_loudness` classifications are produced.
The [M2-04 preliminary fixture](WAC-M2-04-preview-preliminary.json) reported
I=+0.51 LUFS/TP=+1.80 dBTP and its preview failed with exit 4 and zero published
assets. Positive integrated loudness is finite, not silence or an undefined
measurement; it is outside the currently accepted parser domain. The final
lower-amplitude fixture demonstrates peak attenuation inside that domain and
does not certify support above it. Fast ordinary exports do not call this
meter, so this observation must not be generalized to all export paths.

The measured-parameter fallback in `Get-WacLoudnessPlan` applies to accepted
measurement objects; it does not make this rejected parser result an automatic
`measurement_out_of_range` fallback. An objective gate must disclose the
unsupported domain and distinguish an expected rejection from a compliant
measurement. Whether and how to support that domain remains unresolved; no
parser change or silent relaxation is made by this record.

**Timestamp policy.** `Get-WacPreviewTimeline` probes selected-stream origin,
sample rate and rational time base. Preview seeks to the absolute stream
origin plus the source-relative window start with `-seek_timestamp 1`.
Negative selected origins, missing non-WAV origins and invalid/coarse timing
fail closed. WAV without timestamps uses sample zero; missing WAV time base
can use its sample clock. The reported selection bound is
`ceil(48000 * timeBaseSeconds) + 1` output samples, capped at 480 samples/10 ms.

The [final M2-04 matrix](WAC-M2-04-preview.json) independently found a +8-sample
middle-seek source offset for the shifted PCM Matroska fixture, within its
49-sample bound for a 1 ms clock. Its near-start case and tested WAV crops
matched at zero source offset. Exact requested output frame counts and exact
direct bounded-window references do not imply universal exact source-start
selection. The clock bound is an application policy verified on the recorded
fixtures, not a guarantee for every codec, decoder or container. Broader seek
behavior remains unverified; do not guess a compensating trim or decode a full
prefix implicitly to claim equivalence.

Timestamp uncertainty is separate from the preserved approximately 25 ms
Original/Gentle Raw graph delay on the recorded build. Custom graph/build
calibration remains limited. Five-second context and window normalization can
differ from a full render, especially near boundaries; excerpt/context metrics
are not full-recording loudness. These limits must stay visible in objective
evidence and in any future listening comparison.

## Unresolved human outcome

Cleared speech, attributable reviewers, representative coverage, actual
comparison settings/build/revision and playback/gain records are still pending.
No words, consonants, breaths, voice character or artifacts have been judged.
No default-sound promotion or other consequential approval is added.
