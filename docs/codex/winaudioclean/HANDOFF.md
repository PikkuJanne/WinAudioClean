# Final acceptance and action proposal — in progress

This is the WAC-M5-03 engineering handoff, not approval to merge, publish or deploy. Baseline `b471c2dc577cf1138007778e6bef0c56c703b9e0` is clean/live-synchronized and its four CI jobs passed. All 20 improvements and 90 case dispositions have a bounded evidence audit; AC-085..087 await the final gates/delivery.

## Engineering checklist

- [x] Reconcile all 20 implementation groups and 90 canonical case dispositions; verify referenced evidence and preserve historical failures.
- [x] Review mandatory safety/compatibility evidence; no known current data-loss/security/false-success regression identified in the bounded review.
- [x] Preserve Original/Fast default Raw cleaning and Zoom level-only behavior, PCM16/48 kHz defaults, Accurate opt-in and Gentle opt-in/experimental. No listening/default promotion approved.
- [x] Retain eight unrun broader gates and actual privilege skips/advisories without waivers or broad support claims.
- [x] Reconcile tool-only package/license/privacy/rollback and the download-disabled static draft; real media/consent remain pending.
- [ ] Freeze/push this audit checkpoint, run focused structural checks and one actual Full per PS5.1/PS7 host, then record unchanged source/document hashes.
- [ ] Reconstruct exact candidates and inspect manifest/checksum/provenance/version/source/metadata identity.
- [ ] Close/push accepted evidence, verify clean local/live SHA and current PR/CI, then rebuild four candidates at that final accepted SHA for the external exact approval packet.

## Proposed integration

Repository: `PikkuJanne/WinAudioClean`. Live `main` was `7dfe43361395908a277d7b513b1c9a4fd3cd192a`. All six milestone PRs are open drafts and stacked, not merged. Proposed strategy: bottom-first #1 through #6, ordinary merge commits, no branch deletion/history rewrite/main push/settings changes. Owner must approve the exact current heads, method, destination and any downstream base retargeting. After each approved merge, read the actual new main/PR state and stop on a changed head, failed required check or source/asset mismatch. A new merged release source requires a matching rebuilt candidate and renewed exact asset approval.

| PR | Current base | Audited head |
| --- | --- | --- |
| [#1](https://github.com/PikkuJanne/WinAudioClean/pull/1) | `main` | `329852555170c5e58be3db92c18634b5341eb138` |
| [#2](https://github.com/PikkuJanne/WinAudioClean/pull/2) | `codex/wac-m0-handoff` | `f1ad9de795b74acef5b932223c38eedfba24cee6` |
| [#3](https://github.com/PikkuJanne/WinAudioClean/pull/3) | `codex/wac-m1-reliability` | `32f6188461d9f7c11857e390d1145985665dd0dd` |
| [#4](https://github.com/PikkuJanne/WinAudioClean/pull/4) | `codex/wac-m2-audio` | `c2ad4de8fd1258a474ad0ba424bc8f6ee53a2ed3` |
| [#5](https://github.com/PikkuJanne/WinAudioClean/pull/5) | `codex/wac-m3-settings` | `ea5d53d91ff2c035a50b9808fda18ceba38d3b61` |
| [#6](https://github.com/PikkuJanne/WinAudioClean/pull/6) | `codex/wac-m4-regression` | `b471c2dc577cf1138007778e6bef0c56c703b9e0` (baseline; final head recorded after closure) |

## Proposed tool-only release

Target: `PikkuJanne/WinAudioClean` GitHub Release; proposed tag `v2.3`, unoccupied in the read-only audit. This is a proposed label, not a created tag/date/URL. The reconstructed reference `WinAudioClean-2.3-250052238451-tool-only.zip` is 442766 bytes, SHA256 `f0ae14fcba29c29396e9298f7dcf571d9a8dbb8451f52304c3b92c4517c8804e`; it identifies source 2500522, not a future closure or merge.

The final external approval packet and PR checkpoint will identify the actual final accepted source/tree, ZIP filename/size/SHA256, 17 payload entries plus manifest, manifest hash, checksum/provenance sidecar names and hashes, and four observed build results. They are produced after the final push so the source/tag/package can match without putting a commit's future SHA inside itself. Never substitute the reference package, a cached ref or a post-merge source under an earlier approval. No third-party tool is bundled; supply trusted FFmpeg/ffprobe separately.

## Website and media

The nine-file portable website remains draft with null publication fields and disabled download. No hosting provider/site/domain/environment/path has been selected or approved, so deployment is not action-ready. Approve an exact site snapshot and destination separately before preparing any live deployment. Published metadata must use actual verified release URL/date/commit/tree/file/hash/size. Screenshots require real reviewed application pixels; demos require per-hash owner/speaker rights and useful level-matched material. Empty inventories stay pending; draft publication does not imply these reviews happened.

## Required owner instructions for M5-04

| Action | Required exact approval | Current disposition |
| --- | --- | --- |
| Merge | Each current PR head, merge method, target main and authorized downstream base retargeting | Pending; final refreshed heads in external packet/PR checkpoint |
| Tag/release | Final source SHA, v2.3 or owner-selected tag, exact ZIP/sidecars/hashes and GitHub target | Pending; final assets generated after closure push |
| Deploy | Exact website snapshot, hosting destination and draft/published metadata state | Not action-ready; destination unspecified |
| Sound/media/bundling/settings | Separate applicable settings/revision/listening, rights or redistribution/configuration approval | Not approved; outside current handoff |

Approval of one row does not authorize another. Record the owner's actual instruction, date, source/assets/target, constraints and verified result in [APPROVALS.md](APPROVALS.md). No owner approval or risk waiver exists now. M5-04 and AC-088..090 stay unrun until matching actions are explicitly approved.

## Boundaries and recovery

Use [TRACEABILITY.md](TRACEABILITY.md), [COVERAGE.json](COVERAGE.json), [the audit](evidence/WAC-M5-03-audit.json) and [reconstruction/rollback guide](RECONSTRUCTION.md). The eight broader gates are not waived: speech, Explorer/picker gestures, full-size/storage stress, host crash/power loss, privileged symlink, independent meter/seek domain and real unreleased writer. The current same-machine checks are not clean-OS/universal Windows support or exhaustive security certification. Keep normal preferences and source recordings intact; rollback uses a verified complete prior package in a separate folder, isolated settings and fresh exports. Raw diagnostics/audio/tools stay ignored.
