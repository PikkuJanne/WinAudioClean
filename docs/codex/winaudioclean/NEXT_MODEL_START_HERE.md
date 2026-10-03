# Next model: WAC-M3-03

**M3-02 is complete. Start only WAC-M3-03: Add sequential folder queues and batch
summaries.** Read AGENTS, STATUS, DECISIONS, TASKS, SYNC_PROTOCOL, tasks/WAC-M3-03,
DATA_FORMATS, AUDIO_CONTRACT/NATIVE_PROCESS_CONTRACT and M3-02 evidence/source/
Batch/launcher/media scope records. Preserve canonical history, especially
M1-02 policy/resumption and honest M2/M3 preliminary failures/limits. Do not
change the source-only original checkout.

## Synchronize the current checkpoint

Use maintained WinAudioClean-governance, `codex/wac-m3-settings`, exact effective
fetch/push origin `https://github.com/PikkuJanne/WinAudioClean.git`. M3-02 began
at `33dc8b1dde8bb957fc221442e027991a895a85f6` (M3-01); inspect live M3 branch/draft#4
for its actual completed SHA. Run inspect, authenticated fetch --prune,
sync-check, validate-plan and next. Only M3-03 should be ready. Process-only gh
credentials are available; never print/persist them. Verify live draft/head/CI
separately; no workflows/checks currently exist. Completion SHA belongs in the
PR/final response, not itself.

Reuse the suitable M3 milestone branch after fresh verification; no duplicate
draft/worktree. Draft#4 stacks on M2#3, itself on unmerged M1#2/M0. No merge is
needed to unlock work. Feature commits/pushes/drafts are authorized; main/merge/
release/settings/security/deployment/default promotion still require exact owner
authorization. Never force-push/reset/clean/stash.

## Preserve ordered input and launcher contracts

- Existing positional inputPath remains one string. InputPaths is a typed array;
  InputListPath reads strict UTF8 schema1 exact keys/integer version,1..1024
  nonempty entries, <=1MiB including optional BOM. Mutually exclusive with each
  other/inputPath; ordinary full renders only. Malformed list/global settings
  fail2 before jobs. Relative strings anchor beside manifest; invalid pipe/NUL
  text must fail per item and let later valid jobs continue, including PS5.1.
- Optional Batch/Settings siblings handle lists, frozen settings and one mode
  choice; children invoke ordinary main with IgnoreSavedSettings. Stream selection
  may remain per-item interactive. Preserve explicit repeats/order for explicit
  lists; settings dictionaries/false/empty choices retain bound semantics.
- Held CreateNew UTF8 JSONL header/item/summary flushes per item. Never overwrite
  input/manifest/prior results or infer foreign detailed-report ownership by scan.
  Preserve single code; multiple failure6/warnings7/all-success0/cancel130.
  Cancel stops future items with NOT_STARTED. Journal failure5 stops future starts,
  preserves prior audio/records, attempts suffix-only rollback and discloses
  incomplete reporting. No crash/power-loss or multi-file atomicity claim.
- Existing BAT + optional Launcher uses numbered environment captures and a fixed
  PS bootstrap/selected-worker encoded command. Fresh CMD /c framing must match
  original token count/order/value; no path text interpolates into commands.
  Positional raw frame below7600, <=1024 inputs, no observable %/! or ambiguity.
  CMD may expand percent text before BAT starts: raw capture cannot undo it.
  Use literal environment /manifest or direct InputListPath for those/long paths;
  /unattended Raw|Zoom requires one input-or-list and output environment value.
- Preserve default inner PS5.1/explicit local PS7 selection, helper-less prior
  single/environment route, no-input guidance, saved status before one interactive
  pause (including cancellation/worker start3), no unattended pause. Real CMD
  probes do not imply a manual Explorer gesture was performed.

## M3-03 scope

Extend the current explicit sequential orchestration with a bounded local folder
queue builder; inspect existing code before extracting another helper. Recursion
is off by default. Materialize/deduplicate the folder queue before jobs, explain
unsupported selections, exclude this tool's generated outputs/temp artifacts,
and avoid symlink/junction traversal loops. Preserve per-file continuation,
reports and final successful/failed/skipped/cancelled summary. No automatic audio
re-cleaning. Do not silently change explicit-list repeated-item semantics while
adding folder deduplication. Reconcile stable queue identities/output exclusion
with current schema carefully and document any additive report contract.
No GUI/server/default sound retune or later milestone implementation.

## Audio and gates

M3-02 final source preserved normalized pre-existing main helper bodies/full
processing suffix and IO/Settings/Preview bytes from M3-01. Original1.0.0 stays
built-in; Gentle0.1.0 opt-in experimental Raw-only. Application2.3/report1, Fast
default, Accurate repeated prechain/held meter/warnings, PCM16/24/mono/RF64,
owned output/report transactions and bounded preview remain. Positive integrated/
threshold measurements fail rather than becoming UNMEASURABLE. Preserve M2
seek/latency/formatter and same-input/build reproduction limits. Numeric/synthetic
checks provide no listening/default-promotion approval.

Final selected checks:73 Batch plus4 invalid-path cases,33 Transport,58 legacy
Launcher per host. Full:1251 Pester pass +62 Python discovered per host (61 pass,
one symlink-privilege skip); parser/static/plan pass with visible non-gating
advisories. API28/28 calls,32 assets,26 PCM/frame/graph matches +6 direct refs;
BAT6/6 calls +4/4 refs,20 assets,16 matches. All final source/tool/config guards
pass. Prior captures with preliminary code and corrected failures stay distinct.
Use existing pinned modules/FFmpeg9.0.2; no download/security change. Strip
inherited PSMODULEPATH from Python children. Focus smallest relevant checks,
freeze code, then required Full per shell. Record exact commands/exits/hashes/
versions/scopes, failure history and skips. Tests isolate SettingsPath/Ignore;
never write the user's own preferences or publish private audio/reports.

Manual Explorer gesture, active-render Ctrl+C, power-loss, speech listening/
calibration/>4GB/disk exhaustion/long-file memory/codec-seek limits remain.
Media cancellation is a labeled copied dispatch simulation. Update canonical
state/evidence/handoff only for the selected task, stage/review/commit/push
explicitly, verify clean upstream/live/draft equality, and stop after M3-03.
No merge/release/default promotion/deployment.
