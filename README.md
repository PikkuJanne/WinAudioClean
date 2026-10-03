# WinAudioClean — Automated Audio Cleaning & Leveling Droplet (PowerShell + FFmpeg)

A local audio cleaning and leveling tool for speech recordings, including meetings, podcasts and voiceovers. It applies a validated FFmpeg filter chain and saves a separate WAV export. Results depend on the recording; listen to the output before using it.

**Synopsis**

- Two Modes: "Raw Recording" (Clean + Level) and "Zoom/Teams" (Level Only), with Original as the built-in preset. Raw also offers an optional experimental Gentle preset.

- Cleaning: Attempts clipping and click repair, reduces low-frequency rumble, and applies noise reduction and a gate.

- Leveling: Uses dynamic gain adjustment followed by loudness normalization with chosen targets of -12 LUFS integrated loudness and -1.5 dBTP true peak.

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

- WinAudioClean.Preview.ps1
  - Sibling helper for the optional excerpt and level-matched comparison workflow. Full renders work without it.

- WinAudioClean.Settings.ps1
  - Sibling helper for loading and managing optional local JSON preferences. Loading an existing saved file, an explicit SettingsPath or a settings action requires it.

- WinAudioClean.Batch.ps1
  - Sibling helper for ordered file lists, manifest input and a persistent per-item result journal. Lists also require the Settings sibling; single-file rendering does not require Batch.

- WinAudioClean.Launcher.ps1
  - Sibling helper for ordered launcher paths, manifest handoffs and selecting an inner PowerShell host. Keep it beside the BAT for these routes; legacy single-file launching has a fallback without it.

- WinAudioClean.bat
  - Launcher for one or several explicit audio files, with a final interactive pause.

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

1. Drag one or several audio files (WAV, MP3, M4A, MKV, etc.) onto the WinAudioClean.bat icon. Keep all sibling helpers beside it for several files. Use the manifest route below for long lists or names containing percent/exclamation characters.

2. With no saved mode, a window will open asking for Mode Selection:
   - Type 1 for Raw Recording (Microphone audio that needs noise removal).
   - Type 2 for Zoom/Teams (Meeting audio that is already noise-cancelled).

3. Press Enter.

4. Wait for the result. Several files run in the supplied order with one mode choice; their journal records each result, and failed items do not stop later files.

5. Find your new file in your chosen destination, or Music when no destination preference was supplied.

**Command line**

Run from a PowerShell prompt:

.\WinAudioClean.ps1 -inputPath "C:\Path\To\MyRecording.wav"

With no saved mode, you will see the same interactive menu and final log output.

**Input, destination and mode checks**

The single-file route checks input and destination before showing the mode menu. Input
must be an existing, readable, nonempty file. Paths are handled literally,
including spaces, square brackets, apostrophes and Unicode characters. URLs,
PowerShell provider paths, alternate data streams, UNC and device paths are not
supported. Use ordinary Windows drive paths or paths relative to your current
PowerShell directory. Mapped drives and redirected folders can still use network
storage; a drive path does not guarantee that a recording is physically offline.

Music remains the built-in destination. A saved preference or `-OutputDirectory`
can choose another folder; the script creates it if needed and checks that it can write there. An
empty or invalid destination fails before the menu. These checks establish file
accessibility; they do not prove that FFmpeg can decode the media.

At the menu, enter `1` for Raw, `2` for Zoom/Teams, or `Q` to cancel. Empty and
invalid choices ask again. A mode can also be supplied directly:

```powershell
.\WinAudioClean.ps1 -inputPath 'C:\Audio\meeting [draft].wav' -Mode Zoom -OutputDirectory 'C:\Audio\Cleaned' -NonInteractive
```

`-Mode` accepts `Raw` or `Zoom`. `-NonInteractive`, a noninteractive host, and
redirected input require a mode from the CLI or saved settings and never show a mode prompt. Running
without an input file displays usage. Direct script preflight failures return
exit code `2`; menu cancellation returns `130`.

**Ordered file lists and manifests**

Use a typed PowerShell string array for several explicit inputs:

```powershell
& .\WinAudioClean.ps1 -InputPaths @('C:\Audio\first.wav', 'C:\Audio\second [mix].wav') -Mode Raw -OutputDirectory 'C:\Audio\Cleaned' -NonInteractive
```

