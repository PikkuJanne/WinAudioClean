# WinAudioClean — Automated Audio Cleaning & Leveling Droplet (PowerShell + FFmpeg)

A "drop-and-forget" audio post-production tool for podcasters, students, and professionals who just want their audio to sound good. Audio engineering is complex, but this script treats it like a laundry machine, drop dirty audio in, get clean, broadcast-ready audio out. It combines standard noise reduction with loudness normalization to make recordings sound consistent and professional. I use it to process Zoom recordings and voiceovers without opening a DAW.

**Synopsis**

- Two Modes: "Raw Recording" (Clean + Level) and "Zoom/Teams" (Level Only).

- Robust Cleaning: De-clips distortion, cuts rumble (80Hz), de-clicks mouth noises, and gates background hiss.

- Broadcast Leveling: Uses dynamic gain leveling (85%) and loudness limiting (-12dB RMS) to match industry standards.

- Detailed Logging: Writes a report for every file to the Music folder, tracking size, duration, and filter chains.

- Non-Destructive: Always saves a copy (timestamped _Cleaned file), never overwrites the original.

- Visual Feedback: Simple colored text interface that stays open until you see the result.

**Requirements**

- Windows 10 or 11

- Windows PowerShell 5.1 (built-in) or PowerShell 7+

- FFmpeg and ffprobe Windows executables, installed by you (see lookup order below)

**Nice to have**

- A basic understanding of whether your audio is "Raw" (from a mic) or "Processed" (from Zoom/Teams), so you choose the right mode (smiley)

**Files**

Place these together (e.g. C:\Tools\WinAudioClean\):

- WinAudioClean.ps1
  - Main script: handles the TUI, calculates linear gate values, runs FFmpeg, and logs the report.

- WinAudioClean.IO.ps1
  - Required sibling helper for Windows file ownership, validation locks and safe publication.

- WinAudioClean.bat
  - Simple launcher: enables drag-and-drop functionality for audio files.

- ffmpeg.exe
  - The engine: Download this from gyan.dev or similar. The script cannot run without it.

- ffprobe.exe
  - Inspects the available audio tracks before processing. Usually included in the same FFmpeg distribution.

**Installation**

1. Copy the files to a folder of your choice, e.g.: C:\Tools\WinAudioClean\

2. Put ffmpeg.exe and ffprobe.exe inside that folder, or configure their paths as described below.

3. (Optional) Create a desktop shortcut to WinAudioClean.bat and name it something friendly: "Audio Cleaner"

**Usage**
**Recommended: Drag-and-Drop**

1. Drag an audio file (WAV, MP3, M4A, MKV, etc.) onto the WinAudioClean.bat icon.

2. A window will open asking for Mode Selection:
   - Type 1 for Raw Recording (Microphone audio that needs noise removal).
   - Type 2 for Zoom/Teams (Meeting audio that is already noise-cancelled).

3. Press Enter.

4. Wait for the green SUCCESS message.

5. Find your new file in your Music folder.

**Command line**

Run from a PowerShell prompt:

.\WinAudioClean.ps1 -inputPath "C:\Path\To\MyRecording.wav"

You will see the same interactive menu and the same final log output.

**Input, destination and mode checks**

The script checks the input and destination before showing the mode menu. Input
must be an existing, readable, nonempty file. Paths are handled literally,
including spaces, square brackets, apostrophes and Unicode characters. URLs,
PowerShell provider paths, alternate data streams, UNC and device paths are not
supported. Use ordinary Windows drive paths or paths relative to your current
PowerShell directory. Mapped drives and redirected folders can still use network
storage; a drive path does not guarantee that a recording is physically offline.

Music remains the default destination. Use `-OutputDirectory` to choose another
folder; the script creates it if needed and checks that it can write there. An
empty or invalid destination fails before the menu. These checks establish file
accessibility; they do not prove that FFmpeg can decode the media.

At the menu, enter `1` for Raw, `2` for Zoom/Teams, or `Q` to cancel. Empty and
invalid choices ask again. A mode can also be supplied directly:

```powershell
.\WinAudioClean.ps1 -inputPath 'C:\Audio\meeting [draft].wav' -Mode Zoom -OutputDirectory 'C:\Audio\Cleaned' -NonInteractive
```

