# Current v1.0.0 publication scope

2026-10-07: all seven earlier PRs are integrated at R7
`944aaa1c57ae192237f0fee057dd672db4be22d9`; its unchanged-source CI retry passed
all four jobs, with the initial failure preserved. The owner explicitly approved
**Publish v1.0.0 here** in `PikkuJanne/WinAudioClean`. First public application
version `1.0.0` preparation is in progress; publication is not yet verified.
Website hosting remains deferred to the future multi-tool project. Existing
20-group/30-task/90-case engineering scopes and eight unrun/unwaived gaps remain.
See [the supplemental release record](evidence/WAC-M5-04-v1.0.0.md) and
[ledger](evidence/WAC-M5-04-v1.0.0.json).

## Historical integration records through 2026-10-04

# Integrated main and bounded 20-group acceptance

Date: 2026-10-04. **WAC-M5-04 merge-only acceptance is complete; final delivery remains subject to external green CI/live verification.** Canonical 30 done / 0 todo; 90 pass / 0 not_run. No next unlocked task. All eight broader gates remain unrun and unwaived; these canonical engineering/action passes do not certify broader listening/platform/stress claims.

Owner instruction (2026-10-04): **Let's out new version on main branch please** Accepted source `51ac9a37e17a51979f3c79ccbc1dcd6fdd2243c1` was integrated through six ordered ordinary exact-head PR merges. Actual merged-main anchor `a83538f242252d8747a4d9544e3613a6d2790071` / tree `bcacb002a8b40ba5eb61a9f1ac4439d90f2b3f2b` equals the accepted C tree. [Main push CI](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37200347904) is pending in the actual four-job run; it is not claimed passed. Earlier heads #1–4 had no workflow/checks; fresh exact-head PR5/6 four-job CI passed, testing approved C on PR6. Actual main targets were reread before merge; source branches remain preserved.

Release/site direction: **Release and website publication will be done later in another project making multiple tools available.** No tag, release, deployment, bundled dependency, media/default change or private-data action occurred. The nine-file website remains draft/download-disabled; screenshots/audio/consent and hosting destination remain pending. Original/Raw/Zoom, PCM16/48 kHz defaults, Accurate opt-in and Gentle experimental/opt-in stay unchanged.

This additive governance feature/ordinary follow-up PR records completed merge results. Its later exact push/CI/PR7/merge identities are verified externally; they are not claimed in this commit. The accepted-main push CI and final governance PR/main CI must actually pass, with live branch/main checks complete, before the final task response. Preserve recordings/settings/exports and the source-only original. [Approval/results](APPROVALS.md), [merge evidence](evidence/WAC-M5-04.md), [validation ledger](evidence/WAC-M5-04-validation.json).

All 20 implemented engineering groups retain their existing measured scopes and limitations. Current action disposition for groups 17, 18 and 20:

| Group | Actual disposition | Remaining separate work |
| --- | --- | --- |
| 17 — CI/integration | Six ordinary approved merges, exact accepted-tree equality and fresh successful C PR CI verified; main push state is recorded as observed. | Accepted-main/final-governance CI and live feature/PR/main delivery must actually pass externally. |
| 18 — package integrity | Accepted C product tree retained; existing tool-only candidate/provenance remains bound to C. | No new candidate, tag or release; future selected source/assets need new exact approval. |
| 20 — static website | Existing nine-file draft and metadata/download gate retained. | Hosting/publication/media/consent remain pending in the owner's later separately scoped project. |

All eight broader gates remain not_run, without waiver. 90 canonical passes describe actual engineering and approved-merge acceptance; no universal support or listening/publication claim follows.

## Historical 20-group mapping and M5-03 bounded audit

