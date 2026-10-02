# Next model: WAC-M2-01

**M1 is complete. Start only WAC-M2-01: Correct audio claims and name the
Original preset.** Read AGENTS.md, STATUS.md, DECISIONS.md, TASKS.yaml,
SYNC_PROTOCOL.md, tasks/WAC-M2-01.md, AUDIO_CONTRACT.md, SOURCES.md,
DATA_FORMATS.md and evidence/WAC-M1-07.md plus its review/source manifest.
Preserve earlier evidence and the M1-02 policy/resumption history.

## Inspect and synchronize before branching

Use the established WinAudioClean-governance checkout. Preserve the original
source-only starting folder. M1 is on `codex/wac-m1-reliability`, with exact
fetch/push origin `https://github.com/PikkuJanne/WinAudioClean.git`.
M1-07 started at `ca82376ae60560541fb0985c7c565c7872e3bba4`; derive its completion
SHA from the live branch and draft PR #2, not from that starting SHA.

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
git fetch --prune origin
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
gh pr view 2 --repo PikkuJanne/WinAudioClean --json url,isDraft,state,baseRefName,headRefName,headRefOid,statusCheckRollup
```

Only M2-01 should be ready. If default noninteractive Git authentication fails,
use the already authenticated GitHub CLI as a process-only credential helper,
without displaying credentials or changing repository/global configuration:

```powershell
$env:GIT_CONFIG_COUNT = '2'
$env:GIT_CONFIG_KEY_0 = 'credential.helper'
$env:GIT_CONFIG_VALUE_0 = ''
$env:GIT_CONFIG_KEY_1 = 'credential.helper'
$env:GIT_CONFIG_VALUE_1 = '!gh auth git-credential'
```

Inspect any existing process-level Git configuration before replacing it.
After clean live equality, inspect whether `codex/wac-m2-audio` already exists.
Create it from the verified M1 tip only if absent; preserve unrelated work.
If PR #2 is still unmerged, use a new M2 draft PR stacked on
`codex/wac-m1-reliability`. If an approved merge happened, reconcile actual
history first. Reuse any matching M2 draft rather than duplicate it. Do not
merge M1 to unlock the next task. PR #2 currently remains stacked on
`codex/wac-m0-handoff`; PR #1 is also open/unmerged. No CI workflow exists yet.

## Narrow next task

- Audit README, comment-based help and other shipped claims against the
  authoritative sources in SOURCES.md. Correct LUFS/RMS, dynaudnorm `p`,
  afftdn `nf`/`nr` and gate attenuation descriptions. Remove universal-broadcast,
  exact-result, Audition-equivalence and percentage-success claims. Treat
  -12 LUFS as the chosen target, not a guarantee or universal standard.
- Name and version the Original/Legacy preset while preserving the exact
  baseline Raw/Zoom filter strings and order. Keep the current entry points
  and choices. Report preset ID/version separately from application version;
  current report fields are null/not_versioned and need their scoped update.
- Reconcile AC-034/035/036. Compare synthetic output on the same FFmpeg build
  and encoding settings; do not confuse the M1-05 encoding change with filter
  retuning. Use targeted tests, then the required gate; record actual listening
  status. Do not begin Accurate loudness, new presets, previews or saved settings.
- Update task/acceptance evidence and handoff, commit/push the feature branch,
  verify clean local/live/PR equality and stop after M2-01.

## Preserved M1 contracts

- Exact Original filters, default 48 kHz PCM16, optional PCM24, standard
  mono/stereo preservation, explicit equal-weight mono prechain and explicit
  RF64. Audio metadata/chapters are omitted. Preserve the legacy Raw marker
  delay (~25 ms); no default-sound promotion or delay correction is approved.
- `WinAudioClean.ps1` and required `WinAudioClean.IO.ps1` import without runtime
  work. Native declarations are lazy. Keep both siblings in test/distribution
  copies; retain PS5.1 compatibility and `.bat` single-file behavior.
- Pin source/destination identities, CreateNew owned partial, validate complete
  PCM and selected-track timing, then rename the held object without replacing
  anything. Cleanup only owned identities. Preserve foreign replacements and
  crash leftovers. Never replace this with a release/reopen move.
- Finish owned-output cleanup before reporting. Version 1 JSON/text and retained
  summary distinguish processing/reporting status, recording/render time,
  requested/validated format and unmeasured loudness. Report writes use exclusive
  ownership, summary append/rollback and explicit flush. Keep UTF-8/BOM/ANSI
  compatibility and human-label control-character escaping.
- Explicit diagnostic export is local, typed and no-overwrite; it omits free-form
  strings, accepts version 1 objects up to 16 MiB, and warns to review. No upload.
- Exits: 0 complete, 2 input/settings, 3 dependency/start, 4 probe/native/capture,
  5 output/space/cleanup, 7 published audio with incomplete reporting, 130 menu
  cancel. Early pre-render errors stay console-only. Keep native outcomes.
- Main/README CRLF and IO LF must remain intact. Avoid cosmetic runtime edits.

## Tests and known limits

M1-07: Quick 332/332 and Targeted 158/158 in each shell. Full 543 Pester passed
with zero failures/skips plus 61 Python passed and one symlink-privilege skip
per shell. Parser 25 files; 112 visible non-gating analyzer advisories. Fresh
real transactions 30/30 and reporting 24/24 passed. All 37 source identities
match M1-06; M1-07 changes documentation/evidence only. See tests/README.md for
commands and evidence/WAC-M1-07-source.json for exact source/command/log hashes.

Windows NT 10.0.26300, PS5.1.26100.9444 / PS7.6.5, Python 3.14.6;
Pester 5.7.1 and PSScriptAnalyzer 1.24.0 already exist under ignored
`.wac-local/Modules`. Fresh PS5 children omit inherited PSModulePath. Existing
FFmpeg/ffprobe 9.0.2 binaries are under
`.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin`.

No speech listening, full >4 GB render, actual volume exhaustion, long-file/
memory stress or running-render Ctrl+C validation is claimed. Native capture
remains in memory. Reports lack multi-file atomicity/power-loss guarantees;
capacity is not reserved against competing writers. Default batch handoff tests
use a controlled application stub, not a fresh Explorer interactive render.
