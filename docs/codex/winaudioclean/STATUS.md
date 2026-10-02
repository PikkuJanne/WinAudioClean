# Current status

Date: 2026-10-02. **WAC-M2-04 is complete.** M0, M1 and four M2 tasks are done.
AC-001 through AC-045 pass. Fifteen tasks are done; 15 remain todo.

**Next: WAC-M2-05 — Audio gate with honest listening status.** Start separately
after fresh synchronization verification.

## Bounded preview and comparison

Explicit `-Preview` defaults to 0/45 seconds, clipping only the omitted duration
to available selected audio. Validate invariant ranges through 60 seconds and
round to output samples. Five-second pre/post context is bounded by stream ends;
all four encoded assets have exactly the requested frame count. Selected-track
origins use absolute timestamp seeking. Declared container timing uncertainty
is bounded by 10 ms; unsupported origins/precision fail closed. Known Original/
Gentle Raw delay is preserved, approximately 25 ms on the tested build.

Original/Processed retain the selected full-profile settings. Separate
CompareOriginal/CompareProcessed copies use attenuation only, planned with
-1.7 dBTP headroom. Final comparison requires finite TP<=-1.5 dBTP and available
integrated difference<=0.2 LU. Short/silent/undefined matching is WARNING/7.
Preview metrics describe excerpts/context, never the full recording. No full
render, playback or upload starts implicitly; no settings are saved.

Four held transactions validate/measure before no-replace publication and
roll back only owned files on failure/cancellation. Completed audio survives
report failure as WARNING/7. Preview JSON/text reports are separate from normal
summaries. IO and launcher remain unchanged; the optional sibling is required
only for Preview.

- Final Targeted passes **322 Pester per shell**; Full passes
  **1015 Pester and 61 Python per shell**, one Python privilege skip,
  zero failures. Parser/static/plan gates pass; 179 advisories remain.
- **24 preview cases**, four direct references each and 12 identical
  locale PCM pairs pass. Independent source slices disclose any seek rounding;
  all assets retain matched frame counts and no added preview filter shift.
- **20 Original cases plus ten frozen references** pass at zero lag with exact
  decoded PCM. Main/full defaults, Fast arguments and Accurate contracts remain.
- Initial gain/long-offset overload bugs, a temporary test discovery mistake
  and the media timestamp refinement are preserved with exact preliminary scope.

[Task evidence](evidence/WAC-M2-04.md), [source manifest](evidence/WAC-M2-04-source.json),
[preview matrix](evidence/WAC-M2-04-preview.json),
[Original preservation](evidence/WAC-M2-04-original-preservation.json), and
[latency reference](evidence/WAC-M2-04-latency.json).
Preserve all earlier evidence and M1-02 policy/resumption history.

## Preserved audio contracts and limits

Original `original`/`1.0.0` remains default. Gentle `gentle`/`0.1.0` stays Raw-only
and experimental, with no listening approval. Typed cleaning controls and
strict Accurate profile reconstruction remain. Fast ordinary export performs
no added analysis. Full-file Accurate targets I=-12/TP=-1.5/LRA=7, final finite
tolerance +/-0.5 LU and TP<=-1.3 dBTP, explicit reasons and WARNING/7 semantics.
Application2.3/report schema1 and PCM16 default/optional24/mono/RF64 remain.

Speech listening, independent meter calibration, full >4 GB output, disk
exhaustion, long-file/memory stress and running-render Ctrl+C are unverified.
Container seek precision and stateful edges limit preview/full equivalence.
The inherited meter parser rejects positive integrated source loudness; the
lower-amplitude peak fixture does not certify that unsupported domain.
Capture is in memory, capacity is not reserved and publication/report sets lack
multi-file atomicity/power-loss guarantees. Failed previews use console details.

## Checkout and delivery

Use WinAudioClean-governance on `codex/wac-m2-audio`; preserve the source-only
original folder. Origin is `https://github.com/PikkuJanne/WinAudioClean.git`.
Draft PR#3 is stacked on `codex/wac-m1-reliability`, whose draft PR#2 is stacked
on M0. Verify actual completion SHA through live sync/PR after push. No CI
workflow/checks exist. No merge/release/default promotion/security/deployment.