`-InputPaths`, `-InputListPath` and the original positional/`-inputPath` route
are mutually exclusive. File-list runs process inputs in the supplied order,
including repeated entries. They resolve the shared preferences once using
CLI > saved > built-ins and choose mode once. Each item uses the ordinary
full-render path with those frozen choices; saved preferences are not read
again between items. An invalid item is recorded and later items continue.
Batch input cannot accompany preview, settings-management or diagnostic-export
actions. Folder traversal and deduplication are separate future workflows.

For long lists or names that CMD may change, use `-InputListPath` with a UTF-8
JSON manifest. Its only fields are integer `schemaVersion: 1` and `inputs`, an
array of 1–1024 nonempty path strings. A UTF-8 BOM is optional; the complete file
must be at most 1 MiB. Relative input paths resolve from the manifest's folder.
The manifest is data; filter text and scripts are never executed.

```json
{"schemaVersion":1,"inputs":["first.wav","second [mix].wav","literal %name%! .wav"]}
```

```powershell
& .\WinAudioClean.ps1 -InputListPath 'C:\Audio\inputs.json' -Mode Raw -OutputDirectory 'C:\Audio\Cleaned' -NonInteractive
```

To select files from a folder without a long command line, create an explicit
manifest in PowerShell, review it, and run the command above. This example
selects only that folder's WAV files and preserves the sorted list:

```powershell
$paths = @(Get-ChildItem -LiteralPath 'C:\Audio\Inputs' -File -Filter '*.wav' | Sort-Object Name | ForEach-Object { $_.FullName })
@{ schemaVersion = 1; inputs = $paths } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath 'C:\Audio\inputs.json' -Encoding UTF8
```

Each batch writes a new UTF-8 JSONL journal, by default
`WinAudioClean_Batch_<id>.jsonl` in the output directory. Use `-BatchResultPath`
to choose its filename in an existing parent folder; existing files are never
replaced. A header records the
list size and frozen settings, followed by one result per item and a final
summary. Published items also retain their ordinary audio and reports. Item
statuses distinguish success, warning, failure, cancellation and inputs that
were not started. Journal persistence failure stops later work with code `5`;
keep any completed audio and the journal's already-flushed records.
Journals contain input paths, preferences and bounded diagnostics. Review them
before sharing, alongside the ordinary per-file reports.

A one-item list retains the ordinary item's exit code. A multi-item list returns
`0` when all succeed, `7` for warnings only, or `6` when any item fails.
Cancellation returns `130` and leaves later items unattempted. Malformed list
or shared settings fail before processing with code `2`. These queue results do
not add active-render Ctrl+C guarantees or change the audio recipe.

**Local saved settings and unattended runs**

Optional preferences are stored at
`[Environment]::GetFolderPath('ApplicationData')\WinAudioClean\settings.json`.
Use `-SettingsPath` to choose another local JSON file. An absent file uses the
built-in choices; normal runs do not create or update it. Values resolve in
this order: explicit CLI parameter, saved value, then built-in default. A saved
mode can supply the required unattended mode, and a saved audio-stream index
can resolve a multi-track recording. Positional input and `-inputPath` still work.

Inspect, save or reset preferences without an input file:

```powershell
& .\WinAudioClean.ps1 -ShowSettings
& .\WinAudioClean.ps1 -SaveSettings -Mode Raw -Preset Gentle -BitDepth 24 -OutputDirectory 'C:\Audio\Cleaned'
& .\WinAudioClean.ps1 -ResetSettings -ShowSettings
```

`-ShowSettings` prints one compact JSON line with resolved preference `settings`
and an `origins` object identifying CLI, saved or built-in values. Cleaning
preferences retain their override dictionary; the processing console/reports
show the expanded effective cleaning and exact graph. The display also includes
`effectiveCleaning` and `effectiveFilterChain` when the mode is known; otherwise
they are null with `effectiveProfileReason: mode_not_selected`. It may accompany
Save or Reset. `-SaveSettings` writes the resolved supported preferences;
`-ResetSettings` writes an empty settings object so later runs use built-ins.
Save and Reset are exclusive. Reset rejects processing choices. These management
actions do not process audio or run FFmpeg; do not combine them with input,
preview, executable-path or diagnostic-export options.

Saved JSON has this shape; every field inside `settings` is optional:

