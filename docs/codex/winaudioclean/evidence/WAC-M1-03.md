# WAC-M1-03 — Dependencies and explicit audio stream mapping

Date: 2026-10-02. Engineering status: **accepted** (AC-019/020/021).
Next: **WAC-M1-04**, after fresh remote synchronization verification.

## Source and scope

Started clean at `ec27fb9d5ecc7dd07033d889987ac153d65eb373` on
`codex/wac-m1-reliability`. Effective origin fetch/push:
`https://github.com/PikkuJanne/WinAudioClean.git`. Local/upstream/live branch and
draft PR #2 matched. Draft PR #1 remained open; #2 remains stacked on
`codex/wac-m0-handoff`. The source-only starting folder is preserved.

Runtime SHA256 tested in both final Full gates and the final real-media run:
`4d2300a74698b272cb03469e98efb73d7ff1db86a15c24c6dd95292638add3ea`.
`WAC-M1-03-source.json` records maintained runtime/development source hashes,
commands, exits and sanitized log hashes. Source bytes stayed unchanged during
testing. Git text normalization can change line endings in blobs.

Changed files/areas:

- `WinAudioClean.ps1`: explicit tool paths, deterministic discovery, version/
  selected-filter inspection, bounded strict JSON probing, interactive/explicit
  audio choice, absolute mapping, shared input policy and report metadata.
- `README.md`: dependency/track usage, supported formats and exit behavior.
- `tests/WinAudioClean.Media.Tests.ps1`: 99 focused tests. Existing Helpers,
  EntryPoints, Launcher, Reporting and import tests exercise the additional
  inspection calls; the native fixture uses independent inspection controls.
- `scripts/Test-MediaPreflight.py`: optional standard-library synthetic Windows
  validation harness. It is not an application dependency.
- Test documentation, D22/process contract, task/acceptance state, status,
  next-model handoff and sanitized evidence.

The launcher, exact Raw/Zoom filter strings and render encoding remain unchanged.
Legacy overwrite/collision behavior is still assigned to M1-04.

## Behavior and acceptance

| Case | Result and evidence |
| --- | --- |
| AC-019 | pass: explicit > sibling > PATH lookup; invalid explicit/present sibling fails without fallback. FFprobe's sibling is the selected FFmpeg directory. Unit and actual PATH/application-adjacency cases pass. Wrong banners, absent tools, invalid executables, missing exact selected-mode filters and inspection failures reject. Two/three filter-flag layouts work. No download path is introduced. |
| AC-020 | pass: automatic single track; explicit zero/sparse indexes; interactive retries/Q/EOF; unattended ambiguity failure. Actual video index 0 plus 440 Hz mono at 1 and 880 Hz stereo at 2 produces the expected selected audio in both modes/shells. Non-audio/missing indexes exit 2; video-only exits 4 before cleaning. |
| AC-021 | pass: malformed/wrong-shape/oversized JSON, missing/duplicate/invalid indexes and invalid essential audio fields reject. Actual malformed/nonzero probes and version/filter/probe deadlines/reaping pass. Ordinary/renamed HLS/concat references fail in probing and rendering, with zero media requests at a controlled HTTP listener. |

See D22 for the contract. Each inspection has a 15-second process deadline plus
bounded cleanup; rendering retains its unlimited total duration. The 1 MiB
JSON/256-stream checks run after capture, not as limits on child or reader memory.
Both tools allow only `file` and documented ordinary-media demuxers. This policy
is not a decoder sandbox or physical-offline-storage guarantee; filesystem
redirection retains its semantics.

## Local gates actually run

Windows NT 10.0.26300.0; PS5.1.26100.9444 and PS7.6.5; Pester 5.7.1;
PSScriptAnalyzer 1.24.0; Python 3.14.6; existing FFmpeg/ffprobe 9.0.2.
Pinned local modules and the installed Framework compiler were reused.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Media.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Media.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

| Final gate | Pester passed / failed / skipped | Python passed / skipped | Exit |
| --- | --- | --- | ---: |
| Full Windows PowerShell 5.1 | 326 / 0 / 0 | 61 / 1 | 0 |
| Full PowerShell 7 | 326 / 0 / 0 | 61 / 1 | 0 |

