# Next model starts here

Completed: **WAC-M0-02**, minimal helpers and local PowerShell test runners.
Next: **WAC-M0-03 in a fresh thread**. Branch: `codex/wac-m0-handoff`;
[draft PR #1](https://github.com/PikkuJanne/WinAudioClean/pull/1) targets main.
Continue from the verified feature-branch tip.

The starting folder has no Git metadata. Discover the separate Git checkout
created for WAC-M0-01 and verify its root, branch, worktree, exact fetch/push
origin and live GitHub tip. Do not reimport governance or replace current files
with the old bundle. The previous verified checkpoint was
`d88c4fdcb2ccab445fe8b96636e42cf154138950`; this completion commit's exact SHA is
in the PR/final response. Derive live synchronization afresh.

Read AGENTS.md, STATUS.md, DECISIONS.md, SYNC_PROTOCOL.md, TASKS.yaml and
`tasks/WAC-M0-03.md`. Read `evidence/WAC-M0-02.md` for validation and
`tests/README.md` for setup/runner commands. Do not repeat the historical audit
unless drift or a failing check calls for it.

## What exists

- `WinAudioClean.ps1`: Get-WacProcessingProfile, Get-WacOutputPath and
  Get-WacFfmpegArguments; dot-sourcing returns before application side effects.
  Original entry points, filters and command behavior remain.
- `scripts/Install-DevDependencies.ps1`: explicit, checksum-verified Pester 5.7.1
  and PSScriptAnalyzer 1.24.0 setup under ignored `.wac-local/Modules`.
- `scripts/Invoke-Tests.ps1 -Level Quick|Targeted|Full`: PS5.1/PS7 compatible;
  requires Python 3.10+ for governance checks. Never installs dependencies.
- 27 Pester tests: Quick passed 11/11 and Full 27/27 in both shells. Each Full
  run also passed 53 governance tests, skipping one symlink case for unavailable
  Windows privileges. A deliberate output-name defect failed Quick with three
  failures; exact restoration passed 11/11 in an isolated worktree.
- `evidence/WAC-M0-02-*`: sanitized logs and hashes. AC-004 through AC-006 pass;
  later cases are unrun. No WAC-M0-02 blocker remains.

## Scope for WAC-M0-03

Reuse the synthetic generator; characterize both legacy filters on this Windows
machine with exact FFmpeg build/fixture/output records; prepare the permission-
cleared listening-corpus checklist. FFmpeg/ffprobe are absent from PATH and were
not installed by this task. Missing listening material stays pending. Tests used
controlled preflight and process/log mocks, which do not establish real encoding
or speech quality. The `.bat` pins Windows PowerShell internally even from PS7.

48 analyzer advisories remain visible, mainly legacy console output and test
doubles. Error, compatible-syntax and listed safety findings gate; no rules are
suppressed. Invalid-selection, timestamp-collision and overwrite behavior is
labeled as legacy characterization for M1. Preserve default sound.

After the next coherent task, update task/acceptance evidence and handoff,
stage intended files, inspect, commit/push and verify local/live/PR heads.
The existing GitHub CLI credential helper can be used for the push command if
the default helper stalls. Ordinary feature work is authorized; publication and
merge boundaries remain unchanged.