`-Mode` accepts `Raw` or `Zoom`. `-NonInteractive`, a noninteractive host, and
redirected input require an explicit mode and never show a mode prompt. Running
without an input file displays usage. Direct script preflight failures return
exit code `2`; menu cancellation returns `130`.

**Dependencies and audio tracks**

FFmpeg lookup order is `-FfmpegPath`, then `ffmpeg.exe` next to the script, then
`PATH`. FFprobe lookup order is `-FfprobePath`, then `ffprobe.exe` next to the
resolved FFmpeg executable, then `PATH`. Explicit paths are literal `.exe` file
paths; a supplied invalid path fails without falling back to another installation.
A broken sibling executable also fails. Nothing is downloaded automatically.

The script checks each tool's version response and the filters needed for the
selected mode. It displays resolved paths and versions and includes them in the
processing report. Use a Windows build with both executables and the required
filters; a recognized version string alone does not guarantee codec support.
Each version, filter and media inspection has a 15-second process timeout, plus
bounded cleanup. This limit does not apply to rendering.

One audio track is selected automatically. For multiple tracks, the interactive
menu shows absolute stream indexes, codecs, channels, sample rates and available
language/title labels. Choose an index or `Q` to cancel. Unattended processing
requires an explicit `-AudioStreamIndex` when more than one audio track exists:

```powershell
.\WinAudioClean.ps1 -inputPath 'C:\Audio\interview.mkv' -Mode Zoom -AudioStreamIndex 2 -FfmpegPath 'C:\Tools\ffmpeg\bin\ffmpeg.exe' -FfprobePath 'C:\Tools\ffmpeg\bin\ffprobe.exe' -OutputDirectory 'C:\Audio\Cleaned' -NonInteractive
```

The index is the file's absolute stream index, including any video streams. For
example, video at index 0 and audio at indexes 1 and 2 means `-AudioStreamIndex 2`
selects the second audio track. The selected track is explicitly mapped and its
channel count is preserved unless `-Mono` is requested. Video-only input fails before cleaning. Use the
PowerShell entry point for unattended stream selection or explicit tool paths;
the batch launcher's `/unattended` route supports a single audio track.

Supported input containers are WAV, MP3, FLAC, Ogg, MOV/MP4/M4A, Matroska/WebM,
AAC, AIFF, ASF and AVI, subject to the installed build's decoders. Both probing
and rendering allow only these demuxers and the `file` protocol. Playlists,
concat lists, network protocols and device inputs are unsupported, even when a
playlist is renamed to an audio extension. This prevents supported FFmpeg
protocols from fetching remote media references; filesystem redirection or
mapped drives can still use network storage. Malformed metadata, failed probes,
and inputs without a usable audio codec, channel count and sample rate fail
before rendering. The selected audio track must also expose a usable duration;
files with unknown track timing fail safely before rendering.

**Output format and channels**

Exports use **48 kHz, 16-bit signed PCM WAV**. This intentionally replaces the
previous unspecified encoder output, which produced 192 kHz PCM16 with the tested
FFmpeg build. The original Raw/Zoom filters are unchanged; exported samples are
not bit-identical to the earlier files. Use `-BitDepth 24` for 24-bit editing files:

```powershell
.\WinAudioClean.ps1 -inputPath 'C:\Audio\interview.wav' -Mode Raw -BitDepth 24 -NonInteractive
```

Mono stays mono; stereo preserves left/right order. If a mono/stereo file has no
layout label, the channel count defines the standard mono/stereo layout. Other
layouts, mismatched labels and more than two channels fail before rendering.
Prepare a standard mono/stereo track explicitly for these inputs. `-Mono` opts
into an equal-weight left/right mix before the original processing chain; it
does not enable multichannel input. Source metadata and chapters are omitted
from the audio export. Use the PowerShell entry point for these export options;
drag-and-drop retains the defaults.

**Large files and destination space**

Ordinary RIFF WAV is the default. Before rendering, the script estimates PCM
bytes from the selected track's duration, allows 101 ms for rounding/padding and
1 MiB for headers, then adds the greater of 64 MiB or 10% as free-space headroom.
The temporary file becomes the final file by rename, so only one audio copy is
budgeted. Available space is checked for the actual destination and current
user's quota. Unknown capacity and insufficient space fail with exit `5`.
Other jobs can consume space after this check; a later failure still cannot
publish a partial export.

An estimate above the conservative RIFF limit (4,294,967,295 bytes including
the header allowance) fails before rendering. Use `-Rf64` to request RF64 WAV
explicitly, even for a small file. Check that your editor supports RF64:

