# WAC-M1-05 — Explicit PCM exports, channels and capacity

Date: 2026-10-02. Engineering status: **accepted** (AC-025/026/027).
Scope: AC-025/026/027. Next task after accepted, synchronized delivery: WAC-M1-06.

## Source and change

Started clean and live-synchronized at `afbf25aa8f935517a2a14b0f5fa655cb8a8c6e7e`
on `codex/wac-m1-reliability`. Exact effective fetch/push origin is
`https://github.com/PikkuJanne/WinAudioClean.git`. Draft PR #2 is stacked on
`codex/wac-m0-handoff`; draft PR #1 is open/unmerged. The source-only starting
folder is preserved. No merge, release, deployment or security-setting change.

Full/real-media tested working-file SHA256:

- `WinAudioClean.ps1`: `45da24151286e57b5a72be8ef9b604894dac789fc29082c9be75bd1ac5463339`.
- `WinAudioClean.IO.ps1`: `146d5aece5a0666d39fd56f025080a4e0fecdcea678e69bd00c6fa5501202621`.

The delivered main script restores the repository's CRLF line endings; its SHA256
is `0efe0d9b8f070c4d80817ffbef9b6cbf00b46bdcaef8aa589a070e60ecd6316f`.
Its normalized bytes exactly equal the Full/real-tested main above; no code changed.
README line endings were also restored. Final Quick passes **300/300 per shell**,
zero failures/skips, on delivery bytes. The manifest retains both source maps,
newline-equivalence evidence and final Quick logs.

The source manifest records maintained runtime/development files and linked
evidence hashes. Working bytes identify the tests; Git can normalize line endings.
The original `.bat` and exact Raw/Zoom profile strings remain unchanged.

Exports now explicitly use 48 kHz signed PCM16; `-BitDepth 24` selects PCM24.
`-Mono` averages stereo left/right before the original filter chain. Standard
mono/stereo layouts are preserved; missing layouts use channel-count inference.
Mismatched/other layouts and multichannel input fail before rendering, including
with `-Mono`. Source metadata/chapters are not copied. This intentional format
change is documented in README, D24 and AUDIO_CONTRACT; it is not a claim of
bit-identical legacy exports or approval of a new sound preset.

Ordinary RIFF is default. The size estimate includes 101 ms timing slack and
1 MiB headers, with free-space reserve of max(64 MiB, ceil(10% of file bytes)).
Only one audio allocation is needed because the partial becomes the final by
rename. GetDiskFreeSpaceExW reads caller-available capacity on the held destination,
including quota effects. Failed/insufficient capacity fails 5; no render begins.
A conservative RIFF estimate above 4,294,967,295 bytes fails with `-Rf64` guidance.
Explicit `-Rf64` forces RF64 even for short output and requires a compatible reader.
No automatic truncation or splitting is introduced.

The held-file validator checks the requested sample rate, codec/bit depth,
channels/layout, container, complete sample count and timing. RF64 support uses
FFmpeg's single-data-chunk form: first 28-byte ds64, empty extra table, mandatory
sentinels and exact 64-bit RIFF/data/frame counts. Malformed, unsupported,
truncated and overflowing headers are rejected before publication. M1-04's
no-replacement handle rename and owned cleanup remain intact.

Changed files: main/IO runtime; Helpers/EntryPoints expectations; new Encoding
suite; extended Validation suite; new Test-OutputEncoding.py development harness;
README/tests README; audio/native contracts, decision/state/handoff and this evidence.
No Python dependency is added to the application.

## Acceptance evidence

| Case | Evidence |
| --- | --- |
| AC-025 | Real 32-case matrix: 44.1/48 kHz mono/stereo inputs, both Raw/Zoom, PCM16 default and PCM24, both Windows shells. ffprobe and PCM headers confirm 48 kHz, requested codec/bit depth and channels; no unintended 192 kHz export. Four extra explicit-mono cases pass. |
| AC-026 | Distinct 440/880 Hz left/right signals, shaped markers, known impulses and boundary silence. All outputs are exactly 6 s; sample payloads match independently rendered frozen-filter references at zero lag. Channel identity and first/last half-second silence pass; residual marker/activity offset is 0 ms. Known Raw filter delay is explained below. |
| AC-027 | All four bit-depth/channel estimates tested at last-safe/first-unsafe RIFF frame boundaries; huge 64-bit estimate, exact headroom and available-space boundary checks. Actual child-app low-space/unavailable-capacity/oversize failures launch no renderer and preserve source/prior exports. Native query follows pinned junction identity. Four real small forced-RF64 app cases plus malformed ds64 validator cases pass. |

