# WAC-M0-03 — synthetic audio baseline

Date: 2026-10-02. Engineering result: **PASS, AC-007 through AC-009**.
Human speech listening: **PENDING**. No cleared corpus was supplied.

Starting checkpoint: `7291ce86535e9c689befbdb60563ed9eb4b1b2a6` on
`codex/wac-m0-handoff`. Before edits, origin inspection, fetch and live sync
passed; the clean local tree, upstream, live branch and open draft PR #1 matched.
Both effective origin URLs target `https://github.com/PikkuJanne/WinAudioClean.git`.
The source-only starting folder was preserved; work used the established Git checkout.

## Changes and source identity

- `tools/characterize_filters.py` reuses all five existing deterministic fixtures,
  captures 20 renders per run and records final-file metrics and hashes.
- `tests/test_characterize_filters.py` adds eight focused development-tool tests.
- `tests/WinAudioClean.Helpers.Tests.ps1` adds two explicit BASELINE comparisons.
- `tests/README.md`, `tests/fixtures/README.md`, reports and the listening checklist
  describe reproduction, scope and outstanding human review.
- Task/acceptance records and restart instructions carry this checkpoint forward.

`WAC-M0-03-source.json` identifies the actual tested bytes. `WinAudioClean.ps1`,
`.bat`, `BASELINE.json` and the synthetic generator are unchanged from the starting
commit. The `reviewed_commit` inside the generated reports is the historical
baseline anchor, not the current test source revision. No filter, encoder or
runtime dependency changed in the application.

## Tools and preparation

Active machine: Windows NT 10.0.26300.0, AMD64; PowerShell 7.6.5;
Windows PowerShell 5.1.26100.9444; Python 3.14.6; Pester 5.7.1;
PSScriptAnalyzer 1.24.0. Python and test modules remain development-only.

