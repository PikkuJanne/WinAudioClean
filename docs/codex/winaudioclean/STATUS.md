# Current status

Date: 2026-10-02. **WAC-M2-02 is complete.** M0, M1 and two M2 tasks are
done. AC-001 through AC-039 pass. Thirteen tasks are done; 17 remain todo.

**Next: WAC-M2-03 — Add optional gentle cleaning with validated parameters.**
Start separately after fresh synchronization verification.

## Optional measured loudness

Default `-LoudnessMode Fast` retains Original Raw/Zoom filters, render arguments
and NOT_MEASURED compliance. Opt-in Accurate measures the post-conversion,
post-cleaning and post-leveling signal, repeats its deterministic prechain with
validated measured parameters, then measures the final encoded PCM. Accurate
pins both prechains to 192 kHz before loudnorm; export stays at 48 kHz.

The held validation stream supplies binary stdin for final measurement, keeping
the no-replace publication lock intact. Reports distinguish requested targets,
actual normalization type/fallback, final measurements, output validity and
report-writing completeness. Tolerances are +/-0.5 LU around -12 LUFS and true
peak <= -1.3 dBTP. Valid audio with fallback or unavailable/failed/out-of-tolerance
checks receives WARNING/7. Silence/short results use explicit null/reason fields.

- Each shell passes **666 Pester tests and 61 Python tests** in one Full gate;
  one Python symlink-privilege skip, no failures. Focused gates pass 123 each.
- **16/16 Accurate cases pass**: Raw/Zoom, selected stream 1, stereo, natural mono,
  explicit downmix, PCM16/24, high LRA, peak constraints, silence and 0.2 seconds.
  Independent file checks match reported metrics; all eight corresponding
  PS5.1/en-US and PS7/de-DE PCM pairs are identical.
- **20/20 Fast comparisons and 10/10 baseline references pass**, with exact
  decoded PCM equality. Its tested source predates only two Accurate-specific
  diagnostic/report refinements; final Accurate and Full gates cover those.
- Initial smoke found a PS5.1 async return-value leak; explicit void casts and
  one-result assertions fix it. Parser/static/plan checks pass. The Full logs
  retain all analyzer advisories; no suppressions were added.

[Evidence and limits](evidence/WAC-M2-02.md),
[source manifest](evidence/WAC-M2-02-source.json),
[Accurate matrix](evidence/WAC-M2-02-measured-loudness.json), and
[Fast preservation](evidence/WAC-M2-02-fast-compatibility.json).
Earlier evidence and the M1-02 policy/resumption history remain intact.

## Preserved contracts and limits

Original ID `original`, version `1.0.0`, application version `2.3` and schema
`1` remain distinct. No new cleaning preset or saved setting exists yet.
48 kHz PCM16 is default; PCM24, explicit mono and RF64 remain optional. IO and
launcher are unchanged. Selected tracks, owned partials, held-object rename,
PCM validation and report rollback remain covered by the cumulative gate.

Speech listening, full >4 GB rendering, real disk exhaustion, long-file/memory
stress and running-render Ctrl+C remain unverified. Synthetic files and the
same FFmpeg meter do not establish independent meter calibration or voice
quality. Raw's existing approximately 25 ms delay remains. Capture is in memory;
capacity is not reserved; reports have no multi-file atomicity/power-loss
guarantee. Early preflight failures remain console-only.

## Checkout and delivery

Use WinAudioClean-governance on `codex/wac-m2-audio`; preserve the original
source-only folder. Exact effective fetch/push origin:
`https://github.com/PikkuJanne/WinAudioClean.git`.
Draft PR #3 is stacked on `codex/wac-m1-reliability`; unmerged PR #2 is stacked
on `codex/wac-m0-handoff`, with PR #1 also unmerged. Record the completion SHA
and clean local/live/PR verification in PR #3 and the final response after push.
No CI workflow/checks exist. No merge, release, repository-setting change,
default-sound promotion or website deployment occurred.