```json
{
  "schemaVersion": 1,
  "settings": {
    "mode": "Raw",
    "preset": "Gentle",
    "loudnessMode": "Fast",
    "bitDepth": 24,
    "mono": false,
    "rf64": false,
    "outputDirectory": "C:\\Audio\\Cleaned",
    "audioStreamIndex": 1,
    "cleaningOptions": { "HighpassHz": 61.5, "Denoise": true }
  }
}
```

The supported fields are `mode` (`Raw`/`Zoom`), `preset` (`Original`/`Gentle`),
`loudnessMode` (`Fast`/`Accurate`), `bitDepth` (integer 16/24), Boolean `mono`
and `rf64`, a local `outputDirectory`, a nonnegative integer
`audioStreamIndex`, and the typed `cleaningOptions` object described below.
Use JSON numbers and `true`/`false`, with decimal dots; quoted numbers, nulls,
unknown keys, unknown schema versions and arbitrary filter/script text fail.
Field names use the exact casing shown above and in the cleaning-options table.
Files must be UTF-8 JSON of at most 64 KiB, including an optional UTF-8 BOM.
The saved configuration is validated as a whole, including mode/preset
compatibility and disabled cleaning values, before CLI overrides are applied.
Invalid JSON/settings return code `2` and preserve the file. Use
`-IgnoreSavedSettings` to run with CLI/built-ins, or `-ResetSettings` to recover.
There is no automatic migration or silent repair.

Explicit false is an override: `-Mono:$false` and `-Rf64:$false` replace saved
true values. `-CleaningOptions` replaces the entire saved override dictionary;
it does not merge individual keys. `-CleaningOptions @{}` clears saved
overrides and restores the selected preset's cleaning values. For example:

```powershell
& .\WinAudioClean.ps1 -inputPath 'C:\Audio\interview.wav' -AudioStreamIndex 0 -Mono:$false -CleaningOptions @{} -NonInteractive
& .\WinAudioClean.ps1 -inputPath 'C:\Audio\interview.wav' -Mode Raw -IgnoreSavedSettings -NonInteractive
```

Saving normalizes the output directory to an absolute path. A hand-written
relative directory resolves against the current PowerShell location.
Settings writes use a temporary file in the same directory and atomic
replacement; a failed save preserves an existing valid file where storage
permits. This does not promise power-loss durability or conflict merging
between concurrent writers. Preferences stay local and may contain a destination
path; review them before sharing. Input filenames, executable paths,
`NonInteractive`, preview ranges and diagnostic options are never persisted.
The application remains version 2.3 and reports remain schema 1.

**Original preset**

The built-in preset is **Original**, ID `original`, version `1.0.0`.
Choose `1` / `-Mode Raw` for cleaning plus leveling, or `2` / `-Mode Zoom` for
leveling only. Naming the preset preserves these legacy filter values and order:

Raw:

```text
adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5
```

Zoom/Teams:

```text
dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5
```

These are the default Fast settings. The -12 LUFS target is a preset choice,
not a universal broadcast standard or a guarantee of the final file's loudness.
Fast leaves final loudness unmeasured. Accurate adds the optional measurement
workflow below. Preset identity names the Original base settings; loudness mode
and the explicit 48 kHz PCM export policy are separate choices. Different
FFmpeg builds or export settings can produce different samples. Speech listening
approval remains pending.

**Optional Gentle cleaning and advanced settings**

`-Preset Gentle` selects an experimental Raw cleaning candidate, ID `gentle`,
version `0.1.0`. It skips clipping repair, click repair and the gate, uses a
60 Hz high-pass cutoff and sets `afftdn=nf=-35:nr=6`. Dynamic leveling and
loudness targets stay the same. The name describes the chosen settings;
speech listening has not established that it improves a recording.

```powershell
& .\WinAudioClean.ps1 -inputPath 'C:\Audio\interview.wav' -Mode Raw -Preset Gentle -NonInteractive
```

Raw accepts a `-CleaningOptions` hashtable with the settings below. Values
override the selected base preset for that run. All numeric bounds are
inclusive. Booleans must be `$true` or `$false`; numbers must be finite numeric
scalars. Strings, arrays, null values, scriptblocks, unknown keys and arbitrary
FFmpeg filter text are rejected. Numeric settings are validated even when
their stage is disabled.

