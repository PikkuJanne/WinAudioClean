# Next model starts here

**Completed: WAC-M1-01. Next: WAC-M1-02 in a fresh thread.**
Harden native process execution, exit codes and diagnostics. Do only that task,
then checkpoint; do not implement the rest of M1 in the same session.

## Locate and verify the checkout

The supplied source-only folder has no Git metadata. The established separate
checkout is named WinAudioClean-governance, a sibling on the active machine.
Inspect that sibling when needed; its name is a discovery hint, not proof of
repository identity. Preserve local changes and verify live state.

Read AGENTS.md, STATUS.md, DECISIONS.md (D19/D20), SYNC_PROTOCOL.md, TASKS.yaml,
tasks/WAC-M1-02.md and NATIVE_PROCESS_CONTRACT.md. Read evidence/WAC-M1-01.md for
the latest tests and limits; reopen older records only when relevant source drift
or the new task requires it. Do not reimport governance or repeat the M0 audit.

Continue branch codex/wac-m1-reliability. Effective fetch/push target:
https://github.com/PikkuJanne/WinAudioClean.git.
M1 started at M0 completion 329852555170c5e58be3db92c18634b5341eb138.
Derive M1-01's completion SHA from the live branch/PR and verify it afresh.
Inspect branch/root/worktree/origin, fetch, and run:

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
gh pr list --repo PikkuJanne/WinAudioClean --head codex/wac-m1-reliability --state all
```

Only WAC-M1-02 should be ready. Reuse the M1 draft PR. It is stacked on
codex/wac-m0-handoff while M0 draft PR #1 remains unmerged. Inspect current
PR/CI state separately and reconcile the base if an approved merge occurred.
Never merge just to unlock the next task. Source-push/sync failure blocks advancement.

## Current implementation and next boundary

- Input/destination paths resolve literally; input must be a readable nonempty
  file and the destination must pass an owned write probe before the mode menu.
  Music is default. UNC/device/provider/URL/ADS forms are rejected; network
  backing through mapped drives or redirected folders is not ruled out.
- Minimal -Mode Raw|Zoom, -OutputDirectory and -NonInteractive parameters exist.
  Empty/invalid choices retry; Q/cancel/EOF cancels. Host switch abbreviations
  and redirected stdin require an explicit mode. Saved settings remain M3-01.
- Preflight/read failure exits 2; menu cancellation exits 130. Finalize the full
  process/dependency/report mapping in M1-02. The launcher still pauses without
  preserving the app status, and the legacy process code can misreport failures.
- M1-02 must capture stdout/stderr concurrently, handle startup/native/report
  failures, add -nostdin, verify exact argv on Windows and preserve launcher
  status. Keep paths as data and do not assume Start-Process string arrays fix
  Windows quoting. Retain PS5.1 and the original entry points.
- Native arguments still use the legacy command including -y; collision-safe
  transactional output is M1-04. Probing/streams/protocol restrictions are M1-03.
  Exact Raw/Zoom filter text and unspecified encoding remain unchanged; the
  explicit 48 kHz export is M1-05, separately from sound changes.

## Tests and tools

Full in PS5.1 and PS7 passed 108 Pester plus 61 Python tests, with one Python
symlink-privilege skip per run. Parser/static/plan gates pass; 49 analyzer
advisories are visible without suppression. Actual console empty/invalid/Q
checks and abbreviated host noninteractive checks pass in both shells.

Pinned Pester 5.7.1 and PSScriptAnalyzer 1.24.0 are checkout-local under
.wac-local/Modules. Runners never install tools. Use tests/README.md:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Tag EntryPoint
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

Bypass is process-only. Existing portable FFmpeg/ffprobe 9.0.2 essentials are at
.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin; use explicit
paths. Retain ignored binaries/generated audio locally. M0-03 run directories
already exist, so any justified new characterization needs a fresh output name.
M1-01's ignored interactive folder has a **zero-byte ffmpeg.exe sentinel**, not a
working dependency; do not use it for audio or count its checks as native processing.

Human speech listening, real audio through the app, full CMD/native filename
forwarding, channel isolation, timing impulses, long recordings and >4 GB exports
remain unverified. No CI exists yet. No default-sound promotion is approved.

If needed, select the existing GitHub CLI credential helper for one command with
`-c credential.helper= -c 'credential.helper=!gh auth git-credential'`; do not
change persistent configuration. After M1-02, update task/acceptance/status/
evidence/handoff, stage intended files, review, commit/push and verify local/live/
PR heads. Feature pushes and draft PR updates remain authorized.
The next task after accepted, synchronized M1-02 is **WAC-M1-03**, separately.
