# WAC-M2-03 evidence — optional Gentle and typed cleaning

Date: 2026-10-02. Started from clean, live-synchronized checkpoint
`275c6a7fece04b6879f31b4d58a3feb44587e87c` on `codex/wac-m2-audio`, matching draft PR #3.
Effective fetch/push origin: `https://github.com/PikkuJanne/WinAudioClean.git`.
M2 remains stacked on unmerged M1. No source-only starting files were changed.

## Change and acceptance

- AC-040: `-Preset Gentle` is an explicit experimental Raw candidate. Version 1
  effective cleaning settings use four Boolean toggles and five bounded finite
  numeric scalars. Unknown keys, case duplicates, strings, arrays, scriptblocks,
  nulls and nonfinite/out-of-range numbers cannot construct the filter graph.
  Numeric validation also applies to disabled stages. Actual CLI rejection
  cases exit 2 before native startup or destination creation.
- Accurate reconstructs a profile from its typed schema and identity before
  accepting its graph. Exact schema keys, preset/name/version/mode, experimental
  and customization flags and filter equality are checked. The selected stream,
  channel conversion and deterministic prechain remain identical between passes.
- AC-041: Original Raw/Zoom are still the defaults with frozen filter text/order.
  Gentle and cleaning overrides are rejected for Zoom. Fast remains one render;
  Accurate retains held-stream final measurement and all warning/fallback rules.
  IO, launcher, export policy, owned publication and reporting rollback are unchanged.
- Reports add `presetExperimental`, `presetCustomized` and `settings.cleaning`.
  The base preset identity is separate from overrides; exact graph/build and typed
  effective settings identify custom output. Zoom cleaning is null. Redacted
  exports omit the new cleaning/candidate fields. Application 2.3 and schema 1
  are unchanged; Gentle is `gentle`/`0.1.0`, Original `original`/`1.0.0`.
- AC-042: the [candidate record](WAC-M2-03-listening.md) documents the exact
  Original/Gentle settings, unavailable cleared corpus and pending words,
  consonants, breaths, voice character and artifact checks. The acceptance is
  of the unavailable-review record, **not a performed or approved listening review**.

## Local validation

Active Windows machine; PowerShell 5.1.26100.9444 and 7.6.5; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0; existing FFmpeg/ffprobe 9.0.2.
No tool download, machine-security change or persistent configuration change.

Final combined Targeted: **323 Pester passed per shell**, zero failed/skipped.
Final Full: **866 Pester and 61 Python passed per shell**, one Python symlink-
privilege skip, zero failures. Parser (30 files), static safety and plan checks
pass. The 161 analyzer advisories remain non-gating and are retained in the PS7
Full log; no suppression was added. All 44 maintained code hashes stayed stable
through final Targeted and Full. Get-Help shows the preset/options and five
examples correctly in both shells. Exact commands/exits/log and source hashes:
[manifest](WAC-M2-03-source.json), [PS5.1 Full](WAC-M2-03-full-ps51.txt),
[PS7 Full](WAC-M2-03-full-ps7.txt), [help](WAC-M2-03-help.json).

## Real FFmpeg checks

[Gentle/custom matrix](WAC-M2-03-gentle-cleaning.json): **16/16 application cases
and 4/4 independent Fast references pass**, all eight PS5.1/en-US versus
PS7/de-DE decoded-PCM pairs match. Covers Gentle Fast/Accurate, mono/stereo,
explicit downmix, selected second stream, PCM16/24, disabled cleaning stages,
numeric bounds and fractional settings. Actual native arguments are captured
in ignored disposable application copies by a reviewed wrapper that delegates
to the unchanged native helper. Captured graphs, effective settings, held final
input, output format and independent published-file measurements all agree.

Expected warnings in both shells:

| Case | Final LUFS / dBTP | Actual type | Compliance / result |
| --- | --- | --- | --- |
| Gentle Accurate stereo downmix | -13.0 / -1.5 | dynamic | OUT_OF_TOLERANCE / WARNING 7 |
| Gentle Accurate lower-bound mono | -12.3 / -1.5 | dynamic | PASSED, normalization fallback / WARNING 7 |

Other matrix cases exit 0. A valid export is never mistaken for target compliance.
These independent file checks use the same FFmpeg meter; calibration against
another meter and speech quality remain unverified.

[Original preservation](WAC-M2-03-original-preservation.json): **20/20 application
cases and 10/10 frozen references pass** with exact decoded PCM equality at zero
lag on the same build/settings, covering both modes, mono/stereo, PCM16/24,
silence and short input. The reused harness retains its originating WAC-M2-01
identifier; its fresh command, output location and source hashes establish this
M2-03 invocation. No historical evidence was edited.

Media tested main SHA256 `ba14baa4f74cabb73831e817e4aef959fb05f542d5a184e462c1acdf4e368b60`. After media, exactly
two comment-based help sentences were clarified (Original Raw qualifier and
Zoom rejects nonempty options). Reversing only those byte replacements reproduces
the tested media source hash: **all parameters, helper bodies and runtime code
are identical**. Final Targeted, Full and Get-Help pin final main SHA256
`65023091c1452cd23c1c36a2b43ef31f8ae84bc1d0b1026f36a74e41c804de30`. This is a scoped provenance distinction,
not a claim that media ran again on the later help text.

## Corrections and preliminary results

- Read-only review found case-duplicate effective keys could collapse during
  reconstruction, and altered customization flags could mislabel a profile.
  Exact schema keys and base-settings/customization consistency now reject both;
  dedicated final regressions pass.
- Initial combined gates passed 312 per shell on the earlier 189-case cleaning
  suite. These logs remain labeled initial and are superseded by final 323 gates.
- The expanded PS5.1 focused suite initially had 193 passes / 7 diagnostic-
  assertion failures: Write-Error wrapped the word Preflight across lines in long
  temporary paths. All child exits were already 2. Only the test normalizes
  diagnostic whitespace; final Cleaning 200/200 and combined gates pass in both
  shells. [Preliminary PS5.1 log](WAC-M2-03-cleaning-preliminary-ps51.txt) and
  [PS7 log](WAC-M2-03-cleaning-preliminary-ps7.txt) are retained with source hashes.
- One first Fast smoke processed its single case/reference correctly but its
  harness exited 1 because runtime source changed during the run. It was a
  scoped investigation, never counted as acceptance. Final unfiltered matrix
  reports stable sources, fixtures and capture copies.

## Limits and delivery

No speech listening, default-sound promotion, full >4 GB render, actual disk
exhaustion, long-file/memory stress or running-render Ctrl+C certification.
Original Raw's approximately 25 ms delay is preserved; optional candidates
have different stateful stages and need separate timing/listening review for
preview. Capture remains in memory; capacity is not reserved; reports are not
multi-file atomic or guaranteed durable through power loss. Early failures
remain console-only. Audio/raw reports stay ignored; shared artifacts were
reviewed for personal paths, credentials and private recordings.

Commit/push the feature checkpoint and verify clean local/upstream/live branch
and draft PR #3 equality. The exact post-push SHA belongs in PR/final response,
avoiding a self-referential manifest commit. No CI workflow/checks exist. No
merge, release, settings change or deployment is included. **Next: WAC-M2-04 —
Add safe excerpt preview and level-matched comparison.**
