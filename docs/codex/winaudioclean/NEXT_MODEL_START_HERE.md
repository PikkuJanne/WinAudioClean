# Next model: WAC-M1-03

**M1-02 is complete. Start only WAC-M1-03: dependency resolution and audio
stream probing/mapping.** Read AGENTS.md, STATUS.md, DECISIONS.md, TASKS.yaml,
SYNC_PROTOCOL.md, tasks/WAC-M1-03.md, NATIVE_PROCESS_CONTRACT.md and
evidence/WAC-M1-02-resume.md. Preserve earlier evidence; no governance reimport
or repeat of the M0 audit is needed.

## Inspect and synchronize

Work in the established WinAudioClean-governance Git checkout. The source-only
starting folder is preserved. Branch: codex/wac-m1-reliability.
Exact effective fetch/push target: https://github.com/PikkuJanne/WinAudioClean.git.

The successful M1-02 resumption tested unchanged source at
0d02cf48dcede1196024039294e9316f4624b50a. The subsequent completion commit adds
evidence/governance only; derive its SHA from the live branch/PR and verify it
afresh rather than assuming the tested starting SHA remains HEAD.

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
git fetch --prune origin
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
gh pr view 2 --repo PikkuJanne/WinAudioClean --json url,isDraft,state,baseRefName,headRefName,headRefOid,statusCheckRollup
```

Only M1-03 should be ready; no task should be blocked. Reuse draft PR #2, stacked
on codex/wac-m0-handoff while M0 draft PR #1 is unmerged. Recheck the live base/CI
state and reconcile an approved merge if one occurred. Do not merge to unlock
work. Feature commits/pushes and draft PR updates remain authorized.

## Narrow next task

- Retain sibling and PATH FFmpeg resolution; add explicit-path precedence and
  ffprobe discovery, with useful missing/incompatible/filter diagnostics.
- Record resolved executable paths and versions without automatic downloads.
- Probe JSON audio streams and map the selected absolute stream index. Prompt
  on interactive ambiguity; require an explicit choice unattended.
- Bound probes and reject malformed/nonzero/timed-out results. Test local
  playlists referencing external URLs and scope supported protocols.
- Preserve exact Raw/Zoom filter strings, the original entry points and PS5.1.
  Transactional outputs/collisions are M1-04; explicit encoding is M1-05.

## Existing native and launcher behavior

A direct ProcessStartInfo wrapper quotes individual Windows arguments, drains
stdout/stderr concurrently, closes stdin and explicitly disposes streams/process.
FFmpeg uses -nostdin. Rendering has no fixed total deadline; finite caller
timeouts stop the owned child only. Capture stays in memory; no memory stress
claim has been made.

Exits: 0 native success/report complete, 2 input/config, 3 dependency/start,
4 native/capture/cleanup, 7 reporting incomplete after native success, 130 menu
cancellation. Reporting preserves a primary native failure and audio. Exit 0
does not independently validate the rendered media.

The batch launcher uses system Windows PowerShell, preserves status across
pause and supports /unattended Raw|Zoom via WAC_LAUNCH_INPUT and
WAC_LAUNCH_OUTPUT_DIRECTORY set in PowerShell. Positional CMD percent/exclamation
paths have a documented fallback; prior expansion cannot be reconstructed.
Filters, encoding and legacy -y/minute timestamp collisions remain unchanged.

## Evidence and tools

Both resumed Full gates passed: **227 Pester tests per shell**, no failures or
skips; **61 Python tests passed and one symlink-privilege skip per shell**, exit 0.
Parser/static/plan gates pass; 18 PowerShell files and 53 visible analyzer
advisories. All 26 source hashes match the blocked checkpoint.

Initial runs were blocked by Smart App Control and included a corrected PS5
JSON-array assertion issue. The owner later reported Smart App Control Off and
authorized rerunning; read-only state was 0 before/after. Codex did not change
security settings. Preserve historical failed logs and policy records. Future
policy rejection remains a real test failure; do not change security settings
or repeatedly rebuild fixtures to evade it.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Native.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

Pester 5.7.1/PSScriptAnalyzer 1.24.0 are under ignored .wac-local/Modules.
Bypass is process-only. Fixture tests use the installed Framework C# compiler.
Runners never download dependencies. Existing FFmpeg/ffprobe 9.0.2:
.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin.
Use explicit paths and keep binaries/generated audio ignored.

Four real FFmpeg application checks from M1-02 remain valid on identical runtime
bytes: Raw/Zoom, both shells, three-second mono 192 kHz PCM16 WAVs/reports,
unchanged inputs. Saved outputs are .wac-local/WAC-M1-02/real-process. M1-01's
interactive folder has a zero-byte ffmpeg.exe sentinel unsuitable for processing.
Human listening, channel isolation, impulse alignment, long recordings, >4 GB
exports and running-render cancellation remain unverified. No CI exists yet.

After M1-03, reconcile its acceptance/evidence/status/handoff, stage/review
intended files, commit/push and verify local/live/PR heads. Stop before M1-04.