```powershell
.\WinAudioClean.ps1 -inputPath 'C:\Audio\long-session.wav' -Mode Zoom -BitDepth 24 -Rf64 -NonInteractive
```

No duration is silently cut and files are never split automatically. RF64 header
handling and size-boundary estimates are tested with small synthetic files;
full exports larger than 4 GB and real disk exhaustion have not been stress-tested.
The [FFmpeg WAV documentation](https://ffmpeg.org/ffmpeg-formats.html#wav)
describes RF64 compatibility.

**Safe exports**

Each run reserves `.wac-<job-id>.partial` in the destination folder and renders
WAV into that owned file. A successful process must then pass audio, PCM size,
sample-count, channel and duration checks. Only then is it renamed to
`<name>_Cleaned_<timestamp>_<job-id>.wav`. The rename refuses an existing file,
including one created while processing. Repeated and concurrent runs get unique
job IDs. The source is held against writing through processing and reporting.
The report writer rejects linked log files that could redirect an append into
existing audio; a report failure retains the completed export and returns `7`.

Timing is checked against the selected audio track, never a longer video or
container duration: at most 10 ms difference for PCM, or 100 ms for compressed
audio to allow codec padding. This verifies file completeness and plausible
timing; it does not certify perceived quality or achieved loudness.

Failures remove only the current run's owned partial. An abrupt crash may leave
a `.wac-<job-id>.partial` file. It is not a completed export; inspect it and remove
it manually once that job has stopped. Later runs preserve these leftovers.
RIFF and explicitly requested RF64 sizes, PCM format and sample counts are checked
on the held file before publication.

**Run reports and sharing diagnostics**

After a render attempt, the destination contains `WinAudioClean_<job-id>.json`
and `WinAudioClean_<job-id>.txt`. The shared `WinAudioClean_Log.txt` retains a
human-readable entry for each run. Unique report names refuse existing files;
summary entries use an exclusive writer so concurrent jobs cannot interleave.
Early input, dependency, selection and space errors remain console-only.

The version 1 JSON records the selected stream, exact filters, requested output
format, verified audio, native diagnostics and processing/reporting outcomes.
Input recording duration and elapsed rendering time are separate fields.
Loudness and true-peak measurements are currently `null` with a reason; successful
export validation does not claim that a loudness target was achieved.

Published audio remains available if a report cannot be written. The console
returns `7` for a successful export with incomplete reporting; an earlier
processing failure keeps its own code. Surviving reports are corrected to that
outcome where storage permits. A crash or unrecoverable write/rollback failure
can leave incomplete report files. Use the console exit and diagnostics to
resolve those cases; do not treat an incomplete file as a completed report.

Detailed reports stay local and can contain paths, filenames, stream metadata
and sensitive native diagnostics. To create a separate support copy, replace
the example report path below with the JSON path from your run:

```powershell
.\WinAudioClean.ps1 -ExportDiagnostic 'C:\Audio\Cleaned\WinAudioClean_0123456789abcdef0123456789abcdef.json' -DiagnosticOutputPath 'C:\Audio\Cleaned\wac-support.json'
```

The source must be a supported version 1 report no larger than 16 MiB. The
destination's parent folder must already exist, and its filename must be new.
This command runs without FFmpeg and cannot be combined with audio-processing
options. It creates an allowlisted diagnostic JSON with numeric values, booleans
and fixed labels; it omits all free-form source text, paths, filenames, titles,
timestamps, job IDs, dependency banners and raw diagnostics. **Review the export
before sharing it.** Nothing is uploaded automatically; the raw report remains
unchanged. See the [report format](docs/codex/winaudioclean/DATA_FORMATS.md).

New per-run reports use UTF-8 without a BOM. The summary preserves an existing
BOM and its encoding. For a summary without a BOM, valid UTF-8 is retained;
otherwise the current Windows ANSI code page is used. If an entry cannot be
encoded safely, reporting fails rather than replacing existing bytes.

**Native results and launcher automation**

The script runs the resolved FFmpeg executable directly, disables its stdin and
captures stdout and stderr separately. Native failure details appear in the
console and local report. Processing and reporting results use these exit codes:

| Code | Meaning |
| --- | --- |
| 0 | Audio was validated and published; reporting completed. |
| 2 | Invalid input, destination, mode, audio selection, export settings/layout or launcher usage; ambiguous unattended tracks; diagnostic export failure. |
| 3 | Missing, incompatible or filter-deficient dependency, or render process start failure. |
| 4 | Probe/metadata failure, no audio, or processing/capture/cleanup failure. Native failures retain diagnostics. |
| 5 | Output allocation, space/size check, validation, publication or owned-file cleanup failed. |
| 7 | Audio was published, but reporting was incomplete. Audio is retained. |
| 130 | Cancelled at the mode or audio-track menu. |

A reporting failure never changes an existing processing failure to success.
An invalid output is never presented as a completed export. Native diagnostics
remain available when publication fails after FFmpeg returns zero.

The batch launcher preserves the script's exit code across its interactive
pause. Its default route still accepts one dropped file. CMD can expand `%NAME%`
and `!NAME!` in paths before the launcher sees them. When observable, the launcher
rejects these positional paths with a fallback message. An already-open CMD
session may have changed them earlier; use PowerShell directly or the following
route for these filenames and for unattended runs:

```powershell
# Set these values from PowerShell so CMD never receives the paths as arguments.
$env:WAC_LAUNCH_INPUT = 'C:\Audio\meeting %complete%!.wav'
$env:WAC_LAUNCH_OUTPUT_DIRECTORY = 'C:\Audio\Cleaned'
.\WinAudioClean.bat /unattended Zoom
$LASTEXITCODE
```

This route requires both environment values and `Raw` or `Zoom`, and skips the
pause. The launcher uses Windows PowerShell 5.1; direct script calls also support
PowerShell 7. Long native renders have no fixed total timeout. Diagnostics are
captured in memory per run; large recordings and very large diagnostic streams
have not been stress-tested.

**What it actually does (step-by-step)**

1. Checks
   - Verifies the input file exists.
   - Resolves and checks ffmpeg.exe and ffprobe.exe.

2. Mode Selection (TUI)
   - Asks the user if they want the full cleaning suite or just volume leveling.
   - This prevents "over-processing" artifacts on audio that was already cleaned by Zoom's algorithms.

3. Construct Filter Chain
   - Cleaning (Mode 1 Only):
     - adeclip: Repairs digital clipping (distortion) in loud peaks.
     - highpass: Cuts low-end mud and rumble below 80Hz.
     - adeclick: Smooths out mouth clicks and lip smacks.
     - afftdn: Reduces steady background noise (fans, hiss) by ~25dB.
     - agate: Silences the track when the volume drops below -45dB.
   - Leveling (Mode 1 & 2):
     - dynaudnorm: Dynamically boosts quiet sections to make volume consistent (matches Adobe's "Speech Volume Leveler").
     - loudnorm: A final limiter that ensures the average volume hits exactly -12 LUFS.

4. Processing
   - Probes audio tracks and maps the selected absolute stream index.
   - Runs FFmpeg invisibly in the background.
   - Shows a "Processing..." indicator in the console.

5. Logging
   - Writes per-run JSON/text reports and appends WinAudioClean_Log.txt in the selected destination.
   - Records recording duration separately from rendering time, along with file sizes, exact filters, diagnostics and outcome.

**Limitations / When not to use**

   - Extreme Noise: If you recorded in a wind tunnel or a busy cafe, standard signal processing isn't enough. You need AI isolation tools for that.
   - Multi-track editing: This processes one selected audio track. It cannot separate speakers mixed into that track.
   - Music Production: Do not use this on songs. The "De-clipper" and "Highpass" filters are tuned for human speech and will damage the quality of musical instruments.

**Troubleshooting**

- Dependency failure
  - Check the reported executable path. Supply `-FfmpegPath` and `-FfprobePath`, place both tools together next to the script, or add them to PATH. Missing required filters need a compatible FFmpeg build.

- Probe failure or multiple audio tracks
  - Check that the file uses a supported container and contains audio. For unattended multi-track files, supply the absolute `-AudioStreamIndex` shown in the diagnostic.

- Red "FAILED" text
  - Check the console output right above the error. It usually means the input file is corrupt or has a codec FFmpeg doesn't understand.

**Intent & License**

Personal helper for my own content creation workflow, "I just want this recording to sound professional so I can upload it." Provided as-is, without warranty. Use at your own risk. Feel free to fork, trim, or extend it to fit your own loudness standards.