# Improvement traceability
The 20 rows correspond to the improvement groups accepted in the preceding review. All are in scope; optional execution choices and approval boundaries are explicit.
| # | Improvement | Implementing tasks |
|---|---|---|
| 1 | Collision-safe transactional exports | WAC-M1-04, WAC-M1-07 |
| 2 | Input/mode/destination validation | WAC-M1-01, WAC-M1-07, WAC-M3-05, WAC-M3-06 |
| 3 | Explicit WAV format | WAC-M1-05, WAC-M1-07 |
| 4 | Reliable failures and native-process handling | WAC-M1-02, WAC-M1-04, WAC-M1-07 |
| 5 | Probe and choose audio tracks | WAC-M1-03, WAC-M1-07 |
| 6 | Dependency resolution/checks | WAC-M1-03, WAC-M1-07, WAC-M4-04 |
| 7 | Accurate audio terminology | WAC-M2-01, WAC-M2-05, WAC-M4-04 |
| 8 | Optional measured loudness | WAC-M2-02, WAC-M2-05 |
| 9 | Preserved legacy sound and optional presets | WAC-M0-03, WAC-M2-01, WAC-M2-03, WAC-M2-05 |
| 10 | Preview and level-matched comparison | WAC-M2-04, WAC-M2-05 |
| 11 | Multiple files and optional folders | WAC-M3-02, WAC-M3-03, WAC-M3-06 |
| 12 | Noninteractive operation and settings | WAC-M3-01, WAC-M3-06 |
| 13 | Progress and cancellation | WAC-M3-04, WAC-M3-06 |
| 14 | Per-run reports and diagnostics | WAC-M1-02, WAC-M1-06, WAC-M1-07, WAC-M3-06 |
| 15 | Output organization and long recordings | WAC-M1-05, WAC-M1-07, WAC-M3-05, WAC-M3-06 |
| 16 | Regression tests with small refactors | WAC-M0-01, WAC-M0-02, WAC-M0-03, WAC-M0-04, WAC-M1-07, WAC-M2-05, WAC-M4-01 |
| 17 | Repeatable CI and releases | WAC-M0-01, WAC-M0-04, WAC-M4-02, WAC-M4-03, WAC-M5-02, WAC-M5-04 |
| 18 | Dependencies, licensing and package integrity | WAC-M4-03, WAC-M5-02, WAC-M5-04 |
| 19 | Help, setup and troubleshooting | WAC-M2-01, WAC-M4-04 |
| 20 | Static presentation/download website | WAC-M5-01, WAC-M5-02, WAC-M5-04 |

Every task has three acceptance cases. TASKS.yaml and ACCEPTANCE.json are the canonical machine-readable records; task briefs and this table are navigation aids.

## Final engineering audit — 2026-10-04

All 20 groups have implemented, evidenced engineering behavior in the domains below. This is not approval of the broader listening, platform, stress or publication claims. No implementation is relabeled as owner-approved deferred work. The baseline audit reconciles all 90 case dispositions and referenced evidence in [the audit record](evidence/WAC-M5-03-audit.json). The actual final frozen-source cumulative gates and candidate inspection passed; exact evidence is in [the validation ledger](evidence/WAC-M5-03-validation.json). Final closure SHA/assets and current PR/CI must be verified externally after push; they are not observed in this commit.