| Option | Allowed value | Original Raw | Gentle Raw |
| --- | --- | --- | --- |
| `Declip` | Boolean | `$true` | `$false` |
| `Declick` | Boolean | `$true` | `$false` |
| `Denoise` | Boolean | `$true` | `$true` |
| `Gate` | Boolean | `$true` | `$false` |
| `HighpassHz` | 20 to 200 Hz | 80 | 60 |
| `NoiseFloorDb` | -80 to -20 dB | -25 | -35 |
| `NoiseReductionDb` | 0.01 to 20 dB | 12 | 6 |
| `GateThresholdDb` | -80 to -20 dBFS | -45 | -45 (inactive) |
| `GateRangeDb` | -60 to 0 dB | -25 | -25 (inactive) |

For example, disable the Original gate and request 4 dB of noise reduction:

```powershell
& .\WinAudioClean.ps1 -inputPath 'C:\Audio\interview.wav' -Mode Raw -CleaningOptions @{Gate=$false; NoiseReductionDb=4} -NonInteractive
```

Run hashtable examples in PowerShell with the call operator `&`. A native
`powershell.exe -File` or `pwsh -File` invocation cannot pass a hashtable literal
as a typed parameter. Drag-and-drop and the menu use Original when no preset preference is saved; use the
PowerShell entry point for these options. `-Mode Zoom` accepts only Original
with no nonempty cleaning options, so it remains leveling only. These options
can accompany either Fast or Accurate; Accurate repeats the selected cleaning
chain in both passes. Preferences change only when you explicitly save or reset them.

The range limits are application choices within the supported FFmpeg options,
not listening guarantees. High-pass filtering remains present in Raw even when
all four optional stages are disabled. At its built-in settings, Original retains the legacy
gate values `range=0.056:threshold=0.0056` at the nominal -25/-45 dB settings,
and leaves `afftdn nr` implicit at the tested FFmpeg default of 12 dB. Changing
the noise floor or reduction makes `nr` explicit. Other gate dB settings are
converted to linear amplitude as `10^(dB/20)` with
invariant decimal formatting. Preserve the report's exact filters and FFmpeg
build when reproducing a render.

**Local excerpt preview and comparison**

Use `-Preview` to create a short original excerpt, the processed excerpt and
two separate files for comparing them at a matched level:

```powershell
& .\WinAudioClean.ps1 -inputPath 'C:\Audio\interview.wav' -Mode Raw -Preset Gentle -Preview -PreviewStartSeconds 30 -PreviewDurationSeconds 45 -NonInteractive
```

The default starts at zero and requests 45 seconds, shortened to the remaining
audio when needed. An explicit duration must be greater than zero, at most
60 seconds and fit before the selected track ends. Start must be nonnegative
and before the track ends. Start counts from the selected audio track's
beginning, including tracks that start later than others in a container.
Preview rejects negative or missing selected-track timestamp origins;
WAV sample zero is accepted as its origin when timestamps are absent.
Use decimal seconds with a dot, such as `30.125`.
The range is rounded to 48 kHz sample positions; a range shorter than one
output sample is rejected. Range options require `-Preview`.

Each request creates four uniquely named WAVs:

- `Original`: the selected interval with the chosen output/channel policy.
- `Processed`: that interval after the selected Raw/Zoom profile.
- `CompareOriginal`: a separately attenuated original for comparison.
- `CompareProcessed`: a separately attenuated processed excerpt for comparison.

Open the two comparison files yourself to listen. The script never starts
playback or a full recording render as part of preview. Choose or cancel the
mode/audio-track prompt before processing; a cancelled selection creates no
preview audio. Existing files and the source are preserved.

Processing uses up to five seconds of context before and after the excerpt,
limited by the track's ends, then trims both excerpts to matching source
positions and frame counts. Stateful filtering and normalization over that
window can differ from a full render. Container timestamp precision can also
shift a seek by a few samples; the report gives its resolution and a
conservative bound of at most 10 ms. WAV source intervals are checked exactly
in the synthetic tests; container positions are checked within their declared
precision. Unknown/coarse non-WAV timestamp clocks are rejected.
The current Original and Gentle Raw
graphs retain an approximately 25 ms waveform delay on the tested FFmpeg
build; Zoom and the tested Raw graph with all four cleaning stages disabled
had zero reference delay. No delay compensation is applied. Custom graphs
need their own delay check. The report labels context and these limitations.

