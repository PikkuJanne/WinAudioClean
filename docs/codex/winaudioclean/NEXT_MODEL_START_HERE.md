# Next model: WAC-M3-01

**M2-05 is complete. Start only WAC-M3-01: Add noninteractive parameters and
saved settings.** Read AGENTS, STATUS, DECISIONS, TASKS, SYNC_PROTOCOL,
tasks/WAC-M3-01, DATA_FORMATS, AUDIO_CONTRACT and NATIVE_PROCESS_CONTRACT,
then M2-05 evidence/source/classifications/reproduction/human status. Preserve
all prior history, especially M1-02 policy/resumption and preliminary scopes.

## Inspect and synchronize

Use maintained WinAudioClean-governance; keep source-only original untouched.
Current milestone branch `codex/wac-m2-audio`, effective fetch/push origin
`https://github.com/PikkuJanne/WinAudioClean.git`. M2-05 began at `ca512d08bdb806d5c1900ecd9b6d8ba0c1e7037d`;
obtain its actual completed SHA from live branch/draft PR#3. Run handoff.py
inspect, fetch --prune origin, sync-check, validate-plan and next per protocol.
Only M3-01 should be ready. Inspect live PR/CI separately: no workflows/checks
currently exist. Process-only gh credential helper is available; never print
or persist credentials. The completion SHA belongs in PR/response, not itself.

Start M3 from the verified M2 tip on a suitable new milestone feature branch,
reusing a suitable existing branch if present. Stack its draft on M2 until
approved merges change actual history. Existing M2#3 stacks on unmerged M1#2/M0.
Do not merge to unlock work. Feature checkpoints/draft updates are authorized;
main pushes, merges, tags/releases, settings/security changes, default promotion
and deployment require exact owner authorization.

## Reconcile M3-01 with implemented behavior

Mode, Preset, OutputDirectory and NonInteractive already exist; extend rather
than duplicate them. Preserve positional/inputPath and launcher routes, PS5.1,
the two-choice menu, cancel/exit codes and literal local path handling. M3-01 is
typed versioned per-user JSON, explicit CLI > saved > built-in precedence,
effective-settings display, explicit reset/save and safe atomic replacement.
Inspect DATA_FORMATS and actual APIs before deciding narrow field names/storage.
Distinguish omitted options from explicit false/empty/default-looking options
using actual bound parameters. Validate the complete effective configuration,
including inactive cleaning values; reject arbitrary filter/option/script text.
Test malformed/unknown-version/type/locale data and preservation of prior valid
settings on write failure. Keep rendering input paths/capture private and avoid
new prompts/pauses in unattended mode. No batch/GUI/server or later-task creep.

## Preserve audio and reporting contracts

- Runtime/main/IO/Preview/BAT equal M2-04 hashes. Original original/1.0.0 stays
  default with exact legacy Raw/Zoom strings, implicit nr and rounded gate
  literals. Application2.3/schema1 and PCM16 default/optional24/mono/RF64 remain.
- Gentle gentle/0.1.0 is experimental Raw-only; Zoom rejects Gentle/nonempty
  cleaning overrides. Typed bounds, disabled-value validation, fixed graph
  order and strict Accurate profile reconstruction remain. No sound approval.
- Ordinary Fast performs no extra analysis. Accurate repeats selected channel/
  cleaning/leveling prechain ending aresample192000, measured I/TP/LRA/threshold/
  offset and observed type, then held encoded-WAV final meter. Null reasons,
  target misses/fallback, peak precedence and WARNING7 stay distinct from valid
  PCM and report completeness. Finite positive integrated/threshold domain is
  rejected, not UNMEASURABLE or a fabricated fallback; broader support unresolved.
- Explicit Preview defaults0/45seconds, validates ranges/exact48k frames and
  bounded five-second context; no implicit full render/playback/saved state.
  Selected origins/absolute timestamp seeks and <=10ms declared clock policy
  remain; non-WAV missing/negative/coarse timing fails closed. Matroska +8samples
  within49 and approximate25ms Raw delay are disclosed, not compensated.
- Four owned assets retain held input/output identity; comparison copies gain
  only, attenuation with -1.7planning/-1.5ceiling and <=0.2LU matching. Unavailable
  matching warns; peak/pub failures roll back owned objects. Four valid assets
  survive later report failure WARNING7. Preview schema reports stay separate.

## Evidence and testing

M2-05 focused:523/shell; Full:1018Pester+61Python/shell, one privilege
skip. Both wrappers/source captures pass unchanged, including completed new
reproduction utility; prior M2-04 harness-delta caveat remains historical.
Fresh unfiltered five media matrices pass116cases. Same-report/input/build
reproduction passes16reports/22assets with exact PCM/frames/meters; its
formatter/configuration and recorded-range proof is deliberately scoped.
No cleared speech or attributable listening was supplied; AC047 is human-gate
integrity, not audition approval. Default promotion remains unapproved.

Use tests/README and the existing ignored Pester5.7.1/PSSA1.24.0 and pinned
FFmpeg/ffprobe9.0.2; no automatic download. Strip inherited case-insensitive
PSMODULEPATH from Python-spawned shells. Multiple paths require actual arrays
through -Command, not comma text via -File. Freeze code, focus smallest relevant
tests then one required Full per shell. Record exact commands/exits/hashes,
case IDs, warnings and skips. Do not claim every Accurate case compliant.

Listening, independent calibration, >4GB/disk exhaustion, active-render Ctrl+C,
long-file/memory stress and universal codec seeking remain unverified; capacity
is not reserved, capture in memory, sets lack multi-file atomic/power-loss proof.
Update canonical state/evidence/handoff, explicitly stage/review/commit/push,
verify clean local/upstream/live/PR equality. Stop after M3-01; no release or
default-sound promotion.
