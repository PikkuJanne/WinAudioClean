# WAC-M3-01 evidence — typed local preferences and unattended precedence

Date: 2026-10-02. Started from clean, live-synchronized `32f6188461d9f7c11857e390d1145985665dd0dd` on M2
draft PR#3, then created `codex/wac-m3-settings`. Exact fetch/push origin is
`https://github.com/PikkuJanne/WinAudioClean.git`. The source-only original
folder stays untouched. M3 draft delivery stacks on `codex/wac-m2-audio`;
the exact new commit/live/PR SHA is verified after push and recorded outside itself.

## Implemented acceptance

AC-049 passes explicit bound CLI > saved > built-in precedence for all nine
supported preferences, including default-looking values, false switches and
whole cleaning-dictionary replacement/empty clearing. The schema-1 file stores
only already-supported choices. Show provides origins and the expanded selected
profile; reset atomically writes an empty settings object. Positional input,
main+IO-only installations without saved preferences, imports, menu and launcher
contracts remain covered. Ordinary execution never autosaves.

AC-050 passes actual unattended valid jobs and bounded failures for omitted
mode/ambiguous stream, invalid explicit/saved choices and management misuse.
Saved mode/index resolve their omissions. Management has no input/media-process/menu/
audio side effects. Media startup absence is tested using external fixture PID
markers and a real-media delegating hook installed before the settings route.

AC-051 passes strict bounded UTF-8/JSON/schema/key/type/finite-value checks,
including duplicate decoded keys, wrong integer tokens, inactive cleaning bounds
and whole saved combinations before CLI overrides. Config text never executes
or becomes arbitrary filter arguments. Both decimal cultures retain invariant
JSON/graphs. Held native atomic publication follows Flush(true); injected
interruption, locked target, foreign target appearance and foreign temp access
preserve old/foreign bytes, cleaning only owned temporary files. Directory/
junction paths reject; reset explicitly recovers malformed or unknown versions.

## Exact gates and preliminary correction

- Helper smoke: 9/9 per host, exit0; strict settings helper safety/compatibility
  checks pass with six naming advisories. [Metadata](WAC-M3-01-smoke.json)
  retains exact commands, script/source hashes and scoped development failures.
- Initial Settings targeted: PS5.1 122/123, exit1; PS7 123/123, exit0.
  The sole failure was PS5.1 Remove-Item junction cleanup after rejection and
  target-preservation assertions passed. A test-only nonrecursive Directory.Delete
  correction preserves the target; the late-foreign-target assertion was also
  tightened to require an actual native publication failure. No runtime fix
  followed these runs. [Initial record](WAC-M3-01-settings-initial.json) remains.
- Final Settings targeted: **123/123 per shell**, exit0, no skips;
  [exact commands/source/logs](WAC-M3-01-settings-final.json).
- EntryPoints targeted: **80/80 per shell**, exit0, no skips. Its capture ran
  before the Settings test-only corrections, with unchanged captured source;
  selected EntryPoints/main/IO/BAT bytes equal final Full. Its unselected Settings
  snapshot is retained as captured, rather than mislabeled as the final test file.
- Required Full: **1141 Pester +62 Python discovered per shell**, zero failures;
  61 Python execute and one symlink-privilege case skips each. Parser: 34 files;
  static gate passes with 197 non-gating
  advisories visible (PS7 Full prints them). Both final capture wrappers
  exit0 with code stable during their scopes. Full uses the final corrected test.

Windows PowerShell5.1.26100.9444, PowerShell7.6.5, Python3.14.6, Pester5.7.1,
PSScriptAnalyzer1.24.0 and existing pinned FFmpeg/ffprobe9.0.2 were used; no
installation or security setting changed. Python-spawned shell environments
remove inherited PSMODULEPATH. Exact commands/exits/tools/hashes and scopes are
in [the manifest](WAC-M3-01-source.json) and linked logs. Full does not execute
the separate real-media matrices. Post-update plan validation is separate.

## Fresh synthetic media and preserved audio

[Original regression](WAC-M3-01-original.json) passes **20/20** actual app
renders against ten direct frozen references: Raw/Zoom, mono/stereo,44.1/48k
sources, short/silence and PCM16/24. Decoded PCM matches exactly at zero lag.
The host's default user settings file was absent; this IO-only baseline did not
write it. The harness's originating M2-01 task ID is historical; fresh commands,
paths, current content hashes and source revision identify this run.

[Saved-settings matrix](WAC-M3-01-settings-media.json) passes **68/68**
app invocations in both hosts, comprising 42 renders and
26 management/error cases. 18 of the renders
are independently executed equivalent CLI references; 18 saved/override
comparisons match their decoded PCM. Direct frozen Raw/Zoom references, selected
second-track mapping, saved Accurate, PCM24/mono/RF64, false switch overrides,
  partial/empty cleaning replacement, de-DE/fi-FI, whole-file failures, no-media-process
management/recovery and reset-to-Original are covered with exact frames/format
and source/settings/tool preservation. Every run names an isolated SettingsPath.

The ignored copy inserts a delegating native capture wrapper after the import
guard and before support/settings initialization. Capture code/copy/harness and
product hashes are retained; captured processes delegate the same native helper.
It changes no processing recipe. Classify Fast as NOT_MEASURED and preserve
Accurate warning7/fallback/compliance outcomes; structural success does not
promise all loudness targets. Main's entire existing helper region is unchanged,
as are IO, Preview and BAT. Application2.3/report1 and preset versions stay fixed.

## Limits and delivery

Settings durability is complete-file atomic publication, not power-loss/hardware
fault durability or concurrent conflict merging. Strict ordinary storage paths
and reader hardlink restrictions are documented. No arbitrary-target/rate knobs,
batch/GUI, uploads or user recordings were introduced. Validation used only
isolated preferences and did not write the user's own settings file.
Speech listening/default promotion remains pending under prior evidence;
positive-LUFS domain, codec-seek and manual/stress limits remain inherited.
All earlier canonical rows/history/evidence, including M1-02 policy/resumption
and M2 preliminary failures, are preserved.

Feature checkpoint/push/draft are authorized; no main push, merge, release,
deployment or security change. Verify clean local/upstream/live/new draft equality
and live CI separately after push. Only **WAC-M3-02** is next; stop after M3-01.
