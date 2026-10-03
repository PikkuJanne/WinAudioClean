# Next model: WAC-M3-04

**M3-03 is complete. Start only WAC-M3-04: Add stage-aware progress and controlled
cancellation.** Read AGENTS, STATUS, DECISIONS, TASKS, SYNC_PROTOCOL,
tasks/WAC-M3-04, DATA_FORMATS, AUDIO_CONTRACT/NATIVE_PROCESS_CONTRACT and M3-03
evidence/source/media records. Preserve canonical history, especially M1-02
policy/resumption and prior M2/M3 failures/limits. Do not change the source-only
original checkout.

## Synchronize the current checkpoint

Use maintained WinAudioClean-governance, `codex/wac-m3-settings`, exact effective
fetch/push origin `https://github.com/PikkuJanne/WinAudioClean.git`. M3-03 began
at `8d033079dde925abd48c87d9b4f71784756c146d` (M3-02); inspect live M3 branch/draft#4
for its actual completed SHA. Run inspect, authenticated fetch --prune,
sync-check, validate-plan and next. Only M3-04 should be ready. Process-only gh
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

## Preserve folder queues; M3-04 scope

Preserve explicit InputDirectories/Recurse, root-seeded ordinal/BFS ordering,
bound snapshot before jobs, ordinary no-follow ancestor/source handles,
volume/file identity deduplication, strict generated-name/alias exclusions and
proper descendant destination skips. Root==destination explicit selection wins.
Folder schema2 captures selection/source metadata/reasons/skips; explicit lists
retain repeats/schema1. Source identity/length/UTCmtime is checked and held through
each ordinary child. Per-file failures continue and report ownership is unchanged.
Empty/allskipped selections need no mode/native job; aggregate folder failed6,
warning7, success0 and returned cancel130 preserve static skips/preflight failures.
Journal failure5 stops starts and discloses incomplete reporting. New files never
enter running snapshots. Extension candidates are not media proof; renamed
outputs/metadata-restoration/crash claims remain bounded in DATA_FORMATS.

M3-04 adds FFmpeg structured progress with separate diagnostic logging, stage
labels/file position and Accurate analysis/render/verification ranges. Unknown
duration stays indeterminate. Controlled cancellation must target only this
run's owned child process with bounded cleanup and no kill-by-name. Preserve
queue persistence, original sources/prior results and frozen sound defaults.
Current labeled returned-exit130 tests do not prove active-render Ctrl+C. Do not
implement a later task, GUI/server, retune, merge, release or deployment.

## Audio and gates

M3-03 final source preserved normalized pre-existing main helper bodies/full
processing suffix and IO/Settings/Preview/BAT/Launcher bytes from M3-02. Original1.0.0 stays
built-in; Gentle0.1.0 opt-in experimental Raw-only. Application2.3/report1, Fast
default, Accurate repeated prechain/held meter/warnings, PCM16/24/mono/RF64,
owned output/report transactions and bounded preview remain. Positive integrated/
threshold measurements fail rather than becoming UNMEASURABLE. Preserve M2
seek/latency/formatter and same-input/build reproduction limits. Numeric/synthetic
checks provide no listening/default-promotion approval.

Prior M3-02 selected checks:73 Batch plus4 invalid-path cases,33 Transport,58 legacy
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
explicitly, verify clean upstream/live/draft equality, and stop after M3-04.
No merge/release/default promotion/deployment.

Current M3-03 final focused 156 pass/1 skip;
Full 1330 pass/1 skip Pester per host plus Python62
discovered/61pass/oneprivilegeskip. Exact final commands/hash/scopes, media
comparisons, cancellation seams and preliminary fixes are in M3-03 evidence.
Use existing pinned modules/tools and isolate preferences. Code must freeze
before final gates/media; do not claim listening or active cancellation from
synthetic/copied-dispatch checks.
