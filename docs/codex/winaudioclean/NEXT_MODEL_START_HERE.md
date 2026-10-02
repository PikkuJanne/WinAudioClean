# Next model: resume WAC-M1-02

**M1-02 is implemented, but validation is blocked. Do not start M1-03.**
Read AGENTS.md, STATUS.md, DECISIONS.md, TASKS.yaml, SYNC_PROTOCOL.md,
tasks/WAC-M1-02.md, NATIVE_PROCESS_CONTRACT.md and evidence/WAC-M1-02.md.
Preserve prior evidence and the source-only starting folder; work in the
established WinAudioClean-governance Git checkout.

## Inspect and synchronize

Branch: codex/wac-m1-reliability.
Exact effective fetch/push target: https://github.com/PikkuJanne/WinAudioClean.git.
The task started from accepted M1-01 at
116380c0f6f722e5ff116b6aafc348c0fabdd9e5. Inspect the live branch for this
checkpoint's later commit; do not assume the starting SHA is still HEAD.

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
git fetch --prune origin
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
gh pr view 2 --repo PikkuJanne/WinAudioClean --json url,isDraft,state,baseRefName,headRefName,headRefOid,statusCheckRollup
```

The plan should show M1-02 blocked and no ready task. PR #2 remains the M1 draft,
based on codex/wac-m0-handoff while M0 draft PR #1 is unmerged. Recheck live state.
Do not merge to unlock work. Feature commits/pushes and draft PR updates are
authorized; merges/releases/security-policy changes are not.

## Exact blocker and recovery

The Full gate ran 227 Pester cases in each shell: PS5.1 167 passed/60 failed,
PS7 220 passed/7 failed. Windows Code Integrity events match all 51 native
startup failures (44 launcher copies, seven reporting copies). The other 16
PS5.1 failures came from a test-side nested JSON array; that assignment is now
corrected and failure assertions include stdout/stderr. Final Quick parse/static
checks pass; corrected integration has not been rerun.

The unsigned C# fixture uses the installed Framework compiler and writes only
test artifacts. Earlier targeted runs passed, but this does not establish that
machine policy now permits it. No security settings were changed. Do not rerun
compilation/copying to seek an allowed binary, disable policy, sign with an
unapproved certificate, add exclusions, or turn these failures into skips.
Resume both Full gates only when fixture execution has been accepted through
the machine's normal administration process. Keep failures explicit if blocked.

All 23 wrapper cases passed in both failed Full runs, including simultaneous
512 KiB stdout/stderr, exact arguments, stdin EOF, timeouts/reaping and rejection
of NUL/overlong commands. Four real FFmpeg Raw/Zoom application runs across
PS5.1/PS7 also passed. Those establish AC-018; AC-016/017 remain blocked until
the cumulative validation is complete. Evidence separates tested runtime hashes
from post-Full test corrections.

## Current implementation

The original .ps1/.bat entry points remain. A direct ProcessStartInfo wrapper
quotes individual Windows arguments, captures stdout/stderr concurrently,
closes stdin, disposes owned streams/process and preserves failures. FFmpeg uses
-nostdin. Rendering has no fixed total deadline; finite caller timeouts stop the
owned child only. Stream-close/cleanup waits are bounded; capture remains in
memory and has no long-recording stress result.

Application exits: 0 success/report complete, 2 input/config, 3 dependency/start,
4 native/capture/cleanup, 7 reporting incomplete after native success, 130 mode
menu cancellation. Reporting preserves a primary native failure and output.
Exit 0 does not independently validate media output.

The launcher pins system Windows PowerShell, preserves status before pause and
has /unattended Raw|Zoom using WAC_LAUNCH_INPUT/WAC_LAUNCH_OUTPUT_DIRECTORY from
PowerShell environment values. Percent/exclamation positional CMD paths have a
documented fallback; already-expanded CMD input cannot be reconstructed.

Filters, encoding and legacy -y/timestamp collision behavior are unchanged.
M1-03 probes/streams/external references, M1-04 transactional output/collisions,
M1-05 encoding and M3-01 saved settings remain separate tasks.

## Validation commands and local tools

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
# Run Full only after the fixture-policy blocker is resolved.
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

Pester 5.7.1 and PSScriptAnalyzer 1.24.0 are in ignored .wac-local/Modules.
Bypass is process-only. Native fixture tests require the installed Windows
Framework C# compiler; no runner downloads tools. Existing FFmpeg/ffprobe 9.0.2:
.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin.
Use explicit paths. M1-02 real-process outputs are in ignored
.wac-local/WAC-M1-02/real-process; preserve them. The M1-01 interactive folder
contains a zero-byte ffmpeg.exe sentinel and is unsuitable for audio checks.

Final Quick checks pass; independent Python suite: 61 passed, one Windows
symlink-privilege skip. Parser/static gates pass with 53 analyzer advisories.
No speech listening, channel isolation, impulse alignment, long recording or
>4 GB export validation. No CI exists yet.

After both Full gates pass, reconcile TASKS/ACCEPTANCE/evidence/status/handoff,
review/stage intended files, commit/push the feature branch, and verify local,
live branch and PR heads. Only then unlock **WAC-M1-03**.
