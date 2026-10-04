# WAC-M2-04 evidence — bounded preview and separate comparison

Date: 2026-10-02. Started from clean, live-synchronized `cabd6cdd8a537d23ac50e2db006f84193fa0cd59` on
`codex/wac-m2-audio`, matching open draft PR #3. Effective fetch/push origin:
`https://github.com/PikkuJanne/WinAudioClean.git`. The PR remains stacked on
unmerged M1. The source-only original folder was preserved.

## Implemented acceptance

- AC-043: explicit `-Preview` accepts invariant start/duration strings. Defaults
  are 0/45 seconds; only the omitted duration clips to remaining selected audio.
  Explicit duration must fit and be positive through 60 seconds. Requested
  positions round to 48 kHz samples; zero-frame ranges fail. Start/middle/end,
  fractional and very short fixtures are covered. Every asset requires exactly
  the requested output frame count; no hidden padding is applied.
- Up to five seconds of pre/post context feed the selected profile. Original
  and Processed trim matching positions after the selected channel policy and
  48 kHz resampling. Accurate measures/repeats only that context window. It
  does not establish full-recording loudness or full-render equivalence.
- Selected-track origins are probed through the pinned source. Absolute
  `-seek_timestamp 1` seeking adds the stream origin to the relative window
  start. WAV without timestamps uses sample zero. Negative/missing non-WAV
  origins and unsupported/coarse timing fail closed. Container timestamp
  precision limits the source crop: metadata declares its resolution and
  sample uncertainty, bounded by 10 ms. The independent frame-slice comparison
  records any observed offset within that bound rather than claiming universal
  source-sample exactness. Encoded frame counts and matched intervals remain
  exact; the processed reference adds no further unexplained shift.
- AC-044: four assets preserve the unmodified Original/Processed excerpts and
  separate CompareOriginal/CompareProcessed copies. Gain is attenuation only,
  with common target `min(Ia, Ib, Ia-TPa-1.7, Ib-TPb-1.7)`. Comparison copies
  contain gain/resampling only. Held encoded WAVs are measured before and after
  matching. Finite comparison peaks must be <= -1.5 dBTP; available integrated
  values must differ <=0.2 LU (1e-9 numerical comparison guard). Peak failure
  rolls back owned assets. Short/silent/undefined matching stays explicitly
  unavailable, with WARNING/7 and no invented integrated target.
- AC-045: the main route returns after preview and never invokes full rendering
  or playback. Native argument capture proves source renders/analysis are
  bounded; meters and gain copies consume rewound held streams. Four owned
  transactions share pinned source/destination identities and an aggregate
  capacity estimate. All assets are validated before no-replace publication.
  Cancellation and failures remove only owned partials/published objects;
  foreign collision/sentinel files and source/settings stay unchanged. After
  all four valid assets are published, report failure retains them with
  WARNING/7 and explicit incomplete reporting. Probes use 15-second deadlines;
  render/analysis/meter deadlines have a two-minute minimum.

Preview reports use a separate schema-1 `reportType: preview`, JSON/text names
and range/context/timing/graph/gain/stage metadata. They do not append a normal
full-render summary. Main imports the optional Preview sibling only for Preview;
ordinary export/import still requires only the original IO sibling. IO and BAT
hashes equal M2-03. Default Original graphs, Fast full-render arguments and
full-file Accurate behavior are preserved.

## Exact final validation

Final code/test hashes, commands, exits, tool versions and artifact hashes are in
[the source manifest](WAC-M2-04-source.json). Gates pin the same unchanged runtime
and executed test source as the final media matrix. The separate media harness
assertion correction and its exact scope are recorded below.
Pester5.7.1/PSScriptAnalyzer1.24.0 and existing pinned
FFmpeg/ffprobe9.0.2 were used locally; no automatic dependency install occurred.

- Final Targeted: **322 Pester per shell**, zero failures/skips,
  including Preview, loudness/runtime, held native input, preset, transaction
  and report IO suites. Actual array arguments select the files.
- Full: **1015 Pester and 61 Python per shell**, zero failures; one
  Python symlink-privilege skip per shell. Parser: 32 files. Static
  gate passes with 179 unsuppressed advisories. Full includes original
  entry/launcher/import/file/report/native regressions. Plan validation passes.