FFmpeg/ffprobe were absent from PATH and checked installation locations. A portable
Gyan essentials build was downloaded only into ignored `.wac-local/ffmpeg-setup/`.
[FFmpeg's download page](https://ffmpeg.org/download.html) links to the
[Gyan build provider](https://www.gyan.dev/ffmpeg/builds/). The downloaded ZIP was
verified against the provider's published SHA256 before extraction/execution.
The first PowerShell transfer was interrupted because it was slow; a separate
curl transfer completed and passed verification. No unverified archive was used.

Observed build: **9.0.2-essentials_build-www.gyan.dev**, GCC 16.2.0.
`WAC-M0-03-download.json` records the download/checksum URLs and archive identity:
`60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba`.
Both run reports retain full version/configuration/library text, binary SHA256s
and successful `-version` command exits. Required filters were queried and present.
No global installation, PATH change or third-party redistribution was performed.

## Commands and results

All commands below ran from the repository root. Each exited **0**. Logs use
`<repo>` instead of the local checkout path; audio and raw logs remain ignored.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Helpers.Tests.ps1
python -X utf8 -m unittest discover -s docs/codex/winaudioclean/tests -p test_characterize_filters.py -v
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 docs/codex/winaudioclean/tools/characterize_filters.py --output .wac-local/WAC-M0-03/run-1 --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
python -X utf8 docs/codex/winaudioclean/tools/characterize_filters.py --output .wac-local/WAC-M0-03/run-2 --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
Get-FileHash .wac-local/WAC-M0-03/run-1/characterization.json,.wac-local/WAC-M0-03/run-2/characterization.json -Algorithm SHA256
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

| Check | Observed result | Evidence |
| --- | --- | --- |
| AC-007, targeted helpers | 13 Pester passed; both built chains exactly match BASELINE values/order and independent literals | `WAC-M0-03-targeted.txt` |
| Measurement parsing/safety | 8 passed: input-vs-output metrics, separate analysis graphs, nulls/reasons, missing/malformed/ambiguous data failures, refusal to overwrite, bounded no-shell commands, native failure | `WAC-M0-03-characterizer-tests.txt` |
| AC-008, characterization twice | 20 successful renders, 25 probes, 40 discarded measurement passes and 2 tool-version calls per run | `WAC-M0-03-run-1.json`, `WAC-M0-03-run-2.json` |
| Repeat comparison | Full report bytes equal; all five fixture pairs and 20 output pairs rehashed against records; no differences | `WAC-M0-03-comparison.json` |
| Full, PS7 and PS5.1 | 29 Pester passed in each shell; 61 Python tests passed and 1 symlink-privilege skip in each | `WAC-M0-03-full-ps7.txt`, `WAC-M0-03-full-ps51.txt` |

Both Full runs passed parser/static/plan gates. They report 49 analyzer advisories,
one more than M0-02: `PSUseDeclaredVarsMoreThanAssignments` for the new `$baseline`
variable shared between Pester setup and tests. Inspection confirmed the tests
consume it. Existing Raw/Zoom variables have the same scope-related advisory;
no rule is suppressed. No processing or test failure required a product fix.

## Actual audio findings

Both complete report SHA256s:
`a187eee1935ab3448eae4a9c8fce78fa050646ba0959a401fb6edd900509e153`.
Exact binary/build identity, fixture hashes, output hashes, metrics and commands
match across independently generated runs. This is same-build repeatability only.

| Property | Legacy unspecified WAV | Explicit comparison WAV |
| --- | --- | --- |
| Sample rate, all five fixtures/both modes | 192,000 Hz | 48,000 Hz |
| Container / codec / depth | WAV / pcm_s16le / 16-bit | WAV / pcm_s16le / 16-bit |
| Channels | Input mono/stereo count preserved | Input mono/stereo count preserved |
| Duration | Input duration preserved; maximum reported difference 0 s | Same |

Thus the 192 kHz behavior was reproduced on this Windows build. It agrees with
[FFmpeg's loudnorm description](https://ffmpeg.org/ffmpeg-filters.html#loudnorm),
which describes dynamic-mode upsampling and explicit output-rate selection.
The 48 kHz variants are experimental comparison files; application export behavior
has not changed. Their hashes differ from legacy exports as expected.

Final-file astats sample peak/RMS are measured separately from loudnorm, so its
resampling cannot change those sample measurements. Loudness/true peak/range/
threshold use `input_*` values from a second analysis of the final WAV, with its
render discarded. No extra normalization is applied to saved outputs.

The three nonsilent fixtures longer than 0.2 s measured -12.13 to -11.95 LUFS.
These are observations, not a compliance or speech-quality acceptance test.
Silence has null integrated loudness, true peak, sample peak and RMS with explicit
nonfinite reasons. The 0.2 s fixture has null integrated loudness but measurable
peaks/RMS. Finite range/threshold values retained for these cases are FFmpeg's
reported diagnostics, not evidence of meaningful programme loudness.

Duration preservation does not prove impulse alignment or channel isolation.
Full-size exports, speech quality and listening are unrun. The Full runner repeats
the existing controlled launcher checks; this matrix itself calls FFmpeg directly.

## AC-009 — privacy and listening

`WAC-M0-03-listening.md` contains the owner-supplied corpus and review checklist.
It records no admitted clips, no listening results and no default-sound approval.
`git check-ignore -v` confirmed hypothetical listening clips under `.wac-local/`
and `artifacts/local/`, actual generated WAVs and portable binaries are ignored.
`git ls-files -- .wac-local artifacts/local` returned no tracked files.

Staged names, statistics and diffs were inspected: exactly 20 intended text/code
files, no audio/binaries/archives, private recordings, identifying local paths,
credentials, raw user logs or unrelated edits. `git diff --cached --check` passed
with the repository's CRLF handling; all 12 tested source hashes still matched.
`git diff --exit-code` showed no unstaged changes. The final evidence paragraph
was then staged and checked again. AC-009 passes privacy handling; listening
itself remains pending.

After marking M0-03 done, these commands both exited 0:

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
```

The validator preserved 30 tasks, 90 acceptance cases and 20 improvement groups.
Only WAC-M0-04 was ready, with no blocker or approval needed for that task.

## Delivery and next task

The task checkpoint must be committed/pushed on `codex/wac-m0-handoff`, then live
HEAD and draft PR #1 verified. The resulting SHA is recorded in the PR/final
response to avoid putting a commit's own future SHA inside itself.

Next: **WAC-M0-04 in a fresh thread**, baseline gate and continuation checkpoint.
Read STATUS, NEXT_MODEL_START_HERE, this evidence and its task brief. Listening
remains explicitly pending; it does not block this mechanics/privacy task.
