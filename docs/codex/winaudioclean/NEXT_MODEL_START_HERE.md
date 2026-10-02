# Next model: WAC-M2-04

**WAC-M2-03 is complete. Start only WAC-M2-04: Add safe excerpt preview and
level-matched comparison.** Read AGENTS.md, STATUS.md, DECISIONS.md, TASKS.yaml,
SYNC_PROTOCOL.md, tasks/WAC-M2-04.md, AUDIO_CONTRACT.md, DATA_FORMATS.md,
NATIVE_PROCESS_CONTRACT.md and evidence/WAC-M2-03.md with source/listening records.
Preserve all earlier evidence and M1-02 policy/resumption history.

## Inspect and synchronize

Use maintained WinAudioClean-governance on `codex/wac-m2-audio`; preserve the
source-only original folder. Exact effective fetch/push origin:
`https://github.com/PikkuJanne/WinAudioClean.git`. M2-03 started from verified
M2-02 SHA `275c6a7fece04b6879f31b4d58a3feb44587e87c`; find its actual completion
SHA through the live branch and draft PR #3.

Run handoff.py inspect, fetch --prune origin, sync-check, validate-plan and next
per SYNC_PROTOCOL.md. Use `--plan-root` for validate-plan/next. Only M2-04 should
be ready. Inspect live PR/CI separately. If Git needs authentication, use the
authenticated GitHub CLI as a process-only credential helper after inspecting
existing process Git settings. Do not print credentials or persist changes.

Reuse M2 draft #3 stacked on M1 while #2 is unmerged; M1 is stacked on M0.
Inspect actual history if approved merges occurred. Do not merge to unlock work.
Feature commits/pushes and draft updates are authorized; main pushes, merge,
tags/releases, default-sound promotion, settings/security changes and deployment
are not. No CI workflow currently exists.

## Contracts to preserve

- Original `original`/`1.0.0` preserves exact Raw/Zoom defaults. Application 2.3,
  report schema 1, mode, channel conversion and output format are separate.
  Fast is default: one render with unchanged arguments, no extra analysis.
- Gentle `gentle`/`0.1.0` is an experimental Raw-only candidate, no listening
  approval: highpass 60, afftdn nf=-35:nr=6, declip/declick/gate off, leveling
  unchanged. Zoom rejects Gentle and nonempty cleaning options.
- Get-WacCleaningSettings builds schema 1 typed effective settings. Four actual
  Boolean toggles; finite numeric scalars HighpassHz20..200, NoiseFloorDb-80..-20,
  NoiseReductionDb0.01..20, GateThresholdDb-80..-20, GateRangeDb-60..0. Reject
  strings/arrays/nulls/unknown keys/case duplicates; validate disabled settings.
  Only the four declared stages toggle; highpass and leveling remain.
- Original nf=-25/nr12 retains implicit nr; legacy gate nominal -45/-25 retains
  rounded 0.0056/0.056. Other gate dB values convert invariantly. Graph/build,
  settings and customization flag are necessary for reproducing custom output.
- Accurate reconstructs profiles from exact typed schema keys and identity,
  rejects graph/meta/customization mismatch, repeats the deterministic prechain
  ending aresample=192000 before exactly one loudnorm. Targets I=-12/TP=-1.5/LRA=7.
  Map target_offset to invariant offset, retain observed type/fallback semantics.
- Final PCM measurement uses binary stdin from the held validation stream before
  publication; retain locks, no-replace rename, stream ownership, bounded process
  cleanup and PS5.1 void casts. No frozen-path reopen or repeated cleaning.
- Final finite compliance is +/-0.5 LU and TP<=-1.3 dBTP, peak precedence; LRA is
  informational. Subsecond I/LRA null with too_short; finite TP stays. Failed
  measurement is FAILED; malformed first pass is fatal. Valid PCM with fallback
  or failed/unavailable/out-of-tolerance checks is WARNING/7. Reporting.complete
  covers writing only; retain primary processing failure codes.
- Reports add presetExperimental/presetCustomized and typed settings.cleaning
  (null for Zoom). Base identity is separate from overrides. Redaction omits
  these fields and free-form identity/commands/diagnostics. Earlier schema1
  reports remain accepted; raw reports/audio are never uploaded automatically.
- Keep PS1/BAT entry points and IO sibling, import safety, PS5.1, stream policy,
  held source/destination identity, owned partial/report cleanup and rollback.
  Main/README remain CRLF/no BOM; IO remains LF. IO/launcher were unchanged.
- 48 kHz PCM16 remains default; optional PCM24/mono/RF64. Preserve Original
  Raw's approximate 25 ms delay; optional candidates have different stateful
  filters, so preview alignment must measure/account for the selected graph.

## Narrow next scope

Follow M2-04/AC-043 through AC-045: explicit validated excerpt start/duration,
useful 30–60 second defaults where possible, pre/post-roll for stateful filters,
matched source/processed intervals and separately level-matched comparison
assets. Disclose boundary/warmup limitations. Preview loudness is not full-file
loudness. Playback is explicit; creating/cancelling preview must not launch a
full recording or affect full-render settings. Keep all writes/cleanup owned
and no-replace, source unchanged. No saved settings, batch or broad rewrite.

## Validation and limits

Use tests/README.md. Pester5.7.1/PSScriptAnalyzer1.24.0 already under ignored
.wac-local/Modules; FFmpeg/ffprobe9.0.2 under
.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin.
When Python spawns PS5.1 remove inherited keys with key.upper()=='PSMODULEPATH'.
Pass multi-path/tag filters through an actual array in -Command, not comma text
through -File. Run focused checks before one required Full per shell.

M2-03 final Targeted:323 and Full:866 Pester +61 Python per shell, one privilege
skip. Gentle/custom:16 cases +4 Fast references; Original:20 +10 frozen references.
All eight Gentle locale pairs match PCM. Keep correct WARNING7 results. Media
predates only two help-text clarifications; byte comparison established identical
parameters/helpers/runtime. Final gates/help pin final hashes. Preserve the
initial PS5.1 diagnostic-wrap assertion failures and test-only correction.

No cleared speech corpus was supplied: listening remains UNPERFORMED; AC042
accepted only the unavailable-review record. Never substitute synthetic tones
for quality approval. >4 GB/disk exhaustion, running-render Ctrl+C, long-file/
memory stress and independent meter calibration remain unverified. Capture is
in memory; capacity is not reserved; reports lack multi-file atomicity/durability.

Update task/acceptance/status/handoff, explicitly stage/review, commit/push the
feature branch and verify clean local/live/PR equality. Record exact post-push
SHA in PR/final response. Stop after M2-04; no default-sound promotion.
