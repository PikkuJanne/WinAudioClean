# Next model starts here

**M0 is complete. Next: WAC-M1-01 in a fresh thread.**
Validate local input, mode and destination before prompting. Do only that task,
then checkpoint; do not implement all of M1 in one session.

## Locate and verify the checkout

The supplied source-only folder has no `.git`. The established separate checkout
is named `WinAudioClean-governance`, a sibling of that folder on the active
machine. If the current folder has no Git metadata, inspect its parent directory
for that checkout. Verify its root and effective origin; the name is a discovery
hint, not proof of repository identity. No prior chat is needed.

Read AGENTS.md, STATUS.md, DECISIONS.md (including D19), SYNC_PROTOCOL.md,
TASKS.yaml and tasks/WAC-M1-01.md. Use evidence/WAC-M0-04.md for the reconciled
gate; older evidence need only be reopened if relevant source has drifted.

M0 branch: `codex/wac-m0-handoff`; exact fetch/push target:
`https://github.com/PikkuJanne/WinAudioClean.git`.
[Draft PR #1](https://github.com/PikkuJanne/WinAudioClean/pull/1) targets main.
The M0-03 completion checkpoint was `e1bd07b96dc23ab7d84ac0f236ca599a866c73a3`.
M0-04's exact completion SHA is in the live branch/PR and final response; derive
it afresh. Preserve local changes. Inspect origin/branch/worktree, fetch and run:

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
```

Only WAC-M1-01 should be ready. Do not proceed on a source-push or sync failure.
Inspect live PR/CI state separately. Once M0 delivery is verified, create
`codex/wac-m1-reliability` from its completion tip. If PR #1 is still unmerged,
use `codex/wac-m0-handoff` as the new draft PR base. If an approved merge occurred,
inspect the resulting history and choose the matching base without rewriting it.

## WAC-M1-01 implementation boundary

- Validate literal existing/readable filesystem files, reject directories,
  URLs, missing/zero-byte inputs and unsupported forms before native work.
- Resolve/create-check a writable destination before prompting. Keep Music as
  default. Keep UNC support/policy explicit; network shares are not offline disks.
- Invalid/empty choices must not fall back to Zoom. Reprompt interactively and
  provide cancellation. Missing input should give useful usage; unattended
  failure must not prompt. Add only the minimal parameter seam needed for this
  task; saved settings and the broader parameter set belong to M3-01.
- Preserve `.ps1 -inputPath`, `.bat`, PS5.1 compatibility and exact Raw/Zoom filter
  strings. Update legacy defect characterizations only when the corresponding
  behavior is fixed. Do not fold in M1-02's process wrapper or later export work.

Acceptance: AC-013 literal filename matrix, AC-014 validation order/failure,
AC-015 menu/cancel/noninteractive behavior. Read the brief for exact cases.
Complete media probing belongs to M1-03; do not claim preflight proves decodability.

## Current evidence and limits

M0-04 Quick passed 13 Pester; Full in PS5.1 and PS7 passed 29 Pester plus 61 Python
with one symlink-privilege skip each. Parser/static/plan gates pass; 49 analyzer
advisories are visible with no suppression. Source/command/environment identities
and sanitized logs are under evidence/WAC-M0-04-*.

M0-03 has two identical same-build reports for 20 synthetic Raw/Zoom variants.
Legacy WAVs measured 192 kHz PCM16; explicit comparisons measured 48 kHz PCM16.
The application still uses unspecified encoding. Channels/durations match;
this does not establish channel isolation, impulse alignment or speech quality.

Listening remains pending with no cleared corpus or default-sound approval.
Real audio through the launcher, full special-character forwarding, fault
handling, long recordings and >4 GB exports remain unverified. Controlled entry
points/process doubles and direct FFmpeg rendering are separate evidence.
No CI workflow exists yet. These limits do not block the next reliability task.

## Local tools and test commands

Pinned Pester 5.7.1 and PSScriptAnalyzer 1.24.0 are already under
`.wac-local/Modules`. Runners never install dependencies. Use tests/README.md.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Tag EntryPoint
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

Bypass is process-only. Existing checksum-verified FFmpeg/ffprobe 9.0.2 essentials
binaries are at `.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin`;
use explicit executable paths. Generated audio, binaries, private clips and raw
logs stay ignored. The old M0-03 run directories exist; a justified new
characterization run must use a new output directory name.

If the default Git credential helper stalls, the existing GitHub CLI helper can
be selected for a single command with `-c credential.helper= -c
'credential.helper=!gh auth git-credential'`; do not change persistent Git config.

After WAC-M1-01, update task/acceptance/status/evidence/handoff, stage intended
files, review, commit/push and verify local/live/PR heads. Feature work and draft
PRs are already authorized; pending owner decisions are recorded in D19.
The next task after accepted, synchronized M1-01 will be **WAC-M1-02**, separately.
