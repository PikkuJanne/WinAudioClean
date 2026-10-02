# Next model: WAC-M3-02

**M3-01 is complete. Start only WAC-M3-02: Support multiple dropped files through
the existing launcher.** Read AGENTS, STATUS, DECISIONS, TASKS, SYNC_PROTOCOL,
tasks/WAC-M3-02, DATA_FORMATS, AUDIO_CONTRACT/NATIVE_PROCESS_CONTRACT and the
M3-01 evidence/source/settings matrix/focused preliminary+final records.
Preserve canonical history, especially M1-02 policy/resumption and honest
M2/M3 failures/limits. Do not change the source-only original checkout.

## Synchronize the current checkpoint

Use maintained WinAudioClean-governance, `codex/wac-m3-settings`, exact effective
fetch/push origin `https://github.com/PikkuJanne/WinAudioClean.git`. M3 began at
`32f6188461d9f7c11857e390d1145985665dd0dd` (M2-05); inspect live M3 branch/new draft for its actual completed SHA.
Run inspect, authenticated fetch --prune, sync-check, validate-plan and next.
Only M3-02 should be ready. Process-only gh credentials are available; never print
or persist them. Verify live draft/head/CI separately; no CI workflows/checks
currently exist. The completion SHA belongs in PR/final response, not itself.

Reuse the suitable current M3 milestone branch after fresh verification; do not
create a duplicate draft/worktree needlessly. M3 draft is stacked on M2#3, itself
on unmerged M1#2/M0. Do not merge to unlock work. Feature commits/pushes/drafts
are authorized; main/merge/releases/settings/security/deployment/default promotion
still require exact owner authorization. Do not force-push/reset/clean/stash.

## Preserve the new settings contract

- Default ApplicationData\WinAudioClean\settings.json; optional Settings sibling
  loads only for present saved file/explicit SettingsPath/management. Dot-source
  imports remain IO-only and read no preferences. Normal runs never autosave.
- Version1 root schemaVersion/settings, nine existing typed optional choices;
  whole file validates before bound CLI > saved > built-ins. Explicit false
  switches and empty CleaningOptions override saved values; dictionary replacement
  is whole, not key merging. Saving expands resolved preferences but persists
  cleaning overrides rather than the base profile. No input/tool/action/ranges
  or NonInteractive preference. Unsupported versions fail; Ignore/Reset recover.
- Show/Save/Reset have no input/media-process/prompt/audio work. Save/Reset exclusive;
  Reset rejects choices and atomically writes an empty version1 settings object.
  Display includes origins and expanded selected cleaning/graph, or mode-not-
  selected reason. Saved mode/index resolve their unattended omissions.
- Settings uses strict bounded UTF8/JSON, exact keys, duplicate rejection,
  typed finite allowlist, held native READ/WRITE/DELETE writer, Flush(true),
  atomic rename and owned cleanup. Ordinary/reparse/reader-hardlink limits,
  late foreign target/locked/interrupted saves are tested; no power-loss proof.

## M3-02 scope and launcher seams

BAT bytes remain M2 unchanged. Extend ordered multi-file forwarding through the
existing launcher, choosing mode once; retain the single-drop, menu, cancel,
unattended and exit-before-pause routes. Current inputPath remains positional0
and a single string. Inspect real CMD quoting/limits: do not assume naive %* or
-File array passing is safe. Verify spaces/Unicode/brackets/%/!/ampersands/
apostrophes/parentheses, invalid-item aggregate results, long/many paths and
double-click no-input guidance. Use a safe structured handoff only as required.
Folder/manifest fallback must be actionable, with no truncation or shell eval.
Reconcile saved mode/destination/index choices with selecting once; tests must
isolate SettingsPath or deliberately Ignore saved settings, not write user prefs.
No replacement GUI/server, sound retune or later milestone implementation.

## Audio and gate continuity

Main's pre-existing helper region, IO/Preview/BAT are frozen from M2. Original
original/1.0.0 stays built-in with legacy literals/implicit nr; Gentle0.1.0 is
experimental Raw-only, Zoom rejects nonempty cleaning/Gentle. Application2.3,
report1, Fast default and Accurate repeated prechain/held final meter/warnings
remain. Preserve PCM16/24/mono/RF64, ownership guards, explicit bounded preview,
comparison attenuation, selected-origin/clock bounds and no implicit playback.
Positive integrated/threshold values fail, rather than UNMEASURABLE. Preserve
M2 raw latency/seek and same-input/build reproduction limits. Listening and
default promotion remain pending; numeric/synthetic acceptance supplies no approval.

M3-01 final focus: 123 Settings +80 EntryPoints per shell; Full: 1141 Pester +62
Python discovered per shell (61 execute, one privilege skip). Parser/static
pass (34 files, 197 advisories); code
stable during each scope. EntryPoints captured before two unselected Settings
test-only corrections; retain exact per-scope hashes. Initial PS5.1 junction
cleanup failure122/123 is preserved; final123/123 both pass. Original20/20 and
settings 68/68 real invocations pass with 18 exact
saved/CLI PCM pairs and both decimal cultures. Use existing pinned modules and
FFmpeg9.0.2; no download or security change. Strip inherited PSMODULEPATH from
Python children. Focus smallest relevant checks, freeze code, then required Full
per shell. Record exact commands/exits/hashes/versions/scopes and honest skips.

Inherited listening/calibration/>4GB/disk exhaustion/active Ctrl+C/long-file
memory/codec-seek limits remain. Update canonical state/evidence/handoff,
stage/review/commit/push explicitly and verify clean upstream/live/draft equality.
Stop after M3-02; no merge/release/promotion/deployment.