Comparison uses attenuation only. Both excerpts are measured, a common lower
LUFS level is chosen with a -1.7 dBTP headroom target, and the resulting files
are measured again. Matching allows a difference of 0.2 LU and requires true
peak at or below -1.5 dBTP. Silence or clips shorter than one second are
labelled unmeasurable; any available peak still controls safe attenuation.
Preview metrics describe these excerpts, never the full recording's loudness.
The comparison gain leaves full-render settings unchanged.

The shared meter parser currently accepts integrated values through 0 LUFS.
A preliminary very loud synthetic clip reported +0.51 LUFS and was rejected
without publication. This inherited limit remains; the successful peak-guard
fixture has negative integrated loudness and does not establish support for
positive-LUFS material.

The preview JSON/text reports contain each asset's measurements, selected
range, context, gains and exact graphs. They may include local paths and native
diagnostics; review them before sharing. Processing/publication failures
roll back only owned preview files where storage permits. If writing reports
fails after all four valid assets are published, the audio is retained with
WARNING/7 and an incomplete-report diagnostic. Creating these files is
not speech listening approval. The optional helper must be beside the main
script, and the existing Fast/Accurate, bit-depth, mono and stream choices
remain available. Accurate analyzes only the bounded context window.

**Fast and Accurate loudness**

`-LoudnessMode Fast` is the built-in default. It retains the
original single-pass chain and runs no additional loudness analysis. To opt
into two-pass normalization and final-file measurement, use PowerShell:

```powershell
.\WinAudioClean.ps1 -inputPath 'C:\Audio\interview.wav' -Mode Raw -LoudnessMode Accurate -NonInteractive
```

Accurate analyzes the selected recording, renders it using the measured values,
and checks the encoded WAV in a separate FFmpeg process. The analysis and render
repeat the same selected cleaning, dynamic leveling and optional mono conversion.
A 192 kHz resampling step follows dynamic leveling in both passes; exports
remain 48 kHz PCM16 or PCM24.
Accurate takes longer and can sound different from Fast.

Reports keep requested targets separate from measured integrated loudness,
true peak and loudness range. The final check allows an integrated difference
of at most 0.5 LU from -12 LUFS and true peak no higher than -1.3 dBTP
(the -1.5 dBTP target plus 0.2 dB measurement tolerance). These are this tool's
engineering tolerances. A peak violation takes priority; loudness range is
reported for information.

FFmpeg may use dynamic normalization when measured linear normalization is
unavailable or cannot meet its constraints. The report records the actual
normalization type and fallback reason. Fallbacks, undefined measurements and
results outside the tolerances produce **WARNING / exit 7** when a valid WAV
is published. Undefined metrics have `null` values and explicit reasons. For
audio shorter than one second, integrated loudness and loudness range are
unavailable; any finite true-peak measurement is retained.
Malformed first-pass measurements or failed processing stop the run; a failed
final measurement retains a valid export with a warning. Report completeness
is recorded separately from loudness compliance.

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
requires an audio-stream index from saved settings or `-AudioStreamIndex`
when more than one audio track exists:

```powershell
.\WinAudioClean.ps1 -inputPath 'C:\Audio\interview.mkv' -Mode Zoom -AudioStreamIndex 2 -FfmpegPath 'C:\Tools\ffmpeg\bin\ffmpeg.exe' -FfprobePath 'C:\Tools\ffmpeg\bin\ffprobe.exe' -OutputDirectory 'C:\Audio\Cleaned' -NonInteractive
```

The index is the file's absolute stream index, including any video streams. For
example, video at index 0 and audio at indexes 1 and 2 means `-AudioStreamIndex 2`
selects the second audio track. The selected track is explicitly mapped and its
channel count is preserved unless `-Mono` is requested. Video-only input fails before cleaning. Use the
PowerShell entry point for unattended stream selection or explicit tool paths;
the batch launcher's `/unattended` route also uses saved preferences.

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

The built-in export is **48 kHz, 16-bit signed PCM WAV**. This intentionally replaces the
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
drag-and-drop uses saved export preferences or these built-in defaults.

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
Reports identify the base preset and its version separately from the
application `toolVersion`. `presetExperimental` marks Gentle and
`presetCustomized` marks a nonempty cleaning-options override, even if its values
match the defaults. Raw reports include the typed effective `settings.cleaning`;
Zoom records `null`. The base ID/version alone does not describe a customized
render; retain its settings, exact filters, FFmpeg build and output format.
Input recording duration and elapsed processing time are separate fields. The
processing time includes analysis, rendering, validation and publication.
Fast measurements remain `null` with `not_measured` and compliance
`NOT_MEASURED`. Accurate reports the final encoded file's measurements,
normalization stages, actual type, fallback and compliance outcome. Valid PCM
alone does not establish loudness compliance.

