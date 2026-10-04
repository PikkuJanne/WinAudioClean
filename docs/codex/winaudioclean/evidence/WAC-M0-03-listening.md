# WAC-M0-03 listening corpus — PENDING

Record prepared: 2026-10-02. Acceptance case: **AC-009, private corpus handling**.

**Listening review: NOT PERFORMED.** No owner-supplied, permission-cleared speech
corpus has been supplied or selected for this task. Reviewer, review date,
playback setup, processed speech outputs and listening results remain pending.
Synthetic characterization establishes processing behavior only; it cannot
establish speech intelligibility, voice quality or listening approval.

**Default-sound promotion: NOT APPROVED.** The original Raw and Zoom settings
remain the baseline. Any future promotion requires owner approval of the exact
settings and revision, recorded in [APPROVALS.md](../APPROVALS.md).

## Owner-supplied corpus checklist

- [ ] Confirm permission to process and audition each clip locally, including
  all audible participants. Record only `cleared`, `pending` or `excluded` in
  the shared review; keep supporting permission records private. Exclude clips
  with pending permission from processing and listening.
- [ ] Store originals, outputs, permission records and detailed logs outside
  Git or under ignored `.wac-local/listening/`. Local permission does not grant
  permission to upload audio, transcripts, tags or participant information to
  GitHub, CI, a website or a cloud service.
- [ ] Assign neutral IDs such as `clip-001`; keep the ID-to-source mapping
  private. Do not include names, source filenames, absolute local paths,
  identifying speech quotations or private metadata in committed evidence.
- [ ] Cover the material actually used: quiet speech/consonants, breaths and
  pauses, steady noise, changing speaker levels and already-processed Zoom
  speech. Include mono/stereo and different rates when available. Record
  unavailable categories as pending; do not invent representative coverage.
- [ ] Preserve original media. For each cleared clip record duration, sample
  rate, channel count, selected stream and excerpt boundaries using neutral IDs.
  Keep source hashes private if they could identify a known recording.
- [ ] Record the application revision/content hash, FFmpeg build, exact legacy
  filter string and output encoding for every compared render. Relate these to
  the synthetic baseline without substituting synthetic results for speech.

## Listening procedure when cleared material is available

1. Compare the unprocessed source with the relevant legacy Raw or Zoom output.
   State which mode is appropriate to the clip and why; retain original render
   settings. Log each comparison's neutral asset IDs and time range.
2. Make separate, time-aligned comparison copies. Include enough leading and
   trailing audio for stateful filters, then compare the same excerpt. Record
   any edge difference rather than attributing it to speech quality.
3. Level-match comparison copies and record the measurement method, measured
   levels, applied gain in dB and resulting levels for each asset. Record peaks
   and avoid clipping introduced by comparison gains. Use a disclosed fallback
   for clips whose loudness is undefined or unsuitable for the selected meter;
   do not report silence or a short excerpt as full-recording loudness.
4. Use the same playback device and volume across each comparison. Record a
   non-identifying description of headphones/speakers, playback software and
   any playback processing. Start at a comfortable level; keep the setting
   consistent. A second listen with shuffled A/B labels can reduce expectation
   bias; document the method used.
5. Record quiet-word and consonant intelligibility, breaths, voice character,
   pumping, metallic/musical noise, clicks and channel/spatial changes. Capture
   benefits, failures, preference with reasons and any unacceptable regression.
   Note uncertainty and the limited coverage of the available corpus.

## Review record to complete

| Field | Current record |
| --- | --- |
| Reviewer ID / date | Pending |
| Cleared clip IDs / permission status | Pending; no clips admitted |
| Source format / duration / selected stream | Pending |
| Source / Raw / Zoom comparison IDs and excerpt times | Pending |
| Application revision / FFmpeg build / exact filters / encoding | Pending for speech renders |
| Playback setup / comparison order | Pending |
| Level-matching method / before and after levels / gains / peaks | Pending |
| Per-clip observations / preference / regressions | Not performed |
| Coverage gaps / follow-up | Owner-supplied cleared corpus and human review pending |
| Default-sound approval reference | None; not approved |

Create one sanitized per-clip record when listening occurs, using the fields
above. Do not mark this review passed merely because the privacy checks pass.

## Ignore-rule evidence and staging gate

Before creating this record, the following read-only checks ran on Windows in
the repository at `7291ce86535e9c689befbdb60563ed9eb4b1b2a6`:

| Command | Exit | Observed result |
| --- | --- | --- |
| `git check-ignore -v -- .wac-local/listening/clip-001.wav artifacts/local/listening/clip-001.wav` | 0 | Both hypothetical paths ignored: `.gitignore` lines 2 and 3 respectively |
| `git ls-files -- .wac-local artifacts/local` | 0 | No tracked files under either local directory |
| `git diff --cached --name-only` | 0 | Index empty before adding this record |

The paths in the ignore check are examples; no audio was created or inspected
for this check. Git ignore rules do not protect already-tracked files or files
added with force. Before committing this task, inspect `git diff --cached
--name-only`, `git diff --cached --stat` and `git diff --cached` for private
audio, identifying paths/metadata, raw logs and unrelated files. The task's main
evidence record must report that final staged-file inspection.
