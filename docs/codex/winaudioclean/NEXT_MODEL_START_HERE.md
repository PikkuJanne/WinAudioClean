# Next model: WAC-M1-04

**M1-03 is complete. Start only WAC-M1-04: transactional, collision-safe output publication.** Read AGENTS.md, STATUS.md, DECISIONS.md, TASKS.yaml, SYNC_PROTOCOL.md, tasks/WAC-M1-04.md, NATIVE_PROCESS_CONTRACT.md and evidence/WAC-M1-03.md. Preserve earlier evidence; no governance reimport is needed.

## Inspect and synchronize

Use the established WinAudioClean-governance checkout, branch `codex/wac-m1-reliability`. The source-only starting folder is preserved. Exact fetch/push origin: https://github.com/PikkuJanne/WinAudioClean.git.

M1-03 started from `ec27fb9d5ecc7dd07033d889987ac153d65eb373`. Derive its completion SHA from the live branch/PR; do not assume the starting SHA remains HEAD.

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
git fetch --prune origin
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
gh pr view 2 --repo PikkuJanne/WinAudioClean --json url,isDraft,state,baseRefName,headRefName,headRefOid,statusCheckRollup
```

Only M1-04 should be ready, with no blocked task. Reuse draft PR #2, stacked on `codex/wac-m0-handoff` while draft PR #1 is unmerged. Recheck live base/CI state; reconcile an approved merge if one occurred. Feature commits/pushes and draft PR updates are authorized. Do not merge to unlock work.

## Narrow next task

- Allocate unique run identifiers and owned temporary WAVs on the destination volume. Prevent source/output aliases and timestamp/concurrency collisions.
- Validate successful output as nonempty, readable audio with plausible timing before publishing. Reuse bounded probing and selected-stream facts.
- Publish with a no-clobber rename. Reject a destination created after name selection. Failures/crashes must not publish normal-looking invalid exports or delete originals/prior files. Remove only run-owned partial files.
- Replace current collision/overwrite characterizations with regressions. Test encoder failure, simulated disk-full, empty/truncated exit-0 output, rename races and crash leftovers per AC-022/023/024.
- Preserve exact filters, entry points, channel selection and PS5.1. Explicit output encoding belongs separately to M1-05.

## Current seams

The single script remains the application; dot-sourcing defines helpers only. D22 describes `Resolve-WacExecutable`, `Get-WacToolVersion`, `Test-WacRequiredFilters`, `Get-WacAudioStreams`, `Select-WacAudioStream` and `Get-WacLocalMediaArguments`.

Probe objects have validated Index/Codec/Channels/SampleRate and optional labels/layout. No duration contract exists yet; M1-04 needs bounded output/timing validation. The 1 MiB JSON limit is checked after native capture and is not a capture-memory bound.

`Get-WacFfmpegArguments` now requires `-AudioStreamIndex` and emits `-map 0:N`. Both tools use file-only protocols and ordinary-media demuxers before `-i`; preserve this policy in output validation. Inspection calls have 15-second process deadlines. Rendering has no fixed total timeout. The native wrapper quotes Windows arguments, closes stdin, concurrently drains stdout/stderr and disposes owned resources. FFmpeg uses `-nostdin`.

Current exits: 0 native success/report complete; 2 input/config/selection; 3 dependency/start; 4 probe/no-audio/native/capture/cleanup; 7 incomplete reporting after native success; 130 menu cancellation. Finalize code 5 for output validation/publication in M1-04, retaining native diagnostics. Reporting failures retain audio and prior processing failures. Early failures use console diagnostics; reports follow render attempts.

The `.bat` is unchanged in M1-03. It preserves status across pause and supports `/unattended Raw|Zoom` with PowerShell-set input/output environment values. Use `.ps1` for explicit dependency paths or unattended track selection. CMD expansion limits, in-memory capture and running-render Ctrl+C limits remain. Legacy `-y`, minute timestamp names and unvalidated final output are defects owned by the next task.

## Tests and tools

Final Full: **326 Pester passed per shell**, zero failures/skips; **61 Python passed and one symlink-privilege skip per shell**, both runner exits 0. Parser/static/plan pass: 19 PowerShell files, 67 visible analyzer advisories. The Media suite contributes 99 cases, including actual PATH/adjacency and native timeout/reaping. Fixture VERSION/FILTERS/PROBE environment controls are independent of render faults.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Media.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

Use fresh shells. When launching PS5.1 through Python from PS7, omit inherited PSMODULEPATH in that child so the host initializes its default module paths. The first M1-03 Full invocation failed before tests on that wrapper environment; unchanged source passed after this process-only correction. Pester 5.7.1/PSScriptAnalyzer 1.24.0 remain under ignored `.wac-local/Modules`. No security settings changed. Preserve earlier M1-02 Smart App Control failure/resumption records; future policy rejection remains a test failure, not a reason to change settings or repeatedly rebuild fixtures for an allowed hash.

Existing FFmpeg/ffprobe 9.0.2: `.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin`. The optional development harness `scripts/Test-MediaPreflight.py` uses explicit tool paths. Final 32/32 run: `.wac-local/WAC-M1-03/20261002T115537198468Z`; sanitized evidence is committed. It checks video+two distinguishable audio tracks, no-audio/selection failures, and ordinary/renamed HLS/concat rejection in probe/render. The listener received one control request and zero media requests. Eight outputs were readable three-second mono/stereo 192 kHz PCM16 WAVs; inputs stayed unchanged. Actual console reprompt/cancel/selection also passed. No speech listening, channel-isolation, long-file or >4 GB evidence is claimed.

Runtime SHA256 tested in both Full gates and the final real harness: `4d2300a74698b272cb03469e98efb73d7ff1db86a15c24c6dd95292638add3ea`. The source manifest identifies working-tree bytes; Git can normalize line endings.

After M1-04, reconcile acceptance/evidence/status/handoff, stage/review intended files, commit/push and verify local/live/PR heads. Stop before M1-05.
