# Native-process and file-safety contract

Use small PowerShell helpers; do not build a new application framework. Maintain Windows PowerShell 5.1 and supported PowerShell 7 behavior.

## Implemented in WAC-M1-02 (2026-10-02)

`Get-WacFfmpegArguments` returns separate argument values and includes `-nostdin`.
`Invoke-WacNativeProcess` starts a resolved absolute `.exe` with
`UseShellExecute=false` and `CreateNoWindow=true`. The same Windows CRT quoting
helper is used in PS5.1/PS7, including empty values, embedded quotes and trailing
backslashes. NUL and an oversized Windows command line are rejected before start.
Sibling/PATH lookup resolves the executable's full path; full dependency probing
and explicit-path overrides remain M1-03.

Both UTF-8 readers begin before waiting; stdin is closed. The wrapper polls the
owned process, captures its actual exit and bounds stream-close waiting to five
seconds by default. All redirected readers/writer and the process are explicitly
disposed. A supplied timeout kills only the owned process and bounds cleanup;
zero means no total render timeout. Stdout/stderr are captured completely in
memory, separately; long-file/memory stress is not claimed. No shell callbacks,
global process-name termination or eval are used.

Current application codes:

| Code | Meaning |
| --- | --- |
| 0 | Native exit 0, validated audio published, and report complete. |
| 2 | Input/configuration/destination or launcher usage error. |
| 3 | Missing dependency or process start failure. |
| 4 | Native nonzero exit or process/capture/cleanup failure. |
| 5 | Output allocation, space/size check, validation, publication or owned-partial cleanup failure. |
| 7 | Published audio with report-write or report-metadata failure; audio is retained. |
| 130 | Mode-menu cancellation; running-render Ctrl+C exit semantics are not certified. |

Native status and diagnostics remain distinct from report errors. A report failure
preserves an earlier code 3/4/5. Code 6 (batch partial failure) remains a proposal
for its owning task. Code 5 is implemented by M1-04 below.

The `.bat` uses fixed PowerShell code with paths passed through environment
values and saves the result before pausing. Its default single-drop route uses
the system Windows PowerShell executable. `/unattended Raw|Zoom` requires
`WAC_LAUNCH_INPUT` and `WAC_LAUNCH_OUTPUT_DIRECTORY` set from PowerShell, passes
no path through CMD arguments and skips pause. Positional percent/exclamation
forms are rejected when observable in the received value/original CMD invocation.
Expansion that happened in an already-open CMD session cannot be reconstructed;
document direct PowerShell or the environment route for such names. Multi-file
handoff remains M3-02. Tests include real native argv, default handoff/pause with
a controlled application, and full-app unattended results in both outer shells.

Evidence and exact limits: `evidence/WAC-M1-02.md`. The sections below retain
requirements for later probing, transactional output and cancellation work.

## Implemented in WAC-M1-03 (2026-10-02)

The dependency and stream policy is D22 in DECISIONS.md. `-FfmpegPath` takes
precedence over the script sibling and PATH; `-FfprobePath` takes precedence over
the resolved FFmpeg sibling and PATH. An invalid chosen candidate never silently
falls back. Bounded native version/filter checks validate tool identity and
selected-mode filters. Paths/versions appear in the console and render report.

`Get-WacAudioStreams` runs ffprobe JSON inspection with a 15-second process
deadline, rejects native and metadata failures, and returns validated audio
indexes/codec/channel/rate fields. `Select-WacAudioStream` auto-selects a single
track, prompts for interactive ambiguity, and requires `-AudioStreamIndex` for
unattended ambiguity. Cancellation is 130; invalid selection is 2. Dependencies
use 3; probe/metadata/no-audio failures use 4. Early failures use console
diagnostics; no render report is fabricated for an unstarted render.

Both tools receive the same file-only protocol and ordinary-media demuxer
allowlists before `-i`. Unsupported playlists/concat inputs fail before cleaning,
including renamed files. Rendering uses `-map 0:N`, where N is
the selected absolute index, and preserves the selected channels. No automatic
downloads or runtime Python dependency are introduced. Render encoding,
collision/overwrite behavior and cancellation limits still belong to later work.

## Implemented in WAC-M1-04 (2026-10-02)

`WinAudioClean.IO.ps1` is a required sibling helper. Its lazy Windows declarations
use stable file identities and handles for owned partials and publication; both
scripts can be imported without running native compilation or filesystem work.
The source is opened read-only with read sharing before inspection and held
through reporting. Canonical handle paths account for supported junction aliases.
Filesystems that cannot establish the required identities fail closed.

A random 128-bit job ID appears in the partial and final names. CreateNew
exclusively reserves `.wac-<id>.partial` in the pinned destination directory.
FFmpeg receives that owned partial with explicit `-f wav`; its `-y` cannot address
the final name. After exit 0, bounded ffprobe inspection precedes a read/delete
handle that prevents further writing. Identity is checked again, and the exact
held PCM file is structurally validated and renamed by handle without replacement.
The final name is `<stem>_Cleaned_yyyyMMdd-HHmmssfff_<id>.wav`.