### Timing evidence and its limits

The unchanged Raw filters delay measured markers by approximately 25 ms and
activity by approximately 25–30 ms on these fixtures. This is retained behavior,
not an unexplained shift introduced by this task. A separate standalone render
using the exact original chain and unspecified encoding confirms 192 kHz PCM16
with Raw marker offsets 25.005–25.271 ms. The corresponding explicit 48 kHz
reference differs by only 0.00781–0.00812 ms. See `WAC-M1-05-legacy-delay.json`.
The standalone render is not claimed as a historical application invocation.

Zoom marker centroids change slightly under the existing dynamic gain behavior.
Both modes match their independently encoded references exactly at zero lag;
no padding, trimming or filter adjustment hides the measured offsets. Raw's
adeclick can suppress isolated impulses, so impulse values/peaks are recorded
without requiring the transient to survive; shaped markers establish alignment.
The harness reports absolute offsets as well as residual deltas. Its channel-swap
and injected +30 ms shift checks both correctly reject altered signals
(`WAC-M1-05-sensitivity.json`).

## Validation actually run

Windows NT 10.0.26300.0; PS5.1.26100.9444; PS7.6.5; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0; existing FFmpeg/ffprobe 9.0.2.

- Quick PS7: 256 passed at the earlier development point.
- Final Encoding targeted: 48/48 per shell, zero failures/skips, exit 0.
- Final Validation targeted: 70/70 per shell, zero failures/skips, exit 0.
- Corrected entry-point argument subset: 16/16 per shell, zero failures/skips, exit 0.
- Final Full in each shell: **487 Pester passed, zero failures/skips; 61 Python
  passed and one symlink-privilege skip**, runner exits 0. All recorded source
  hashes remain unchanged. Parser: 23 PowerShell files; static/plan pass with 98
  visible non-gating analyzer advisories.
- Final encoding harness: **40/40**, exit 0, unchanged runtime/harness/fixtures.
  This includes 32 matrix, four mono and four small RF64 cases. Real report:
  `WAC-M1-05-real-encoding.json`; its script arguments, child-process argv and source identities are retained.
- Existing transaction harness rerun: **30/30**, 32 application invocations,
  exit 0, stable runtime hashes. MP3/AAC, repeat/concurrent exports, invalid and
  truncated media, simulated encoder/disk failure, rename races and crash/recovery
  pass in both shells under the new 48 kHz policy. Source/prior hashes are unchanged.
  `WAC-M1-05-transaction-regression.json` retains the unmodified harness's historical
  `task: WAC-M1-04` label; this is explicitly its regression rerun during M1-05.

Reproduction from the repository root:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Encoding.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Validation.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-OutputEncoding.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
python -X utf8 scripts/Test-OutputTransactions.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M1-05/transaction-regression-new
```

Use a fresh unused harness output directory. Child wrappers remove inherited
PSMODULEPATH so PS5.1 initializes its own defaults. No persistent environment or
machine-security settings change. Generated audio, tool binaries and raw logs
remain ignored; only sanitized text evidence is committed.

## Development corrections and remaining limits

An early PS5 Encoding test used New-Item Junction with a bracketed target; PS5
interpreted it as a wildcard. Changing that test target to an ordinary path with
spaces restored the fixture; runtime did not change. The first full gate found
old entry-point assertions expecting 20 FFmpeg arguments instead of the new 34;
updated tests also check each explicit encoding argument. Runtime was unchanged.
A first direct PS5 subset invocation omitted the established transient runner
flag and failed module import before discovery; the corrected command passed
without changing persistent policy. The first 40-case audio run passed individual
cases but correctly exited 1 when
runtime line-ending normalization changed source hashes; final acceptance uses
the stable rerun. Development outcomes/hashes are retained separately.

No speech listening, achieved-loudness/true-peak certification, full >4 GB output,
real volume exhaustion, running-render Ctrl+C or long-file/memory stress is
claimed. Available-space checks cannot reserve capacity against concurrent jobs.
Native capture remains in memory. No CI workflow/checks are currently configured.

Independent runtime review found no actionable defect. After engineering
acceptance, stage/review only intended files, commit/push this feature branch,
and verify local/live/PR HEAD equality. Record the resulting SHA in the PR/final
response rather than recursively inserting it into its own commit. Stop before
WAC-M1-06, the versioned and privacy-aware run-report task.
