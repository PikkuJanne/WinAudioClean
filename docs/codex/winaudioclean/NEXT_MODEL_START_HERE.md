# Next model: WAC-M2-05

**WAC-M2-04 is complete. Start only WAC-M2-05: Audio gate with honest listening
status.** Read AGENTS.md, STATUS.md, DECISIONS.md, TASKS.yaml, SYNC_PROTOCOL.md,
tasks/WAC-M2-05.md, AUDIO_CONTRACT.md, DATA_FORMATS.md, NATIVE_PROCESS_CONTRACT.md
and evidence/WAC-M2-04.md/source/media. Preserve prior evidence and M1-02 history.

## Inspect and synchronize

Use maintained WinAudioClean-governance, `codex/wac-m2-audio`, exact effective
fetch/push origin `https://github.com/PikkuJanne/WinAudioClean.git`. Keep the
source-only original folder untouched. M2-04 started from `cabd6cdd8a537d23ac50e2db006f84193fa0cd59`; find its
actual completion SHA through the live branch and draft PR#3. Run handoff.py
inspect, fetch --prune origin, sync-check, validate-plan and next per protocol
(--plan-root for validate-plan/next). Only M2-05 should be ready. Inspect live
PR/CI separately; no workflow/checks currently exist. Process-only authenticated
GitHub CLI credential helper is available; never print or persist credentials.

Reuse stacked M2 draft#3 on unmerged M1 draft#2/M0. Inspect actual history if an
approved merge occurred. Feature checkpoints/draft updates are authorized;
main pushes, merges, tags/releases, default-sound promotion, settings/security
changes and deployment require exact authorization. Do not merge to unlock work.

## Preserve runtime contracts

- Original graphs/identity `original`/`1.0.0`, application2.3/schema1, channel
  policy and optional encoding are separate. Fast ordinary export remains
  unchanged with no extra analysis. IO and BAT remain unchanged from M2-03.
- Gentle `gentle`/`0.1.0` remains experimental Raw-only: highpass60, afftdn
  nf=-35:nr=6, declip/declick/gate off, leveling unchanged. Typed cleaning
  bounds/schema, disabled-value validation and exact Accurate profile rebuilding
  remain. Zoom rejects Gentle/nonempty overrides. Preserve rounded Original
  gate values and implicit default nr; reproduce exact graph/build/settings.
- Full Accurate repeats the same selected post-channel/cleaning/leveling
  prechain ending aresample192000, targets -12/-1.5/LRA7, measured offset mapping
  and actual normalization type. Final encoded measurement uses the held WAV
  binary stdin before no-replace publication. Keep finite +/-0.5 LU/TP<=-1.3,
  peak precedence, explicit unavailable reasons and WARNING7 semantics.
- Preview imports its optional sibling only when requested, defaults0/45sec,
  caps explicit duration60, validates actual selected duration and exact48k
  output frames. Bound five-second context then trim matching positions;
  Accurate analysis is context-only. No hidden full render/playback/upload.
- Timestamp origin plus window start uses seek_timestamp1. WAV no-PTS origin
  is sample zero; unsupported/negative/missing non-WAV timing fails closed.
  Record rational timestamp resolution and bounded <=10ms sample uncertainty.
  Matroska millisecond PTS can shift the common source crop by a few samples:
  final evidence measures/discloses it; do not claim universal sample-perfect
  seeking or compensate by guessing. Known graph delay is preserved (Raw
  Original/Gentle about25ms on pinned build); custom calibration remains limited.
- Four owned Original/Processed/CompareOriginal/CompareProcessed assets share
  pinned source/destination identities, capacity4outputs+reserve, held meters
  and gain-only comparison copies. Target min(Ia,Ib,Ia-TPa-1.7,Ib-TPb-1.7),
  gains<=0, finalTP<=-1.5/pairdifference<=0.2 plus1e-9 floatguard. Unmeasurable
  matching is WARNING7. Peak/processing/publication failure rolls back only
  owned objects. Report failure after4valid publications retains audio WARNING7.
- Preview schema1 reports are separate from normal summaries; all metrics are
  excerpt/context-only. No saved state. Preserve source locks through reports,
  owned cleanup and PS5.1 compatibility. Reports/capture remain local/private.

## Next task and validation

M2-05 is an objective audio/compatibility gate, reproduction from recorded
input/build/settings and honest listening/approval status. Run implemented-mode
checks and classify undefined/ineligible metrics. Complete permission-cleared
listening if material exists; otherwise keep pending/unperformed explicitly.
No cleared speech was supplied for M2-03/04. Missing optional candidate approval
does not block unrelated reliability delivery or authorize default promotion.
Do not invent consent/reviewer results or broaden into saved settings/batch.

Use tests/README.md. Existing ignored Pester5.7.1/PSScriptAnalyzer1.24.0 and
FFmpeg/ffprobe9.0.2 are installed. Python-spawned shells need inherited keys
with key.upper()=='PSMODULEPATH' removed. Use actual arrays in -Command for
multiple paths/tags, not comma text via -File. Focus before one Full per shell.
M2-04 final Targeted:322, Full:1015Pester+61Python per shell,
one privilege skip; 24preview cases/12locale pairs and20Original cases
+10frozen references pass. Source manifest pins finalphysicalhashes. Initial
126focus predates timingprecision refinement; final gates supersede it. Preserve
documented preliminary bugs/scopes and current timestamp uncertainty.

Review the inherited parser's positive integrated-loudness limit explicitly:
raw hot square I=+0.51 LUFS failed closed. The final lower-amplitude peak fixture
does not certify that domain. Timestamp tick+one-sample bounds are the tested
application policy, not a guarantee for all codecs/decoder seek behavior.

The first full preview matrix also exposed a harness assertion that expected
finite LRA=0 for silence although the application correctly reports null/silence.
Only three assertion lines were added to classify silent/undefined I/LRA (and
unavailable TP). Removing exactly that block reproduces the captured prior
harness SHA. The correction was outside Targeted/Full execution: those runners
parse/analyze PowerShell, run Pester and run Python governance tests; they never
execute Test-Preview.py. Runtime, PowerShell tests, native fixtures and Python
governance sources stayed unchanged. The Full capture wrapper's broad hash
flag detects the unused harness change and exits1 despite both shell gates
exiting0; this scoped provenance condition is recorded, not claimed as an
unchanged whole-tree gate. The final corrected unfiltered media matrix pins
the final harness and stable sources. No cumulative test result is fabricated.

Speech listening, independent calibration, >4GB output, actual disk exhaustion,
running-render Ctrl+C and long-file/memory stress remain unverified. Capacity is
not reserved; capture is in memory; sets are not multi-file atomic or power-loss
durable. Use synthetic media only for mechanics. Update canonical acceptance,
task/status/handoff, stage/review explicitly, commit/push and verify clean
local/live/PR equality. Stop after M2-05; no default-sound promotion or release.
