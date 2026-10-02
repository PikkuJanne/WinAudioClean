# Current status

Date: 2026-10-02. **WAC-M1-02 is complete.** M0-01 through M0-04 and M1-01
remain complete. AC-001 through AC-018 pass. Six tasks are done; 24 remain todo.

**Next: WAC-M1-03 — resolve dependencies and probe/map audio streams.**
Stop after synchronizing this M1-02 completion checkpoint.

## Current behavior

- Literal input/destination preflight and explicit Raw/Zoom modes remain.
  Music is the default destination; menu cancellation exits 130.
- Native execution uses a resolved absolute executable and Windows argument
  quoting. Both output streams drain concurrently, stdin closes, and FFmpeg
  receives -nostdin. Readers and the process are explicitly disposed.
- Exit codes: 0 native success/report complete; 2 input/config; 3 missing/start
  dependency; 4 native/capture/cleanup failure; 7 native success with incomplete
  reporting; 130 menu cancellation. Logs retain separate diagnostic streams and
  native/application exits. Reporting failures preserve an earlier native failure.
- The original launcher preserves status across pause. /unattended Raw|Zoom
  reads input/output paths from environment variables set in PowerShell and
  skips pause. Direct PowerShell or this environment route preserves names
  containing percent/exclamation characters; earlier positional CMD expansion
  cannot be reconstructed.
- Exact Raw/Zoom filters, unspecified output encoding and legacy -y/collision
  behavior remain. See D21 and NATIVE_PROCESS_CONTRACT.md.

## Completed validation

Windows NT 10.0.26300.0; PS5.1.26100.9444; PS7.6.5; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0. Existing tools were reused.

- Resumed Full in **each shell: 227 Pester passed, zero failures/skips; 61 Python
  passed, one symlink-privilege skip; runner exit 0**.
- Parser/static/plan gates pass. All 18 PowerShell files parse; 53 analyzer
  advisories remain visible without suppression.
- This includes direct and batch filename matrices, startup/native/report errors,
  launcher pause/status, 23 native wrapper cases with simultaneous 512 KiB output
  streams, stdin EOF, command rejection and timeout/reaping.
- All 26 runtime/development source hashes match the saved blocked checkpoint.
  No runtime or test source changed during the successful resumption.
- Four earlier real application runs (Raw/Zoom on both shells) passed with
  existing FFmpeg 9.0.2, readable three-second mono WAVs/reports and unchanged
  inputs. Runtime hashes still match; these were not rerun. ffprobe measured
  the unchanged 192 kHz PCM16 output.

The initial Full runs failed when Windows Code Integrity rejected unsigned
test fixtures, alongside a corrected PS5 test-only JSON array issue. The owner
then reported Smart App Control Off and authorized the rerun; read-only registry
checks returned 0 before and after it. Codex made no security-setting changes.
The passing tests cover this environment, not unsigned fixtures under Smart App
Control On. Previous failure logs and policy records are retained.

See [successful resumption](evidence/WAC-M1-02-resume.md), its source manifest and
both Full logs. [Initial evidence](evidence/WAC-M1-02.md) remains historical.

## Remaining boundaries

M1-03 owns dependency discovery, media probing, stream selection and external
references. M1-04 owns transactional exports and collision safety; M1-05 owns
explicit encoding. Running-render Ctrl+C semantics, capture memory stress,
human speech listening, channel isolation, impulse alignment, long recordings
and >4 GB outputs remain unverified. No CI workflow exists yet.

## Checkout and delivery

Use the established WinAudioClean-governance Git checkout; the source-only
starting folder is preserved. Effective fetch/push origin:
https://github.com/PikkuJanne/WinAudioClean.git.
Branch: codex/wac-m1-reliability. This resumption started from the clean, live
verified blocked checkpoint 0d02cf48dcede1196024039294e9316f4624b50a.

[M1 draft PR #2](https://github.com/PikkuJanne/WinAudioClean/pull/2) is stacked on
codex/wac-m0-handoff while M0 draft PR #1 remains unmerged. Record this completion
commit's exact SHA and fresh local/live/PR-head verification in the PR/final
response. Engineering acceptance and live synchronization are separate checks.
