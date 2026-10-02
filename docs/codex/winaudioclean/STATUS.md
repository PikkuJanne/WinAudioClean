# Current status

Date: 2026-10-02. **WAC-M2-03 is complete.** M0, M1 and three M2 tasks are
done. AC-001 through AC-042 pass. Fourteen tasks are done; 16 remain todo.

**Next: WAC-M2-04 — Add safe excerpt preview and level-matched comparison.**
Start separately after fresh synchronization verification.

## Optional cleaning candidate

Original `original`/`1.0.0` remains the exact default Raw/Zoom graph. Opt-in
Raw `-Preset Gentle`, `gentle`/`0.1.0`, is experimental: declip/declick/gate off,
60 Hz highpass, `afftdn=nf=-35:nr=6`, shared leveling unchanged. Typed
`-CleaningOptions` accept four Boolean toggles and five bounded finite numeric
values. Invalid/injected/unknown settings fail before native execution.
Zoom rejects Gentle and nonempty cleaning options, remaining leveling only.

Accurate rebuilds/validates profiles and repeats the selected signal/prechain
with measured values; held-stream final measurement and warning semantics stay
intact. Reports separate base identity from candidate/customization flags and
effective cleaning settings. Redacted exports continue to omit those fields.
Application 2.3, report schema 1, encoding and file/report ownership are unchanged.

- Final Targeted passes **323 Pester per shell**. Full passes **866 Pester and
  61 Python per shell**, one Python symlink-privilege skip and no failures.
  Parser/static/plan checks pass; 161 analyzer advisories remain unsuppressed.
- **16 Gentle/custom cases and four Fast references pass**, with identical
  decoded PCM across all eight PS5.1/en-US and PS7/de-DE pairs. Actual arguments,
  streams/channels, repeated Accurate graphs and independent output checks agree.
  Expected downmix target miss and dynamic fallback stay WARNING/7.
- **20 Original cases and ten frozen references pass**, exact decoded PCM at
  zero lag. After media only two help sentences changed; byte comparison proves
  runtime equality. Final Full/Targeted/help pin the completed source.
- No approved speech corpus was supplied. AC-042 accepts the unavailable-review
  candidate record; **listening itself is unperformed and quality is unapproved**.
  Preserve initial test diagnostic-wrap failures and their test-only correction.

[Evidence and limits](evidence/WAC-M2-03.md),
[source manifest](evidence/WAC-M2-03-source.json),
[candidate record](evidence/WAC-M2-03-listening.md),
[Gentle matrix](evidence/WAC-M2-03-gentle-cleaning.json), and
[Original preservation](evidence/WAC-M2-03-original-preservation.json).
All earlier evidence and M1-02 policy/resumption history remain intact.

## Preserved contracts and limits

Fast remains default with no extra analysis invocation. Accurate targets remain
I=-12/TP=-1.5/LRA=7; finite final compliance requires +/-0.5 LU and TP <= -1.3 dBTP,
peak precedence and explicit short/silent/unavailable reasons. Valid PCM with
fallback or non-passing measurements remains WARNING/7; malformed first analysis
is fatal. Output validity and report-writing completeness stay separate.

48 kHz PCM16 stays default; PCM24, mono and RF64 remain optional. Selected
tracks, held source/destination identities, owned partials, no-replace rename,
complete PCM validation, report serialization/rollback and PS5.1 remain covered.
IO and launcher are unchanged. Saved settings and excerpt preview are not yet
implemented. Original Raw's approximate 25 ms delay remains.

Speech listening, independent meter calibration, >4 GB output, actual disk
exhaustion, long-file/memory stress and running-render Ctrl+C remain unverified.
Capture is in memory; capacity is not reserved; reports lack multi-file atomicity
and power-loss guarantees. Early failures remain console-only.

## Checkout and delivery

Use WinAudioClean-governance on `codex/wac-m2-audio`; preserve the source-only
original folder. Effective origin: `https://github.com/PikkuJanne/WinAudioClean.git`.
Draft PR #3 remains stacked on `codex/wac-m1-reliability`, whose draft PR #2 is
stacked on `codex/wac-m0-handoff`. Record completion SHA and clean local/live/PR
equality in PR #3/final response after push. No CI workflow/checks exist. No
merge, release, default-sound promotion, security change or deployment occurred.
