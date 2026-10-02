# Current status

Date: 2026-10-02. **WAC-M1-02 is implemented but blocked at validation.**
M0-01 through M0-04 and M1-01 remain complete. AC-001 through AC-015 remain
accepted. AC-018 passes; AC-016/017 are blocked pending a green cumulative gate.
The remaining 24 tasks are todo. **Resume WAC-M1-02; do not start M1-03.**

## Current behavior

- Literal input/destination preflight and explicit Raw/Zoom modes from M1-01
  remain. Music is the default destination; menu cancellation exits 130.
- Native execution uses a resolved absolute executable and tested Windows
  argument quoting. Both output streams drain concurrently, stdin closes, and
  FFmpeg receives -nostdin. Readers and the process are explicitly disposed.
- Exit codes: 0 native success/report complete; 2 input/config; 3 missing/start
  dependency; 4 native/capture/cleanup failure; 7 native success with incomplete
  reporting; 130 menu cancellation. Logs preserve both diagnostic streams and
  native/application exits. Reporting failures retain any earlier native failure.
- The original launcher preserves status across pause. /unattended Raw|Zoom
  reads input/output paths from environment variables set in PowerShell and
  skips pause. CMD percent/exclamation expansion has documented limitations;
  direct PowerShell or the environment route preserves those names.
- Exact Raw/Zoom filters, unspecified output encoding and legacy -y/collision
  behavior remain. See D21 and NATIVE_PROCESS_CONTRACT.md.

## Validation and blocker

Windows NT 10.0.26300.0; PS5.1.26100.9444; PS7.6.5; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0. No tools or policies were installed/changed.

- Targeted runs passed: helpers 13, direct entry points 64, launcher 58,
  reporting 8, native wrapper 21 per shell before two additional rejection cases.
- Both Full runs executed 227 Pester cases. PS5.1: **167 passed / 60 failed**.
  PS7: **220 passed / 7 failed**. Both returned 1. They did not reach Python.
- All 23 native wrapper cases passed in each Full run, including exact argv,
  simultaneous 512 KiB stdout/stderr with end markers, stdin EOF, native exit,
  start failure, command limit and bounded timeout/reaping.
- Windows Code Integrity events 3033/3077 match 44 blocked launcher fixture
  copies and seven blocked reporting fixture copies. These were compiled benign
  test executables, not the actual FFmpeg distribution. No security changes or
  repeated fixture retries were made after this Full-run diagnosis.
- The other 16 PS5.1 failures were test-only JSON array nesting. Array assignment
  was corrected and assertions now expose child errors. Final Quick checks
  parse these changes; native integration after correction is still blocked.
- Four real application runs (Raw/Zoom on both shells) passed with existing
  FFmpeg 9.0.2, readable three-second mono WAVs/reports and unchanged inputs.
  ffprobe measured the unchanged 192 kHz PCM16 encoding.
- Final Quick passed in both shells; independent Python suite passed 61 with
  one symlink-privilege skip. See the evidence for exact commands/counts.
  Parser/static/plan gates passed with 53 visible analyzer advisories.

See [M1-02 evidence](evidence/WAC-M1-02.md), source identities, failed Full logs,
policy correlation and real-process metadata. Passing targeted runs do not
override the failed cumulative gate. No CI workflow exists yet.

## Resume and boundaries

Resume the same M1-02 checkpoint after fixture execution is accepted by the
machine's existing security policy through normal administration. Do not disable
Code Integrity, add exclusions, or recompile/copy repeatedly to find an allowed
fixture. Run both Full gates and reconcile evidence before marking the task done.

M1-03 owns media probing/external references; M1-04 transactional export and
collision safety; M1-05 explicit encoding. Human speech listening, channel
isolation, impulse alignment, long recordings and >4 GB output remain unverified.
The four short synthetic runs make no sound-quality or release-readiness claim.

## Checkout and delivery

Use the established WinAudioClean-governance Git checkout; the source-only
starting folder is preserved. Effective fetch/push origin:
https://github.com/PikkuJanne/WinAudioClean.git.
Branch: codex/wac-m1-reliability. Starting checkpoint:
116380c0f6f722e5ff116b6aafc348c0fabdd9e5 (accepted M1-01).

[M1 draft PR #2](https://github.com/PikkuJanne/WinAudioClean/pull/2) is stacked on
codex/wac-m0-handoff while M0 draft PR #1 remains unmerged. This blocked checkpoint
must still be committed/pushed and live heads verified. Its final SHA belongs
in the PR/final response, not a self-referential evidence commit.
