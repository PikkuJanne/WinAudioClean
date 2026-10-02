# Next model: WAC-M2-02

**WAC-M2-01 is complete. Start only WAC-M2-02: Add measured loudness without
changing the default fast path.** Read AGENTS.md, STATUS.md, DECISIONS.md,
TASKS.yaml, SYNC_PROTOCOL.md, tasks/WAC-M2-02.md, AUDIO_CONTRACT.md,
DATA_FORMATS.md, SOURCES.md and evidence/WAC-M2-01.md with its source manifest.
Preserve earlier evidence and the M1-02 policy/resumption history.

## Inspect and synchronize

Use the established WinAudioClean-governance checkout on `codex/wac-m2-audio`.
Preserve the original source-only starting folder. Exact effective fetch/push
origin: `https://github.com/PikkuJanne/WinAudioClean.git`. M2-01 started from
verified M1 tip `f1ad9de795b74acef5b932223c38eedfba24cee6`. Find the actual M2
completion SHA through the live branch and matching draft PR.

Run handoff.py inspect, fetch --prune origin, handoff.py sync-check,
validate-plan and next as described in SYNC_PROTOCOL.md. Only M2-02 should be
ready. Inspect live draft PR/CI state and branch head separately. If Git needs
authentication, use the already authenticated GitHub CLI as a process-only
credential helper after inspecting existing process Git settings. Do not
display credentials or change persistent configuration.

Reuse the M2 branch/draft, based on `codex/wac-m1-reliability` while PR #2
is unmerged; PR #2 is stacked on `codex/wac-m0-handoff`. Inspect actual live
history if approved merges occurred. Do not merge to unlock this task.
No CI workflow exists. Feature commits/pushes and draft PR updates are in scope;
merge, main pushes, tags/releases, sound promotion and deployment are not.

## M2-01 implementation to preserve

- Original ID `original`, display `Original`, preset version `1.0.0` covers both
  existing Raw/Zoom choices. Exact baseline filter strings/order stay frozen.
  Application version `2.3` and schema version `1` are separate.
- Selected profile supplies JSON presetId/presetName/presetVersion and null
  presetVersionReason. Text/summary show a PRESET line. Redacted support exports
  still omit identity/version fields; old M1 null/not_versioned reports remain
  valid inputs. No saved settings or new preset selector exists yet.
- README, proper Get-Help and menu wording describe chosen targets honestly.
  Keep success/export validity separate from loudness compliance. Synthetic
  comparisons and real menus are tested; speech listening remains unperformed.
- M1 export defaults remain 48 kHz PCM16; optional PCM24, explicit equal-weight
  stereo-to-mono prechain and RF64. Omit metadata/chapters. Preserve the existing
  Raw delay (~25 ms); do not promote a new default sound.
- Retain PS1/BAT entry points, required IO sibling, import safety, PS5.1 support,
  held source/destination identities, owned partial, complete WAV validation,
  no-replace held-object rename, owned cleanup and serialized report rollback.
  IO and launcher are unchanged by M2-01. Preserve main/README CRLF and IO LF.

## Narrow next scope

Follow M2-02/AC-037 through AC-039: preserve the default single-pass Fast path,
add optional Accurate measurement using the same selected stream/channel policy,
cleaning and dynamic-leveling prechain in both passes. Parse finite measurements
invariantly and map target_offset to offset. Report actual linear/dynamic
fallback. Independently measure the final resampled/quantized file and report
requested versus achieved values; give explicit reasons for unmeasurable input.
Use the declared AUDIO_CONTRACT tolerances and peak precedence; do not claim
out-of-tolerance results compliant. No new cleaning presets or preview yet.

## Local validation and limits

Use tests/README.md. Pester 5.7.1/PSScriptAnalyzer 1.24.0 already exist under
ignored `.wac-local/Modules`. Existing FFmpeg/ffprobe 9.0.2 are under
`.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin`.
When spawning PS5.1 from Python, remove inherited environment keys whose
uppercase name equals PSMODULEPATH. The first M2-01 targeted failure came from
case-sensitive removal against Windows uppercase keys; corrected run passed.

Run focused checks before one required Full per shell. Use fresh ignored output
folders for real-media harnesses, record exact source/commands, update task and
acceptance state plus handoff, push and verify clean local/live/PR equality.
Stop after M2-02. No speech listening, full >4 GB render, actual disk exhaustion,
long-file/memory stress or running-render Ctrl+C is established. Native capture
remains in memory; space is not reserved against competitors; reports have no
multi-file atomicity or power-loss guarantee; early failures stay console-only.
