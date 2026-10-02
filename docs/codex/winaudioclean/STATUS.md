# Current status

Date: 2026-10-02. **WAC-M1-05 is complete.** M0-01 through M0-04 and M1-01
through M1-04 remain complete. AC-001 through AC-027 pass. Nine tasks are done;
21 remain todo.

**Next: WAC-M1-06 — produce readable, structured, privacy-aware run reports.**
Stop after synchronizing this M1-05 checkpoint.

## Current behavior

- Explicit 48 kHz signed PCM16 WAV; `-BitDepth 24` offers PCM24. Preserve exact
  Raw/Zoom profiles, entry points, literal paths, dependency/track policy and
  owned transactional publication.
- Preserve standard mono/stereo layouts and order; missing labels infer from
  channel count. Reject other/mismatched layouts and multichannel input.
  `-Mono` explicitly averages stereo before the original chain. Exported files
  omit source metadata/chapters.
- Default RIFF size estimate includes 101 ms timing slack and 1 MiB headers;
  free-space reserve is max(64 MiB, ceil(10% of file bytes)). Query quota-aware
  available capacity through the pinned destination. A conservative RIFF estimate
  above 4,294,967,295 bytes fails early with `-Rf64` guidance. Explicit RF64 is
  validated with strict 64-bit ds64 sizes/frame counts before held-handle rename.
- Early invalid settings/layout return 2; space/size failures return 5. Native
  and reporting codes remain unchanged. Never silently truncate or split audio.

## Validation

Windows NT 10.0.26300.0; PS5.1.26100.9444; PS7.6.5; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0; existing FFmpeg/ffprobe 9.0.2.

- Final Full per shell: **487 Pester passed, zero failures/skips; 61 Python
  passed, one symlink-privilege skip**, both runner exits 0; all recorded source
  hashes unchanged. Parser: 23 PowerShell files. Static/plan pass; 98 analyzer
  advisories are non-gating and retained.
- Encoding targeted 48/48; Validation 70/70; corrected entry subset 16/16 per shell.
- Real encoding harness **40/40**, including 32 format-matrix, four mono and four
  small RF64 runs across both shells. All outputs are exactly 6 s; independently
  measured channel content/boundary silence and zero-lag PCM/reference equality
  pass. Runtime/harness/fixture hashes stay unchanged.
- Real transaction regression **30/30**, 32 application invocations. MP3/AAC,
  concurrency, failure cleanup and crash/race cases pass under the new 48 kHz
  policy; inputs/prior exports stay unchanged.

[Evidence, development corrections and reproduction](evidence/WAC-M1-05.md).
Earlier evidence is preserved. Initial stale argument-count assertions and a
PS5 junction fixture issue were corrected without runtime changes; final checks
pass. No machine-security settings changed. The source manifest identifies the
exact working bytes tested; the pushed Git commit can normalize line endings.

## Remaining boundaries

The original Raw chain has an approximately 25 ms marker delay on these fixtures.
An independently rendered legacy 192 kHz output confirms it predates this export
change; explicit 48 kHz marker positions differ by under 0.009 ms. No filter delay
was silently corrected and no speech-quality approval is claimed.

Full >4 GB output, real disk exhaustion, speech listening, long-file/memory stress
and running-render Ctrl+C remain unverified. Space checks cannot reserve capacity
against competing jobs. Native capture remains in memory. No CI workflow exists.
Versioned/private-safe per-run reporting remains M1-06.

## Checkout and delivery

Use the established WinAudioClean-governance checkout on `codex/wac-m1-reliability`;
preserve the source-only starting folder. Exact fetch/push origin:
https://github.com/PikkuJanne/WinAudioClean.git.
Starting checkpoint: `afbf25aa8f935517a2a14b0f5fa655cb8a8c6e7e`.
[Draft PR #2](https://github.com/PikkuJanne/WinAudioClean/pull/2) remains stacked
on `codex/wac-m0-handoff`; draft PR #1 is open/unmerged. Actual completion SHA and
fresh local/live/PR verification belong in PR/final response.

Delivery note: the main script and README retain their tracked CRLF line endings.
Main bytes equal the Full/real-tested source after newline normalization. Final
Quick passed 300/300 in both shells on delivery bytes; the source manifest retains
Full and delivery hashes separately. No logic changed after the Full gate.
