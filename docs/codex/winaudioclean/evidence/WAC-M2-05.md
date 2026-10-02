# WAC-M2-05 evidence — objective audio gate and honest human status

Date: 2026-10-02. Started from clean live-synchronized `ca512d08bdb806d5c1900ecd9b6d8ba0c1e7037d` on
`codex/wac-m2-audio`, matching open draft PR #3. Effective fetch/push origin:
`https://github.com/PikkuJanne/WinAudioClean.git`. The draft remains stacked on
unmerged M1; the source-only original folder is untouched.

## Acceptance and unchanged runtime

AC-046 passes the mandatory mechanics/format checks in the implemented,
documented domain. Main, IO, Preview and BAT bytes equal M2-04: no graph,
default, encoding, runtime/report schema or dependency policy changed. Three
parameterized Loudness test cases now pin the inherited rejection of positive
input/output integrated loudness and positive output threshold before short
input can be called unavailable. The existing input-threshold case remains.
The new Python utility is development-only and optional.

AC-047 passes the integrity audit, **not a listening review**. No permission-
cleared owner speech corpus was supplied; no speech was selected, rendered or
played. Reviewer, consent, playback, per-clip observations and promotion approval
remain pending in [the human-gate record](WAC-M2-05-listening.md). Original is
still default; Gentle is experimental and opt-in. Numeric acceptance supplies
no owner approval of a default-sound change.

AC-048 recreates outputs from actual local report fields on the same retained
synthetic input/build. The accepted content is pinned in
[the source manifest](WAC-M2-05-source.json); its future pushed SHA is recorded
in the PR/final response, without a recursive evidence commit. Source revision,
input/executable hashes are not embedded in ordinary reports; this harness
retains them separately. Prior task/history/evidence records are preserved.

## Exact local gates

- Final Targeted: **523 Pester per shell**, zero failures/skips, selecting
  Preset, Loudness, LoudnessRuntime, NativeInput, Cleaning, Preview and Encoding
  with an actual PowerShell array. The three domain-rejection additions run.
- Final Full: **1018 Pester and 61 Python per shell**, zero failures, one
  Python symlink-privilege skip each. Parser: 32 files. Static gate
  passes with 179 unsuppressed non-gating advisories. Both shell gates
  and both capture wrappers exit 0. All captured code/test hashes, including the
  completed reproduction utility, stay unchanged through both phases. Full does
  not execute the separate media scripts. Post-update plan validation is separate.
- Windows PowerShell5.1.26100.9444, PowerShell7.6.5, Python3.14.6,
  Pester5.7.1, PSScriptAnalyzer1.24.0 and the existing FFmpeg/ffprobe9.0.2 build
  were used. Exact command arrays, exits, versions, source and log hashes are
  recorded in the manifest and linked artifacts. No dependency was installed.

## Fresh unfiltered media matrix

All **116 application cases** pass their documented structural/behavior checks:

| Matrix | App cases | Additional proof |
| --- | ---: | --- |
| [Original](WAC-M2-05-original.json) | 20 | 10 frozen direct references; exact decoded PCM at zero lag |
| [Measured loudness](WAC-M2-05-measured.json) | 16 | Repeated Accurate prechains, actual types, held encoded meters and warning/undefined classifications |
| [Gentle/custom](WAC-M2-05-gentle.json) | 16 | Four Fast references; typed controls, exact stages and locale PCM pairs |
| [Preview](WAC-M2-05-preview.json) | 24 | 96 direct asset references, bounded input, exact frames and 12 locale pairs |
| [Encoding](WAC-M2-05-encoding.json) | 40 | 20 frozen references, channels, 44.1/48k sources, PCM16/24 and small RF64 |

These are unfiltered runs in fresh ignored directories, not sums of partial
investigations. Their legacy harness task IDs identify originating utilities;
fresh commands, directories, source revision and hashes identify this gate.
All fixtures/runtime/harness/capture copies remain unchanged as recorded.
Both hosts use en-US/de-DE where the respective harness declares that scope.