| # | Implemented behavior | Recorded verification | Pending or excluded claim / risk | Evidence |
| --- | --- | --- | --- | --- |
| 1 | Run-owned CreateNew partials, held validation, no-replace publication and identity-based cleanup. | Transaction/native and real-output collision/fault evidence; M1-07 safety review; current stable Full regression evidence. | No multi-file atomicity, host-kill or power-loss durability guarantee. | [WAC-M1-04](evidence/WAC-M1-04.md), [WAC-M1-07](evidence/WAC-M1-07.md) |
| 2 | Literal local input/mode/destination checks; unattended failures; optional picker and organization validation. | Preflight/menu/entry-point matrices, synthetic workflow/automation and two owner-observed neutral-name menu retries. | Actual picker/follow-up gestures and broad Explorer punctuation coverage remain unperformed; original unquoted parentheses drop was rejected and neutral-name retry is disclosed. | [WAC-M1-01](evidence/WAC-M1-01.md), [WAC-M1-07](evidence/WAC-M1-07.md), [WAC-M3-05](evidence/WAC-M3-05.md), [WAC-M3-06](evidence/WAC-M3-06.md) |
| 3 | Explicit 48 kHz PCM16 default, optional PCM24/mono/RF64 and held complete-WAV verification. | Real encoding/channel/timing matrix and corruption/native/output validation tests; package/documentation waveform checks. | Encoder output intentionally differs from historical implicit exports; large >4 GB/full-volume stress is unrun. | [WAC-M1-05](evidence/WAC-M1-05.md), [WAC-M1-07](evidence/WAC-M1-07.md) |
| 4 | Direct native invocation, individual arguments, separate captures, bounded ownership/cleanup, truthful exit and reporting outcomes. | Native/launcher/entry-point/fault evidence, successful M1-02 resumption and current Full regressions. | M1-02 initial Smart App Control rejection is historical; successful fixture execution is scoped to owner-changed policy Off, not policy On. Actual unreleased writer/host crash domains are not certified. | [WAC-M1-02](evidence/WAC-M1-02-resume.md), [WAC-M1-04](evidence/WAC-M1-04.md), [WAC-M1-07](evidence/WAC-M1-07.md) |
| 5 | Bounded ffprobe metadata and explicit absolute stream mapping; ambiguous unattended tracks fail. | Probe/selection/multitrack real-media and malformed metadata tests; later queues and docs retain stream identity. | Selected dependency/build and container domain only; unsupported preview timing/origin fails closed. | [WAC-M1-03](evidence/WAC-M1-03.md), [WAC-M1-07](evidence/WAC-M1-07.md) |
| 6 | Explicit/sibling/PATH dependency selection with version/filter checks and tool-only installation guidance. | Real dependency matrices, fresh package startup/documented setup and missing-tool failures. | User-supplied FFmpeg/ffprobe remain separate; no runtime download/bundling or unsigned-fixture policy On claim. | [WAC-M1-03](evidence/WAC-M1-03.md), [WAC-M1-07](evidence/WAC-M1-07.md), [WAC-M4-04](evidence/WAC-M4-04.md) |
| 7 | Original preset identity and corrected parameter/loudness claims in menu/help/README and static draft. | Claims/filter-help audit, exact Original compatibility, executed public help/examples and static-browser review. | No universal broadcast/exact-loudness/percentage success or speech-quality claim. | [WAC-M2-01](evidence/WAC-M2-01-claims-review.md), [WAC-M2-05](evidence/WAC-M2-05-listening.md), [WAC-M4-04](evidence/WAC-M4-04.md) |
| 8 | Opt-in Accurate two-pass loudness with final encoded-file measurement, explicit compliance/fallback/warning outcomes. | Real measured/silent/short/high-LRA cases, malformed/nonfinite parser and fatal/warning native faults; reproduction evidence. | Same-build FFmpeg meter mechanics, not independent calibration. Positive LUFS domain rejected; no universal target compliance. | [WAC-M2-02](evidence/WAC-M2-02.md), [WAC-M2-05](evidence/WAC-M2-05-listening.md) |
| 9 | Original Raw/Zoom graph/order preserved; Gentle Raw and typed customization remain explicit experimental choices. | BASELINE graph tests, decoded same-build Original comparisons, typed invalid-option tests and preserved-default reports. | No cleared formal speech A/B review or default-sound promotion approval. Gentle quality advantage remains unverified. | [WAC-M0-03](evidence/WAC-M0-03.md), [WAC-M2-01](evidence/WAC-M2-01-claims-review.md), [WAC-M2-03](evidence/WAC-M2-03.md), [WAC-M2-05](evidence/WAC-M2-05-listening.md) |
| 10 | Bounded timed excerpt, contextual render and four separate attenuation-only level-matched comparison assets. | Real preview timing/frame/peak/collision/rollback matrix and same-input/build report reproduction. | Formal speech comparison unperformed; container seek sample tolerance, five-second context/full-render difference and meter/build domain remain disclosed. | [WAC-M2-04](evidence/WAC-M2-04.md), [WAC-M2-05](evidence/WAC-M2-05-listening.md) |
| 11 | Ordered explicit lists/BAT transport and bounded frozen local folder queues, optional recursion and journals. | Actual CMD boundaries, synthetic real-media list/folder cases, junction/hardlink/deduplication/change/cancellation evidence. | Broad manual Explorer multi-file punctuation gestures remain unrun; earlier CMD percent/exclamation expansion cannot be recovered; documented safe environment/manifest route applies. | [WAC-M3-02](evidence/WAC-M3-02.md), [WAC-M3-03](evidence/WAC-M3-03.md), [WAC-M3-06](evidence/WAC-M3-06.md) |
| 12 | Unattended parameters and strict typed bounded JSON preferences; CLI > saved > built-in, explicit atomic save/reset only. | Precedence/schema/duplicate-key/foreign-target/write-fault tests and actual fresh-package management/documentation commands. | No automatic save/migration; crash/power-loss settings durability is not claimed. | [WAC-M3-01](evidence/WAC-M3-01.md), [WAC-M3-06](evidence/WAC-M3-06.md) |
| 13 | Stage/media-time progress and explicit owned-child Ctrl+C/Break cancellation, with cancelled outcomes and retained earlier exports. | Real signal/PID-ready cancellation and progress matrices plus source/earlier-export/survivor preservation checks. | No actual console close/logoff/forced-host-kill/power-loss recovery or long-running stress claim. | [WAC-M3-04](evidence/WAC-M3-04.md), [WAC-M3-06](evidence/WAC-M3-06.md) |
| 14 | Per-run structured/text reports and preserved summary; processing validity separated from warnings; explicit allowlisted redacted support export. | Report/native/privacy/fault/journal outcome matrices and actual documented diagnostic success/rejection cases. | Early pre-render failures can remain console-only; sourceRevision null/not_embedded and local report paths are disclosed. Ordinary schema-1 exporter does not accept Preview or journals. | [WAC-M1-02](evidence/WAC-M1-02-resume.md), [WAC-M1-06](evidence/WAC-M1-06.md), [WAC-M1-07](evidence/WAC-M1-07.md), [WAC-M3-06](evidence/WAC-M3-06.md) |
| 15 | Legacy flat Music layout plus chosen destinations, optional held JobFolder organization and RF64/capacity policy. | Output organization/redirected Music/identity/permission/format tests and short synthetic/documented package runs. | Full >4 GB/volume exhaustion/long-recording memory-storage/UNC-long-path stress remain unrun; documented short-base paths apply. Actual picker/open gestures remain unperformed. | [WAC-M1-05](evidence/WAC-M1-05.md), [WAC-M1-07](evidence/WAC-M1-07.md), [WAC-M3-05](evidence/WAC-M3-05.md), [WAC-M3-06](evidence/WAC-M3-06.md) |
| 16 | Small test seams, layered runners, traceable regression/fault/corruption checks and preserved historical failures. | M0 through M4 evidence, three source mutants per host, current clean-source Full on PS5.1/PS7 and hosted jobs. | Eight broader coverage gaps and actual local privilege skips remain; test inventory alone is not execution evidence. | [WAC-M0-01](evidence/WAC-M0-01.md), [WAC-M0-02](evidence/WAC-M0-02.md), [WAC-M0-03](evidence/WAC-M0-03.md), [WAC-M0-04](evidence/WAC-M0-04.md), [WAC-M1-07](evidence/WAC-M1-07.md), [WAC-M2-05](evidence/WAC-M2-05-listening.md), [WAC-M4-01](evidence/WAC-M4-01.md) |
| 17 | Pinned explicit developer setup, least-privilege exact-SHA Windows CI, deterministic clean-source builder and recoverable feature checkpoints. | Fresh GitHub reconstruction with clone-local verified setup; focused checks, both first-attempt Full gates and four identical builds. | M5-04 publication actions/AC-088..090 remain not_run and require exact consequential owner approval; publishing is unnecessary for engineering handoff. | [WAC-M0-01](evidence/WAC-M0-01.md), [WAC-M0-04](evidence/WAC-M0-04.md), [WAC-M4-02](evidence/WAC-M4-02.md), [WAC-M4-03](evidence/WAC-M4-03.md), [WAC-M5-02](evidence/WAC-M5-02.md) |
| 18 | Tool-only fixed-allowlist package from committed blobs, MIT/notices and exact manifest/checksum/provenance inspection. | Real fresh extracted use, independent source/sidecar/ZIP verification and four candidate metadata checks with checksum/version rejection. | Third-party bundling is not approved; existing dependencies stay external. Publishing assets and broad security certification remain pending/outside scope. | [WAC-M4-03](evidence/WAC-M4-03.md), [WAC-M5-02](evidence/WAC-M5-02.md) |
| 19 | Actual comment help, README/setup/portable/support/security/report documentation covering supported options and limits. | 64 executed documented examples/support cases plus help-parameter comparison; exact reconstruction-guide negative helper executed once. | Examples use disclosed synthetic media/current Windows prerequisites; no other-machine/clean-OS/general path or listening claim. | [WAC-M2-01](evidence/WAC-M2-01-claims-review.md), [WAC-M4-04](evidence/WAC-M4-04.md) |
| 20 | Portable isolated static page, existing MIT branding, versioned strict release schema/validator and draft download gate. | Actual browser keyboard/responsive/15 metadata fixtures, 17 independent VM vectors and actual-package source/hash/date/name checks. | Screenshots/audio/consent inventories explicitly pending; committed metadata remains draft/null and download disabled; deployment/release approvals absent. | [WAC-M5-01](evidence/WAC-M5-01.md), [WAC-M5-02](evidence/WAC-M5-02.md) |

All eight [retained gates](COVERAGE.json) remain `not_run`, with no owner waiver: speech listening, Explorer matrix, picker gestures, storage stress, host crash/power loss, privileged file symlink, meter/seek domain and unreleased preview writer. Their required trigger and risk remain in the audit and coverage records. Missing subjective evidence keeps Gentle opt-in/experimental and prohibits sound promotion. Future M5-04 publication is an approval action, not deferred implementation. AC-088..090 remain unrun. See [the handoff checklist](HANDOFF.md).
