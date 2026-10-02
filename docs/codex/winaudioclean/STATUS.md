# Current status

Date: 2026-10-02. **WAC-M1-04 is complete.** M0-01 through M0-04 and M1-01
through M1-03 remain complete. AC-001 through AC-024 pass. Eight tasks are done;
22 remain todo.

**Next: WAC-M1-05 — specify PCM output, channel policy and large-file behavior.**
Stop after synchronizing this M1-04 checkpoint.

## Current behavior

- Preserve entry points, literal-path preflight, dependency precedence, explicit
  absolute stream mapping, file/demuxer restrictions and exact Raw/Zoom filters.
- `WinAudioClean.IO.ps1` is now a required sibling. Hold source and destination
  identities; reserve a uniquely named partial on the destination volume. Render
  only there with explicit WAV format. Validate probe/PCM structure, sample count,
  channels and selected-track duration, then rename without replacing a final.
- Failures remove only owned partials. Crashes leave identifiable partials; later
  runs preserve them. Report guards reject linked log files that could damage
  audio. Reporting failure retains a published export.
- Timing requires usable selected-stream metadata: 10 ms PCM/100 ms compressed
  tolerance. Unknown timing fails before render. RF64 remains unsupported.
- Exits: 0 validated/published/report complete; 2 preflight/selection; 3 dependency/
  start; 4 probe/native/capture/cleanup; 5 output allocation/validation/publication/
  owned cleanup; 7 published audio with incomplete report; 130 menu cancellation.

## Validation

Windows NT 10.0.26300.0; PS5.1.26100.9444; PS7.6.5; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0; existing FFmpeg/ffprobe 9.0.2.

- Final Full in each shell: **398 Pester passed, zero failures/skips; 61 Python
  passed, one symlink-privilege skip**, runner exits 0. 22 PowerShell files parse;
  static/plan pass, 79 analyzer advisories.
- Transaction 27/27 and Validation 29/29 per shell. Final Full includes native,
  filename/launcher, dependency/probe, report, alias/race and output-fault checks.
- Final real-output harness: **30/30**, 32 application invocations, unchanged
  runtime hashes. Repeats/same-stem/concurrency, MP3/AAC, invalid output, simulated
  encoder/disk errors, rename race and crash/recovery all pass in both shells.
  Source/prior hashes stay unchanged. Synthetic frequency/channels/duration pass.

See [M1-04 evidence](evidence/WAC-M1-04.md), its source manifest, Full logs,
real-output report and development history. Earlier evidence is preserved.
The existing media harness also passed 32/32 after its stability check was
extended to cover both runtime files; application/Pester source was unchanged.
No security settings changed. The raw runtime hashes are recorded in the manifest.

## Remaining boundaries

Encoding still follows the existing FFmpeg default (192 kHz PCM16 in these tests).
Explicit 48 kHz PCM16/24, channel/impulse checks, space estimates and RF64 policy are
M1-05. Native capture remains in memory. Speech listening, running-render Ctrl+C,
long-file/memory stress, real disk exhaustion and >4 GB output remain unverified.
No CI workflow exists.

## Checkout and delivery

Use the established WinAudioClean-governance checkout; preserve the source-only
starting folder. Branch: `codex/wac-m1-reliability`. Exact fetch/push origin:
https://github.com/PikkuJanne/WinAudioClean.git.

Starting clean/live-verified checkpoint: `e2b5443b9aee11bb9be5d41750cdac66c808c7bd`.
[Draft PR #2](https://github.com/PikkuJanne/WinAudioClean/pull/2) remains stacked
on `codex/wac-m0-handoff`; draft PR #1 remains open/unmerged. Record the actual
completion SHA and fresh local/live/PR verification in PR/final response.