[Derived classifications](WAC-M2-05-classifications.json) audit the same
hashed local reports, without adding renders or counting extra cases. Ordinary
Fast remains NOT_MEASURED, never a loudness-compliance pass. The measured matrix
has four PASSED/0 cases, two PASSED/7 cases with fallback, six
OUT_OF_TOLERANCE/7, two silence/7 and two too_short/7. Gentle has eight
NOT_MEASURED/0, four PASSED/0, two target-miss/7 and two PASSED/7 with fallback.
Preview short/silent matching remains UNMEASURABLE/7, with available true peak
still constrained. Null metrics have fixed reasons; actual normalization type,
known peak precedence and truthful warning outcomes remain distinct from valid
encoded PCM and complete reporting. No promise that every Accurate export
reaches -12 LUFS is made.

## Report-driven reproduction

[Final reproduction](WAC-M2-05-reproduction.json) passes **16/16 reports and
22/22 recreated assets**: eight configurations in both hosts cover
Original Fast/Accurate, Gentle Fast/Accurate, fractional custom cleaning,
selected stereo stream, downmix, PCM16/24, RF64, Accurate silence, Zoom Fast
and a selected-stream Accurate preview with all four assets.

The seed choices only create the initial reports. Replay reads those reports,
independently reconstructs the versioned fixed recipe plus typed effective
cleaning/channel/format settings, reconciles preset/customization flags and
requires exact reported graphs before running direct pinned FFmpeg. Accurate
reanalysis must reproduce recorded measurements, targets, measured parameters,
fallback and observed type. Preview uses the recorded window/sample positions;
comparison copies consume recreated excerpt bytes and verify their gains from
encoded metrics. Every recreated asset has exact decoded PCM, frame count,
format and classified meter equality. Cross-shell/locale PCM also matches.
Reports are hashed before parsing; inputs, reports, assets, source and executable
hashes remain unchanged. Published/report content is never rewritten for replay.

This proves the selected reports on the same input/build. It does not independently
revalidate every range-policy field, guarantee cross-build PCM or claim universal
.NET formatter parity for every highly precise custom value. Reconstructed
literals/graphs fail closed if they differ; independent preview range/alignment
checks remain in Pester and the existing matrix. Meters use the same FFmpeg
implementation, not separately calibrated equipment.

Two scoped smoke failures remain labeled: first missing PCM16 ffprobe
`channel_layout`, then gain subtraction noise `-11.899999999999999` versus the
reported `-11.9` filter. Only the new utility changed: absent one/two-channel
labels use the documented standard layout while conflicts fail; invariant
literal formatting removes binary noise and still checks exact graph equality.
The two failed [initial](WAC-M2-05-reproduction-smoke-initial.json)/
[layout](WAC-M2-05-reproduction-smoke-layout.json) summaries are preliminary,
not acceptance. [Corrected Preview-only smoke](WAC-M2-05-reproduction-preview-correction.json)
passes two reports/eight assets, but only the final unfiltered stable-source
matrix establishes AC-048. Runtime was never changed by these corrections.

## Explicit unresolved limits and human decisions

- Finite positive integrated/threshold loudnorm values remain outside the
  inherited parser domain and fail closed; they are not silence/undefined data.
  Fresh rejection regressions and prior +0.51 LUFS failure are disclosed, not
  evidence of support. Ordinary Fast bypasses this meter. Broader support is
  unresolved; no threshold was relaxed or default sound changed.
- Preview container seek bounds are fixture-tested application policy, capped
  at 10 ms; unsupported origins/coarse clocks fail closed. The shifted Matroska
  middle crop retains the disclosed +8-sample offset inside its 49-sample bound.
  Known approximately25ms Raw delay is preserved; custom graph/build calibration
  and five-second boundary/full-program equivalence remain limited.
- Cleared speech/listening/default promotion, independent meter calibration,
  full >4GB exports, real disk exhaustion, long-file/memory stress and active-
  render Ctrl+C are unverified. Capture is in memory, capacity is not reserved,
  and publication/report sets have no multi-file atomicity/power-loss guarantee.

No merge, release, repository/security setting change or deployment occurs.
After explicit staging/review, commit/push this task and verify clean local,
upstream, live branch and draft PR#3 equality. No CI workflow/checks exist.
**Next: WAC-M3-01 — Add noninteractive parameters and saved settings.**
