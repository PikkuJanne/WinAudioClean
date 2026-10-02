# Current status

Date: 2026-10-02. **WAC-M1-03 is complete.** M0-01 through M0-04 and M1-01/02 remain complete. AC-001 through AC-021 pass. Seven tasks are done; 23 remain todo.

**Next: WAC-M1-04 — make output publication transactional and collision safe.** Stop after synchronizing this M1-03 checkpoint.

## Current behavior

- Preserve literal path/destination preflight, the original entry points, exact Raw/Zoom filters, default Music destination and launcher exit handling.
- Resolve FFmpeg by explicit path, script sibling, then PATH; resolve ffprobe by explicit path, the selected FFmpeg's sibling, then PATH. Invalid selected tools fail without fallback. Nothing is downloaded automatically.
- Check tool versions and selected-mode filters. Each inspection has a 15-second process deadline plus bounded cleanup. Paths and versions appear in the console and render report.
- Validate ffprobe JSON and render with `-map 0:N` using the selected absolute stream index. A single audio track is automatic; interactive ambiguity prompts; unattended ambiguity requires `-AudioStreamIndex`.
- Both probe/render allow only the file protocol and documented ordinary-media demuxers. Playlists/concat/device/network inputs are unsupported even when renamed. Filesystem redirection can still reach network storage.
- Exits: 0 native success/report complete; 2 input/config/selection; 3 dependency/start; 4 probe/no-audio/native/capture/cleanup; 7 native success with incomplete reporting; 130 menu cancellation. Early failures use console diagnostics; rendering attempts produce reports.

## Validation

Windows NT 10.0.26300.0; PS5.1.26100.9444; PS7.6.5; Python 3.14.6; Pester 5.7.1; PSScriptAnalyzer 1.24.0; existing FFmpeg/ffprobe 9.0.2.

- Final Full in **each shell: 326 Pester passed, zero failures/skips; 61 Python passed, one symlink-privilege skip; runner exit 0**. All 19 PowerShell files parse. Static/plan gates pass; 67 analyzer advisories remain visible.
- New Media suite: 99/99 in each shell, including actual PATH lookup, ffprobe adjacency, native inspection failures and timeout/reaping. Existing preflight/native/entry/reporting/launcher regressions pass in Full.
- Real media: 32/32. Video index 0 plus 440 Hz mono index 1 and 880 Hz stereo index 2 verify absolute selection in Raw/Zoom in both shells. Eight readable three-second 192 kHz PCM16 WAVs retain expected frequency/channel counts; inputs remain unchanged.
- Ordinary and renamed HLS/concat lists fail in the app and direct render helper. A loopback listener received its positive control and zero media requests.
- Actual consoles: PS5.1 retries empty/invalid input, then Q exits 130 without audio/report. PS7 rejects video index 0, then audio index 2 processes successfully.
- Tested runtime SHA256: `4d2300a74698b272cb03469e98efb73d7ff1db86a15c24c6dd95292638add3ea`.

The first Python-driven PS5.1 Full invocation failed before tests because it inherited PS7 module paths. A child-only environment correction restored normal module discovery; unchanged source passed. The sanitized failure is retained. No security settings changed. Earlier M1-02 application-control failures and the owner's authorized resumption remain historical evidence.

See [M1-03 evidence](evidence/WAC-M1-03.md), its source manifest, both final Full logs and the real-media report. Only synthetic/sanitized evidence is committed.

## Remaining boundaries

Legacy `-y` and minute timestamp collisions remain until M1-04. Exit 0 still does not independently validate final media. Explicit encoding is M1-05. Native capture remains in memory; the JSON size limit is checked after capture. Running-render Ctrl+C, long-recording/memory stress, channel isolation, impulse alignment, human speech listening and >4 GB output remain unverified. No CI workflow exists.

## Checkout and delivery

Use the established WinAudioClean-governance checkout; the source-only starting folder is preserved. Branch: `codex/wac-m1-reliability`. Exact effective fetch/push origin: https://github.com/PikkuJanne/WinAudioClean.git.

Starting clean/live-verified checkpoint: `ec27fb9d5ecc7dd07033d889987ac153d65eb373`. [Draft PR #2](https://github.com/PikkuJanne/WinAudioClean/pull/2) remains stacked on `codex/wac-m0-handoff` while draft PR #1 is unmerged. Record this task's actual completion SHA and fresh local/live/PR verification in the PR/final response. Engineering acceptance and live synchronization are separate checks.
