# Next model starts here

Completed: **WAC-M0-03**, repeatable Windows synthetic audio baseline and private
listening checklist. Next: **WAC-M0-04 in a fresh thread**. Stop at that coherent
gate; do not start M1 in the same thread.

Branch: `codex/wac-m0-handoff`; [draft PR #1](https://github.com/PikkuJanne/WinAudioClean/pull/1)
targets main. Continue from the verified feature-branch tip. The source-only
starting folder has no Git metadata; discover the established separate Git
checkout and verify root, branch, worktree, effective fetch/push origins and live
GitHub/PR heads. The preceding checkpoint was
`7291ce86535e9c689befbdb60563ed9eb4b1b2a6`; M0-03's completion SHA is in the PR/final
response. Derive live sync afresh; preserve local changes.

Read AGENTS.md, STATUS.md, DECISIONS.md, SYNC_PROTOCOL.md, TASKS.yaml,
`tasks/WAC-M0-04.md` and `evidence/WAC-M0-03.md`. Use `tests/README.md` for commands.
Do not reimport old governance or repeat the historical audit without drift.

## Current baseline

- Original .ps1/.bat entry points and all application behavior are unchanged
  from M0-02. The three pure helpers remain safely importable.
- `tools/characterize_filters.py` reuses all five synthetic fixtures for 20
  Raw/Zoom legacy/explicit encoding variants. Reports include exact build and
  binary identities, commands/exits, fixture/output hashes, formats/durations
  and independent final-file astats/loudnorm input measurements.
- Two Windows reports are byte-identical, including all output hashes/metrics.
  Legacy unspecified WAV outputs are 192 kHz PCM16; explicit comparison outputs
  are 48 kHz PCM16. Channels and reported durations match input in all cases.
  Silence/very-short input have null integrated loudness with reasons.
- Current tested source hashes and sanitized evidence are under
  `evidence/WAC-M0-03-*`; AC-007 through AC-009 pass. Listening is **pending**.
- Targeted: 13 Pester passed. Characterizer: 8 unit tests passed. Full on both
  PS5.1 and PS7: 29 Pester passed; 61 Python passed and one symlink-privilege skip.
  49 analyzer advisories are visible, including shared Pester setup variables.
  Parser/static/plan gates passed; no suppressed rules.

## Tools and reproduction

Pinned Pester 5.7.1 and PSScriptAnalyzer 1.24.0 remain checkout-local under
`.wac-local/Modules`. Runners never install tools. Use process-only Bypass for
PS5.1 as documented; persistent policy is unchanged.

FFmpeg/ffprobe are not on PATH. A checksum-verified portable Gyan 9.0.2 essentials
build is under `.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin`.
Use explicit executable arguments. `WAC-M0-03-download.json` records provenance;
run JSON records exact binaries/build. Do not commit binaries or generated WAVs.
The two run folders already exist under `.wac-local/WAC-M0-03/`; future runs must
use new names because the characterizer refuses existing directories.

## M0-04 scope and remaining limits

Reconcile baseline evidence once, resolve actual blockers and record contracts
and pending human decisions. Fresh launcher/PS5.1/PS7 controlled checks already
pass; direct FFmpeg audio characterization is separate. Speech-quality/listening,
impulse alignment, channel isolation, long recordings and >4 GB checks remain
unrun. Use the ready `WAC-M0-03-listening.md` checklist when cleared clips exist.
Default sound is not approved for promotion. Explicit 48 kHz encoding has only
been compared; it is not the application's current export policy.

After the M0-04 gate, update task/acceptance evidence and handoff, stage intended
files, inspect, commit/push and verify local/live/PR heads. The exact next task
then becomes **WAC-M1-01**, in a separate thread after the gate is recoverable.
The GitHub CLI credential helper can be used command-scoped if necessary.
Ordinary feature work is authorized; merge, release and deployment remain separate.
