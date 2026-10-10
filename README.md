# WinAudioClean 1.0.0

**[v1.0.0 is published on GitHub](https://github.com/PikkuJanne/WinAudioClean/releases/tag/v1.0.0).**
Download the tool-only ZIP and its matching checksum/provenance files from that release.
Website hosting will follow separately in the future multi-tool website project.
Earlier internal builds used version `2.3`; their historical reports remain valid.

Clean and level speech recordings locally with PowerShell and FFmpeg. Choose **Raw** for cleaning plus leveling, or **Zoom/Teams** for leveling only. The built-in **Original** preset preserves the legacy filter settings. Results depend on the recording; listen before using the export.

## First run

1. Use a Windows desktop with Windows PowerShell 5.1 or PowerShell 7. The active-machine checks used Windows build 26300, PowerShell 5.1.26100.9444 / 7.6.5 and FFmpeg/ffprobe 9.0.2 essentials. Windows 10/11 are intended targets; other builds and managed security configurations are not universally verified.
2. Verify the tool-only ZIP using the [portable package guide](docs/PORTABLE_PACKAGE.md), then extract **all** its files into a short folder you can write to. Installation needs no administrator rights, Git, Python or test modules.
3. Obtain a Windows FFmpeg distribution with both `ffmpeg.exe` and `ffprobe.exe`; check its origin, integrity and license. Put both beside `WinAudioClean.ps1` and keep all eight PowerShell components beside the BAT. Nothing is downloaded automatically. See [dependency notices](THIRD_PARTY_NOTICES.md).
4. Open PowerShell in the extracted folder. For the examples below, copy one of your recordings there as `recording.wav` (a readable mono/stereo WAV; at least four seconds for the explicit preview). The file is your input, not part of the ZIP. Other supported media can be supplied with its real filename.
5. Run the first command below. `Exports` is created automatically. `-IgnoreSavedSettings` makes these examples independent of any existing preferences.

<!-- example: first-run -->
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Zoom -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive
```

The host's `-ExecutionPolicy` applies to this process. Follow your organization's policy if execution is blocked; see [security guidance](docs/SECURITY.md). For PowerShell 7, use `pwsh.exe` instead of `powershell.exe`.

Check the displayed result and the new WAV/reports in `Exports`, then listen. Sources and prior exports are preserved. A valid WAV with a loudness/report warning returns `7`; it needs review. Early input/dependency/probe failures may produce only console diagnostics.

For ordinary interactive use, drag a simply named file onto `WinAudioClean.bat`, choose `1` (Raw), `2` (Zoom/Teams), or `Q` to cancel, and read the result before its final pause. With saved mode preferences there may be no mode prompt. CMD can alter punctuation before the BAT starts: use direct PowerShell or the environment/manifest route below for complex names, especially `%`, `!`, ambiguous quotes or parentheses rejected by the launcher. Several safely transported files run sequentially with one mode choice.

Processing stays on your machine. Reports can contain private paths, filenames, tags and native diagnostics. Drive letters, mapped drives, junctions and redirected folders can still point to network/synchronized storage. See [support and privacy](docs/SUPPORT.md).

## Common commands

Run these in the same extracted folder with `recording.wav` and the supplied dependencies. Every output gets a new job ID; repeating a command preserves earlier exports. Direct PowerShell calls support typed arrays/hashtables. A native `-File` command cannot receive a hashtable literal.

Original Raw, with optional 24-bit editing output:

<!-- example: raw-24 -->
```powershell
& .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Raw -BitDepth 24 -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive
```

Accurate loudness adds analysis and final encoded-WAV measurement. It takes longer and can sound different from Fast:

<!-- example: accurate -->
```powershell
& .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Zoom -LoudnessMode Accurate -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive
```

Gentle is an **experimental Raw candidate**, ID `gentle`, version `0.1.0`; it has no speech listening approval. This example also replaces its cleaning overrides for this invocation:

<!-- example: gentle -->
```powershell
& .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Raw -Preset Gentle -CleaningOptions @{Gate=$false; NoiseReductionDb=4} -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive
```

Extract one selected audio track to WAV. `-AudioStreamIndex` is the absolute stream index, counting video too. This WAV example uses its only track, index `0`; for a multi-track container, use the index shown by the application, such as `2` when video is `0` and audio tracks are `1` and `2`. Unattended ambiguous tracks require an explicit index. Video, source metadata and chapters are omitted; speakers already mixed into a track cannot be separated.

<!-- example: track-mono-rf64 -->
```powershell
& .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Zoom -AudioStreamIndex 0 -Mono -BitDepth 24 -Rf64 -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive
```

This requests mono and RF64 even for a small file. Confirm your editor reads RF64 before using it for long recordings.

Preview creates four local WAVs: Original, Processed, CompareOriginal and CompareProcessed. Open the comparison pair yourself; no playback or full render starts automatically:

<!-- example: preview -->
```powershell
& .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Zoom -Preview -PreviewStartSeconds 1 -PreviewDurationSeconds 3 -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive
```

An explicit interval must fit inside the selected track. Omitted range defaults are start `0`, duration `45` seconds clipped to the available audio; explicit duration is positive and at most `60`. Up to five seconds of context on each side warm up filters. Stateful results can differ from a full render. Raw Original/Gentle retained about 25 ms filter delay on the tested build; there is no delay compensation. Container seeks have declared precision (maximum accepted bound 10 ms); missing/negative origins and unknown/coarse clocks are rejected except WAV sample zero. Comparison uses attenuation only, within 0.2 LU and at or below -1.5 dBTP where measurement is available; short/silent excerpts have explicit unavailable reasons.

An explicit list retains order and repetitions; this example intentionally requests the same source twice:

<!-- example: list -->
```powershell
& .\WinAudioClean.ps1 -InputPaths @('.\recording.wav', '.\recording.wav') -Mode Zoom -OutputDirectory '.\Exports' -JobFolder -IgnoreSavedSettings -NonInteractive
```

For long lists or CMD-sensitive names, use a UTF-8 JSON manifest. Relative paths are anchored beside the manifest:

<!-- example: manifest -->
```powershell
@{schemaVersion=1; inputs=@('recording.wav')} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath '.\inputs.json' -Encoding UTF8
& .\WinAudioClean.ps1 -InputListPath '.\inputs.json' -Mode Zoom -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive
```

Folder discovery is explicit. This example first copies the input into a separate folder. Existing selections are frozen before processing; new exports cannot enter the running queue:

<!-- example: folder -->
```powershell
New-Item -ItemType Directory -Path '.\Inputs' -Force | Out-Null
Copy-Item -LiteralPath '.\recording.wav' -Destination '.\Inputs\recording.wav'
& .\WinAudioClean.ps1 -InputDirectories @('.\Inputs') -Mode Zoom -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive
```

No recursion occurs unless `-Recurse` is added. Discovery deduplicates file identities, skips reparse entries/generated names and excludes a proper descendant output subtree. Renamed old exports cannot always be recognized; keep sources separate. Explicit lists retain repeats and do not apply folder exclusions.

Preferences save only when requested. These commands use a separate example settings file, show resolved values/origins, and reset that file to built-ins:

<!-- example: settings-save -->
```powershell
& .\WinAudioClean.ps1 -SaveSettings -SettingsPath '.\example-settings.json' -Mode Zoom -OutputDirectory '.\Exports' -IgnoreSavedSettings
```

Inspect the saved values and their origins:

<!-- example: settings-show -->
```powershell
& .\WinAudioClean.ps1 -ShowSettings -SettingsPath '.\example-settings.json'
```

Reset this example file and inspect the built-in values:

<!-- example: settings-reset -->
```powershell
& .\WinAudioClean.ps1 -ResetSettings -ShowSettings -SettingsPath '.\example-settings.json'
```

Normal preferences live at `[Environment]::GetFolderPath('ApplicationData')\WinAudioClean\settings.json`. Explicit CLI > saved > built-in. Invalid complete settings fail before overrides; `-IgnoreSavedSettings` bypasses them. Explicit `-Mono:$false` / `-Rf64:$false` override saved true; `-CleaningOptions @{}` clears the complete saved override dictionary. Typed schema-1 UTF-8 JSON is limited to 64 KiB; unknown versions/fields and quoted numbers are rejected. Atomic replacement preserves earlier bytes on pre-publication failure; power-loss durability is not promised.

BAT unattended use treats paths as environment data and skips the pause:

<!-- example: bat -->
```powershell
$env:WAC_LAUNCH_INPUT_LIST_PATH = $null
$env:WAC_LAUNCH_INPUT = (Get-Item -LiteralPath '.\recording.wav').FullName
$env:WAC_LAUNCH_OUTPUT_DIRECTORY = (Get-Item -LiteralPath '.\Exports').FullName
$env:WAC_LAUNCH_IGNORE_SAVED_SETTINGS = '1'
& .\WinAudioClean.bat /unattended Zoom
$wacExit = $LASTEXITCODE
Remove-Item Env:WAC_LAUNCH_INPUT, Env:WAC_LAUNCH_OUTPUT_DIRECTORY, Env:WAC_LAUNCH_IGNORE_SAVED_SETTINGS -ErrorAction SilentlyContinue
$wacExit
```

For a manifest BAT handoff, clear `WAC_LAUNCH_INPUT` and set `WAC_LAUNCH_INPUT_LIST_PATH` to its absolute path. `/manifest` is interactive; `/unattended Raw|Zoom` accepts either environment selection. `WAC_LAUNCH_SETTINGS_PATH` isolates preferences; `WAC_LAUNCH_POWERSHELL` selects an installed host by absolute `.exe` path. The default inner host is Windows PowerShell 5.1. The Launcher helper is needed for manifests/multiple positional files/host selection. Positional CMD handoffs must be under 7,600 characters, at most 1,024 inputs, and establish a fresh unambiguous CMD frame.

Read the complete built-in help:

<!-- example: help -->
```powershell
Get-Help .\WinAudioClean.ps1 -Full
```

## Options and built-in defaults

All options are described by `Get-Help`. The two hidden `Wac*` parameters are internal invocation state.

| Option | Behavior / built-in default |
| --- | --- |
| `inputPath` | One literal file; positional argument zero remains supported. No input prints usage, exit 2. |
| `Mode`, `NonInteractive` | Raw/Zoom; no built-in mode, choose at a prompt. Unattended/redirected input needs CLI or saved mode. |
| `OutputDirectory` | Music when no saved/CLI destination is supplied; created and checked for writing. No fallback to current directory. |
| `FfmpegPath`, `FfprobePath` | Optional explicit executable paths; lookup details below. |
| `AudioStreamIndex` | Automatic for one audio track; otherwise prompted or explicit absolute index. |
| `Preset`, `LoudnessMode` | Original / Fast. Gentle is Raw only; Accurate is opt-in. |
| `BitDepth`, `Mono`, `Rf64` | 16; mono conversion off; RF64 off. Output always 48 kHz PCM WAV. |
| `CleaningOptions` | Empty typed override dictionary, Raw only; bounds below. |
| `Preview`, `PreviewStartSeconds`, `PreviewDurationSeconds` | Off; 0; 45 clipped to available source. Preview cannot accompany list/folder selection. |
| `InputPaths`, `InputListPath`, `InputDirectories`, `Recurse` | No selection; mutually exclusive with single input. Recursion off. |
| `BatchResultPath` | New unique JSONL journal in destination; an override requires an existing parent and new filename. |
| `JobFolder` | Off; on creates a new `WinAudioClean_Job_<id>` with `media` and `reports`. Never reused/swept. |
| `SettingsPath`, `IgnoreSavedSettings` | Per-user file; bypass off. Missing preferences use built-ins; no automatic save. |
| `ShowSettings`, `SaveSettings`, `ResetSettings` | Explicit management actions without audio/FFmpeg; save and reset cannot accompany each other. |
| `ExportDiagnostic`, `DiagnosticOutputPath` | Explicit local redacted export of an ordinary full-run report; new destination in existing parent. |
| `PickFile`, `OpenOutputFolder` | Off. Explicit interactive Windows actions; picker needs STA/Forms, open acts after published success/warning. Rejected unattended/redirected. |

Cleaned sources retain standard mono/stereo channel order. `-Mono` averages stereo left/right before filtering. Multichannel, conflicting layouts, unknown timing and unusable audio metadata fail safely. Timing checks compare the selected track's duration within 10 ms for PCM / 100 ms for compressed padding. They do not preserve video synchronization, container timecodes or compensate filter delay. The encoder changed from legacy unspecified output (192 kHz PCM16 on the tested build) to explicit 48 kHz PCM16; exported samples are not bit-identical to earlier versions.

Raw's numeric cleaning bounds are inclusive: `HighpassHz` 20..200 Hz; `NoiseFloorDb` -80..-20 dB; `NoiseReductionDb` 0.01..20 dB; `GateThresholdDb` -80..-20 dBFS; `GateRangeDb` -60..0 dB. `Declip`, `Declick`, `Denoise`, `Gate` require Booleans. Strings, nulls, collections, arbitrary filter text and unknown keys fail, including inactive values. Zoom rejects Gentle and nonempty overrides. Raw highpass remains even when all four toggleable stages are off.

## Sound and measurements

Application **1.0.0**, Original **original / 1.0.0**, Gentle **gentle / 0.1.0**, and report schemas are separate versions. The application and Original preset can share a version string while identifying different things. Default Raw Original/Fast preserves this exact graph:

```text
adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5
```

Zoom Original/Fast preserves:

```text
dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5
```

The requested targets are **-12 LUFS integrated loudness** and **-1.5 dBTP true peak**, not RMS or universal delivery standards. Fast reports `NOT_MEASURED`. Accurate repeats the selected prechain (192 kHz before normalization), measures encoded PCM, and allows ±0.5 LU / maximum -1.3 dBTP; LRA is informational. Fallback, unavailable/missed/failed final checks retain valid audio with warning 7. A malformed first-pass measurement stops processing. No retry forces compliance. Short/silent/undefined measurements have null values/reasons; the meter parser does not accept positive integrated LUFS.

`dynaudnorm p=0.85` is a peak-amplitude target, not a leveling percentage. Original `afftdn nf=-25` is the noise floor; reduction remains implicit (12 dB on the tested build). The gate's linear `range=0.056` limits attenuation, rather than muting all noise. Gentle skips declip/declick/gate, uses highpass 60 Hz and `afftdn=nf=-35:nr=6`, then the same leveling targets. Details: [official FFmpeg filters](https://ffmpeg.org/ffmpeg-filters.html). Severe distortion/lost speech may be unrecoverable; pumping, lost quiet words and voice changes need listening review. Speech-quality/default-promotion approval is separate from numeric checks.

## Dependencies and limits

FFmpeg resolves from explicit `-FfmpegPath`, beside the script, then PATH. FFprobe resolves from explicit `-FfprobePath`, beside the resolved FFmpeg, then PATH. A bad explicit or present sibling executable fails without fallback. Version responses and mode-specific filter capabilities are checked; there is no claimed universal minimum/build compatibility. Version/filter/media inspections have 15-second deadlines. Fast render has no fixed total timeout; Accurate and Preview use duration-derived bounded deadlines. Diagnostics are captured in memory and long-file/memory stress is unverified.

Supported demuxers: WAV, MP3, FLAC, Ogg, MOV/MP4/M4A, Matroska/WebM, AAC, AIFF, ASF, AVI, subject to available decoders. Only FFmpeg's `file` protocol is allowed. URLs, playlists, concat lists, devices, UNC/device/provider paths and alternate data streams are unsupported. Ordinary drive/relative paths handle spaces, brackets, apostrophes and Unicode through direct PowerShell. That does not certify every CMD positional spelling.

Use short extraction and output paths. Generated filenames and `-JobFolder` nesting add length and can exceed the active host's native file-operation limits. The tested PS7 build failed on a long path that PS5.1 handled; cross-host long-path behavior is not guaranteed. For journal/output path errors, follow the [destination troubleshooting](docs/SUPPORT.md).

RIFF estimates above 4,294,967,295 bytes fail before rendering; `-Rf64` explicitly opts in and requires compatible readers. Space estimation adds padding/header allowance and reserves the larger of 64 MiB or 10% headroom. Other writers can still exhaust space. No automatic splitting/trimming occurs. RF64/size boundaries have small synthetic checks; >4 GB exports, real exhaustion and long stress remain unverified.

Manifest lists allow 1..1,024 nonempty strings, schema 1, maximum 1 MiB UTF-8 including optional BOM. Folder bounds are 64 roots, 1,024 recorded entries (including skips/failures), 1,024 directories, 2,048 pinned ancestors and 1 MiB of recorded paths. An incomplete/over-limit scan fails instead of truncating. Queues are sequential, keep completed outputs after later failures, and cannot accompany Preview/settings-management/diagnostic-export actions.

## Reports, cancellation and support

After an ordinary render attempt, per-job `WinAudioClean_<id>.json` / `.txt` and appended `WinAudioClean_Log.txt` record exact filters, versions, native results, selected-track duration and separate processing wall time. Early failures may be console-only. Preview uses separate schema-1 preview reports; explicit-list journals are schema 1, folder journals schema 2. With JobFolder, reports/journals go into `reports` and audio into `media`. A journal override remains independent. Published audio survives a later report-writing failure.

To create a support export from an **ordinary full-run** JSON in `Exports`, select one and write a new diagnostic filename:

<!-- example: diagnostic -->
```powershell
$report = Get-ChildItem -LiteralPath '.\Exports' -File -Filter 'WinAudioClean_*.json' | Where-Object { $_.Name -notlike 'WinAudioClean_Preview_*' } | Sort-Object Name | Select-Object -First 1
& .\WinAudioClean.ps1 -ExportDiagnostic $report.FullName -DiagnosticOutputPath '.\Exports\support-diagnostic.json'
```

The source must be supported ordinary schema 1, at most 16 MiB; destination must be new with an existing parent. The allowlisted projection omits paths, free-form metadata/diagnostics, timestamps, job IDs and preset identity/settings. No FFmpeg is needed and nothing is uploaded. **Review before sharing.** Preview JSON and queue JSONL cannot use this exporter; summarize them manually without private details. Full field definitions are in the [report format](docs/codex/winaudioclean/DATA_FORMATS.md).

| Exit | Meaning |
| --- | --- |
| 0 | Completed without warnings; also successful management/export or empty/all-skipped folder selection. |
| 2 | Invalid input/configuration/destination/selection/usage or settings/diagnostic management failure. |
| 3 | Missing/incompatible dependency or process start failure. |
| 4 | Probe/no-audio, analysis/render/capture failure; malformed first-pass measurements. |
| 5 | Output space/allocation/validation/publication/owned cleanup or journal persistence failure. |
| 6 | Failed entries in a multi-item list/folder queue; journal retains item codes. |
| 7 | Valid published audio with loudness/report warnings; review and retain it. |
| 130 | Cancelled; remaining queued pending inputs not started. |

Ctrl+C/Ctrl+Break in an attached Windows console requests owned-child cancellation and safe cleanup; `Q` cancels prompts. Publication alone reaches progress 100%, not proof of loudness/report success. Closing the window, killing PowerShell or power loss may prevent cleanup/reporting. Inspect `.wac-<id>.partial` only after its job has stopped; later runs do not sweep leftovers. New exports use no-replace publication; a collision fails safely and preserves the existing file.

For missing dependencies, unreadable media, permission failures, collisions, settings recovery and private support reports, follow [troubleshooting](docs/SUPPORT.md). Read [security and privacy](docs/SECURITY.md) before sharing data. No mandatory GUI, server, account, cloud processing, telemetry or updater is used. Website hosting will follow separately in the future multi-tool website project.

Provided as-is under the [MIT license](LICENSE). Third-party builds have their own obligations; see [notices](THIRD_PARTY_NOTICES.md).