Published audio remains available if a report cannot be written. The console
returns `7` for a valid published export with loudness or reporting warnings;
an earlier processing failure keeps its own code. Surviving reports are corrected to that
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
timestamps, job IDs, preset identity/flags, cleaning settings, dependency banners
and raw diagnostics. **Review the export
before sharing it.** Nothing is uploaded automatically; the raw report remains
unchanged. See the [report format](docs/codex/winaudioclean/DATA_FORMATS.md).

New per-run reports use UTF-8 without a BOM. The summary preserves an existing
BOM and its encoding. For a summary without a BOM, valid UTF-8 is retained;
otherwise the current Windows ANSI code page is used. If an entry cannot be
encoded safely, reporting fails rather than replacing existing bytes.

**Native results and launcher automation**

The script runs the resolved FFmpeg executable directly and captures stdout
and stderr separately. Interactive input to FFmpeg is disabled. Accurate's
final check streams the held WAV into FFmpeg as binary input while the file
remains protected from changes. Native failure details appear in the console
and local report. Processing and reporting results use these exit codes:

| Code | Meaning |
| --- | --- |
| 0 | Audio was validated and published without loudness or reporting warnings, or settings inspect/save/reset completed successfully. |
| 2 | Invalid input, destination, mode, preset/cleaning options, loudness mode, audio selection, export settings/layout, saved JSON/settings, file list/manifest or launcher usage; ambiguous unattended tracks; settings-management or diagnostic export failure. |
| 3 | Missing, incompatible or filter-deficient dependency, or analysis/render process start failure. |
| 4 | Probe/metadata failure, no audio, or analysis/processing/capture/cleanup failure. Malformed first-pass measurements fail here. Native failures retain diagnostics. |
| 5 | Output allocation, space/size check, validation, publication, owned-file cleanup or batch-journal persistence failed. |
| 6 | A multi-item list completed with failed items; per-item codes remain in its journal. |
| 7 | Valid audio was published with loudness or reporting warnings. Audio is retained; inspect the report for the reason. |
| 130 | Cancelled at the mode or audio-track menu, or a list item cancelled and remaining inputs were not started. |

A reporting failure never changes an existing processing failure to success.
An invalid output is never presented as a completed export. Native diagnostics
remain available when publication fails after FFmpeg returns zero.

The BAT preserves the script's exit code across one final interactive pause.
One positional file keeps the ordinary single-file route; several quoted paths
use the ordered list route. The launcher verifies a fresh CMD `/c` command frame
against its captured arguments. The original command line must be shorter than
7,600 characters, with at most 1,024 inputs. Existing or nested CMD sessions
cannot establish that positional handoff; use direct PowerShell or the
environment routes below instead.

CMD can expand `%NAME%` and `!NAME!` before the BAT sees them. Observable percent
or exclamation characters in positional paths or the original command line are
rejected; this cannot repair earlier expansion. For literal names and long
lists, set a manifest path from PowerShell so no input paths enter CMD text:

```powershell
$env:WAC_LAUNCH_INPUT = $null
$env:WAC_LAUNCH_INPUT_LIST_PATH = 'C:\Audio\inputs.json'
& .\WinAudioClean.bat /manifest
$LASTEXITCODE
```

The manifest uses the schema and bounds described above. `/manifest` remains
interactive, using saved mode/output preferences or the usual prompts/defaults.
When set, `WAC_LAUNCH_OUTPUT_DIRECTORY` overrides its destination preference.
It rejects a simultaneously set `WAC_LAUNCH_INPUT`. Large lists belong in the
manifest file rather than an environment variable containing the list itself.

For unattended processing, supply exactly one input or manifest environment
value, a destination and `Raw` or `Zoom`:

```powershell
# Set these values from PowerShell so CMD never receives the paths as arguments.
$env:WAC_LAUNCH_INPUT_LIST_PATH = $null
$env:WAC_LAUNCH_INPUT = 'C:\Audio\meeting %complete%!.wav'
$env:WAC_LAUNCH_OUTPUT_DIRECTORY = 'C:\Audio\Cleaned'
& .\WinAudioClean.bat /unattended Zoom
$LASTEXITCODE
```

