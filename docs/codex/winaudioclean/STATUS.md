# Current status

Date: 2026-10-02. **WAC-M1-07 and milestone M1 are complete.** M0-01 through
M0-04 and M1-01 through M1-07 are done. AC-001 through AC-033 pass. Eleven tasks
are done; 19 remain todo.

**Next: WAC-M2-01 — Correct audio claims and name the Original preset.**
Start it separately after fresh synchronization verification. No M2 runtime
work is included in this checkpoint.

## M1 reliability gate

The runtime, launcher, fixtures, test code and harnesses remain unchanged from
M1-06 (`ca82376ae60560541fb0985c7c565c7872e3bba4`). M1-07 adds a file-safety and
compatibility review, test instructions, fresh evidence and the next handoff.
No known source/prior-export overwrite, broad cleanup, ambiguous publication
or false-success defect was found in the reviewed paths and fault cases.

Windows NT 10.0.26300; PS5.1.26100.9444 / PS7.6.5; Python 3.14.6;
Pester 5.7.1 / PSScriptAnalyzer 1.24.0; FFmpeg/ffprobe 9.0.2:

- Quick: **332 passed per shell**; focused M1 gate: **158 passed per shell**.
- One Full run per shell: **543 Pester passed, zero failures/skips; 61 Python
  passed plus one symlink-privilege skip**, runner exits 0. Parser 25 files;
  static/plan gates pass with 112 visible non-gating analyzer advisories.
- Fresh real transactions: **30/30 cases**, 32 application invocations.
- Fresh real reporting: **24/24 cases**, 24 renders plus four diagnostic CLI
  invocations. Source, prior exports and prior summary content survived the
  tested failures. Runtime/harness hashes remain stable and match Full.
- [Evidence and commands](evidence/WAC-M1-07.md),
  [write/cleanup review](evidence/WAC-M1-07-review.md), and
  [all 37 tested source identities](evidence/WAC-M1-07-source.json).

## Current behavior and boundaries

Literal preflight, dependency/track inspection, owned and validated collision-
safe publication, explicit 48 kHz PCM16/24, optional mono/RF64 and structured
local reports remain implemented. Original Raw/Zoom filters and PS1/BAT entry
points remain. See DECISIONS.md D20-D25 and the native/audio/data contracts.

Successful published audio with incomplete reporting returns WARNING/7;
processing failures retain their primary codes. Per-run files use exclusive
creation; the summary serializes append/rollback. Diagnostic export is explicit,
local, typed, no-overwrite and capped at 16 MiB. No audio or diagnostics upload.

Full >4 GB output, actual disk exhaustion, speech listening, long-file/memory
stress and running-render Ctrl+C remain unverified. Native capture remains in
memory; space is not reserved against competing writers. Reports lack multi-
file atomicity and power-loss guarantees. Early pre-render failures remain
console-only. The legacy Raw marker delay (~25 ms) is unchanged. Independent
loudness is not measured. Legacy README/help quality claims are assigned to
M2-01 and are not endorsed by the reliability results.

## Checkout and delivery

Use WinAudioClean-governance on `codex/wac-m1-reliability`; preserve the original
source-only folder. Exact effective fetch/push origin:
https://github.com/PikkuJanne/WinAudioClean.git.
[Draft PR #2](https://github.com/PikkuJanne/WinAudioClean/pull/2) remains stacked
on `codex/wac-m0-handoff`; draft PR #1 is open/unmerged. There is no CI workflow
or check run; local results do not imply CI success.

The completion SHA and final clean local/live/PR equality are recorded in the
PR/final response, avoiding a recursive evidence commit. For M2, inspect and
create/reuse `codex/wac-m2-audio` from the verified M1 tip; while PR #2 remains
unmerged, stack the M2 draft on `codex/wac-m1-reliability`. No merge, release,
default-sound change, repository setting change or deployment is authorized.
