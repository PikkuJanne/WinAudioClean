# WAC-M1-04 â€” Owned output and collision-safe publication

Date: 2026-10-02. Engineering status: **accepted** (AC-022/023/024).
Next: **WAC-M1-05**, after fresh live synchronization verification.

## Source and scope

Started clean and synchronized at `e2b5443b9aee11bb9be5d41750cdac66c808c7bd`
on `codex/wac-m1-reliability`. Effective origin fetch/push:
`https://github.com/PikkuJanne/WinAudioClean.git`. Draft PR #2 remains stacked
on `codex/wac-m0-handoff`; draft PR #1 is open/unmerged. The source-only starting
folder is preserved. No merges, releases or deployment were performed.

Final tested working-file SHA256:

- `WinAudioClean.ps1`: `b725d9de6186b8296c546887938a809c5546a78d048cf6b4036b5de7912d9c36`.
- `WinAudioClean.IO.ps1`: `1634f984ec713d8a5514e00965b9ac57fef0cef0e3bc02f06d5d0d7a5c90bb7e`.

`WAC-M1-04-source.json` records all 31 maintained runtime/development
source hashes, exact Full commands, exits and evidence hashes. Source bytes were
unchanged within each recorded run. After Full, the older media harness was
updated to track both runtime files and independently passed its 32-case gate;
the manifest retains both source snapshots. Application/Pester source did not
change. Git can normalize text line endings.

Changed areas: main script transaction/timing/PCM validation; new required IO
helper; updated native fixture and existing entry/launcher/report regressions;
new Transaction and Validation suites; real-output development harness; README,
D23, process contract, task/acceptance state and handoff. The original `.bat`,
exact Raw/Zoom filters and unspecified output encoder remain unchanged.

## Acceptance

| Case | Result and evidence |
| --- | --- |
| AC-022 | pass: same input twice rapidly, two same-stem sources, and simultaneous Raw/Zoom jobs produce unique exports in both shells. Sources and prior-export hashes stay unchanged. Handles/identities also protect source aliases and reserve partial names exclusively. |
| AC-023 | pass: encoder exit 17, simulated disk-full exit 28, invalid/empty/truncated/short output, failed output probing and report aliases are covered. Native failures remain application 4; invalid output uses 5. Abrupt pre-rename exit 99 leaves one identifiable partial and no final; a later successful run preserves it. No disk was actually filled. |
| AC-024 | pass: a foreign final created immediately before publication survives byte-for-byte; publication fails 5 and cleans only the owned partial. Exit 0 empty/truncated output cannot publish. WAV chunk/sample tests also reject repaired lengths hiding a short render and oversized extensible format data. |

The IO helper uses CreateNew and a random 128-bit ID. FFmpeg receives only
`.wac-<id>.partial`, with explicit `-f wav`. Its `-y` fills that owned partial.
After successful bounded probing, the same file identity is held against writes
and deletion while its PCM bytes are validated and renamed without replacement.
Final names are `<stem>_Cleaned_yyyyMMdd-HHmmssfff_<id>.wav`.

Input locking extends through reporting. Destination handles pin physical paths;
tests include a retargeted junction and attempted physical-directory renames.
Report guards reject reparse files/multiple hardlinks before appending. Failed
publication never reads a foreign final as successful output. Reporting failure
retains published audio with code 7 and preserves prior native/output failures.
Cleanup uses only an owned identity, retaining foreign replacements with a
diagnostic. Later runs never sweep crash leftovers.

Timing comes from the selected track, using stream duration or a Matroska
per-stream DURATION end timestamp minus start time. Unknown timing fails 4 before
rendering. PCM sample duration must agree within 10 ms; compressed audio allows
100 ms for padding. Channels, probe format and PCM headers/sample counts agree.
RF64 is rejected until M1-05. These checks establish file completeness and
plausible timing, not achieved loudness or perceived quality. See D23 and the
process contract for the implementation policy and primary API references.

## Local checks actually run

Windows NT 10.0.26300.0; PS5.1.26100.9444 and PS7.6.5; Python 3.14.6;
Pester 5.7.1; PSScriptAnalyzer 1.24.0; existing FFmpeg/ffprobe 9.0.2.

Final commands, each exit 0:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-OutputTransactions.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
python -X utf8 scripts/Test-MediaPreflight.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M1-04/media-regression-20261002-1310
```

- Full in each shell: **398 Pester passed, zero failures/skips; 61 Python passed,
  one symlink-privilege skip**. Parser: 22 PowerShell files. Static/plan gates pass;
  79 analyzer advisories remain visible. No security settings changed.
- Transaction: 27/27 per shell. Validation: 29/29 per shell. Helpers/Native: 36/36.
  Corrected naming subset: 52/52 per shell. Final Full covers all these cases again.
- Real harness: **30/30 cases**, 32 application invocations across both shells,
  unchanged runtime hashes. Independent samples confirm mono 440 Hz/stereo 880 Hz,
  channel counts and plausible duration. Real MP3 and AAC/M4A inputs pass too.
  Successful exports remain the existing 192 kHz PCM16 output on this build.
- Existing media harness after its hash update: **32/32**, unchanged main/IO
  hashes. Track-selection checks pass; its loopback listener receives zero media
  requests. `WAC-M1-04-media-regression.json` retains the detailed results.

The Full wrapper removes inherited PSMODULEPATH only in child environments so
PS5.1 initializes its own module defaults. The real harness does the same.
Fault cases use documented overrides in isolated app copies; original runtime,
copy, override, fixture and tool hashes are recorded. Production has no test-fault
environment switches. No recording is uploaded; only synthetic/sanitized evidence
is committed. Detailed results: `WAC-M1-04-real-output.json`, both Full logs and
the source manifest.

## Development corrections and limits

Initial naming assertions still expected minute/second timestamps: 44 failures
per shell. The corrected 52-case subsets pass. The first native rename design
returned Win32 87; the corrected held-file rename uses an absolute target resolved
from a pinned directory. Tests caught incompatible PS5 report sharing and
metadata-only handles that did not pin files/directories. Final guards use
write access for reports and read access for directories; both shells verify
their behavior. Review caught and fixed an extensible WAV size bound.

Two intermediate real runs passed all 30 cases but correctly exited 1 because
source changed while they ran. They are retained locally and excluded from final
acceptance. `WAC-M1-04-development.txt` records this history, targeted outcomes,
retained log hashes and IO review. Earlier task evidence remains unchanged.

No speech listening, true-peak/loudness certification, running-render Ctrl+C,
full >4 GB output, real volume exhaustion or power-loss durability is claimed.
Native capture remains in memory. Known-duration metadata is required; unsupported
file identity or header formats fail safely. Explicit PCM output/channel/space
and RF64 policy is the next task. No CI workflow/checks currently exist.

Engineering acceptance is separate from synchronization. After this evidence
commit, push the feature branch and record its exact live-verified SHA in PR #2
and the final response. Stop before M1-05.