- [Preview matrix](WAC-M2-04-preview.json): **24/24 application cases**
  in PS5.1/en-US and PS7/de-DE, with all four direct references per case and
  independently decoded source slices. All 12 locale pairs produce
  identical decoded PCM for all four assets. Original/Gentle/custom cleaning,
  Fast/Accurate, mono/stereo/downmix, PCM16/24 and small RF64 are covered.
  Measurements use a separate FFmpeg invocation on published files, the same
  meter implementation rather than independently calibrated equipment.
- [Original preservation](WAC-M2-04-original-preservation.json): **20/20 cases
  and 10/10 frozen references**, exact decoded PCM equality at zero lag. The
  reused harness retains its original task identifier; its new invocation and
  source hashes identify this M2-04 run. Existing evidence is preserved.
- [Latency reference](WAC-M2-04-latency.json): pinned-build synthetic markers
  correlate Original/Gentle Raw at +1200 samples (25 ms), tested Zoom and
  all-cleaning-disabled Raw at zero. No latency compensation is applied.
  Custom graphs/builds are not universally calibrated.

## Corrections and preliminary scope

Initial helper tests caught `Math.Min(0,doubleGain)` choosing an integer
overload and rounding fractional attenuation, including a required -0.4 dB
peak guard. Double zero fixes all gain clamps; final regressions pass. A long
sample offset likewise required an Int64 zero in Math.Max; the supported 1e9
duration ceiling is tested without allocating or decoding long media.

The initial 68-unit summary and later preliminary helper/CLI logs remain
separate. A test-construction mistake temporarily placed orchestration cases
inside a CLI driver here-string, so the 113-test preliminary passes did not
execute those fault cases. The block was moved; final gates explicitly execute
every fault/cancel case. The earlier 126-case focus predates the last timing
precision refinement; final Targeted/Full and media supersede it. No omitted
test is counted as executed.

The special media investigation exposed a synthetic hot square with integrated
loudness above the existing parser domain and a small Matroska source seek
offset from millisecond PTS rounding. The fixture amplitude was reduced while
retaining a true-peak guard requirement; the parser was not broadened. The
timing refinement reports/validates timestamp uncertainty. Preliminary scopes,
failed checks, commands and source hashes remain labeled; only the final
unfiltered stable-source matrix establishes acceptance.

The inherited parser rejects integrated measurements above 0 LUFS; the first
hot fixture measured +0.51 LUFS and failed closed. The final peak-guard case
does not establish support for those positive integrated source values. Keep
this known preview limitation for the next objective audio gate. The tick-plus-
one-sample seek bound is an application acceptance policy tested on these
fixtures, not a universal guarantee for every codec/decoder. See the primary
[FFmpeg stream timing definitions](https://ffmpeg.org/doxygen/9.0/structAVStream.html)
and [seek option definitions](https://ffmpeg.org/ffmpeg.html#Main-options).

The first unfiltered preview matrix had 22 passes and two silence assertion
failures: the application correctly reported null/silence while its harness
expected finite LRA=0. Three harness assertion lines now classify unavailable
I/LRA and TP; a two-host scoped correction passes and the final unfiltered
matrix supersedes the initial run. Removing exactly those three lines
reproduces the captured earlier harness hash. This file is not executed by
Targeted/Full. Runtime, Pester/native fixtures and Python governance sources
remain identical; the Full capture wrapper reports a broad source-change
exit1 while both shell gates exit0. The manifest records that provenance scope
instead of claiming every captured file stayed unchanged. The corrected
media matrix pins the final harness with stable sources. No cumulative test
result is replaced or inferred.

## Limits and delivery

No permission-cleared speech corpus was supplied; listening is unperformed and
Gentle remains opt-in/experimental, with no default-sound approval. Preview
cannot promise full-render equivalence, eliminate stateful boundary effects,
or remove container timestamp uncertainty. No full >4 GB output, actual disk
exhaustion, running-render Ctrl+C, long-file/memory stress or independent meter
calibration is certified. Capture remains in memory; capacity is not reserved;
multi-file publication/reports are not atomic or power-loss durable. Failed
preview requests use console diagnostics. Generated audio/raw reports remain
ignored and shared evidence is sanitized.

Commit/push this feature checkpoint, verify clean local/upstream/live branch
and draft PR #3 equality, and record the exact post-push SHA in PR/final response.
No CI workflow/checks exist. No merge/release/security change/deployment is
included. **Next: WAC-M2-05 — Audio gate with honest listening status.**
