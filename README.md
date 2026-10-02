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

- FFmpeg (Must be downloaded and placed in the script folder)

**Nice to have**

- A basic understanding of whether your audio is "Raw" (from a mic) or "Processed" (from Zoom/Teams), so you choose the right mode (smiley)

**Files**

Place these together (e.g. C:\Tools\WinAudioClean\):

- WinAudioClean.ps1
  - Main script: handles the TUI, calculates linear gate values, runs FFmpeg, and logs the report.

- WinAudioClean.bat
  - Simple launcher: enables drag-and-drop functionality for audio files.

- ffmpeg.exe
  - The engine: Download this from gyan.dev or similar. The script cannot run without it.

**Installation**

1. Copy the files to a folder of your choice, e.g.: C:\Tools\WinAudioClean\

2. Ensure ffmpeg.exe is inside that same folder.

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

**Native results and launcher automation**

The script runs the resolved FFmpeg executable directly, disables its stdin and
captures stdout and stderr separately. Native failure details appear in the
console and local report. Processing and reporting results use these exit codes:

| Code | Meaning |
| --- | --- |
| 0 | FFmpeg returned success and reporting completed. |
| 2 | Invalid input, destination, mode or launcher usage. |
| 3 | FFmpeg was missing or could not start. |
| 4 | FFmpeg failed, or native capture/cleanup failed. The native exit is retained in diagnostics. |
| 7 | FFmpeg returned success, but reporting was incomplete. Audio is retained. |
| 130 | Cancelled at the mode menu. |

A reporting failure never changes an existing processing failure to success.
Exit `0` does not independently verify the rendered media. Output collisions and
complete media validation remain limitations of this development version.

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
   - Checks if ffmpeg.exe is present.

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
   - Runs FFmpeg invisibly in the background.
   - Shows a "Processing..." indicator in the console.

5. Logging
   - Generates a WinAudioClean_Log.txt in the Music folder.
   - Records the exact duration, file sizes, and the full technical filter string used.

**Limitations / When not to use**

   - Extreme Noise: If you recorded in a wind tunnel or a busy cafe, standard signal processing isn't enough. You need AI isolation tools for that.
   - Multi-track editing: This processes the file as a single block. It cannot level one person's voice without leveling the other person's voice.
   - Music Production: Do not use this on songs. The "De-clipper" and "Highpass" filters are tuned for human speech and will damage the quality of musical instruments.

**Troubleshooting**

- "FFmpeg.exe not found!"
  - The script looks in its own folder for the executable. Make sure you didn't leave ffmpeg.exe in your Downloads folder.

- Red "FAILED" text
  - Check the console output right above the error. It usually means the input file is corrupt or has a codec FFmpeg doesn't understand.

**Intent & License**

Personal helper for my own content creation workflow, "I just want this recording to sound professional so I can upload it." Provided as-is, without warranty. Use at your own risk. Feel free to fork, trim, or extend it to fit your own loudness standards.