Both gates parse all 19 PowerShell files and pass static/plan checks. All 67
non-gating analyzer advisories are visible in the PS7 log; no suppression or gate
weakening was introduced. The only Python skip is the existing Windows symlink
privilege case. Final logs: `WAC-M1-03-full-ps51.txt` and
`WAC-M1-03-full-ps7.txt`. Media passed 99/99 per shell; corrected native entry
regressions passed 38/38 per shell before the cumulative gate.

Development corrections addressed observed issues: FFmpeg 9.0.2 has two filter
flag columns; the fixture initially omitted filter descriptions; a report test
used the wrong existing label; PS7 distinguishes absent and empty environment
variables in fixture setup; and the harness initially reused an output folder
name for two playlist extensions. These were corrected before final gates.
Initial migration failures were captured in tool output; corrected entry rerun
logs and incomplete harness runs remain under `.wac-local`. Failed attempts are
not represented as passing runs.

The first Python-driven PS5.1 Full invocation exited 1 before tests because
inherited PS7 PSMODULEPATH prevented `Import-PowerShellDataFile` autoloading.
The identical command/source passed after the wrapper omitted PSMODULEPATH in
that child, letting Windows PowerShell initialize its normal defaults. This
changed no machine/user module paths, product/test source or security settings.
The failure is retained in `WAC-M1-03-full-ps51-environment-failure.txt` and the
manifest. The simultaneous PS7 run passed and was retained without rerunning.

## Real media and console evidence

```powershell
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-MediaPreflight.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
```

Final run: `.wac-local/WAC-M1-03/20261002T115537198468Z`, **32/32 passed,
harness exit 0**. `WAC-M1-03-real-media.json` records exact argument arrays,
tool/source/input/output hashes, metadata, exits and independent frequency
measurements. Eight Raw/Zoom outputs retain expected mono/stereo counts and
440/880 Hz signals, with expected-to-other tone power ratios above 100. They are
readable three-second 192 kHz PCM16 WAVs. No explicit encoding was introduced;
inputs stayed unchanged. This is synthetic evidence, not speech listening.

Eight application playlist probes and eight direct render-helper checks reject
HLS/concat and renamed variants. The loopback listener's `/control` request
succeeded; no `/segment.ts` or `/track.wav` request arrived. Direct render
diagnostics reject ordinary HLS and both concat variants as formats outside the
allowlist. This build rejects renamed HLS earlier during format detection
because its extension/MIME type is not recognized as HLS.

Actual terminals used final source and the synthetic two-track fixture. PS5.1
received empty Enter, `wrong`, then `q`; it reprompted twice, exited 130 and left
no WAV/report. PS7 received video index `0`, then audio index `2`; it reprompted,
mapped track 2 and exited 0 with one WAV/report. Host versions and application
exits were printed by the wrapper. Sanitized text: `WAC-M1-03-console.txt`.
Raw transcripts remain ignored. EOF/host errors also have helper tests;
running-render cancellation is not certified.

## Limits, review and delivery

No speech listening, channel-isolation/impulse alignment, long-recording/memory
stress or >4 GB tests were performed. Final-media validation, alias prevention,
collision safety and no-clobber publication remain M1-04. Explicit encoding
remains M1-05. No CI workflow exists. Earlier Smart App Control failures and
owner-authorized M1-02 resumption remain preserved; no security setting changed.

Independent runtime/README review found no actionable issue. Evidence review
corrected the renamed-HLS diagnostic and initial-log retention wording. Staged
review passed for 26 intended text files, with matching tested source/evidence
hashes, no unstaged work, and no detected private paths or secrets. The plan retains 30 tasks,
90 cases and 20 improvement groups; only M1-03 and AC-019/020/021 advance.
The only next ready task is M1-04. Live branch/PR synchronization remains a
separate check; the exact completion SHA belongs in the PR/final response
rather than inside its own commit. No merge, release or deployment.