To process a manifest unattended, clear `WAC_LAUNCH_INPUT`, set
`WAC_LAUNCH_INPUT_LIST_PATH` and use the same `/unattended Raw|Zoom` route. It
skips the pause. Preferences can be isolated with `WAC_LAUNCH_SETTINGS_PATH`
and `WAC_LAUNCH_IGNORE_SAVED_SETTINGS=1`; the latter accepts only unset or `1`.
The launcher defaults to Windows PowerShell 5.1. Set `WAC_LAUNCH_POWERSHELL`
to the absolute path of an existing local PowerShell `.exe` to select the inner
host, such as PowerShell 7. These values are passed as data. Manifest lists and
inner-host selection require the Launcher sibling; direct script calls also
support PowerShell 7.

Long native renders have no fixed total timeout. Diagnostics are
captured in memory per run; large recordings and very large diagnostic streams
have not been stress-tested.

**What it actually does (step-by-step)**

1. Checks
   - Verifies the input file exists.
   - Resolves and checks ffmpeg.exe and ffprobe.exe.

2. Mode Selection (TUI)
   - Asks the user if they want the full cleaning suite or just volume leveling.
   - Zoom/Teams skips the cleaning filters for recordings that already received noise reduction.

3. Construct Filter Chain
   - Original cleaning by default (Mode 1 Only; optional Raw settings are described above):
     - adeclip: Attempts to reconstruct clipped peaks.
     - highpass: Attenuates low frequencies with an 80 Hz cutoff.
     - adeclick: Attempts to remove impulsive clicks.
     - afftdn: `nf=-25` sets the noise floor in dB. Reduction is controlled separately by `nr`, left at FFmpeg's default of 12 dB.
     - agate: Reduces low-level audio below a threshold of about -45 dBFS. `range=0.056` limits attenuation to about 25 dB; it does not mute the track.
   - Leveling (Mode 1 & 2):
     - dynaudnorm: Adjusts gain over time. `p=0.85` sets a peak-amplitude target of 0.85 of full scale, not a leveling percentage.
     - loudnorm: Requests -12 LUFS integrated loudness and -1.5 dBTP maximum true peak. LUFS measures loudness; it is not an RMS level.

   Parameter definitions: FFmpeg's [afftdn](https://ffmpeg.org/ffmpeg-filters.html#afftdn),
   [agate](https://ffmpeg.org/ffmpeg-filters.html#agate),
   [dynaudnorm](https://ffmpeg.org/ffmpeg-filters.html#dynaudnorm) and
   [loudnorm](https://ffmpeg.org/ffmpeg-filters.html#loudnorm) documentation.

4. Processing
   - Probes audio tracks and maps the selected absolute stream index.
   - Runs FFmpeg invisibly in the background.
   - Shows a "Processing..." indicator in the console.

5. Logging
   - Writes per-run JSON/text reports and appends WinAudioClean_Log.txt in the selected destination.
   - Records recording duration separately from rendering time, along with file sizes, exact filters, diagnostics and outcome.

**Limitations / When not to use**

   - Heavy noise or distortion may remain, and filtering can introduce artifacts. Listen for lost quiet words, pumping and changes to voice character.
   - Multi-track editing: This processes one selected audio track. It cannot separate speakers mixed into that track.
   - Music: This preset is intended for speech. Its filters can alter musical tone and dynamics.

**Troubleshooting**

- Dependency failure
  - Check the reported executable path. Supply `-FfmpegPath` and `-FfprobePath`, place both tools together next to the script, or add them to PATH. Missing required filters need a compatible FFmpeg build.

- Probe failure or multiple audio tracks
  - Check that the file uses a supported container and contains audio. For unattended multi-track files, supply the absolute `-AudioStreamIndex` shown in the diagnostic.

- Red "FAILED" text
  - Check the console output right above the error. It usually means the input file is corrupt or has a codec FFmpeg doesn't understand.

**Intent & License**

Personal helper for my own content creation workflow, "I just want this recording to sound professional so I can upload it." Provided as-is, without warranty. Use at your own risk. Feel free to fork, trim, or extend it to fit your own loudness standards.