Require one readable PCM audio stream, nonempty aligned sample data, consistent
RIFF/chunk/format sizes and agreement between the probe and the PCM parameters.
Compare sample-count duration with the selected input track: 10 ms tolerance for
PCM, 100 ms for compressed padding. Prefer stream duration; Matroska's per-stream
DURATION tag minus start time is a fallback. Never substitute container duration.
Unknown selected timing fails before rendering. RF64 is explicitly rejected here;
output rate/encoding and early size/space policy remain M1-05.

Failure cleanup marks only a matching owned file for deletion by handle. A
foreign replacement is retained with a diagnostic. A crash can leave an
identifiable partial; later runs never sweep it. Report paths are held against
replacement and reject reparse files or multiple hardlinks before Add-Content,
protecting prior audio from report aliases. Reporting follows publication and
retains audio if it fails. Output errors use code 5; native failures retain their
own codes and diagnostics. Evidence: `evidence/WAC-M1-04.md`.

## Arguments and execution [S02]

Treat executable paths and every user path as data. Avoid Invoke-Expression, cmd /c construction from user strings, expression-valued configuration and arbitrary filter strings. Start-Process joins ArgumentList items into a command line; simply changing a string to a string array does not solve quoting. Modern ProcessStartInfo.ArgumentList is not available in the same form on all target runtimes. Isolate and test any compatibility quoting path rather than assume equivalence.

Run only the resolved FFmpeg/ffprobe executable. Verify exact child argv using an argument-echo fixture on Windows. Test spaces, trailing backslashes, brackets, Unicode, apostrophes, parentheses, &, %, ! and path-length boundaries through the actual .bat. CMD/PowerShell -File array expansion is a separate boundary: do not certify it by direct PowerShell tests alone. Reject unrepresentable input with a safe alternative rather than silently corrupt it.

Input paths must resolve to existing local filesystem files; explicit supported UNC paths can still reside on a network share. Do not advertise physical offline storage for them. Reject URLs and block external-media references where supported by an allowlisted protocol/demuxer policy. Disable stdin for unattended child jobs. Never turn repository/user media metadata into commands.

## Lifecycle and output

Drain stdout and stderr concurrently, close handles, handle launch exceptions and observe exit status after process exit. Progress belongs on a dedicated structured stream; error logs are not the progress parser. A probe must have a timeout; long audio renders need user cancellation and a sensible inactivity policy, not an arbitrary short total timeout. Avoid false failure for long normal jobs.

The original proposed map was 0 success; 2 invalid input/config; 3 missing/incompatible dependency; 4 probe/processing failure; 5 output-validation/publication failure; 6 batch completed with failed items; 130 cancelled. The implemented table above now defines current codes, including reporting warning 7. Native FFmpeg exit codes remain in diagnostics when mapped to application codes. Preserve script status before launcher pause.

## Files and cancellation

Allocate a unique job directory/temp filename in the final destination volume, explicitly choose WAV even if the filename ends in .partial, and use no-clobber semantics. Only after exit 0 and successful probe/format/duration checks may a no-overwrite move publish the final name. Defend the rename race, not just Test-Path before launch. Timestamp seconds alone are not a concurrency guarantee.

No input/output alias, including normalized paths and supported link/file-identity cases. Cancellation targets the owned process object/ID for that run, not every ffmpeg.exe. Remove only files whose ownership was established by that run. Do not sweep user directories, delete prior exports, or clean unrelated processes. Crash leftovers need explicit identification and optional cleanup, not an unsafe startup purge.

## Implemented in WAC-M1-05 (2026-10-02)

The export policy in AUDIO_CONTRACT.md now requires explicit 48 kHz PCM16/24,
mono/stereo layout preservation and optional prechain stereo-to-mono conversion.
The process receives separate codec/rate/channel/layout/container arguments;
source metadata/chapters are omitted. Default RIFF exports that exceed the
conservative size boundary fail before rendering with `-Rf64` guidance. RF64 is
explicit, including small files, and its ds64 sizes/sample counts are validated
on the held file. Earlier M1-04 statements that RF64 was unsupported remain
historical; this section supersedes that limitation.

`Get-WacAvailableOutputBytes` queries GetDiskFreeSpaceExW using the resolved held
destination directory, not the input drive or an unpinned user path. Use caller
available bytes (quota aware), not total free space. Unknown capacity or an
estimate larger than availability fails with code 5 and owned cleanup. The
same-volume partial/final rename needs one audio allocation plus headroom;
concurrent writers can still consume space afterward. Invalid export settings
or unsupported layouts use code 2. Missing `pan` for requested stereo-to-mono
uses code 3. All native diagnostics/publication/cleanup guarantees above remain.
