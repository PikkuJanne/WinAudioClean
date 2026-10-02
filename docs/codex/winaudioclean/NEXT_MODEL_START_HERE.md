# Next model: WAC-M2-03

**WAC-M2-02 is complete. Start only WAC-M2-03: Add optional gentle cleaning
with validated parameters.** Read AGENTS.md, STATUS.md, DECISIONS.md,
TASKS.yaml, SYNC_PROTOCOL.md, tasks/WAC-M2-03.md, AUDIO_CONTRACT.md,
DATA_FORMATS.md, NATIVE_PROCESS_CONTRACT.md and evidence/WAC-M2-02.md with its
source manifest. Preserve all earlier evidence and M1-02 resumption history.

## Inspect and synchronize

Use the maintained WinAudioClean-governance checkout on `codex/wac-m2-audio`.
Preserve the source-only original folder. Exact effective fetch/push origin:
`https://github.com/PikkuJanne/WinAudioClean.git`. M2-02 started from verified
M2-01 SHA `eafb6144cc3f2e2b1167a7d03e91654bdfb4fc20`. Find the actual M2-02
completion SHA through the live branch and draft PR #3.

Run handoff.py inspect, fetch --prune origin, sync-check, validate-plan and
next per SYNC_PROTOCOL.md. Only M2-03 should be ready. Inspect live PR/CI state
separately. Use authenticated GitHub CLI as a process-only credential helper
if needed, after inspecting existing process Git settings. Never print
credentials or change persistent configuration.

Reuse M2 draft PR #3, based on `codex/wac-m1-reliability` while PR #2 is
unmerged; PR #2 remains stacked on `codex/wac-m0-handoff`. Inspect actual
history if approved merges occurred. Do not merge to unlock work. No CI
workflow exists. Feature commits/pushes and draft PR updates are authorized;
merge, main pushes, tags/releases, default-sound promotion and deployment are not.

## Contracts to preserve

- Original ID `original`, version `1.0.0` covers the frozen Raw/Zoom filters.
  Application `2.3`, report schema `1`, mode, mono and encoding are separate.
  Default Fast renders with the original argv and adds no analysis invocation.
- Accurate measures the exact prechain and repeats it with measured values;
  both graphs end the prechain with `aresample=192000` before one loudnorm.
  Targets are I=-12/TP=-1.5/LRA=7. Map target_offset to offset invariantly.
  The helper currently allowlists the two Original chains; adapting it for a
  new validated preset is M2-03 work, without weakening parameter validation.
- Final encoded PCM is measured from the held validation stream via binary
  stdin before publication. Preserve its locks, no-replace rename, stream
  ownership, bounded copy/process cleanup and PS5.1 void-cast behavior.
- Real actual normalization_type is separate from requested linear mode.
  Undefined/short/out-of-range measurements have explicit fallbacks; malformed
  analysis is fatal. Final failures are FAILED, not UNMEASURABLE. Retain valid
  output with WARNING/7 for fallback or non-passing checks; reporting.complete
  describes report writing only. Preserve primary processing failure codes.
- Compliance requires finite I/TP, +/-0.5 LU around -12 and TP <= -1.3 dBTP;
  peak violations take precedence. LRA is informational. Under 1 second,
  I/LRA are null with too_short, while finite TP remains. Do not infer speech
  quality, exact targets or actual type from a requested mode.
- Additive report fields include actual stage commands/diagnostics locally.
  Redaction retains only typed finite values and fixed enums/reasons. Earlier
  schema 1 reports remain accepted; raw reports never upload automatically.
- Preserve PS1/BAT entry points, IO sibling, PS5.1 support, import safety,
  selected-stream policy, owned output/report cleanup and rollback. Main and
  README use CRLF; IO remains LF. IO/launcher were unchanged by M2-02.
- 48 kHz PCM16 is default; optional PCM24/mono/RF64 remain. Original Raw delay
  (~25 ms) remains; no default-sound change is approved.

## Narrow next scope

Follow M2-03 / AC-040 through AC-042: an optional conservatively named gentle
preset, bounded typed cleaning options/toggles and a listening candidate record.
Original Raw/Zoom stay default. Reject injected/unknown filter settings. Use
permission-cleared local speech only; if unavailable, record that listening
is unperformed. Synthetic checks are not listening approval. No saved settings,
preview, batch feature, broad rewrite or release belongs to this task.

## Validation and limits

Use tests/README.md. Existing Pester 5.7.1/PSScriptAnalyzer 1.24.0 live in
ignored .wac-local/Modules. FFmpeg/ffprobe 9.0.2 are under
.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin.
When spawning PS5.1 from Python remove inherited environment keys with
key.upper() == 'PSMODULEPATH'. Pass multiple -Path/-Tag values through a real
PowerShell array in -Command; a comma-string through -File selects zero tests.

Run focused checks before one Full per shell. M2-02 Full passes 666 Pester and
61 Python tests per shell, with one Python symlink-privilege skip. Final
Accurate matrix passes 16 cases; Fast passes 20 cases plus 10 frozen references.
No private speech or generated audio belongs in Git. Keep exact source/tool/
command/log hashes and sanitization. Do not overwrite prior task evidence.

Speech listening, >4 GB output, actual disk exhaustion, running-render Ctrl+C,
long-file/memory stress and independent meter calibration remain unverified.
Capture is in memory; capacity is not reserved; reports are not multi-file
atomic. Preserve these limits rather than treating synthetic checks as proof.

Update task/acceptance/status/handoff, stage only intended paths, review staged
content, commit/push the feature branch and verify clean local/live/PR equality.
Record the exact post-push SHA in the PR/final response. Stop after M2-03.
