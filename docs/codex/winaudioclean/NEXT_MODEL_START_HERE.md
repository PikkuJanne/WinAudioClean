# Next model: WAC-M1-05

**M1-04 is complete. Start only WAC-M1-05: explicit PCM output, channel policy
and large-file behavior.** Read AGENTS.md, STATUS.md, DECISIONS.md, TASKS.yaml,
SYNC_PROTOCOL.md, tasks/WAC-M1-05.md, AUDIO_CONTRACT.md,
NATIVE_PROCESS_CONTRACT.md and evidence/WAC-M1-04.md. Preserve earlier evidence.

## Inspect and synchronize

Use the established WinAudioClean-governance checkout on
`codex/wac-m1-reliability`. Preserve the source-only starting folder. Exact
fetch/push origin: https://github.com/PikkuJanne/WinAudioClean.git.
M1-04 started from `e2b5443b9aee11bb9be5d41750cdac66c808c7bd`; derive its completion
SHA from the live branch/PR instead of assuming the starting SHA is current.

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
git fetch --prune origin
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
gh pr view 2 --repo PikkuJanne/WinAudioClean --json url,isDraft,state,baseRefName,headRefName,headRefOid,statusCheckRollup
```

Only M1-05 should be ready. Reuse draft PR #2, stacked on `codex/wac-m0-handoff`
while draft PR #1 is unmerged. Recheck live base/CI state. Feature commits/pushes
and draft PR updates are authorized; merges/releases/deployment remain separate.

## Narrow next task

- Add explicit 48 kHz/16-bit PCM WAV default and optional 24-bit PCM; document this
  intentional format change. Preserve the exact filters and Raw/Zoom sound.
- Preserve selected channels/layout; mono conversion must be explicit. Establish
  unsupported-layout policy and test distinct stereo signals/known impulses.
- Estimate destination/temp space with headroom. Offer/test RF64 beyond RIFF's
  size limit or fail early with guidance. Never truncate or split silently.
- Cover AC-025/026/027, including 44.1/48 kHz mono/stereo in both modes/bit depths,
  timing/channel alignment, size boundaries, low-space injection and a small RF64
  header fixture. Do not claim full >4 GB stress unless actually run.

## Current seams and preservation requirements

Main script defines helpers and dot-sources required sibling `WinAudioClean.IO.ps1`.
Both import without runtime work. IO native declarations compile lazily. Copy
both files into test/app sandboxes and distribution folders.

`Get-WacAudioStreams` returns DurationSeconds plus validated index/codec/channels/
rate. Direct stream duration wins; Matroska per-stream DURATION minus start_time
is the fallback. Container duration is excluded. Missing timing fails 4 before
render. Inspections retain 15-second deadlines; rendering has no total deadline.

`New-WacOutputTransaction` pins the input and destination, reserves CreateNew
`.wac-<GUID>.partial`, and provides canonical InputPath/TempPath/FinalPath.
FFmpeg arguments include explicit `-f wav`; `-y` only fills the owned partial.
Output probing occurs before `Freeze-WacOutputTransaction` takes the read/delete
handle. `Assert-WacWaveOutput` validates that same file's RIFF/chunks/PCM samples,
channels and timing (10 ms PCM/100 ms compressed). `Publish-WacOutputTransaction`
renames by held handle with replacement disabled. Close removes only owned files;
foreign replacements and crash leftovers survive. Preserve these guarantees when
extending the validator to RF64 or changing encoding. No release/reopen rename.

Report guards use write access/no delete sharing; PS5 Add-Content is incompatible
with a read/write guard, and metadata-only handles do not prevent replacement.
Directory pins use GENERIC_READ/no delete sharing. Report writes are still within
the source-lock lifetime. Code 5 means output failure; 7 means published audio
with incomplete reporting. Native failures keep their own codes/diagnostics.

The existing output encoder is unspecified and produced 192 kHz PCM16 in real
tests. RIFF PCM8/16/24/32/extensible validation is supported; RF64 is rejected.
Do not confuse the current structural validator with the next encoding policy.
File-only protocols/demuxers, explicit stream mapping, dependency precedence,
literal paths, menu handling and `.bat` exit propagation remain unchanged.

## Tests and tools

Final Full: **398 Pester passed per shell**, zero failures/skips; 61 Python passed
and one symlink-privilege skip per shell. 22 PowerShell files parse; 79 non-gating
analyzer advisories. Real output harness: 30/30, 32 app invocations; stable hashes.
Transaction 27/27, Validation 29/29. See the evidence for commands and limitations.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Validation.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

Fresh shells; pinned modules under ignored `.wac-local/Modules`. Python wrappers
must omit inherited PSMODULEPATH in each PS5 child so the host initializes its
defaults; do not change persistent environment/security settings. Preserve M1-02
application-control history and authorized resumption. Policy rejection is a
failed check, not permission to bypass machine security.

Existing FFmpeg 9.0.2 lives under
`.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin`.
`scripts/Test-OutputTransactions.py` validates real publication/failure behavior;
`scripts/Test-MediaPreflight.py` retains the earlier track/network policy matrix.
Both are optional development tooling with explicit local executables. Runtime
needs no Python/downloads/uploads. Generated media/raw logs stay ignored.

After M1-05, reconcile task/acceptance/evidence/status/handoff, stage/review
intended files, commit/push, verify local/live/PR heads, and stop before M1-06.
