<#
.SYNOPSIS
Cleans and levels spoken-word recordings locally with PowerShell and FFmpeg.
.DESCRIPTION
The Original preset (ID original, version 1.0.0) retains the legacy Raw/Zoom
filter values and order. Choose 1/Raw for cleaning plus leveling, or 2/Zoom
for leveling only. Default -LoudnessMode Fast keeps single-pass normalization
with requested targets of -12 LUFS integrated and -1.5 dBTP true peak, without
independent final measurement. -LoudnessMode Accurate measures the signal after
channel conversion, cleaning and leveling, then repeats that prechain with
measured normalization parameters. It independently measures the encoded PCM.
Accurate accepts integrated loudness within 0.5 LU and true peak <= -1.3 dBTP
(-1.5 target plus 0.2 dB tolerance). Fallback or an unavailable/failed/out-of-
tolerance check produces WARNING (exit 7) when a valid export was published.
Check loudnessCompliance separately from output validity. Neither certifies
speech quality. Accurate's additional passes take more time.

Original Raw applies adeclip, an 80 Hz highpass, adeclick, afftdn and agate before the
shared leveling chain. These filters can reduce some clipping, rumble, clicks
and steady noise, but can also alter speech. Listen to the result.

Parameter meanings in the preserved filters:
- loudnorm I is an integrated LUFS target, distinct from RMS level. -12 LUFS
  is this preset's choice, not a universal delivery standard or exact result.
- dynaudnorm p=0.85 sets the target peak amplitude relative to full scale.
- afftdn nf=-25 sets the noise floor in dB; nr sets reduction and is left at
  the FFmpeg default (12 dB on the tested build).
- agate threshold=0.0056 and range=0.056 are linear values. The nonzero range
  limits attenuation; it does not mute all background sound.

Exports are 48 kHz PCM16 WAV, with optional PCM24, explicit mono or RF64.
That encoder policy was introduced separately from the legacy filters; preset
identity does not promise identical files across formats or FFmpeg builds.
Standard mono/stereo channels are preserved unless -Mono is requested.
Original preset version, application version and report schema version are
recorded separately. Raw/Zoom default to Original. -Preset Gentle is an opt-in
experimental Raw candidate: 60 Hz highpass and afftdn nf=-35:nr=6, with declip,
declick and gate disabled. It retains leveling and has no listening approval.
Custom cleaning settings are recorded separately from the named base preset.

-Preview creates only a bounded local excerpt and comparison assets. It uses
up to five seconds of surrounding audio on each side for filter warmup, then
trims to the requested source interval. Stateful filters and normalization can
differ from a full-recording run; selected-graph delay is retained and disclosed.
Separate comparison copies use attenuation for level matching and a peak guard.
Silent/subsecond excerpts may be unmeasurable. Preview metrics describe excerpts,
not full-program loudness or speech quality. No playback starts automatically.
Ranges count from the selected track's timestamp origin. Negative or missing
origins are rejected; WAV without timestamps uses its first sample as zero.

The source and prior exports are preserved. New audio and per-run JSON/text
reports are written to Music by default; WinAudioClean_Log.txt is the summary.
Choose -JobFolder to group one invocation in a new local job folder, with media
and reports subfolders. -PickFile and -OpenOutputFolder are explicit optional
interactive actions. Ordinary console/unattended processing needs no desktop UI.
Reports may contain local paths and metadata. Diagnostic export is a separate
local action for ordinary full-run reports; preview/queue records require manual
review/summarization. Nothing is automatically uploaded. Early preflight/probe
failures may have console diagnostics only. Fast render has no fixed total
timeout; Accurate/Preview stages use duration-derived deadlines. Timing checks
validate selected-track duration, not container timecodes/video synchronization.
A crash may leave owned partials; inspect only after the job stops. Installation
in a user-writable folder needs no administrator rights or global security change.
See README.md, docs/SUPPORT.md, docs/SECURITY.md and docs/PORTABLE_PACKAGE.md.
.PARAMETER inputPath
One existing readable nonempty local file, also accepted at positional argument
zero. Ordinary drive/relative filesystem paths only; URLs, UNC/device/provider
paths and alternate data streams are rejected. No input prints usage (exit 2).
.PARAMETER Mode
Raw cleans plus levels; Zoom levels only. There is no built-in mode value:
choose at the prompt unless CLI or saved preferences supply it. Unattended or
redirected input requires a resolved mode. Q cancels interactive selection.
.PARAMETER OutputDirectory
Destination, created and checked for write access. Built-in default is the
current user's Music folder; CLI overrides saved preferences. No current-folder
fallback. JobFolder optionally creates separate media/reports subfolders.
.PARAMETER FfmpegPath
Explicit literal Windows ffmpeg.exe path. Lookup is explicit path, beside this
script, then PATH. Invalid explicit or present sibling candidates fail without
fallback. Version/filter capabilities are checked; no download occurs.
.PARAMETER FfprobePath
Explicit literal Windows ffprobe.exe path. Lookup is explicit path, beside the
resolved FFmpeg executable, then PATH. Invalid explicit/present sibling tools
fail without fallback. Use a trusted compatible build with both executables.
.PARAMETER AudioStreamIndex
Nonnegative absolute media stream index (including video indexes). Automatically
select the only audio track; otherwise choose interactively or bind the index
for unattended use. Only that audio track is exported; video/metadata/chapters
are omitted. Standard mono/stereo is supported, not multichannel downmix.
.PARAMETER BitDepth
PCM output bit depth: 16 (built-in default) or 24. Output is always 48 kHz WAV.
This encoder policy is separate from Original's retained legacy filter values;
files are not promised bit-identical across settings or FFmpeg builds.
.PARAMETER LoudnessMode
Fast (built-in default) uses the retained single-pass graph and reports final
loudness NOT_MEASURED. Accurate adds analysis and encoded-PCM verification with
-12 LUFS/-1.5 dBTP targets, +/-0.5 LU and maximum -1.3 dBTP acceptance. Valid
audio with fallback/unavailable/missed/failed final checks returns warning 7.
.PARAMETER Mono
Off by default. Explicitly average stereo left/right before processing; mono
stays mono. Without this switch standard mono/stereo channel order is retained.
An explicitly bound false overrides a saved true. Does not enable multichannel.
.PARAMETER Rf64
Off by default (ordinary RIFF WAV). Request RF64 even for small files; confirm
your reader supports it. Conservative RIFF size estimates above 4294967295 bytes
fail before rendering. Explicit false overrides saved true. No automatic split.
.PARAMETER NonInteractive
Off by default. Disable mode/track prompts; requires resolved mode and an
explicit/saved audio index for ambiguous input. Host noninteractive mode and
redirected stdin also suppress prompts. Picker/open-folder actions are rejected.
.PARAMETER ExportDiagnostic
Local ordinary full-run schema-1 JSON report (maximum 16 MiB) to project into
allowlisted support JSON. Requires DiagnosticOutputPath; no input or FFmpeg.
Omits paths, free-form metadata/diagnostics, timestamps, IDs and preset settings.
Preview JSON and queue JSONL are unsupported. Review manually before sharing.
Nothing is uploaded; the source report remains unchanged.
.PARAMETER DiagnosticOutputPath
New filename for ExportDiagnostic in an existing writable parent directory.
Existing files are never replaced. Export/validation failures return 2.
.PARAMETER Preset
Original (default) preserves the existing Raw/Zoom graphs. Gentle is experimental
and requires Raw. Neither the preset name nor synthetic checks certify speech quality.
.PARAMETER CleaningOptions
Optional typed dictionary for Raw. Declip, Declick, Denoise and Gate require
Boolean values. Finite numeric scalars: HighpassHz 20..200, NoiseFloorDb -80..-20,
NoiseReductionDb 0.01..20, GateThresholdDb -80..-20, GateRangeDb -60..0.
Unknown keys, numeric strings and arbitrary filter text are rejected. Supply a
PowerShell hashtable through & invocation; a literal hashtable cannot be passed
through a native -File argument. Zoom rejects nonempty cleaning options.
An explicit dictionary replaces the saved override dictionary, including @{}.
.PARAMETER SettingsPath
Optional local JSON preferences path. Defaults to the current user's application
data folder, WinAudioClean\settings.json. Missing files use built-in defaults.
Existing files are fully validated before use: explicit CLI > saved > built-in.
Requires the sibling WinAudioClean.Settings.ps1 when a settings file is present
or -SettingsPath or a management action is requested. No automatic save occurs.
.PARAMETER IgnoreSavedSettings
Bypass reading saved preferences for this invocation. Explicit CLI choices and
built-in defaults still apply. Use this to recover from a rejected settings file.
.PARAMETER ShowSettings
Print effective preferences and each value's origin as JSON, then exit without
input, FFmpeg, a menu or audio output. May accompany SaveSettings or ResetSettings.
.PARAMETER SaveSettings
Validate and atomically save effective preferences, then print them and exit.
CLI values override saved values; -IgnoreSavedSettings saves from built-in values.
Stores only existing processing preferences, never input/executable paths,
preview ranges, NonInteractive or diagnostic actions. Requires no input file.
.PARAMETER ResetSettings
Atomically replace preferences with an empty version-1 settings object, restoring
built-in defaults. Bypasses malformed/unknown-version JSON for explicit recovery.
Cannot accompany SaveSettings or processing choices. Requires no input file.
.PARAMETER InputPaths
Ordered explicit file list supplied through a PowerShell call. Select mode once,
then process each entry sequentially with the same resolved preferences. Repeated
entries remain explicit requests. Mutually exclusive with inputPath/InputListPath.
.PARAMETER InputListPath
Local UTF-8 JSON manifest: {"schemaVersion":1,"inputs":["recording.wav"]}.
Requires 1..1024 nonempty path strings and at most 1 MiB including optional BOM.
Relative paths resolve beside the manifest. Use this instead of a long CMD line
or positional percent/exclamation paths. No folder traversal or shell evaluation.
.PARAMETER InputDirectories
One through 64 local folders. Freeze the selection before sequential processing;
deduplicate by file identity and record unsupported/generated/reparse entries as
skipped. Mutually exclusive with inputPath, InputPaths and InputListPath. Requires
the sibling Queue, Batch and Settings components. Explicit lists retain repeats.
.PARAMETER Recurse
Opt in to ordinary subfolders for InputDirectories. Default: immediate entries
only. Never follow symbolic links, junctions or other reparse entries. A proper
descendant destination subtree is excluded; new files never enter a running queue.
.PARAMETER BatchResultPath
Optional new JSON Lines journal for explicit lists or folder queues. The parent must
already exist; an existing file is never replaced. Default: a unique
WinAudioClean_Batch_<id>.jsonl in the destination. Each item is flushed before
the next starts. One-item explicit lists retain their exit; other failed batches
produce 6, warnings alone 7, cancellation 130. Journal failure stops new jobs
with 5 and preserves prior outputs/results with incomplete-report diagnostics.
.PARAMETER Preview
Create source/processed excerpts and separate level-matched comparison WAVs.
The opt-in route ends after preview; it never starts a full render or playback.
Requires the sibling WinAudioClean.Preview.ps1. Open comparison files explicitly.
.PARAMETER JobFolder
Group one invocation, including an entire queue, in a new WinAudioClean_Job_<id>
folder under Music or the chosen destination. Audio goes into media; JSON/text
reports, the summary and the default batch journal go into reports. An explicit
BatchResultPath still overrides journal placement. Requires WinAudioClean.Output.ps1.
Folders are never reused or swept. Failed attempts may retain empty directories.
This option is not saved as a preference; the legacy flat layout remains default.
.PARAMETER PickFile
Explicitly show an optional single-file picker in an interactive Windows STA
host. Windows Forms loads only for this action; console paths need no GUI.
Cannot accompany any input/queue selection. Cancel returns 130 without processing.
An unavailable picker fails with guidance to supply inputPath. No-input use shows
console usage and never automatically opens a picker.
.PARAMETER OpenOutputFolder
Explicitly open only the completed destination directory after published success
or warning. Requires an interactive console; unattended/redirected requests fail
before processing. Failed/cancelled/mixed-failed queues never open a destination.
An open failure prints a warning and preserves the processing exit. No file or
playback is opened. JobFolder opens the job root once, including for queues.
.PARAMETER PreviewStartSeconds
Nonnegative finite seconds from the selected source's start, default 0.
Use an invariant decimal point. Requires -Preview and a start inside the source.
.PARAMETER PreviewDurationSeconds
Positive finite duration through 60 seconds, default 45. The omitted default
shortens to the available source; an explicit duration beyond the end is rejected.
Requires -Preview. Source interval rounding is to complete 48 kHz samples.
.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Zoom -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive

From the extracted folder, supply your readable recording.wav and trusted
sibling ffmpeg.exe/ffprobe.exe. Exports is created automatically. The process
execution policy does not change machine-wide settings. Built-in PS5.1 is used.
.EXAMPLE
& .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Raw -BitDepth 24 -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive

Original Raw with 48 kHz PCM24 output; original filters remain unchanged.
.EXAMPLE
& .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Zoom -LoudnessMode Accurate -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive

Measured normalization and final encoded-PCM verification. Review warning 7;
valid audio is retained. Numeric checks do not certify speech quality.
.EXAMPLE
& .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Raw -Preset Gentle -CleaningOptions @{Gate=$false; NoiseReductionDb=4} -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive

Experimental Gentle with a typed override dictionary. No listening approval.
.EXAMPLE
& .\WinAudioClean.ps1 -inputPath '.\recording.wav' -Mode Zoom -Preview -PreviewStartSeconds 1 -PreviewDurationSeconds 3 -OutputDirectory '.\Exports' -IgnoreSavedSettings -NonInteractive

Requires at least four seconds of input. Creates four local excerpt/comparison
WAVs only; open them yourself. No playback or full render starts automatically.
.EXAMPLE
& .\WinAudioClean.ps1 -SaveSettings -SettingsPath '.\example-settings.json' -Mode Zoom -OutputDirectory '.\Exports' -IgnoreSavedSettings

Explicitly save to a separate example preferences file without processing audio.
CLI overrides saved values; normal runs never save automatically.
.NOTES
Author: Janne Vuorela. Application version 1.0.0. Windows desktop with PS5.1/PS7.
Windows 10/11 are intended targets; active-machine validation used build 26300,
PS5.1.26100.9444 / PS7.6.5 and FFmpeg/ffprobe 9.0.2 essentials. Other OS/build
and managed-policy compatibility is not universally verified.
Keep WinAudioClean.ps1, WinAudioClean.IO.ps1 and WinAudioClean.bat together.
Keep WinAudioClean.Preview.ps1 beside them to use optional previews.
Keep WinAudioClean.Settings.ps1 beside them to use saved preferences.
Keep WinAudioClean.Batch.ps1 and WinAudioClean.Settings.ps1 for explicit lists.
Supply FFmpeg/ffprobe through -FfmpegPath/-FfprobePath, beside the script, or PATH.
No dependency is automatically downloaded. Processing time depends on the file
and machine. Severe noise and lost/clipped detail may not be recoverable;
80 Hz filtering and leveling can affect voice character. Speech-quality
listening has not been completed. This is a personal tool provided as-is.
.LINK
https://ffmpeg.org/ffmpeg-filters.html
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)][string]$inputPath,
    [string]$Mode,
    [string]$OutputDirectory,
    [string]$FfmpegPath,
    [string]$FfprobePath,
    [string]$AudioStreamIndex,
    [string]$BitDepth = '16',
    [string]$LoudnessMode = 'Fast',
    [string]$Preset = 'Original',
    [System.Collections.IDictionary]$CleaningOptions = @{},
    [switch]$Preview,
    [string]$PreviewStartSeconds = '0',
    [string]$PreviewDurationSeconds = '45',
    [switch]$Mono,
    [switch]$Rf64,
    [switch]$NonInteractive,
    [string]$ExportDiagnostic,
    [string]$DiagnosticOutputPath,
    [string]$SettingsPath,
    [switch]$IgnoreSavedSettings,
    [switch]$ShowSettings,
    [switch]$SaveSettings,
    [switch]$ResetSettings,
    [string[]]$InputPaths,
    [string]$InputListPath,
    [string[]]$InputDirectories,
    [switch]$Recurse,
    [string]$BatchResultPath,
    [switch]$JobFolder,
    [switch]$PickFile,
    [switch]$OpenOutputFolder,
    [Parameter(DontShow = $true)]$WacOutputLayout,
    [Parameter(DontShow = $true)]$WacRunContext
)

. (Join-Path $PSScriptRoot 'WinAudioClean.IO.ps1')

# Importing defines helpers only; filesystem checks run when explicitly called.
function Resolve-WacFileSystemPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A filesystem path is required.' }
    # UNC and device namespaces are outside the current supported path policy.
    # A drive path can still be mapped/redirected; this is not an offline guarantee.
    if ($Path -match '^[\\/]{2}') { throw 'UNC and device paths are not supported. Use a local drive path.' }
    if ($Path -match '^[a-zA-Z][a-zA-Z0-9+.-]*://' -or $Path.Contains('::')) {
        throw 'Only filesystem paths are supported; URLs and provider-qualified paths are not accepted.'
    }
    $provider = $null
    $drive = $null
    try {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
    } catch {
        throw 'Cannot resolve this filesystem path.'
    }
    if ($provider.Name -ne 'FileSystem') { throw 'Only filesystem paths are supported.' }
    if ($resolved -match '^[\\/]{2}') { throw 'UNC and device paths are not supported. Use a local drive path.' }
    # Restrict native handoff to ordinary Windows drive paths, with no alternate
    # data streams, wildcard characters, or control characters.
    if ($resolved -notmatch '^[a-zA-Z]:[\\/]' -or $resolved.Substring(2) -match '[:*?"<>|\x00-\x1f]') {
        throw 'Unsupported filesystem path. Use an ordinary Windows file or directory path.'
    }
    $resolved
}

function Get-WacInputFile {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'No input file supplied. Drop a file onto WinAudioClean.bat or run: .\WinAudioClean.ps1 -inputPath "C:\Audio\recording.wav" [-Mode Raw|Zoom -NonInteractive]'
    }
    $resolved = Resolve-WacFileSystemPath -Path $Path
    try { $item = Get-Item -LiteralPath $resolved -Force -ErrorAction Stop }
    catch { throw 'Input file does not exist or cannot be accessed.' }
    if ($null -eq $item) { throw 'Input file does not exist or cannot be accessed.' }
    if ($item -isnot [System.IO.FileInfo]) { throw 'Input must be a file, not a directory.' }
    $stream = $null
    try {
        $stream = [System.IO.File]::Open($item.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        if ($stream.Length -eq 0) { throw 'Input file is empty (zero bytes).' }
        $null = $stream.ReadByte()
    } catch {
        throw "Input file is not readable or is empty (zero bytes): $($_.Exception.Message)"
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
    }
    $item
}

function Get-WacOutputDirectory {
    param([string]$Path, [switch]$DefaultMusic)

    if ($DefaultMusic -and ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '^[a-zA-Z]:[\\/]')) {
        throw 'Music is unavailable or redirected to an unsupported location. Supply -OutputDirectory with a writable local folder.'
    }

    $resolved = Resolve-WacFileSystemPath -Path $Path
    $probe = $null
    try {
        $null = [System.IO.Directory]::CreateDirectory($resolved)
        $probePath = [System.IO.Path]::Combine($resolved, ('.wac-write-check-' + [guid]::NewGuid().ToString('N') + '.tmp'))
        $probe = [System.IO.FileStream]::new($probePath, [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 1, [System.IO.FileOptions]::DeleteOnClose)
        $probe.WriteByte(0)
        $probe.Flush()
    } catch {
        throw "Output directory cannot be created or written: $($_.Exception.Message)"
    } finally {
        if ($null -ne $probe) { $probe.Dispose() }
    }
    $resolved
}

function Get-WacDefaultOutputDirectory {
    [Environment]::GetFolderPath('MyMusic')
}

function Show-WacUsage {
    Write-Host 'No input file supplied. Drop files onto WinAudioClean.bat, or use one of these PowerShell commands:'
    Write-Host '.\WinAudioClean.ps1 -inputPath "C:\Audio\recording.wav" -Mode Zoom -NonInteractive'
    Write-Host '.\WinAudioClean.ps1 -inputPath "C:\Audio\recording.wav" -Mode Raw -OutputDirectory "C:\Audio\Exports" -JobFolder'
    Write-Host '.\WinAudioClean.ps1 -PickFile -Mode Zoom -OpenOutputFolder'
    Write-Host 'Music is the default. -JobFolder groups one invocation in a new job folder with media and reports subfolders.'
    Write-Host 'Use -InputPaths, -InputListPath or -InputDirectories for queues. Picker/open actions require an interactive console.'
}

function Show-WacFilePicker {
    if (-not (Test-WacInteractive)) { throw 'PickFile requires an interactive console. Supply -inputPath for terminal or unattended use.' }
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
        throw 'The optional file picker requires an STA host. Start PowerShell with -STA, or supply -inputPath.'
    }
    $dialog = $null
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Choose one local recording for WinAudioClean'
        $dialog.Filter = 'Media files|*.wav;*.mp3;*.flac;*.ogg;*.m4a;*.mp4;*.mkv;*.webm;*.aac;*.aif;*.aiff;*.wma;*.avi|All files|*.*'
        $dialog.Multiselect = $false
        $dialog.CheckFileExists = $true
        $dialog.CheckPathExists = $true
        $dialog.RestoreDirectory = $true
        if ($dialog.ShowDialog() -eq 'OK') { return $dialog.FileName }
        return $null
    } catch { throw ('Optional file picker is unavailable: ' + $_.Exception.Message + ' Supply -inputPath instead.') }
    finally { if ($null -ne $dialog) { $dialog.Dispose() } }
}

function Open-WacDestinationFolder {
    param([Parameter(Mandatory = $true)][string]$Directory, [string]$ExpectedDirectoryIdentity)
    $resolved = Resolve-WacFileSystemPath -Path $Directory
    $item = Get-Item -LiteralPath $resolved -Force -ErrorAction Stop
    if ($item -isnot [IO.DirectoryInfo]) { throw 'Only an existing destination directory can be opened.' }
    Initialize-WacNativeFileIO
    $handle = $null; $process = $null
    try {
        $handle = [WinAudioClean.NativeFileIO]::OpenDirectory($resolved)
        if ($ExpectedDirectoryIdentity -and [WinAudioClean.NativeFileIO]::Identity($handle) -ne $ExpectedDirectoryIdentity) {
            throw 'The completed destination directory changed; it will not be opened.'
        }
        $canonical = Resolve-WacFileSystemPath -Path ([WinAudioClean.NativeFileIO]::ResolvedPath($handle))
        $start = New-Object Diagnostics.ProcessStartInfo
        $start.FileName = $canonical
        $start.UseShellExecute = $true
        $start.Verb = 'open'
        $process = [Diagnostics.Process]::Start($start)
    } finally {
        if ($null -ne $process) { $process.Dispose() }
        if ($null -ne $handle) { $handle.Dispose() }
    }
}

function Invoke-WacOutputFollowUp {
    param([bool]$Requested, [bool]$Interactive, [int]$ExitCode, [bool]$Published, [string]$Directory, [string]$ExpectedDirectoryIdentity)
    if (-not $Requested -or -not $Interactive -or -not $Published -or $ExitCode -notin @(0, 7)) { return }
    try { Open-WacDestinationFolder -Directory $Directory -ExpectedDirectoryIdentity $ExpectedDirectoryIdentity }
    catch { Write-Warning ('Destination could not be opened: ' + $_.Exception.Message + ' Audio outcome is unchanged; open the printed directory manually.') }
}

function Get-WacOutputOrganization {
    param($Layout)
    if ($null -eq $Layout) { return $null }
    Assert-WacOutputLayout -Layout $Layout
    [ordered]@{ jobId = $Layout.JobId; rootDirectory = $Layout.RootDirectory
        mediaDirectory = $Layout.MediaDirectory; reportDirectory = $Layout.ReportDirectory }
}

function Test-WacInteractive {
    param(
        [switch]$NonInteractive,
        [string[]]$HostArguments = [Environment]::GetCommandLineArgs(),
        [bool]$InputRedirected = [Console]::IsInputRedirected,
        [bool]$UserInteractive = [Environment]::UserInteractive
    )

    if ($NonInteractive -or -not $UserInteractive -or $InputRedirected) { return $false }
    # Inspect host switches only; script arguments may contain the same text.
    foreach ($argument in ($HostArguments | Select-Object -Skip 1)) {
        if ($argument -notmatch '^[-/]') { continue }
        $hostSwitch = $argument.Substring(1).ToLowerInvariant()
        if (-not $hostSwitch) { continue }
        if ('file'.StartsWith($hostSwitch) -or 'command'.StartsWith($hostSwitch) -or
            'encodedcommand'.StartsWith($hostSwitch) -or 'commandwithargs'.StartsWith($hostSwitch) -or
            $hostSwitch -in @('ec', 'cwa')) { break }
        if ($hostSwitch.Length -ge 4 -and 'noninteractive'.StartsWith($hostSwitch)) { return $false }
    }
    $true
}

function Read-WacHostSelection {
    param([string]$Prompt)
    $restore = $null -ne $script:WacRunContext -and $script:WacRunContext.ConsoleHandlerRegistered
    # Native control interception is for running work. At Read-Host, retain the
    # host's usual Ctrl+C behavior instead of swallowing it while input waits.
    if ($restore) { $script:WacRunContext.Dispose() }
    try { Read-Host $Prompt }
    finally { if ($restore) { $script:WacRunContext.CaptureConsole() } }
}

function Read-WacMode {
    while ($true) {
        try { $choice = Read-WacHostSelection -Prompt "`nEnter selection (1 or 2; Q to cancel)" }
        catch { throw 'Cannot read a mode. Supply -Mode Raw or -Mode Zoom with -NonInteractive.' }
        if ($null -eq $choice) { return $null }
        switch ($choice.Trim()) {
            '1' { return 'Raw' }
            '2' { return 'Zoom' }
            'q' { return $null }
            'cancel' { return $null }
            default { Write-Host 'Invalid selection. Enter 1 for Raw, 2 for Zoom, or Q to cancel.' -ForegroundColor Yellow }
        }
    }
}

function Get-WacCleaningSettings {
    param([string]$Preset = 'Original', [System.Collections.IDictionary]$Options = @{})

    if ($Preset -notin @('Original', 'Gentle')) { throw 'Preset must be Original or Gentle.' }
    if ($null -eq $Options) { throw 'Cleaning options must be a typed dictionary, not null.' }
    $gentle = $Preset -eq 'Gentle'
    $settings = [ordered]@{
        schemaVersion = 1
        Declip = (-not $gentle); Declick = (-not $gentle); Denoise = $true; Gate = (-not $gentle)
        HighpassHz = $(if ($gentle) { 60.0 } else { 80.0 })
        NoiseFloorDb = $(if ($gentle) { -35.0 } else { -25.0 })
        NoiseReductionDb = $(if ($gentle) { 6.0 } else { 12.0 })
        GateThresholdDb = -45.0; GateRangeDb = -25.0
    }
    $bounds = @{
        HighpassHz = @(20, 200); NoiseFloorDb = @(-80, -20); NoiseReductionDb = @(0.01, 20)
        GateThresholdDb = @(-80, -20); GateRangeDb = @(-60, 0)
    }
    # Never coerce strings, booleans, arrays or scriptblocks into filter values.
    # Numeric settings are finite scalar CLR numbers, serialized invariantly.
    $seen = @{}
    foreach ($key in $Options.Keys) {
        if ($key -isnot [string] -or $key -notin @('Declip', 'Declick', 'Denoise', 'Gate') + @($bounds.Keys)) {
            throw 'Unknown cleaning option. Only documented cleaning settings are accepted.'
        }
        if ($seen.ContainsKey($key)) { throw 'Duplicate cleaning option.' }
        $seen[$key] = $true
        $value = $Options[$key]
        if ($key -in @('Declip', 'Declick', 'Denoise', 'Gate')) {
            if ($value -isnot [bool]) { throw "Cleaning option $key must be a Boolean." }
            $settings[$key] = $value
        } else {
            if ($value -isnot [byte] -and $value -isnot [sbyte] -and $value -isnot [int16] -and
                $value -isnot [uint16] -and $value -isnot [int] -and $value -isnot [uint32] -and
                $value -isnot [long] -and $value -isnot [uint64] -and $value -isnot [single] -and
                $value -isnot [double] -and $value -isnot [decimal]) {
                throw "Cleaning option $key must be a finite numeric scalar."
            }
            $number = [double]$value
            if ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or
                $number -lt $bounds[$key][0] -or $number -gt $bounds[$key][1]) {
                throw "Cleaning option $key is outside its supported range."
            }
            $settings[$key] = $number
        }
    }
    $settings
}

function Get-WacProcessingProfile {
    param([string]$Choice, [string]$Preset = 'Original',
        [System.Collections.IDictionary]$CleaningOptions = @{})

    if ($Choice -cnotin @('1', '2')) { throw 'Invalid processing choice. Expected 1 (Raw) or 2 (Zoom).' }
    $settings = Get-WacCleaningSettings -Preset $Preset -Options $CleaningOptions
    if ($Choice -eq '2' -and ($Preset -ne 'Original' -or $CleaningOptions.Count -gt 0)) {
        throw 'Zoom is leveling only. Use Original with no cleaning options, or choose Raw for cleaning.'
    }
    $gentle = $Preset -eq 'Gentle'
    $levelFilters = 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
    $filters = @()
    if ($Choice -eq '1') {
        $culture = [Globalization.CultureInfo]::InvariantCulture
        if ($settings.Declip) { $filters += 'adeclip' }
        $filters += 'highpass=f=' + $settings.HighpassHz.ToString('0.###############', $culture)
        if ($settings.Declick) { $filters += 'adeclick' }
        if ($settings.Denoise) {
            $denoise = 'afftdn=nf=' + $settings.NoiseFloorDb.ToString('0.###############', $culture)
            # The frozen Original graph intentionally leaves nr at FFmpeg's default.
            if ($gentle -or $settings.NoiseFloorDb -ne -25 -or $settings.NoiseReductionDb -ne 12) {
                $denoise += ':nr=' + $settings.NoiseReductionDb.ToString('0.###############', $culture)
            }
            $filters += $denoise
        }
        if ($settings.Gate) {
            # Preserve the legacy rounded linear values at its documented dB settings.
            $range = if ($settings.GateRangeDb -eq -25) { '0.056' } else {
                [math]::Pow(10, $settings.GateRangeDb / 20).ToString('0.###############', $culture)
            }
            $threshold = if ($settings.GateThresholdDb -eq -45) { '0.0056' } else {
                [math]::Pow(10, $settings.GateThresholdDb / 20).ToString('0.###############', $culture)
            }
            $filters += 'agate=range=' + $range + ':threshold=' + $threshold
        }
    }
    $filters += $levelFilters
    [pscustomobject]@{
        PresetId = $(if ($gentle) { 'gentle' } else { 'original' })
        PresetName = $(if ($gentle) { 'Gentle (experimental)' } else { 'Original' })
        PresetVersion = $(if ($gentle) { '0.1.0' } else { '1.0.0' })
        PresetExperimental = $gentle; CleaningCustomized = ($CleaningOptions.Count -gt 0)
        ModeChoice = $Choice; ModeName = $(if ($Choice -eq '1') { 'RAW (Clean+Level)' } else { 'ZOOM (Level Only)' })
        CleaningSettings = $(if ($Choice -eq '1') { $settings } else { $null })
        FilterChain = ($filters -join ',')
    }
}

function Get-WacOutputPath {
    param([string]$InputPath, [string]$OutputFolder, [string]$Timestamp,
        [ValidatePattern('^[a-fA-F0-9]{32}$')][string]$JobId = [guid]::NewGuid().ToString('N'))

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    [IO.Path]::Combine($OutputFolder, "$fileName`_Cleaned_$Timestamp`_$JobId.wav")
}

function Get-WacFfmpegArguments {
    param([string]$InputPath, [string]$FilterChain, [string]$OutputFile,
        [Parameter(Mandatory = $true)][ValidateRange(0, 2147483647)][int]$AudioStreamIndex,
        $OutputPolicy = (Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })))

    # Runtime passes only the exclusively created, held transaction partial.
    # -y lets FFmpeg fill that owned file; it never receives the final path.
    @('-nostdin') + (Get-WacLocalMediaArguments) + @('-i', $InputPath,
        '-map', ('0:' + $AudioStreamIndex.ToString([Globalization.CultureInfo]::InvariantCulture)), '-vn', '-af', ($OutputPolicy.FilterPrefix + $FilterChain),
        '-ar', '48000', '-c:a', $OutputPolicy.Codec, '-ac', [string]$OutputPolicy.Channels,
        '-channel_layout', $OutputPolicy.Layout, '-map_metadata', '-1', '-map_chapters', '-1',
        '-f', 'wav', '-rf64', $(if ($OutputPolicy.Rf64) { 'always' } else { 'never' }), $OutputFile,
        '-y', '-hide_banner', '-loglevel', 'error', '-stats')
}

function Get-WacOutputPolicy {
    param([Parameter(Mandatory = $true)]$InputAudio,
        [ValidateSet('16', '24')][string]$BitDepth = '16', [switch]$Mono, [switch]$Rf64)

    if ($InputAudio.Channels -notin @(1, 2)) {
        throw 'Only mono and stereo input tracks are supported. Prepare a mono/stereo track explicitly before processing; multichannel audio is never downmixed automatically.'
    }
    $layout = if ($InputAudio.Channels -eq 1) { 'mono' } else { 'stereo' }
    if ($null -ne $InputAudio.ChannelLayout -and
        ($InputAudio.ChannelLayout -isnot [string] -or
        (-not [string]::IsNullOrWhiteSpace($InputAudio.ChannelLayout) -and $InputAudio.ChannelLayout -cne $layout))) {
        throw "Unsupported channel layout. Expected $layout for $($InputAudio.Channels) channel(s); prepare a standard mono/stereo track explicitly."
    }
    $channels = if ($Mono) { 1 } else { $InputAudio.Channels }
    [pscustomobject]@{
        SampleRate = 48000; Bits = [int]$BitDepth; Codec = ('pcm_s' + $BitDepth + 'le')
        Channels = [int]$channels; Layout = $(if ($channels -eq 1) { 'mono' } else { 'stereo' }); Rf64 = [bool]$Rf64
        # Explicit mono is an equal-weight stereo mix before the original chain.
        FilterPrefix = $(if ($Mono -and $InputAudio.Channels -eq 2) { 'pan=mono|c0=0.5*c0+0.5*c1,' } else { '' })
    }
}

function Get-WacOutputSpaceEstimate {
    param([Parameter(Mandatory = $true)][double]$DurationSeconds,
        [Parameter(Mandatory = $true)]$OutputPolicy)

    if ([double]::IsNaN($DurationSeconds) -or [double]::IsInfinity($DurationSeconds) -or
        $DurationSeconds -le 0 -or $DurationSeconds -gt 1000000000) {
        throw 'Cannot estimate output space from this duration (supported range: greater than zero through 1 billion seconds).'
    }
    if ($OutputPolicy.SampleRate -ne 48000 -or $OutputPolicy.Bits -notin @(16, 24) -or $OutputPolicy.Channels -notin @(1, 2)) {
        throw 'Invalid output format for disk estimation.'
    }
    # Include compressed padding/timing tolerance and one sample of rounding.
    # Decimal arithmetic avoids 32-bit overflow and floating-point size boundaries.
    $frames = [decimal]::Ceiling(([decimal]$DurationSeconds + [decimal]0.101) * 48000)
    $dataBytes = [long]($frames * $OutputPolicy.Channels * ($OutputPolicy.Bits / 8))
    $fileBytes = $dataBytes + [long]1MB
    if (-not $OutputPolicy.Rf64 -and $fileBytes -gt [long][uint32]::MaxValue) {
        throw 'Estimated WAV size exceeds the safe RIFF limit. Use -Rf64 with an RF64-compatible editor, or explicitly choose mono/16-bit when suitable. Audio will not be truncated or split.'
    }
    $reserveBytes = [long][math]::Max([decimal]64MB, [decimal]::Ceiling([decimal]$fileBytes / 10))
    [pscustomobject]@{
        DataBytes = $dataBytes; FileBytes = $fileBytes; ReserveBytes = $reserveBytes
        RequiredBytes = ($fileBytes + $reserveBytes)
    }
}

function Assert-WacOutputSpace {
    param([Parameter(Mandatory = $true)]$Transaction, [Parameter(Mandatory = $true)]$Estimate)
    $available = Get-WacAvailableOutputBytes -Transaction $Transaction
    if ($available -lt $Estimate.RequiredBytes) {
        throw "Insufficient destination space: need $($Estimate.RequiredBytes) bytes including headroom; $available bytes available. Free space or choose another -OutputDirectory."
    }
    $available
}

function Get-WacLocalMediaArguments {
    # Apply before the input in BOTH tools. Playlists/concat/device demuxers and
    # network/nested protocols are deliberately outside the supported policy.
    @('-protocol_whitelist', 'file', '-format_whitelist',
        'wav,mp3,flac,ogg,mov,matroska,webm,aac,aiff,asf,avi')
}

function Resolve-WacExecutable {
    param([ValidateSet('ffmpeg.exe', 'ffprobe.exe')][string]$Name,
        [string]$ExplicitPath, [string]$SiblingDirectory)

    if ($PSBoundParameters.ContainsKey('ExplicitPath')) {
        if ([string]::IsNullOrWhiteSpace($ExplicitPath)) { throw "An explicit $Name path cannot be empty." }
        $candidate = Resolve-WacFileSystemPath -Path $ExplicitPath
    } else {
        $candidate = Join-Path $SiblingDirectory $Name
        if (-not (Test-Path -LiteralPath $candidate -ErrorAction Stop)) {
            $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $command) { throw "$Name not found. Supply its explicit path, put it in '$SiblingDirectory', or add it to PATH. No tools are downloaded automatically." }
            $candidate = Resolve-WacFileSystemPath -Path $command.Source
        }
    }
    try { $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop }
    catch { throw "Cannot access $Name at '$candidate'. Check the explicit path or installation." }
    if ($item -isnot [IO.FileInfo] -or $item.Extension -ne '.exe' -or $item.Length -eq 0) {
        throw "Invalid $Name executable at '$candidate'. Supply a nonempty Windows .exe file."
    }
    $item.FullName
}

function Assert-WacInspectionResult {
    param($Result, [string]$Operation)

    if (-not $Result.Started -or $Result.TimedOut -or $Result.Error -or
        $Result.CleanupError -or $null -eq $Result.ExitCode -or $Result.ExitCode -ne 0) {
        throw "$Operation failed (native exit: $($Result.ExitCode); timeout: $($Result.TimedOut)). $($Result.Error) $($Result.CleanupError) $($Result.StandardError)"
    }
}

function Get-WacToolVersion {
    param([string]$FilePath, [ValidateSet('ffmpeg', 'ffprobe')][string]$ToolName,
        [ValidateRange(1, 60000)][int]$TimeoutMilliseconds = 15000)

    $result = Invoke-WacNativeProcess -FilePath $FilePath -ArgumentList @('-version') -TimeoutMilliseconds $TimeoutMilliseconds
    Assert-WacInspectionResult -Result $result -Operation "$ToolName version check at '$FilePath'"
    $versionLine = ($result.StandardOutput -split '\r?\n' | Select-Object -First 1).Trim()
    if ($versionLine -notmatch ('^' + $ToolName + ' version \S+')) {
        throw "Incompatible $ToolName at '$FilePath': its -version response is not recognized. Use a Windows FFmpeg build containing ffmpeg.exe and ffprobe.exe."
    }
    $versionLine
}

function Test-WacRequiredFilters {
    param([string]$FfmpegPath, [string]$FilterChain,
        [ValidateRange(1, 60000)][int]$TimeoutMilliseconds = 15000)

    $result = Invoke-WacNativeProcess -FilePath $FfmpegPath -ArgumentList @('-hide_banner', '-filters') -TimeoutMilliseconds $TimeoutMilliseconds
    Assert-WacInspectionResult -Result $result -Operation "FFmpeg filter check at '$FfmpegPath'"
    $available = @(foreach ($line in ($result.StandardOutput -split '\r?\n')) {
        if ($line -match '^\s*[TSC.]{2,3}\s+([a-zA-Z0-9_]+)\s+[AVN|]+->[AVN|]+\s') { $Matches[1] }
    })
    $required = @($FilterChain -split ',' | ForEach-Object { ($_ -split '=', 2)[0] } | Select-Object -Unique)
    $missing = @($required | Where-Object { $_ -cnotin $available })
    if ($missing.Count -gt 0) {
        throw "FFmpeg at '$FfmpegPath' lacks filters required by this mode: $($missing -join ', '). Choose a build with these filters or supply -FfmpegPath."
    }
}

function Get-WacStreamDuration {
    param($Stream)

    $seconds = 0.0
    $style = [Globalization.NumberStyles]::Float
    $culture = [Globalization.CultureInfo]::InvariantCulture
    if ($Stream.duration -is [string] -and
        [double]::TryParse($Stream.duration, $style, $culture, [ref]$seconds) -and
        -not [double]::IsNaN($seconds) -and -not [double]::IsInfinity($seconds) -and $seconds -gt 0) {
        return $seconds
    }
    # Matroska commonly provides a per-stream end timestamp instead of duration.
    # Container duration is deliberately excluded: another track may be longer.
    if ($Stream.tags.DURATION -is [string] -and
        $Stream.tags.DURATION -match '^(\d{1,9}):([0-5]\d):([0-5]\d(?:\.\d+)?)$') {
        $seconds = [double]::Parse($Matches[1], $culture) * 3600 +
            [double]::Parse($Matches[2], $culture) * 60 + [double]::Parse($Matches[3], $culture)
        $start = 0.0
        if ($Stream.start_time -is [string] -and
            [double]::TryParse($Stream.start_time, $style, $culture, [ref]$start) -and
            -not [double]::IsNaN($start) -and -not [double]::IsInfinity($start)) { $seconds -= $start }
        if ($seconds -gt 0) { return $seconds }
    }
    $null
}

function Assert-WacWaveOutput {
    param([Parameter(Mandatory = $true)][IO.Stream]$Stream,
        [Parameter(Mandatory = $true)]$InputAudio,
        [Parameter(Mandatory = $true)]$OutputAudio,
        $OutputPolicy)

    # Read the same object held against writes/deletion through publication.
    # Chunk lengths and frame alignment detect truncation that ffprobe can accept.
    if (-not $Stream.CanSeek -or $Stream.Length -lt 44) { throw 'Output WAV is empty or truncated.' }
    $reader = [IO.BinaryReader]::new($Stream, [Text.Encoding]::ASCII, $true)
    try {
        $Stream.Position = 0
        $signature = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        if ($signature -cnotin @('RIFF', 'RF64')) { throw 'Output must be a RIFF or RF64 WAV.' }
        $isRf64 = $signature -ceq 'RF64'
        $declaredLength = $reader.ReadUInt32()
        $riffLength = [long]$declaredLength + 8
        if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -cne 'WAVE') {
            throw 'Output WAV declared size does not match the file (incomplete or invalid output).'
        }
        $rf64DataBytes = [long]0
        $rf64Frames = [long]0
        if ($isRf64) {
            # Support the single-data-chunk RF64 form emitted by FFmpeg. Additional
            # 64-bit chunk tables are deliberately rejected, never partly parsed.
            if ($declaredLength -ne [uint32]::MaxValue -or $Stream.Length -lt 80 -or
                [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -cne 'ds64' -or $reader.ReadUInt32() -ne 28) {
                throw 'Invalid RF64 header: expected size sentinel and a first 28-byte ds64 chunk.'
            }
            $riffSize64 = $reader.ReadUInt64()
            $dataSize64 = $reader.ReadUInt64()
            $sampleCount64 = $reader.ReadUInt64()
            $tableCount = $reader.ReadUInt32()
            if ($tableCount -ne 0) { throw 'Unsupported RF64 ds64 chunk table; only one PCM data chunk is supported.' }
            if ($riffSize64 -gt [uint64]([long]::MaxValue - 8) -or $dataSize64 -gt [uint64][long]::MaxValue -or
                $sampleCount64 -gt [uint64][long]::MaxValue) { throw 'Invalid RF64 ds64 size or sample count exceeds supported 64-bit bounds.' }
            $riffLength = [long]$riffSize64 + 8
            $rf64DataBytes = [long]$dataSize64
            $rf64Frames = [long]$sampleCount64
        } elseif ($declaredLength -eq [uint32]::MaxValue) {
            throw 'Invalid RIFF size sentinel; use RF64 for large WAV output.'
        }
        if ($riffLength -ne $Stream.Length) {
            throw 'Output WAV declared size does not match the file (incomplete or invalid output).'
        }
        $format = $null
        $dataBytes = [long]0
        $seenData = $false
        $chunks = 0
        while ($Stream.Position -lt $riffLength) {
            if (++$chunks -gt 4096 -or $riffLength - $Stream.Position -lt 8) { throw 'Invalid WAV chunk table.' }
            $name = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
            $length = [long]$reader.ReadUInt32()
            if ($name -ceq 'ds64') { throw 'Unexpected or duplicate RF64 ds64 chunk.' }
            if ($isRf64 -and $name -ceq 'data') {
                if ($length -ne [uint32]::MaxValue) { throw 'Invalid RF64 data size: expected the ds64 size sentinel.' }
                $length = $rf64DataBytes
            } elseif ($length -eq [uint32]::MaxValue) {
                throw 'Unsupported WAV chunk size sentinel.'
            }
            # Compare before adding: a hostile 64-bit length must never overflow
            # or promote integer arithmetic to an imprecise floating-point value.
            $remaining = $riffLength - $Stream.Position
            $padding = $length % 2
            if ($length -gt $remaining -or $padding -gt ($remaining - $length)) { throw 'Output WAV chunk is truncated.' }
            $next = $Stream.Position + $length + $padding
            if ($name -ceq 'fmt ') {
                if ($null -ne $format -or $length -lt 16) { throw 'Invalid WAV format chunk.' }
                $tag = $reader.ReadUInt16()
                $channels = $reader.ReadUInt16()
                $rate = $reader.ReadUInt32()
                $byteRate = $reader.ReadUInt32()
                $align = $reader.ReadUInt16()
                $bits = $reader.ReadUInt16()
                $validBits = $bits
                $channelMask = [uint32]0
                if ($tag -eq 65534) {
                    if ($length -lt 40) { throw 'Invalid extensible WAV format.' }
                    $extraSize = $reader.ReadUInt16()
                    if ($extraSize -lt 22 -or $extraSize -gt ($length - 18)) { throw 'Invalid extensible WAV format length.' }
                    $validBits = $reader.ReadUInt16()
                    $channelMask = $reader.ReadUInt32()
                    $subtype = [guid]::new($reader.ReadBytes(16))
                    if ($subtype -ne [guid]'00000001-0000-0010-8000-00aa00389b71' -or $validBits -le 0 -or $validBits -gt $bits) {
                        throw 'Unsupported WAV PCM subtype.'
                    }
                    $tag = 1
                }
                if ($tag -ne 1 -or $channels -le 0 -or $rate -le 0 -or $bits -notin @(8, 16, 24, 32) -or
                    $align -ne ($channels * ($bits / 8)) -or $byteRate -ne ([long]$rate * $align)) {
                    throw 'Output WAV has invalid or unsupported PCM parameters.'
                }
                $format = [pscustomobject]@{
                    Channels = [int]$channels; SampleRate = [int]$rate; BlockAlign = [int]$align
                    Bits = [int]$bits; ValidBits = [int]$validBits; ChannelMask = $channelMask
                }
            } elseif ($name -ceq 'data') {
                if ($seenData -or $length -eq 0) { throw 'Output WAV has empty or duplicate sample data.' }
                $seenData = $true
                $dataBytes = $length
            }
            $Stream.Position = $next
        }
        if ($null -eq $format -or -not $seenData -or $dataBytes % $format.BlockAlign -ne 0) {
            throw 'Output WAV has missing or incomplete PCM samples.'
        }
        $frames = [long]([decimal]$dataBytes / $format.BlockAlign)
        if ($isRf64 -and $rf64Frames -ne $frames) { throw 'RF64 ds64 sample count disagrees with PCM samples.' }
        $seconds = [double]$frames / $format.SampleRate
        $expectedCodec = if ($format.Bits -eq 8) { 'pcm_u8' } else { 'pcm_s' + $format.Bits + 'le' }
        $expectedChannels = $InputAudio.Channels
        if ($null -ne $OutputPolicy) {
            $policyCodec = 'pcm_s' + $OutputPolicy.Bits + 'le'
            $policyLayout = if ($OutputPolicy.Channels -eq 1) { 'mono' } else { 'stereo' }
            if ($OutputPolicy.SampleRate -ne 48000 -or $OutputPolicy.Bits -notin @(16, 24) -or
                $OutputPolicy.Channels -notin @(1, 2) -or $OutputPolicy.Codec -cne $policyCodec -or
                $OutputPolicy.Layout -cne $policyLayout -or $OutputPolicy.Rf64 -isnot [bool]) {
                throw 'Invalid requested output encoding policy.'
            }
            if ($OutputPolicy.Channels -eq 1) { $expectedChannels = 1 }
            if ($format.SampleRate -ne $OutputPolicy.SampleRate -or $format.Bits -ne $OutputPolicy.Bits -or
                $format.ValidBits -ne $OutputPolicy.Bits -or $expectedCodec -cne $OutputPolicy.Codec -or
                $format.Channels -ne $OutputPolicy.Channels -or $isRf64 -ne $OutputPolicy.Rf64) {
                throw 'Output WAV does not match the requested encoding, channel count or RF64 policy.'
            }
            $expectedMask = if ($OutputPolicy.Channels -eq 1) { 4 } else { 3 }
            # Classic mono/stereo WAV has no layout field; zero/absent masks and
            # missing probe layouts use the same conventional channel inference.
            if (($format.ChannelMask -ne 0 -and $format.ChannelMask -ne $expectedMask) -or
                (-not [string]::IsNullOrWhiteSpace($OutputAudio.ChannelLayout) -and
                    $OutputAudio.ChannelLayout -cne $OutputPolicy.Layout)) {
                throw 'Output WAV channel layout does not match the requested layout.'
            }
        }
        if ($OutputAudio.Codec -ne $expectedCodec -or $OutputAudio.Channels -ne $format.Channels -or
            $OutputAudio.SampleRate -ne $format.SampleRate -or $expectedChannels -ne $format.Channels -or
            $null -eq $OutputAudio.DurationSeconds -or [math]::Abs($OutputAudio.DurationSeconds - $seconds) -gt 0.001) {
            throw 'Output probe and PCM samples disagree, or selected channel count changed.'
        }
        # PCM timing target is 10 ms; compressed headers may include codec padding.
        $tolerance = if ($InputAudio.Codec -like 'pcm_*') { 0.010 } else { 0.100 }
        if ($null -eq $InputAudio.DurationSeconds -or $InputAudio.DurationSeconds -le 0 -or
            [math]::Abs($InputAudio.DurationSeconds - $seconds) -gt ($tolerance + 0.000001)) {
            throw "Output duration $seconds s differs from selected input duration $($InputAudio.DurationSeconds) s (tolerance $tolerance s)."
        }
        [pscustomobject]@{
            Frames = $frames; DurationSeconds = $seconds; Channels = $format.Channels
            SampleRate = $format.SampleRate; Bits = $format.Bits; Rf64 = $isRf64
        }
    } finally { $reader.Dispose() }
}

function Get-WacAudioStreams {
    param([string]$FfprobePath, [string]$InputPath,
        [ValidateRange(1, 60000)][int]$TimeoutMilliseconds = 15000)

    $arguments = @('-v', 'error') + (Get-WacLocalMediaArguments) + @('-show_entries',
        'stream=index,codec_type,codec_name,channels,channel_layout,sample_rate,duration,start_time:stream_tags=language,title,DURATION', '-of', 'json', '-i', $InputPath)
    $result = Invoke-WacNativeProcess -FilePath $FfprobePath -ArgumentList $arguments -TimeoutMilliseconds $TimeoutMilliseconds
    Assert-WacInspectionResult -Result $result -Operation 'Audio probe (only supported local media formats and the file protocol are allowed)'
    if ([string]::IsNullOrWhiteSpace($result.StandardOutput) -or [Text.Encoding]::UTF8.GetByteCount($result.StandardOutput) -gt 1MB) {
        throw 'Invalid probe JSON: empty response or metadata exceeds 1 MiB.'
    }
    # Root arrays can be unrolled by PowerShell's pipeline; check the JSON token
    # as well as the converted shape so an array of one object is not accepted.
    if (-not $result.StandardOutput.TrimStart().StartsWith('{')) { throw 'Invalid probe JSON: expected an object containing a streams array.' }
    try { $metadata = ConvertFrom-Json -InputObject $result.StandardOutput -ErrorAction Stop }
    catch { throw 'Invalid probe JSON: cannot parse ffprobe metadata.' }
    if ($null -eq $metadata -or $metadata.streams -isnot [Array] -or $metadata.streams.Count -gt 256) {
        throw 'Invalid probe JSON: expected a streams array with at most 256 entries.'
    }
    $seen = @{}
    $audio = @(foreach ($stream in $metadata.streams) {
        if ($null -eq $stream -or ($stream.index -isnot [int] -and $stream.index -isnot [long]) -or
            $stream.index -lt 0 -or $stream.index -gt [int]::MaxValue -or $seen.ContainsKey([string]$stream.index) -or
            $stream.codec_type -isnot [string] -or [string]::IsNullOrWhiteSpace($stream.codec_type)) {
            throw 'Invalid probe JSON: missing, duplicate or invalid stream index/type.'
        }
        $seen[[string]$stream.index] = $true
        if ($stream.codec_type -ceq 'audio') {
            $rate = 0
            if ($stream.codec_name -isnot [string] -or [string]::IsNullOrWhiteSpace($stream.codec_name) -or
                ($stream.channels -isnot [int] -and $stream.channels -isnot [long]) -or $stream.channels -le 0 -or
                $stream.channels -gt [int]::MaxValue -or $stream.sample_rate -isnot [string] -or
                $stream.sample_rate -notmatch '^[0-9]+$' -or -not [int]::TryParse($stream.sample_rate, [ref]$rate) -or $rate -le 0) {
                throw 'Invalid probe JSON: audio codec, channel count or sample rate is missing or invalid.'
            }
            [pscustomobject]@{
                Index = [int]$stream.index; Codec = $stream.codec_name; Channels = [int]$stream.channels
                SampleRate = $rate; ChannelLayout = $stream.channel_layout
                Language = $stream.tags.language; Title = $stream.tags.title
                DurationSeconds = Get-WacStreamDuration -Stream $stream
            }
        }
    })
    if ($audio.Count -eq 0) { throw 'No audio streams found. Choose a supported file containing audio.' }
    $audio
}

function Select-WacAudioStream {
    param([object[]]$Streams, [string]$RequestedIndex, [bool]$Interactive = $false)

    if ($Streams.Count -eq 0) { throw 'No audio streams are available for selection.' }
    if ($PSBoundParameters.ContainsKey('RequestedIndex')) {
        $index = 0
        if ($RequestedIndex -notmatch '^[0-9]+$' -or -not [int]::TryParse($RequestedIndex, [ref]$index)) {
            throw 'Audio stream index must be a nonnegative absolute stream index shown by ffprobe.'
        }
        $selected = @($Streams | Where-Object { $_.Index -eq $index })
        if ($selected.Count -ne 1) { throw "Audio stream index $RequestedIndex is not an available audio stream. Available indexes: $(($Streams.Index) -join ', ')." }
        return $selected[0]
    }
    if ($Streams.Count -eq 1) { return $Streams[0] }
    if (-not $Interactive) {
        throw "Multiple audio streams found. Supply -AudioStreamIndex with an absolute index: $(($Streams.Index) -join ', ')."
    }
    Write-Host 'Choose an audio track by its absolute stream index:'
    foreach ($stream in $Streams) {
        # Treat media labels as display text only; remove terminal controls.
        $label = ("[{0}] {1}; {2} channel(s); {3} Hz; {4}; {5}" -f $stream.Index, $stream.Codec,
            $stream.Channels, $stream.SampleRate, $stream.Language, $stream.Title) -replace '[\x00-\x1f\x7f-\x9f]', ' '
        Write-Host $label
    }
    while ($true) {
        try { $answer = Read-WacHostSelection -Prompt 'Audio stream index (Q to cancel)' }
        catch { throw 'Cannot read an audio stream selection. Supply -AudioStreamIndex with -NonInteractive.' }
        if ($null -eq $answer -or $answer.Trim() -in @('q', 'cancel')) { return $null }
        $index = 0
        if ($answer.Trim() -match '^[0-9]+$' -and [int]::TryParse($answer.Trim(), [ref]$index)) {
            $selected = @($Streams | Where-Object { $_.Index -eq $index })
            if ($selected.Count -eq 1) { return $selected[0] }
        }
        Write-Host 'Invalid selection. Enter an audio index shown above, or Q to cancel.' -ForegroundColor Yellow
    }
}

function ConvertTo-WacNativeArgument {
    param([AllowEmptyString()][string]$Argument)

    if ($Argument.IndexOf([char]0) -ge 0) { throw 'Native arguments cannot contain NUL.' }
    # Windows CRT quoting, shared by PS5.1 and PS7. Always quote, including an
    # empty argument, and double backslashes before quotes/the closing delimiter.
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') {
            [void]$builder.Append([char]'\', (2 * $slashes + 1))
        } else {
            [void]$builder.Append([char]'\', $slashes)
        }
        [void]$builder.Append($character)
        $slashes = 0
    }
    [void]$builder.Append([char]'\', (2 * $slashes))
    [void]$builder.Append('"')
    $builder.ToString()
}

function Initialize-WacProgressRuntime {
    if ('WinAudioClean.RunControl' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
namespace WinAudioClean {
    public sealed class RunControl : IDisposable {
        private int requested;
        private delegate bool Handler(uint signal);
        private Handler handler;
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern bool SetConsoleCtrlHandler(Handler handler, bool add);
        public bool IsCancellationRequested { get { return Interlocked.CompareExchange(ref requested, 0, 0) != 0; } }
        public bool ConsoleHandlerRegistered { get; private set; }
        public int FileIndex = 1;
        public int FileCount = 1;
        public string CurrentStage;
        public string CancellationStage;
        public void Request() {
            if (Interlocked.CompareExchange(ref requested, 1, 0) == 0) CancellationStage = CurrentStage;
        }
        public void CaptureConsole() {
            if (ConsoleHandlerRegistered) return;
            handler = delegate(uint signal) {
                if (signal > 1) return false;
                Request(); return true;
            };
            ConsoleHandlerRegistered = SetConsoleCtrlHandler(handler, true);
        }
        public void Dispose() {
            if (ConsoleHandlerRegistered) {
                if (!SetConsoleCtrlHandler(handler, false)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
                ConsoleHandlerRegistered = false;
            }
            GC.KeepAlive(handler);
        }
    }
    public sealed class ProgressSnapshot {
        public long OutTimeMicroseconds = -1;
        public bool End;
        public int Blocks;
        public int InvalidLines;
        public int TruncatedLines;
    }
    public sealed class ProgressReader {
        private readonly object gate = new object();
        private readonly ProgressSnapshot snapshot = new ProgressSnapshot();
        public Task Completion { get; private set; }
        public ProgressReader(StreamReader reader) {
            Completion = Task.Factory.StartNew(() => Drain(reader), CancellationToken.None,
                TaskCreationOptions.LongRunning, TaskScheduler.Default);
        }
        public ProgressSnapshot Snapshot() {
            lock (gate) return new ProgressSnapshot {
                OutTimeMicroseconds=snapshot.OutTimeMicroseconds, End=snapshot.End, Blocks=snapshot.Blocks,
                InvalidLines=snapshot.InvalidLines, TruncatedLines=snapshot.TruncatedLines };
        }
        private void Drain(StreamReader reader) {
            char[] buffer = new char[4096];
            StringBuilder line = new StringBuilder();
            bool overlong = false, invalidBlock = false;
            long pendingTime = -1;
            int fieldCount = 0, count;
            while ((count = reader.Read(buffer, 0, buffer.Length)) > 0) {
                for (int i=0; i<count; i++) {
                    char c=buffer[i];
                    if (c != '\n') {
                        if (!overlong) {
                            if (line.Length >= 4096) { line.Clear(); overlong=true; }
                            else line.Append(c);
                        }
                        continue;
                    }
                    if (overlong) {
                        lock (gate) snapshot.TruncatedLines++;
                        overlong=false; invalidBlock=true; line.Clear(); continue;
                    }
                    string value=line.ToString().TrimEnd('\r'); line.Clear();
                    int equals=value.IndexOf('=');
                    if (equals <= 0) {
                        lock (gate) snapshot.InvalidLines++;
                        invalidBlock=true; continue;
                    }
                    if (fieldCount >= 64) {
                        lock (gate) snapshot.InvalidLines++;
                        invalidBlock=true;
                    } else fieldCount++;
                    // Even a rejected block must consume its terminator so a
                    // later valid block can recover. The counter stays bounded.
                    string key=value.Substring(0,equals), data=value.Substring(equals+1);
                    if (key == "out_time_us") {
                        long time;
                        if (pendingTime >= 0 || !Int64.TryParse(data, System.Globalization.NumberStyles.None,
                            System.Globalization.CultureInfo.InvariantCulture, out time)) {
                            lock (gate) snapshot.InvalidLines++;
                            invalidBlock=true;
                        } else pendingTime=time;
                    }
                    if (key == "progress") {
                        if (data != "continue" && data != "end") {
                            lock (gate) snapshot.InvalidLines++;
                        } else if (!invalidBlock && pendingTime >= 0) {
                            lock (gate) {
                                snapshot.OutTimeMicroseconds=Math.Max(snapshot.OutTimeMicroseconds,pendingTime);
                                snapshot.End |= data == "end";
                                snapshot.Blocks++;
                            }
                        }
                        pendingTime=-1; fieldCount=0; invalidBlock=false;
                    }
                }
            }
            if (overlong || line.Length > 0) lock (gate) snapshot.TruncatedLines++;
        }
    }
}
'@
}

function New-WacRunContext {
    param([switch]$CaptureConsole)
    Initialize-WacProgressRuntime
    $context = New-Object WinAudioClean.RunControl
    if ($CaptureConsole) { $context.CaptureConsole() }
    $context
}

function Request-WacCancellation {
    param($RunContext)
    if ($null -ne $RunContext) { $RunContext.Request() }
}

function Get-WacProgressArguments {
    param([string[]]$ArgumentList)
    $arguments = @($ArgumentList)
    $statsIndex = [array]::IndexOf($arguments, '-stats')
    if ($statsIndex -ge 0) { $arguments[$statsIndex] = '-nostats' }
    if ('-nostats' -notin $arguments) { $arguments = @('-nostats') + $arguments }
    @('-progress', 'pipe:1') + $arguments
}

function New-WacProgressState {
    param($RunContext, [string]$Stage, [double]$DurationSeconds = 0,
        [ValidateRange(0, 99)][int]$StartPercent = 0, [ValidateRange(0, 99)][int]$EndPercent = 95)
    if ($EndPercent -lt $StartPercent) { throw 'Progress range must be ordered.' }
    if ($null -ne $RunContext) { $RunContext.CurrentStage = $Stage }
    $known = $DurationSeconds -gt 0 -and -not [double]::IsNaN($DurationSeconds) -and -not [double]::IsInfinity($DurationSeconds)
    [pscustomobject]@{ Stage = $Stage; RunContext = $RunContext; DurationSeconds = $DurationSeconds
        FileIndex = $(if ($null -eq $RunContext) { 1 } else { $RunContext.FileIndex })
        FileCount = $(if ($null -eq $RunContext) { 1 } else { $RunContext.FileCount })
        StartPercent = $StartPercent; EndPercent = $EndPercent; Percent = $(if ($known) { $StartPercent } else { -1 })
        ProcessedSeconds = 0.0; StructuredEnd = $false; UpdateCount = 0; ProcessId = $null; Snapshot = $null; DisplayUnavailable = $false }
}

function Write-WacProgress {
    param($State, [switch]$Completed)
    try {
        $parameters = @{ Id = 1; Activity = "WinAudioClean - file $($State.FileIndex) of $($State.FileCount)"
            Status = $State.Stage; PercentComplete = $State.Percent; ErrorAction = 'Stop' }
        if ($Completed) { $parameters.Completed = $true }
        Write-Progress @parameters
    } catch { $State.DisplayUnavailable = $true } # Display failure never decides processing success.
}

function Update-WacProgress {
    param($State, $Snapshot)
    if ($null -ne $Snapshot) {
        $State.Snapshot = $Snapshot
        $State.StructuredEnd = $Snapshot.End
        $State.ProcessedSeconds = [math]::Max($State.ProcessedSeconds, [math]::Max(0.0, $Snapshot.OutTimeMicroseconds / 1000000.0))
        if ($State.Percent -ge 0) {
            $fraction = [math]::Min(1.0, $State.ProcessedSeconds / $State.DurationSeconds)
            $State.Percent = [math]::Max($State.Percent, [int][math]::Floor($State.StartPercent + ($State.EndPercent - $State.StartPercent) * $fraction))
        }
    }
    $State.UpdateCount++
    Write-WacProgress -State $State
}

function Add-WacProgressStage {
    param([string]$Stage, [double]$DurationSeconds = 0, [int]$StartPercent = 0, [int]$EndPercent = 95)
    $state = New-WacProgressState -RunContext $script:WacRunContext -Stage $Stage -DurationSeconds $DurationSeconds -StartPercent $StartPercent -EndPercent $EndPercent
    if ($null -eq $script:WacProgressStages) { $script:WacProgressStages = New-Object 'System.Collections.Generic.List[object]' }
    $script:WacProgressStages.Add($state)
    Update-WacProgress -State $state
    $state
}

function Complete-WacProgress {
    $state = Add-WacProgressStage -Stage 'Completed' -DurationSeconds 1 -StartPercent 99 -EndPercent 99
    $state.Percent = 100
    Update-WacProgress -State $state
}

function Get-WacProgressReport {
    @($script:WacProgressStages | ForEach-Object {
        [ordered]@{ stage = $_.Stage; fileIndex = $_.FileIndex; fileCount = $_.FileCount; percent = $_.Percent
            processedSeconds = $_.ProcessedSeconds; durationSeconds = $(if ($_.Percent -lt 0) { $null } else { $_.DurationSeconds })
            structuredEnd = $_.StructuredEnd; updates = $_.UpdateCount; processId = $_.ProcessId; snapshot = $_.Snapshot }
    })
}

function Invoke-WacNativeProcess {
    param(
        [string]$FilePath,
        [AllowEmptyCollection()][string[]]$ArgumentList = @(),
        [ValidateRange(0, 2147483647)][int]$TimeoutMilliseconds = 0,
        [ValidateRange(1, 60000)][int]$StreamCloseTimeoutMilliseconds = 5000,
        [System.IO.Stream]$StandardInputStream,
        $RunContext = $script:WacRunContext,
        $ProgressState
    )

    $result = [pscustomobject]@{
        Started = $false; ExitCode = $null; StandardOutput = ''; StandardError = ''
        Error = $null; TimedOut = $false; CleanupError = $null
        Cancelled = $false; OwnedProcessId = $null; Progress = $null; CancellationInputError = $null
    }
    $process = $null
    $stdoutReader = $null
    $stderrReader = $null
    $stdinWriter = $null
    $stdoutTask = $null
    $stderrTask = $null
    $stdinTask = $null
    $stdinClosed = $false
    $progressReader = $null
    try {
        if ($null -ne $RunContext -and $RunContext.IsCancellationRequested) { $result.Cancelled = $true; return $result }
        if ($null -ne $StandardInputStream -and -not $StandardInputStream.CanRead) { throw 'Native input stream must be readable.' }
        if (-not [IO.Path]::IsPathRooted($FilePath) -or [IO.Path]::GetExtension($FilePath) -ne '.exe') {
            throw 'Native execution requires a resolved absolute .exe path.'
        }
        $quoted = @(foreach ($argument in $ArgumentList) { ConvertTo-WacNativeArgument -Argument $argument })
        $commandLine = $quoted -join ' '
        if (($commandLine.Length + $FilePath.Length + 4) -gt 32767) {
            throw 'Native command exceeds the Windows command-line limit. Use shorter paths.'
        }
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $FilePath
        $startInfo.Arguments = $commandLine
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        $inputEncodingToRestore = $null
        $restoreInputEncoding = $false
        try {
            if ($startInfo.PSObject.Properties['StandardInputEncoding']) {
                $startInfo.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
            } else {
                # Framework builds stdin's writer from Console.InputEncoding.
                # Its automatic flush can prepend a UTF-8 BOM even to raw input.
                $inputEncodingToRestore = [Console]::InputEncoding
                if ($inputEncodingToRestore.CodePage -eq 65001 -and $inputEncodingToRestore.GetPreamble().Length -gt 0) {
                    $restoreInputEncoding = $true
                    [Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
                }
            }
            $result.Started = $process.Start()
            if ($result.Started) {
                # Own all pipe handles before restoring encoding: even a failed
                # restoration must leave the outer cleanup able to close them.
                $stdoutReader = $process.StandardOutput
                $stderrReader = $process.StandardError
                $stdinWriter = $process.StandardInput
            }
        } finally {
            if ($restoreInputEncoding) { [Console]::InputEncoding = $inputEncodingToRestore }
        }
        if (-not $result.Started) { throw 'The native process did not start.' }
        $result.OwnedProcessId = $process.Id
        if ($null -ne $ProgressState) { $ProgressState.ProcessId = $process.Id }
        # Both readers start before waiting, so neither full pipe can block the
        # child. No script callbacks or PowerShell runspace are needed to drain.
        if ($null -ne $ProgressState) {
            Initialize-WacProgressRuntime
            $progressReader = New-Object WinAudioClean.ProgressReader -ArgumentList $stdoutReader
            $stdoutTask = $progressReader.Completion
        } else { $stdoutTask = $stdoutReader.ReadToEndAsync() }
        $stderrTask = $stderrReader.ReadToEndAsync()
        if ($null -eq $StandardInputStream) {
            $stdinWriter.Close()
            $stdinClosed = $true
        } else {
            # Read from the caller's held immutable file without reopening its
            # path. Async copying keeps both diagnostic pipes draining.
            $stdinTask = $StandardInputStream.CopyToAsync($stdinWriter.BaseStream)
        }
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(100)) {
            if ($null -ne $progressReader) { Update-WacProgress -State $ProgressState -Snapshot $progressReader.Snapshot() }
            if ($null -ne $RunContext -and $RunContext.IsCancellationRequested) {
                $result.Cancelled = $true
                $process.Kill()
                if (-not $process.WaitForExit(5000)) { throw 'Cancelled native process did not stop within 5000 ms.' }
                break
            }
            if (-not $stdinClosed -and $stdinTask.IsCompleted) {
                [void]$stdinTask.GetAwaiter().GetResult()
                $stdinWriter.Close()
                $stdinClosed = $true
            }
            # Zero is deliberate for rendering: a long recording has no short
            # total deadline. Probe/test callers can supply a finite timeout.
            if ($TimeoutMilliseconds -gt 0 -and $watch.ElapsedMilliseconds -ge $TimeoutMilliseconds) {
                $result.TimedOut = $true
                $result.Error = "Native process timed out after $TimeoutMilliseconds ms."
                $process.Kill()
                if (-not $process.WaitForExit(5000)) { throw 'Timed-out native process did not stop within 5000 ms.' }
                break
            }
        }
        $result.ExitCode = $process.ExitCode
        if ($null -ne $RunContext -and $RunContext.IsCancellationRequested) { $result.Cancelled = $true }
        if ($null -ne $stdinTask) {
            if (-not $stdinTask.Wait($StreamCloseTimeoutMilliseconds)) { throw 'Native input stream transfer did not finish.' }
            [void]$stdinTask.GetAwaiter().GetResult()
        }
        $readers = [System.Threading.Tasks.Task[]]@($stdoutTask, $stderrTask)
        if (-not [System.Threading.Tasks.Task]::WaitAll($readers, $StreamCloseTimeoutMilliseconds)) {
            throw "Native output streams did not close within $StreamCloseTimeoutMilliseconds ms."
        }
        if ($null -eq $progressReader) { $result.StandardOutput = $stdoutTask.Result }
        $result.StandardError = $stderrTask.Result
    } catch {
        if ($result.Cancelled -and $null -ne $stdinTask -and $stdinTask.IsFaulted -and
            $stdinTask.Exception.GetBaseException() -is [IO.IOException] -and
            [object]::ReferenceEquals($_.Exception.GetBaseException(), $stdinTask.Exception.GetBaseException())) {
            $result.CancellationInputError = $stdinTask.Exception.GetBaseException().Message
        } elseif (-not $result.Error) { $result.Error = $_.Exception.Message }
    } finally {
        if ($null -ne $process) {
            try {
                if ($result.Started -and -not $process.HasExited) {
                    # Stop this owned child only, including on pipeline interruption.
                    $process.Kill()
                    if (-not $process.WaitForExit(5000)) { throw 'Native process cleanup exceeded 5000 ms.' }
                }
                if ($result.Started -and $process.HasExited) { $result.ExitCode = $process.ExitCode }
            } catch { $result.CleanupError = $_.Exception.Message }
            if ($null -eq $progressReader -and $null -ne $stdoutTask -and $stdoutTask.Status -eq 'RanToCompletion') { $result.StandardOutput = $stdoutTask.Result }
            if ($null -ne $progressReader) {
                $result.Progress = $progressReader.Snapshot()
                Update-WacProgress -State $ProgressState -Snapshot $result.Progress
            }
            if ($null -ne $stderrTask -and $stderrTask.Status -eq 'RanToCompletion') { $result.StandardError = $stderrTask.Result }
            # Process.Dispose does not own readers accessed through these
            # properties. Dispose them explicitly, including incomplete reads.
            foreach ($stream in @($stdinWriter, $stdoutReader, $stderrReader)) {
                if ($null -ne $stream) {
                    try { $stream.Dispose() }
                    catch { $result.CleanupError = $_.Exception.Message }
                }
            }
            if ($null -ne $stdinTask) {
                try {
                    if (-not $stdinTask.Wait($StreamCloseTimeoutMilliseconds)) { throw 'Native input transfer cleanup exceeded its deadline.' }
                    [void]$stdinTask.GetAwaiter().GetResult()
                } catch {
                    if ($result.Cancelled -and $stdinTask.IsFaulted -and $stdinTask.Exception.GetBaseException() -is [IO.IOException] -and
                        [object]::ReferenceEquals($_.Exception.GetBaseException(), $stdinTask.Exception.GetBaseException())) {
                        $result.CancellationInputError = $stdinTask.Exception.GetBaseException().Message
                    } else { $result.CleanupError = $_.Exception.Message }
                }
            }
            try { $process.Dispose() }
            catch { $result.CleanupError = $_.Exception.Message }
        }
    }
    $result
}

function ConvertTo-WacMeasurement {
    param($Value, [string]$UnavailableReason = 'not_measured')

    if ($null -eq $Value) { return [ordered]@{ value = $null; reason = $UnavailableReason } }
    $number = 0.0
    if (-not [double]::TryParse([Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture), [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return [ordered]@{ value = $null; reason = 'not_numeric' }
    }
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
        return [ordered]@{ value = $null; reason = 'nonfinite' }
    }
    [ordered]@{ value = $number; reason = $null }
}

function ConvertFrom-WacLoudnormJson {
    param([string]$StandardError, [double]$DurationSeconds)

    if ([double]::IsNaN($DurationSeconds) -or [double]::IsInfinity($DurationSeconds) -or
        $DurationSeconds -le 0 -or $DurationSeconds -gt 1000000000) { throw 'Invalid loudness measurement duration.' }
    if ([string]::IsNullOrWhiteSpace($StandardError) -or $StandardError.Length -gt 1048576) {
        throw 'Loudness diagnostics are empty or exceed the 1 MiB limit.'
    }
    # loudnorm writes one flat JSON object. Match complete lines so braces in
    # filenames or other diagnostic text do not become measurement objects.
    $blocks = @([regex]::Matches($StandardError, '(?m)^[ \t]*\{[^{}]*\}[ \t]*\r?$') |
        Where-Object { $_.Value -match '"(?:input_i|input_tp|input_lra|input_thresh|normalization_type|target_offset)"\s*:' })
    if ($blocks.Count -ne 1 -or $blocks[0].Length -gt 8192) { throw 'Expected one bounded loudnorm JSON object.' }
    $json = $blocks[0].Value.Trim()
    $numberPattern = '-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?'
    $pairPattern = '"(?<key>[a-z_]+)"\s*:\s*(?<value>"[^"\\\x00-\x1f]*"|' + $numberPattern + ')\s*'
    $shape = [regex]::Match($json, '\A\{\s*' + $pairPattern + '(?:,\s*' + $pairPattern + ')*\}\z')
    if (-not $shape.Success) { throw 'Malformed loudnorm JSON object.' }
    $fields = @{}
    for ($index = 0; $index -lt $shape.Groups['key'].Captures.Count; $index++) {
        $key = $shape.Groups['key'].Captures[$index].Value
        if ($fields.ContainsKey($key)) { throw 'Duplicate loudnorm measurement field.' }
        $fields[$key] = $shape.Groups['value'].Captures[$index].Value.Trim('"')
    }
    $bounds = @{
        input_i = @(-200, 0); input_tp = @(-200, 99); input_lra = @(0, 99); input_thresh = @(-200, 0)
        output_i = @(-200, 0); output_tp = @(-200, 99); output_lra = @(0, 99); output_thresh = @(-200, 0)
        target_offset = @(-99, 99)
    }
    $expected = @($bounds.Keys) + @('normalization_type')
    if ($fields.Count -ne $expected.Count -or @($expected | Where-Object { -not $fields.ContainsKey($_) }).Count -ne 0) {
        throw 'Missing or unsupported loudnorm measurement field.'
    }
    if ($fields.normalization_type -cnotin @('linear', 'dynamic')) { throw 'Invalid loudnorm normalization type.' }
    $undefined = $fields.input_i -ceq '-inf'
    if ($undefined -and ($fields.output_i -cne '-inf' -or $fields.target_offset -cne 'inf')) {
        throw 'Inconsistent undefined loudnorm measurements.'
    }
    $values = @{}
    foreach ($key in $bounds.Keys) {
        $raw = $fields[$key]
        if ($undefined -and (($key -in @('input_i', 'output_i', 'input_tp', 'output_tp') -and $raw -ceq '-inf') -or
            ($key -eq 'target_offset' -and $raw -ceq 'inf'))) {
            $values[$key] = $null
            continue
        }
        $value = 0.0
        if ($raw.Length -gt 64 -or $raw -cnotmatch ('\A' + $numberPattern + '\z') -or
            -not [double]::TryParse($raw, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or
            [double]::IsNaN($value) -or [double]::IsInfinity($value) -or
            $value -lt $bounds[$key][0] -or $value -gt $bounds[$key][1] -or ($bounds[$key][0] -eq -200 -and $value -eq -200)) {
            throw ('Invalid or out-of-range loudnorm measurement: ' + $key + '.')
        }
        $values[$key] = $value
    }
    if ($undefined -and ($values.input_lra -ne 0 -or $values.output_lra -ne 0)) {
        throw 'Inconsistent undefined loudnorm range.'
    }
    $reason = $null
    if ($DurationSeconds -lt 1) { $reason = 'too_short' }
    elseif ($undefined) { $reason = if ($null -eq $values.input_tp) { 'silence' } else { 'undefined_loudness' } }
    [pscustomobject]@{
        Available = ($null -eq $reason); Reason = $reason
        InputI = $(if ($reason) { $null } else { $values.input_i })
        InputTP = $values.input_tp
        InputLRA = $(if ($reason) { $null } else { $values.input_lra })
        InputThreshold = $values.input_thresh; TargetOffset = $values.target_offset
        NormalizationType = $fields.normalization_type
    }
}

function Get-WacLoudnessPlan {
    param([Parameter(Mandatory = $true)][Alias('Profile')]$ProcessingProfile,
        [Parameter(Mandatory = $true)]$OutputPolicy, $Measurement)

    $terminal = ',loudnorm=I=-12:TP=-1.5'
    $chain = $ProcessingProfile.FilterChain
    # Rebuild an allowlisted profile from its typed effective settings. Merely
    # ending an arbitrary graph in loudnorm is not permission to execute it.
    try {
        if ($ProcessingProfile.ModeChoice -cnotin @('1', '2') -or
            $ProcessingProfile.PresetId -cnotin @('original', 'gentle')) { throw 'Invalid profile identity.' }
        $presetName = if ($ProcessingProfile.PresetId -eq 'gentle') { 'Gentle' } else { 'Original' }
        $options = @{}
        if ($ProcessingProfile.ModeChoice -eq '1') {
            $effective = $ProcessingProfile.CleaningSettings
            if ($effective -isnot [System.Collections.IDictionary] -or $effective.Count -ne 10 -or
                $effective.schemaVersion -isnot [int] -or $effective.schemaVersion -ne 1) {
                throw 'Invalid effective cleaning schema.'
            }
            $schemaKeys = @('schemaVersion', 'Declip', 'Declick', 'Denoise', 'Gate', 'HighpassHz',
                'NoiseFloorDb', 'NoiseReductionDb', 'GateThresholdDb', 'GateRangeDb')
            foreach ($key in $effective.Keys) {
                if ($key -isnot [string] -or $key -cnotin $schemaKeys) { throw 'Invalid effective cleaning schema key.' }
                if ($key -cne 'schemaVersion') { $options[$key] = $effective[$key] }
            }
        } elseif ($null -ne $ProcessingProfile.CleaningSettings) { throw 'Zoom cannot contain cleaning settings.' }
        $expected = Get-WacProcessingProfile -Choice $ProcessingProfile.ModeChoice -Preset $presetName -CleaningOptions $options
        if ($ProcessingProfile.ModeChoice -eq '2' -and $ProcessingProfile.CleaningCustomized) {
            throw 'Zoom cannot be customized.'
        }
        if ($ProcessingProfile.ModeChoice -eq '1' -and -not $ProcessingProfile.CleaningCustomized) {
            $baseSettings = Get-WacCleaningSettings -Preset $presetName
            foreach ($key in $baseSettings.Keys) {
                if ($ProcessingProfile.CleaningSettings[$key] -cne $baseSettings[$key]) { throw 'Unmarked custom cleaning settings.' }
            }
        }
        if ($chain -isnot [string] -or $chain -cne $expected.FilterChain -or
            $ProcessingProfile.PresetVersion -cne $expected.PresetVersion -or
            $ProcessingProfile.PresetName -cne $expected.PresetName -or
            $ProcessingProfile.ModeName -cne $expected.ModeName -or
            $ProcessingProfile.PresetExperimental -isnot [bool] -or
            $ProcessingProfile.PresetExperimental -ne $expected.PresetExperimental -or
            $ProcessingProfile.CleaningCustomized -isnot [bool] -or
            -not $chain.EndsWith($terminal, [StringComparison]::Ordinal)) { throw 'Profile does not match its typed settings.' }
    } catch { throw 'Accurate loudness requires a validated profile with the supported terminal normalization filter.' }
    $prechain = $chain.Substring(0, $chain.Length - $terminal.Length)
    if ($prechain -match '(?i)loudnorm' -or [string]::IsNullOrWhiteSpace($prechain)) {
        throw 'Accurate loudness requires exactly one terminal normalization filter.'
    }
    if ($OutputPolicy.FilterPrefix -cnotin @('', 'pan=mono|c0=0.5*c0+0.5*c1,')) {
        throw 'Unsupported channel conversion for Accurate loudness.'
    }
    # Explicit rate prevents FFmpeg graph negotiation from changing the signal
    # received by loudnorm between dynamic analysis and a linear second pass.
    $prechain = $OutputPolicy.FilterPrefix + $prechain + ',aresample=192000'
    $normalizer = 'loudnorm=I=-12:TP=-1.5:LRA=7'
    $render = $normalizer + ':linear=false:print_format=json'
    $linear = $false
    $fallback = $null
    if ($null -ne $Measurement) {
        if ($Measurement.Available -isnot [bool]) { throw 'Invalid loudness measurement availability.' }
        if ($Measurement.Available) {
            $mapping = [ordered]@{
                InputI = @('measured_I', -99, 0); InputTP = @('measured_TP', -99, 99)
                InputLRA = @('measured_LRA', 0, 99); InputThreshold = @('measured_thresh', -99, 0)
                TargetOffset = @('offset', -99, 99)
            }
            $render = $normalizer
            $outsideAllowed = $false
            foreach ($name in $mapping.Keys) {
                $value = $Measurement.$name
                if (($value -isnot [double] -and $value -isnot [int] -and $value -isnot [long] -and $value -isnot [decimal]) -or
                    [double]::IsNaN($value) -or [double]::IsInfinity($value)) {
                    throw 'Cannot use invalid measured values in an Accurate render.'
                }
                if ($value -lt $mapping[$name][1] -or $value -gt $mapping[$name][2]) { $outsideAllowed = $true }
                $render += ':' + $mapping[$name][0] + '=' + $value.ToString('0.###############', [Globalization.CultureInfo]::InvariantCulture)
            }
            if ($outsideAllowed) {
                $render = $normalizer + ':linear=false:print_format=json'
                $fallback = 'measurement_out_of_range'
            } else {
                $render += ':linear=true:print_format=json'
                $linear = $true
            }
        } else {
            if ($Measurement.Reason -cnotin @('too_short', 'silence', 'undefined_loudness')) { throw 'Invalid loudness fallback reason.' }
            $fallback = $Measurement.Reason
        }
    }
    [pscustomobject]@{
        Prechain = $prechain
        AnalysisFilter = $prechain + ',' + $normalizer + ':print_format=json'
        RenderFilter = $prechain + ',' + $render
        FinalMeasurementFilter = $normalizer + ':print_format=json'
        LinearRequested = $linear; FallbackReason = $fallback
    }
}

function Get-WacLoudnessArguments {
    param([string]$InputPath, [Parameter(Mandatory = $true)][string]$FilterChain,
        [ValidateRange(0, 2147483647)][int]$AudioStreamIndex = 0,
        [Parameter(Mandatory = $true)]$OutputPolicy, [switch]$FromPipe)

    if ($FromPipe) {
        # The frozen validated WAV is streamed from its held handle. Measure its
        # actual channels/samples; do not repeat conversion or the prechain.
        @('-nostdin', '-protocol_whitelist', 'pipe', '-format_whitelist', 'wav', '-f', 'wav', '-i', 'pipe:0',
            '-map', '0:0', '-vn', '-af', $FilterChain, '-f', 'null', '-', '-hide_banner', '-loglevel', 'info', '-nostats')
    } else {
        @('-nostdin') + (Get-WacLocalMediaArguments) + @('-i', $InputPath,
            '-map', ('0:' + $AudioStreamIndex.ToString([Globalization.CultureInfo]::InvariantCulture)), '-vn', '-af', $FilterChain,
            '-ar', '48000', '-ac', $OutputPolicy.Channels.ToString([Globalization.CultureInfo]::InvariantCulture),
            '-channel_layout', $OutputPolicy.Layout, '-f', 'null', '-', '-hide_banner', '-loglevel', 'info', '-nostats')
    }
}

function ConvertTo-WacFinalLoudness {
    param([Parameter(Mandatory = $true)]$Measurement)

    $metrics = [ordered]@{}
    foreach ($pair in @(@('integratedLufs', 'InputI'), @('truePeakDbtp', 'InputTP'), @('loudnessRangeLu', 'InputLRA'))) {
        $value = $Measurement.($pair[1])
        $metrics[$pair[0]] = [ordered]@{ value = $value; reason = $(if ($null -eq $value) { $Measurement.Reason } else { $null }) }
    }
    $status = 'PASSED'; $reason = $null
    if ($null -ne $Measurement.InputTP -and $Measurement.InputTP -gt -1.3) {
        $status = 'OUT_OF_TOLERANCE'; $reason = 'true_peak_exceeded'
    } elseif (-not $Measurement.Available) {
        $status = 'UNMEASURABLE'; $reason = $Measurement.Reason
    } elseif ([math]::Abs($Measurement.InputI + 12) -gt 0.5) {
        $status = 'OUT_OF_TOLERANCE'; $reason = 'loudness_out_of_tolerance'
    }
    [pscustomobject]@{ Measurements = $metrics; Compliance = [ordered]@{ status = $status; reason = $reason } }
}

function ConvertTo-WacLoudnessStage {
    param([Parameter(Mandatory = $true)]$Process, [double]$DurationSeconds,
        [string[]]$Arguments, [string]$InputSource = 'file')

    $stage = [ordered]@{ status = 'FAILED'; arguments = @($Arguments); inputSource = $InputSource
        process = $Process; measurement = $null; error = $null }
    try {
        if ($Process.PSObject.Properties['Cancelled'] -and $Process.Cancelled) { $stage.status = 'CANCELLED'; throw 'Loudness processing cancelled.' }
        if (-not $Process.Started -or $Process.Error -or $Process.CleanupError -or $Process.TimedOut -or
            $null -eq $Process.ExitCode -or $Process.ExitCode -ne 0) { throw 'Loudness native process failed.' }
        $stage.measurement = ConvertFrom-WacLoudnormJson -StandardError $Process.StandardError -DurationSeconds $DurationSeconds
        $stage.status = 'PASSED'
    } catch { $stage.error = $_.Exception.Message }
    $stage
}

function Update-WacReportOutcome {
    param([System.Collections.IDictionary]$Report)

    $Report.reporting.complete = ($Report.reporting.errors.Count -eq 0)
    $Report.applicationExitCode = $Report.processingExitCode
    $Report.status = $Report.processingStatus
    if ((-not $Report.reporting.complete -or $Report.warningCodes.Count -gt 0) -and $Report.processingExitCode -eq 0) {
        $Report.applicationExitCode = 7
        $Report.status = 'WARNING'
    }
}

function Add-WacReportFailure {
    param([System.Collections.IDictionary]$Report, [string]$Code, [string]$Message)

    $Report.warningCodes = @($Report.warningCodes) + $Code
    $Report.reporting.errors = @($Report.reporting.errors) + $Message
    Update-WacReportOutcome -Report $Report
}

function New-WacRunReport {
    param([System.Collections.IDictionary]$Context)

    $c = $Context
    $inputDuration = ConvertTo-WacMeasurement -Value $c.Stream.DurationSeconds -UnavailableReason 'unavailable'
    $elapsed = ConvertTo-WacMeasurement -Value $c.ElapsedSeconds -UnavailableReason 'unavailable'
    $report = [ordered]@{
        schemaVersion = 1
        jobId = $c.Transaction.JobId
        toolVersion = $c.ToolVersion
        presetId = $c.Profile.PresetId; presetName = $c.Profile.PresetName
        presetVersion = $c.Profile.PresetVersion; presetVersionReason = $null
        presetExperimental = [bool]$c.Profile.PresetExperimental
        presetCustomized = [bool]$c.Profile.CleaningCustomized
        sourceRevision = $null; sourceRevisionReason = 'not_embedded'
        status = $(if ($c.ExitCode -eq 0) { 'SUCCESS' } else { 'FAILED' })
        processingStatus = $(if ($c.ExitCode -eq 0) { 'SUCCESS' } elseif ($c.ExitCode -eq 130) { 'CANCELLED' } else { 'FAILED' })
        processingExitCode = $c.ExitCode
        applicationExitCode = $c.ExitCode
        nativeExitCode = $c.Process.ExitCode
        reasonCodes = @($c.ReasonCodes)
        warningCodes = @($c.LoudnessWarnings | Where-Object { $_ })
        timing = [ordered]@{
            startedAtUtc = $c.StartedAt.ToUniversalTime().ToString('o', [Globalization.CultureInfo]::InvariantCulture)
            endedAtUtc = [DateTime]::UtcNow.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
            processingElapsedSeconds = $elapsed.value; processingElapsedSecondsReason = $elapsed.reason
        }
        dependencies = [ordered]@{
            ffmpeg = [ordered]@{ path = $c.FfmpegPath; version = $c.FfmpegVersion }
            ffprobe = [ordered]@{ path = $c.FfprobePath; version = $c.FfprobeVersion }
        }
        input = [ordered]@{
            path = $c.Transaction.InputPath; sizeBytes = $c.InputBytes
            durationSeconds = $inputDuration.value; durationSecondsReason = $inputDuration.reason
            stream = [ordered]@{
                index = $c.Stream.Index; codec = $c.Stream.Codec; channels = $c.Stream.Channels
                sampleRate = $c.Stream.SampleRate; channelLayout = $c.Stream.ChannelLayout
                language = $c.Stream.Language; title = $c.Stream.Title
            }
        }
        settings = [ordered]@{
            mode = $c.Mode; modeName = $c.ModeName; bitDepth = $c.Policy.Bits
            loudnessMode = $(if ($c.LoudnessMode) { $c.LoudnessMode } else { 'Fast' })
            mono = [bool]$c.Mono; rf64 = [bool]$c.Policy.Rf64
            cleaning = $c.Profile.CleaningSettings
            exactFilters = $(if ($c.Normalization -and $c.Normalization.requestedMode -eq 'Accurate') { $c.Normalization.renderFilter } else { $c.Policy.FilterPrefix + $c.FilterChain })
        }
        output = [ordered]@{
            path = $c.Transaction.FinalPath; partialPath = $c.Transaction.TempPath
            published = [bool]$c.Transaction.Published; sizeBytes = $c.OutputBytes
            sizeReason = $(if ($null -eq $c.OutputBytes) { 'unavailable' } else { $null })
            validity = $(if ($c.Transaction.Published) { 'PASSED' } else { 'FAILED' })
            format = [ordered]@{
                sampleRate = $c.Policy.SampleRate; bitDepth = $c.Policy.Bits; codec = $c.Policy.Codec
                channels = $c.Policy.Channels; channelLayout = $c.Policy.Layout
                container = $(if ($c.Policy.Rf64) { 'RF64' } else { 'RIFF' })
            }
            verified = $c.VerifiedAudio
        }
        requestedTargets = [ordered]@{ integratedLufs = -12; truePeakDbtp = -1.5; loudnessRangeLu = 7 }
        loudnessTolerances = [ordered]@{ integratedLufs = 0.5; truePeakDbtp = 0.2 }
        normalization = $c.Normalization
        measurements = [ordered]@{
            integratedLufs = (ConvertTo-WacMeasurement -Value $null)
            truePeakDbtp = (ConvertTo-WacMeasurement -Value $null)
            loudnessRangeLu = (ConvertTo-WacMeasurement -Value $null)
        }
        loudnessCompliance = [ordered]@{ status = 'NOT_MEASURED'; reason = 'no_independent_measurement' }
        space = [ordered]@{
            estimatedFileBytes = $c.SpaceEstimate.FileBytes; reserveBytes = $c.SpaceEstimate.ReserveBytes
            availableBytesBeforeRender = $c.AvailableBytes
        }
        diagnostics = [ordered]@{
            standardOutput = $c.Process.StandardOutput; standardError = $c.Process.StandardError
            processError = $c.Process.Error; nativeCleanupError = $c.Process.CleanupError
            outputError = $c.ValidationError; outputCleanupErrors = @($c.CleanupErrors)
            jsonPath = [IO.Path]::Combine($(if ($c.ReportFolder) { $c.ReportFolder } else { $c.Transaction.OutputFolder }), ('WinAudioClean_' + $c.Transaction.JobId + '.json'))
            textPath = [IO.Path]::Combine($(if ($c.ReportFolder) { $c.ReportFolder } else { $c.Transaction.OutputFolder }), ('WinAudioClean_' + $c.Transaction.JobId + '.txt'))
        }
        reporting = [ordered]@{ complete = $true; errors = @() }
        privacy = 'Local detailed report: may contain paths, filenames, metadata and sensitive diagnostics. Use explicit redacted export and review before sharing.'
    }
    if ($c.FinalLoudness) {
        $report.measurements = $c.FinalLoudness.Measurements
        $report.loudnessCompliance = $c.FinalLoudness.Compliance
    }
    if ($c.MetadataError) { Add-WacReportFailure -Report $report -Code 'output_metadata_unavailable' -Message $c.MetadataError }
    Update-WacReportOutcome -Report $report
    $report
}

function Format-WacReportLabel {
    param([string]$Value)

    # Metadata must not create extra labeled lines in the human report.
    [regex]::Replace($Value, '[\x00-\x1f\x7f]', {
        param($match)
        '\u{0:x4}' -f [int][char]$match.Value
    })
}

function Format-WacRunReport {
    param([System.Collections.IDictionary]$Report)

    $r = $Report
    $nativeExitText = if ($null -eq $r.nativeExitCode) { 'not started' } else { [string]$r.nativeExitCode }
    $inputSize = '{0:N2} MB' -f ($r.input.sizeBytes / 1MB)
    $outputSize = if ($null -eq $r.output.sizeBytes) { 'N/A' } else { '{0:N2} MB' -f ($r.output.sizeBytes / 1MB) }
    @"
================================================================================
LOG DATE       : $($r.timing.endedAtUtc)
--------------------------------------------------------------------------------
STATUS         : $($r.status) (Native Exit Code: $nativeExitText; Application Exit Code: $($r.applicationExitCode))
PROCESSING     : $($r.processingStatus) (Application Exit Code: $($r.processingExitCode))
MODE           : $($r.settings.modeName)
PRESET         : $($r.presetName) (ID: $($r.presetId); version: $($r.presetVersion))
PRESET FLAGS   : experimental=$($r.presetExperimental); customized=$($r.presetCustomized)
CLEANING       : $(if ($r.settings.cleaning) { $r.settings.cleaning | ConvertTo-Json -Compress } else { 'none (leveling only)' })
INPUT DURATION : $($r.input.durationSeconds) s (selected stream)
PROCESSING TIME: $($r.timing.processingElapsedSeconds) s (analysis, rendering, validation and publication)
STARTED UTC    : $($r.timing.startedAtUtc)
ENDED UTC      : $($r.timing.endedAtUtc) (processing and output cleanup complete)

INPUT FILE     : $($r.input.path)
INPUT SIZE     : $inputSize
OUTPUT FILE    : $($r.output.path)
OUTPUT SIZE    : $outputSize
JOB ID         : $($r.jobId)
PARTIAL FILE   : $($r.output.partialPath)
PUBLISHED      : $($r.output.published)
VALIDITY       : $($r.output.validity)
VERIFIED AUDIO : $($r.output.verified.DurationSeconds) s; $($r.output.verified.Frames) frames; $($r.output.verified.SampleRate) Hz; $($r.output.verified.Bits) bits

ACTIVE FILTERS : $($r.settings.exactFilters)
EXPORT FORMAT  : $($r.output.format.sampleRate) Hz; $($r.output.format.codec); $($r.output.format.bitDepth) bits; $($r.output.format.channelLayout); $($r.output.format.container) WAV
LOUDNESS MODE  : $($r.settings.loudnessMode)
REQUEST TARGETS: -12 LUFS integrated; -1.5 dBTP true peak; 7 LU loudness range
MEASUREMENTS   : I=$($r.measurements.integratedLufs.value) LUFS [$($r.measurements.integratedLufs.reason)]; TP=$($r.measurements.truePeakDbtp.value) dBTP [$($r.measurements.truePeakDbtp.reason)]; LRA=$($r.measurements.loudnessRangeLu.value) LU [$($r.measurements.loudnessRangeLu.reason)]
LOUDNESS CHECK : $($r.loudnessCompliance.status); $($r.loudnessCompliance.reason); tolerances 0.5 LU / +0.2 dBTP; export validity is separate
NORMALIZATION : $($r.normalization.actualType); fallback=$($r.normalization.fallbackReason)
ANALYSIS STAGE : $($r.normalization.analysis.status); native exit=$($r.normalization.analysis.process.ExitCode); $($r.normalization.analysis.error)
RENDER STAGE   : $($r.normalization.render.status); native exit=$($r.normalization.render.process.ExitCode); $($r.normalization.render.error)
FINAL STAGE    : $($r.normalization.final.status); native exit=$($r.normalization.final.process.ExitCode); $($r.normalization.final.error)
SPACE ESTIMATE : $($r.space.estimatedFileBytes) file bytes + $($r.space.reserveBytes) reserve bytes; $($r.space.availableBytesBeforeRender) available before rendering
TOOL VERSION   : $($r.toolVersion); schema $($r.schemaVersion); revision not_embedded
EXECUTABLE     : $($r.dependencies.ffmpeg.path)
FFMPEG VERSION : $(Format-WacReportLabel -Value $r.dependencies.ffmpeg.version)
FFPROBE        : $($r.dependencies.ffprobe.path)
FFPROBE VERSION: $(Format-WacReportLabel -Value $r.dependencies.ffprobe.version)
AUDIO STREAM   : $($r.input.stream.index) (absolute index; map 0:$($r.input.stream.index))
INPUT AUDIO    : $($r.input.stream.codec); $($r.input.stream.channels) channel(s); $($r.input.stream.sampleRate) Hz
STREAM TITLE   : $(Format-WacReportLabel -Value $r.input.stream.title)
STREAM LANGUAGE: $(Format-WacReportLabel -Value $r.input.stream.language)
INPUT POLICY   : file protocol; WAV, MP3, FLAC, Ogg, MOV/MP4, Matroska/WebM, AAC, AIFF, ASF, AVI
REASON CODES   : $($r.reasonCodes -join ', ')
WARNING CODES  : $($r.warningCodes -join ', ')
PROCESS ERROR  : $($r.diagnostics.processError)
CLEANUP ERROR  : $($r.diagnostics.nativeCleanupError) $($r.diagnostics.outputCleanupErrors -join '; ')
REPORT ERROR   : $($r.reporting.errors -join '; ')
OUTPUT ERROR   : $($r.diagnostics.outputError)
JSON REPORT    : $($r.diagnostics.jsonPath)
TEXT REPORT    : $($r.diagnostics.textPath)
PRIVACY        : $($r.privacy)
STANDARD OUTPUT:
$($r.diagnostics.standardOutput)
STANDARD ERROR:
$($r.diagnostics.standardError)
================================================================================

"@
}

function Write-WacRunReports {
    param([System.Collections.IDictionary]$Report, [string]$OutputFolder)

    # Hold all writers until the final outcome is known. Each failed writer is
    # retired; surviving reports are rewritten with the warning outcome. The
    # summary is written last and rolled back before any corrected attempt.
    $writers = [ordered]@{}
    $paths = [ordered]@{
        json = $Report.diagnostics.jsonPath; text = $Report.diagnostics.textPath
        summary = [IO.Path]::Combine($OutputFolder, 'WinAudioClean_Log.txt')
    }
    try {
        foreach ($kind in $paths.Keys) {
            try { $writers[$kind] = Open-WacReportWriter -Path $paths[$kind] -CreateNew:($kind -ne 'summary') }
            catch {
                Add-WacReportFailure -Report $Report -Code ($kind + '_report_unavailable') -Message $_.Exception.Message
                Write-Warning ('Report could not be written: ' + $_.Exception.Message)
            }
        }
        do {
            $retry = $false
            $text = Format-WacRunReport -Report $Report
            $json = $Report | ConvertTo-Json -Depth 12
            foreach ($kind in @($writers.Keys)) {
                $writer = $writers[$kind]
                try {
                    if ($kind -eq 'summary') {
                        Reset-WacSummaryReport -Writer $writer -Length $writer.InitialLength
                        $null = Add-WacSummaryReportContent -Writer $writer -Content $text
                    } else {
                        $content = if ($kind -eq 'json') { $json + "`r`n" } else { $text }
                        Set-WacOwnedReportContent -Writer $writer -Content $content
                    }
                } catch {
                    Add-WacReportFailure -Report $Report -Code ($kind + '_report_write_failed') -Message $_.Exception.Message
                    Write-Warning ('Report could not be written: ' + $_.Exception.Message)
                    try {
                        if ($kind -eq 'summary') { Reset-WacSummaryReport -Writer $writer -Length $writer.InitialLength }
                        else { Remove-WacOwnedReport -Writer $writer }
                    } catch {
                        Add-WacReportFailure -Report $Report -Code 'report_cleanup_failed' -Message $_.Exception.Message
                        Write-Warning ('Incomplete report could not be removed or rolled back: ' + $_.Exception.Message)
                    } finally {
                        try { Close-WacReportWriter -Writer $writer }
                        catch { Write-Warning ('Report handle release failed: ' + $_.Exception.Message) }
                        $writers.Remove($kind)
                    }
                    $retry = $true
                    break
                }
            }
        } while ($retry -and $writers.Count -gt 0)
    } finally {
        foreach ($writer in $writers.Values) {
            # All content was explicitly flushed above. A subsequent handle
            # release advisory must not rewrite the persisted terminal outcome.
            try { Close-WacReportWriter -Writer $writer }
            catch { Write-Warning ('Report handle release failed: ' + $_.Exception.Message) }
        }
    }
}

function ConvertTo-WacRedactedReport {
    param($Report)

    if ($null -eq $Report -or ($Report.schemaVersion -isnot [int] -and $Report.schemaVersion -isnot [long]) -or $Report.schemaVersion -ne 1 -or
        $Report.status -isnot [string] -or $Report.processingStatus -isnot [string] -or
        $Report.status -cnotin @('SUCCESS', 'WARNING', 'FAILED', 'CANCELLED') -or
        $Report.processingStatus -cnotin @('SUCCESS', 'FAILED', 'CANCELLED')) { throw 'Expected a version 1 WinAudioClean run report.' }
    # Copy no free-form source strings: even version/filter/error fields may
    # contain filenames, metadata or credentials. All retained values are typed
    # numbers, booleans, fixed enums or values regenerated from built-in profiles.
    $mode = if ($Report.settings.mode -cin @('Raw', 'Zoom')) { $Report.settings.mode } else { $null }
    $safe = [ordered]@{
        schemaVersion = 1; diagnosticExport = 'redacted'
        reviewWarning = 'Review this export before sharing. No file has been uploaded.'
        status = $Report.status; processingStatus = $Report.processingStatus
        applicationExitCode = $null; nativeExitCode = $null
        settings = [ordered]@{ mode = $mode; bitDepth = $null; mono = $null; rf64 = $null; loudnessMode = $null }
        input = [ordered]@{ durationSeconds = $null; channels = $null; sampleRate = $null; streamIndex = $null }
        timing = [ordered]@{ processingElapsedSeconds = $null }
        output = [ordered]@{ published = $null; validity = $null; format = [ordered]@{} }
        measurements = [ordered]@{}
        normalization = [ordered]@{ requestedMode = $null; actualType = $null; linearRequested = $null; fallbackReason = $null }
        loudnessCompliance = [ordered]@{ status = $null; reason = $null }
        diagnostics = [ordered]@{ omitted = $true; reason = 'may_contain_paths_or_metadata' }
    }
    foreach ($name in @('applicationExitCode', 'nativeExitCode')) {
        $value = $Report.$name
        if (($value -is [int] -or $value -is [long]) -and $value -ge [int]::MinValue -and $value -le [int]::MaxValue) { $safe[$name] = $value }
    }
    if (($Report.settings.bitDepth -is [int] -or $Report.settings.bitDepth -is [long]) -and $Report.settings.bitDepth -in @(16, 24)) { $safe.settings.bitDepth = $Report.settings.bitDepth }
    foreach ($name in @('mono', 'rf64')) { if ($Report.settings.$name -is [bool]) { $safe.settings[$name] = $Report.settings.$name } }
    foreach ($name in @('channels', 'sampleRate', 'index')) {
        $value = $Report.input.stream.$name
        $target = if ($name -eq 'index') { 'streamIndex' } else { $name }
        if (($value -is [int] -or $value -is [long]) -and $value -ge 0 -and $value -le [int]::MaxValue) { $safe.input[$target] = $value }
    }
    $safe.input.durationSeconds = (ConvertTo-WacMeasurement -Value $Report.input.durationSeconds -UnavailableReason 'unavailable')
    $safe.timing.processingElapsedSeconds = (ConvertTo-WacMeasurement -Value $Report.timing.processingElapsedSeconds -UnavailableReason 'unavailable')
    if ($Report.output.published -is [bool]) { $safe.output.published = $Report.output.published }
    if ($Report.output.validity -cin @('PASSED', 'FAILED')) { $safe.output.validity = $Report.output.validity }
    foreach ($name in @('sampleRate', 'bitDepth', 'channels')) {
        $value = $Report.output.format.$name
        $safe.output.format[$name] = if (($value -is [int] -or $value -is [long]) -and $value -gt 0 -and $value -le [int]::MaxValue) { $value } else { $null }
    }
    foreach ($name in @('codec', 'channelLayout', 'container')) {
        $allowed = switch ($name) { 'codec' { @('pcm_s16le', 'pcm_s24le') } 'channelLayout' { @('mono', 'stereo') } 'container' { @('RIFF', 'RF64') } }
        $safe.output.format[$name] = if ($Report.output.format.$name -cin $allowed) { $Report.output.format.$name } else { $null }
    }
    $metricReasons = @('unavailable', 'not_measured', 'too_short', 'silence', 'undefined_loudness', 'measurement_failed', 'nonfinite', 'not_numeric')
    foreach ($name in @('integratedLufs', 'truePeakDbtp', 'loudnessRangeLu')) {
        $value = $Report.measurements.$name.value
        $reason = if ($Report.measurements.$name.reason -cin $metricReasons) { $Report.measurements.$name.reason } else { 'not_measured' }
        if ($null -ne $value -and $value -isnot [double] -and $value -isnot [int] -and $value -isnot [long] -and $value -isnot [decimal]) {
            $value = $null; $reason = 'not_numeric'
        }
        $safe.measurements[$name] = ConvertTo-WacMeasurement -Value $value -UnavailableReason $reason
    }
    if ($Report.settings.loudnessMode -cin @('Fast', 'Accurate')) { $safe.settings.loudnessMode = $Report.settings.loudnessMode }
    if ($Report.normalization.requestedMode -cin @('Fast', 'Accurate')) { $safe.normalization.requestedMode = $Report.normalization.requestedMode }
    if ($Report.normalization.actualType -cin @('linear', 'dynamic')) { $safe.normalization.actualType = $Report.normalization.actualType }
    if ($Report.normalization.linearRequested -is [bool]) { $safe.normalization.linearRequested = $Report.normalization.linearRequested }
    if ($Report.normalization.fallbackReason -cin @('too_short', 'silence', 'undefined_loudness', 'measurement_out_of_range', 'ffmpeg_dynamic_fallback')) {
        $safe.normalization.fallbackReason = $Report.normalization.fallbackReason
    }
    if ($Report.loudnessCompliance.status -cin @('NOT_MEASURED', 'PASSED', 'OUT_OF_TOLERANCE', 'UNMEASURABLE', 'FAILED')) {
        $safe.loudnessCompliance.status = $Report.loudnessCompliance.status
    }
    if ($Report.loudnessCompliance.reason -cin @('no_independent_measurement', 'true_peak_exceeded', 'loudness_out_of_tolerance', 'too_short', 'silence', 'undefined_loudness', 'measurement_failed')) {
        $safe.loudnessCompliance.reason = $Report.loudnessCompliance.reason
    }
    $safe
}

function Export-WacDiagnostic {
    param([string]$Path, [string]$Destination)

    $source = $null; $directory = $null; $writer = $null
    try {
        $sourcePath = Resolve-WacFileSystemPath -Path $Path
        $destinationPath = Resolve-WacFileSystemPath -Path $Destination
        $source = [IO.File]::Open($sourcePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        if ($source.Length -gt 16MB) { throw 'Diagnostic input exceeds the 16 MiB export limit.' }
        $reader = [IO.StreamReader]::new($source, [Text.Encoding]::UTF8, $true, 4096, $true)
        try {
            $jsonText = $reader.ReadToEnd()
            if (-not $jsonText.TrimStart().StartsWith('{')) { throw 'Diagnostic input must be a JSON object.' }
            $data = $jsonText | ConvertFrom-Json -ErrorAction Stop
        }
        finally { $reader.Dispose() }
        $redacted = ConvertTo-WacRedactedReport -Report $data
        Initialize-WacNativeFileIO
        $directory = [WinAudioClean.NativeFileIO]::OpenDirectory([IO.Path]::GetDirectoryName($destinationPath))
        $canonical = [WinAudioClean.NativeFileIO]::ResolvedPath($directory)
        $writer = Open-WacReportWriter -Path ([IO.Path]::Combine($canonical, [IO.Path]::GetFileName($destinationPath))) -CreateNew
        try { Set-WacOwnedReportContent -Writer $writer -Content (($redacted | ConvertTo-Json -Depth 10) + "`r`n") }
        catch {
            Remove-WacOwnedReport -Writer $writer
            throw
        }
        Write-Warning 'Review the redacted diagnostic export before sharing. No file has been uploaded.'
        Write-Host ('Diagnostic export saved to: ' + $writer.Path)
    } finally {
        if ($null -ne $writer) { Close-WacReportWriter -Writer $writer }
        if ($null -ne $directory) { $directory.Dispose() }
        if ($null -ne $source) { $source.Dispose() }
    }
}


# Dot-sourcing exposes only helpers. Normal -File, &, and .bat calls still run below.
if ($MyInvocation.InvocationName -eq '.') { return }

# Explicit local support export bypasses media/dependency initialization.
if ($PSBoundParameters.ContainsKey('ExportDiagnostic') -or $PSBoundParameters.ContainsKey('DiagnosticOutputPath')) {
    try {
        foreach ($name in $PSBoundParameters.Keys) {
            if ($name -notin @('ExportDiagnostic', 'DiagnosticOutputPath', 'NonInteractive')) {
                throw 'Diagnostic export cannot be combined with audio processing options.'
            }
        }
        Export-WacDiagnostic -Path $ExportDiagnostic -Destination $DiagnosticOutputPath
        exit 0
    } catch {
        Write-Error -Message ('Diagnostic export failed: ' + $_.Exception.Message) -ErrorAction Continue
        exit 2
    }
}

# Settings are optional for an installation with no saved preferences. Imports
# return above without reading user configuration or requiring this component.
# Explicit management never probes an input, resolves native tools or prompts.
$settingsManagement = $ShowSettings -or $SaveSettings -or $ResetSettings
if (-not $settingsManagement -and -not $PickFile -and [string]::IsNullOrWhiteSpace($inputPath) -and
    -not $PSBoundParameters.ContainsKey('InputPaths') -and -not $PSBoundParameters.ContainsKey('InputListPath') -and
    -not $PSBoundParameters.ContainsKey('InputDirectories') -and -not $PSBoundParameters.ContainsKey('BatchResultPath') -and
    -not $PSBoundParameters.ContainsKey('Recurse')) {
    Show-WacUsage
    Write-Error -Message 'No input file supplied. See the console usage examples.' -ErrorAction Continue
    exit 2
}
$audioStreamIndexSpecified = $PSBoundParameters.ContainsKey('AudioStreamIndex')
$resolvedSettings = $null
try {
    $settingsFilePath = $SettingsPath
    if (-not $PSBoundParameters.ContainsKey('SettingsPath')) {
        $applicationData = [Environment]::GetFolderPath('ApplicationData')
        if ($applicationData) { $settingsFilePath = [IO.Path]::Combine($applicationData, 'WinAudioClean', 'settings.json') }
    }
    $useSettingsComponent = $settingsManagement -or $PSBoundParameters.ContainsKey('SettingsPath') -or
        (-not $IgnoreSavedSettings -and $settingsFilePath -and (Test-Path -LiteralPath $settingsFilePath))
    if ($useSettingsComponent) {
        $settingsComponent = Join-Path $PSScriptRoot 'WinAudioClean.Settings.ps1'
        if (-not (Test-Path -LiteralPath $settingsComponent -PathType Leaf)) {
            throw 'Keep WinAudioClean.Settings.ps1 beside the main script to use saved preferences.'
        }
        . $settingsComponent
        if ($settingsManagement) {
            $preferenceNames = @('Mode', 'Preset', 'LoudnessMode', 'BitDepth', 'Mono', 'Rf64', 'OutputDirectory', 'AudioStreamIndex', 'CleaningOptions')
            foreach ($name in $PSBoundParameters.Keys) {
                if ($name -notin $preferenceNames + @('SettingsPath', 'IgnoreSavedSettings', 'ShowSettings', 'SaveSettings', 'ResetSettings', 'NonInteractive')) {
                    throw 'Settings management cannot be combined with input, preview, dependencies or diagnostic actions.'
                }
            }
            if ($SaveSettings -and $ResetSettings) { throw 'SaveSettings and ResetSettings cannot be combined.' }
            if ($ResetSettings) {
                foreach ($name in $preferenceNames) {
                    if ($PSBoundParameters.ContainsKey($name)) { throw 'ResetSettings cannot be combined with processing choices.' }
                }
            }
        }
        $settingsFilePath = Resolve-WacFileSystemPath -Path $settingsFilePath
        $savedSettings = @{}
        if (-not $IgnoreSavedSettings -and -not $ResetSettings) {
            $savedSettings = Read-WacSettings -Path $settingsFilePath
        }
        $resolvedSettings = Resolve-WacSettings -Explicit $PSBoundParameters -Saved $savedSettings
        if ($settingsManagement) {
            if ($ResetSettings) {
                $null = Save-WacSettings -Path $settingsFilePath -Values @{}
                Write-Host 'Saved preferences reset to built-in defaults.'
            } elseif ($SaveSettings) {
                $null = Save-WacSettings -Path $settingsFilePath -Values $resolvedSettings.Values
                Write-Host 'Preferences saved.'
            }
            $settingsDisplay = ConvertTo-WacSettingsJson -Values $resolvedSettings.Values | ConvertFrom-Json
            $settingsDisplay | Add-Member -MemberType NoteProperty -Name origins -Value $resolvedSettings.Origins
            $displayProfile = $null
            if ($resolvedSettings.Values.Mode) {
                $displayChoice = if ($resolvedSettings.Values.Mode -eq 'Raw') { '1' } else { '2' }
                $displayProfile = Get-WacProcessingProfile -Choice $displayChoice -Preset $resolvedSettings.Values.Preset -CleaningOptions $resolvedSettings.Values.CleaningOptions
            }
            $settingsDisplay | Add-Member -MemberType NoteProperty -Name effectiveCleaning -Value $(if ($displayProfile) { $displayProfile.CleaningSettings } else { $null })
            $settingsDisplay | Add-Member -MemberType NoteProperty -Name effectiveFilterChain -Value $(if ($displayProfile) { $displayProfile.FilterChain } else { $null })
            $settingsDisplay | Add-Member -MemberType NoteProperty -Name effectiveProfileReason -Value $(if ($displayProfile) { $null } else { 'mode_not_selected' })
            Write-Output ($settingsDisplay | ConvertTo-Json -Depth 8 -Compress)
            exit 0
        }
        $Mode = $resolvedSettings.Values.Mode
        $Preset = $resolvedSettings.Values.Preset
        $LoudnessMode = $resolvedSettings.Values.LoudnessMode
        $BitDepth = $resolvedSettings.Values.BitDepth
        $Mono = $resolvedSettings.Values.Mono
        $Rf64 = $resolvedSettings.Values.Rf64
        $OutputDirectory = $resolvedSettings.Values.OutputDirectory
        $AudioStreamIndex = $resolvedSettings.Values.AudioStreamIndex
        $CleaningOptions = $resolvedSettings.Values.CleaningOptions
        $audioStreamIndexSpecified = $null -ne $resolvedSettings.Values.AudioStreamIndex
    }
} catch {
    Write-Error -Message ('Settings failed: ' + $_.Exception.Message + ' Use -IgnoreSavedSettings or -ResetSettings for recovery.') -ErrorAction Continue
    exit 2
}

# One controller per invocation; queue children borrow it and never unregister it.
$ownsRunContext = $null -eq $WacRunContext
if ($ownsRunContext) { $WacRunContext = New-WacRunContext -CaptureConsole }
$script:WacRunContext = $WacRunContext
$script:WacProgressStages = New-Object 'System.Collections.Generic.List[object]'
$ownsOutputLayout = $false
$script:WacOutputLayout = $WacOutputLayout
try {

$interactive = Test-WacInteractive -NonInteractive:$NonInteractive
try {
    if (($PickFile -or $OpenOutputFolder) -and -not $interactive) {
        throw 'PickFile and OpenOutputFolder require an interactive console. Omit these actions for terminal or unattended use.'
    }
    if ($PickFile) {
        foreach ($name in @('inputPath', 'InputPaths', 'InputListPath', 'InputDirectories', 'Recurse', 'BatchResultPath')) {
            if ($PSBoundParameters.ContainsKey($name)) { throw 'PickFile cannot be combined with an input or queue selection.' }
        }
        $inputPath = Show-WacFilePicker
        if ([string]::IsNullOrWhiteSpace($inputPath)) { Write-Host 'Cancelled. No audio was processed.'; exit 130 }
    }
    if ($JobFolder -or $null -ne $WacOutputLayout) {
        $outputComponent = Join-Path $PSScriptRoot 'WinAudioClean.Output.ps1'
        if (-not (Test-Path -LiteralPath $outputComponent -PathType Leaf)) {
            throw 'Keep WinAudioClean.Output.ps1 beside the main script to use JobFolder.'
        }
        . $outputComponent
        if ($null -ne $WacOutputLayout) { Assert-WacOutputLayout -Layout $WacOutputLayout }
    }
} catch {
    Write-Error -Message ('Local interaction failed: ' + $_.Exception.Message) -ErrorAction Continue
    exit 2
}

# Explicit lists reuse the ordinary single-file path, with preferences frozen
# once and no child configuration reads. Legacy installations/imports need no
# batch component. Folder discovery is a separate, explicitly selected route.
$batchRequested = $PSBoundParameters.ContainsKey('InputPaths') -or $PSBoundParameters.ContainsKey('InputListPath')
$folderRequested = $PSBoundParameters.ContainsKey('InputDirectories')
if ($batchRequested -or $folderRequested -or $PSBoundParameters.ContainsKey('BatchResultPath') -or $PSBoundParameters.ContainsKey('Recurse')) {
    try {
        if (-not $batchRequested -and -not $folderRequested) { throw 'BatchResultPath requires an explicit list or InputDirectories; Recurse requires InputDirectories.' }
        if ($PSBoundParameters.ContainsKey('Recurse') -and -not $folderRequested) { throw 'Recurse requires InputDirectories.' }
        if ($Preview -or $PSBoundParameters.ContainsKey('PreviewStartSeconds') -or $PSBoundParameters.ContainsKey('PreviewDurationSeconds')) {
            throw 'Lists and folders support ordinary full renders; preview requires one inputPath.'
        }
        foreach ($component in @('WinAudioClean.Settings.ps1', 'WinAudioClean.Batch.ps1')) {
            $componentPath = Join-Path $PSScriptRoot $component
            if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw "Keep $component beside the main script to use input lists." }
            . $componentPath
        }
        if ($null -eq $resolvedSettings) { $resolvedSettings = Resolve-WacSettings -Explicit $PSBoundParameters }
        $batchArguments = @{ Parameters = $PSBoundParameters; ResolvedSettings = $resolvedSettings; ApplicationPath = $PSCommandPath }
        if ($folderRequested) {
            $componentPath = Join-Path $PSScriptRoot 'WinAudioClean.Queue.ps1'
            if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) { throw 'Keep WinAudioClean.Queue.ps1 beside the main script to use folder queues.' }
            . $componentPath
            $directories = @(Resolve-WacFolderSelection -Parameters $PSBoundParameters)
            $outputFolder = Get-WacOutputDirectory -Path $resolvedSettings.Values.OutputDirectory -DefaultMusic:($resolvedSettings.Origins.OutputDirectory -eq 'BuiltIn')
            $queue = New-WacFolderQueue -Directories $directories -OutputDirectory $outputFolder -Recurse:$Recurse
            $batchArguments.FolderQueue = $queue
            $batchInputs = @($queue.Entries | ForEach-Object { $_.InputPath })
        } else { $batchInputs = @(Resolve-WacBatchInputs -Parameters $PSBoundParameters) }
        if ($JobFolder -and $null -eq $WacOutputLayout) {
            $outputFolder = Get-WacOutputDirectory -Path $resolvedSettings.Values.OutputDirectory -DefaultMusic:($resolvedSettings.Origins.OutputDirectory -eq 'BuiltIn')
            $WacOutputLayout = New-WacOutputLayout -BaseDirectory $outputFolder
            $script:WacOutputLayout = $WacOutputLayout; $ownsOutputLayout = $true
        }
        if ($null -ne $WacOutputLayout) { $batchArguments.OutputLayout = $WacOutputLayout }
        $batchResult = Invoke-WacBatch -Inputs $batchInputs -RunContext $WacRunContext @batchArguments
        Invoke-WacOutputFollowUp -Requested:$OpenOutputFolder -Interactive:$interactive -ExitCode $batchResult.ExitCode -Published:([bool]$batchResult.HasPublishedOutput) -Directory $batchResult.OutputDirectory -ExpectedDirectoryIdentity $batchResult.OutputDirectoryIdentity
        exit $batchResult.ExitCode
    } catch {
        Write-Error -Message ('Input selection failed: ' + $_.Exception.Message) -ErrorAction Continue
        exit 2
    }
}

# --- CONFIGURATION ---
$scriptVersion = "1.0.0"

# The preview component is optional for normal exports. Loading defines helpers;
# it never renders or launches playback. Existing full-render installations and
# dot-source imports retain their original IO-only dependency contract.
if ($Preview) {
    try { . (Join-Path $PSScriptRoot 'WinAudioClean.Preview.ps1') }
    catch {
        Write-Error -Message ('Preview component failed: keep WinAudioClean.Preview.ps1 beside the main script. ' + $_.Exception.Message) -ErrorAction Continue
        exit 3
    }
}

# Validate before displaying the menu or starting any native process. Reading a
# file here proves accessibility; bounded media probing follows below.
try {
    $inputFileItem = Get-WacInputFile -Path $inputPath
    $inputPath = $inputFileItem.FullName
    if ($PSBoundParameters.ContainsKey('Mode') -and $Mode -notin @('Raw', 'Zoom')) {
        throw 'Invalid mode. Supply -Mode Raw or -Mode Zoom.'
    }
    if ($audioStreamIndexSpecified) {
        $parsedIndex = 0
        if ($AudioStreamIndex -notmatch '^[0-9]+$' -or -not [int]::TryParse($AudioStreamIndex, [ref]$parsedIndex)) {
            throw 'Audio stream index must be a nonnegative absolute stream index shown by ffprobe.'
        }
    }
    if ($BitDepth -cnotin @('16', '24')) { throw 'Bit depth must be 16 or 24. Supply -BitDepth 16 or -BitDepth 24.' }
    if ($LoudnessMode -notin @('Fast', 'Accurate')) { throw 'Loudness mode must be Fast or Accurate.' }
    $LoudnessMode = if ($LoudnessMode -eq 'Accurate') { 'Accurate' } else { 'Fast' }
    $null = Get-WacCleaningSettings -Preset $Preset -Options $CleaningOptions
    if ($Mode) {
        $validatedChoice = if ($Mode -eq 'Raw') { '1' } else { '2' }
        $null = Get-WacProcessingProfile -Choice $validatedChoice -Preset $Preset -CleaningOptions $CleaningOptions
    }
    if (-not $Preview -and ($PSBoundParameters.ContainsKey('PreviewStartSeconds') -or $PSBoundParameters.ContainsKey('PreviewDurationSeconds'))) {
        throw 'Preview start/duration require -Preview. No full recording will be processed implicitly.'
    }
    if ($Preview) {
        # Validate numeric options against the supported duration ceiling here;
        # the actual selected stream is pinned/probed and checked by the preview.
        $null = Get-WacPreviewRange -InputDurationSeconds 1000000000 -Start $PreviewStartSeconds -Duration $PreviewDurationSeconds -DurationExplicit:($PSBoundParameters.ContainsKey('PreviewDurationSeconds'))
    }
    $defaultMusic = -not $PSBoundParameters.ContainsKey('OutputDirectory') -and
        ($null -eq $resolvedSettings -or $resolvedSettings.Origins.OutputDirectory -eq 'BuiltIn')
    if ($defaultMusic) { $OutputDirectory = Get-WacDefaultOutputDirectory }
    $outFolder = Get-WacOutputDirectory -Path $OutputDirectory -DefaultMusic:$defaultMusic
    if (-not $Mode -and -not $interactive) {
        throw 'A mode is required for unattended use. Supply -Mode Raw or -Mode Zoom with -NonInteractive.'
    }
    if ($JobFolder -and $null -eq $WacOutputLayout) {
        $WacOutputLayout = New-WacOutputLayout -BaseDirectory $outFolder
        $script:WacOutputLayout = $WacOutputLayout; $ownsOutputLayout = $true
    }
    $reportFolder = $outFolder
    if ($null -ne $WacOutputLayout) {
        Assert-WacOutputLayout -Layout $WacOutputLayout
        $outFolder = $WacOutputLayout.MediaDirectory; $reportFolder = $WacOutputLayout.ReportDirectory
    }
} catch {
    Write-Error -Message ("Preflight failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 2
}
$null = Add-WacProgressStage -Stage 'Inspecting'
try {
    $resolveArguments = @{ Name = 'ffmpeg.exe'; SiblingDirectory = $PSScriptRoot }
    if ($PSBoundParameters.ContainsKey('FfmpegPath')) { $resolveArguments.ExplicitPath = $FfmpegPath }
    $ffmpegPath = Resolve-WacExecutable @resolveArguments
    $resolveArguments = @{ Name = 'ffprobe.exe'; SiblingDirectory = [IO.Path]::GetDirectoryName($ffmpegPath) }
    if ($PSBoundParameters.ContainsKey('FfprobePath')) { $resolveArguments.ExplicitPath = $FfprobePath }
    $ffprobePath = Resolve-WacExecutable @resolveArguments
    $ffmpegVersion = Get-WacToolVersion -FilePath $ffmpegPath -ToolName ffmpeg
    $ffprobeVersion = Get-WacToolVersion -FilePath $ffprobePath -ToolName ffprobe
} catch {
    if ($WacRunContext.IsCancellationRequested) { Write-Host 'Cancelled. No audio was processed.'; exit 130 }
    Write-Error -Message ("Dependency failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 3
}

# --- TUI: HEADER ---
if ($interactive) { Clear-Host }
Write-Host "WinAudioClean $scriptVersion" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Gray
Write-Host "Input: " -NoNewline; Write-Host $inputPath -ForegroundColor Yellow
Write-Host "FFmpeg: $ffmpegPath ($ffmpegVersion)" -ForegroundColor Gray
Write-Host "FFprobe: $ffprobePath ($ffprobeVersion)" -ForegroundColor Gray

# --- TUI: SELECTION ---
if (-not $Mode) {
    Write-Host ("`nSelect Processing Mode ({0} preset):" -f $Preset) -ForegroundColor White
    Write-Host "[1] RAW RECORDING (Clean + Level)" -ForegroundColor Green
    Write-Host "    -> Cleaning plus leveling for mic recordings. Listen for speech changes."
    Write-Host "[2] ZOOM/TEAMS (Level Only)" -ForegroundColor Magenta
    Write-Host "    -> Leveling for meeting audio; skips the Raw cleaning filters."
    Write-Host '[Q] Cancel'
    try { $Mode = Read-WacMode }
    catch {
        Write-Error -Message $_.Exception.Message -ErrorAction Continue
        exit 2
    }
    if (-not $Mode) {
        Write-Host 'Cancelled. No audio was processed.'
        exit 130
    }
}

# --- FILTER SELECTION ---
$effectiveSettingsDisplay = [ordered]@{
    mode = $Mode; preset = $Preset; loudnessMode = $LoudnessMode; bitDepth = [int]$BitDepth
    mono = [bool]$Mono; rf64 = [bool]$Rf64; outputDirectory = $outFolder
    audioStreamIndex = $(if ($audioStreamIndexSpecified) { [int]$AudioStreamIndex } else { $null })
    cleaningOptions = $CleaningOptions
}
Write-Host ('Effective settings: ' + ($effectiveSettingsDisplay | ConvertTo-Json -Depth 6 -Compress))
$choice = if ($Mode -eq 'Raw') { '1' } else { '2' }
try { $processingProfile = Get-WacProcessingProfile -Choice $choice -Preset $Preset -CleaningOptions $CleaningOptions }
catch {
    Write-Error -Message ('Cleaning settings failed: ' + $_.Exception.Message) -ErrorAction Continue
    exit 2
}
$modeName = $processingProfile.ModeName
$filterChain = $processingProfile.FilterChain
Write-Host ("Preset: {0} (ID: {1}; version: {2})" -f $processingProfile.PresetName, $processingProfile.PresetId, $processingProfile.PresetVersion)
if ($processingProfile.PresetExperimental) { Write-Host 'Gentle is an experimental listening candidate; speech quality has not been reviewed.' -ForegroundColor Yellow }
if ($processingProfile.CleaningCustomized) { Write-Host 'Custom cleaning settings override the named base preset. Inspect the effective settings and listen.' -ForegroundColor Yellow }
if ($processingProfile.CleaningSettings) { Write-Host ('Cleaning: ' + ($processingProfile.CleaningSettings | ConvertTo-Json -Compress)) }

try {
    Test-WacRequiredFilters -FfmpegPath $ffmpegPath -FilterChain $filterChain
    if ($LoudnessMode -eq 'Accurate') { Test-WacRequiredFilters -FfmpegPath $ffmpegPath -FilterChain 'aresample' }
    if ($Preview) { Test-WacRequiredFilters -FfmpegPath $ffmpegPath -FilterChain 'atrim,asetpts,aresample,volume' }
}
catch {
    if ($WacRunContext.IsCancellationRequested) { Write-Host 'Cancelled. No audio was processed.'; exit 130 }
    Write-Error -Message ("Dependency failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 3
}
if ($Preview) {
    $previewArguments = @{
        InputPath = $inputPath; OutputFolder = $outFolder
        FfmpegPath = $ffmpegPath; FfprobePath = $ffprobePath
        ProcessingProfile = $processingProfile; LoudnessMode = $LoudnessMode
        BitDepth = $BitDepth; Mono = $Mono; Rf64 = $Rf64
        Start = $PreviewStartSeconds; Duration = $PreviewDurationSeconds
        DurationExplicit = $PSBoundParameters.ContainsKey('PreviewDurationSeconds')
        Interactive = $interactive; ToolVersion = $scriptVersion
        FfmpegVersion = $ffmpegVersion; FfprobeVersion = $ffprobeVersion
    }
    if ($null -ne $WacOutputLayout) { $previewArguments.ReportFolder = $reportFolder; $previewArguments.OutputLayout = $WacOutputLayout }
    if ($audioStreamIndexSpecified) { $previewArguments.AudioStreamIndex = $AudioStreamIndex }
    try { $previewResult = Invoke-WacPreview @previewArguments }
    catch {
        Write-Error -Message ('Preview failed: ' + $_.Exception.Message) -ErrorAction Continue
        exit 5
    }
    Write-Host ('Preview: ' + $previewResult.Status)
    if ($previewResult.Error) { Write-Error -Message $previewResult.Error -ErrorAction Continue }
    if ($previewResult.CleanupErrors) { Write-Warning ($previewResult.CleanupErrors -join ' ') }
    if ($previewResult.ReportPaths) { Write-Host ('Preview reports: ' + ($previewResult.ReportPaths | ConvertTo-Json -Compress)) }
    Write-Host 'Preview finished. Open the comparison files explicitly to listen; no full recording or playback starts automatically.'
    $followUpDirectory = if ($null -ne $WacOutputLayout) { $WacOutputLayout.RootDirectory } else { $previewResult.OutputDirectory }
    $followUpIdentity = if ($null -ne $WacOutputLayout) { $WacOutputLayout.Identities.Root } else { $previewResult.OutputDirectoryIdentity }
    Invoke-WacOutputFollowUp -Requested:$OpenOutputFolder -Interactive:$interactive -ExitCode $previewResult.ExitCode -Published:($previewResult.Status -in @('SUCCESS', 'WARNING')) -Directory $followUpDirectory -ExpectedDirectoryIdentity $followUpIdentity
    exit $previewResult.ExitCode
}

$transaction = $null
$applicationExitCode = 0
try {
    $transaction = New-WacOutputTransaction -InputPath $inputPath -OutputFolder $outFolder
    $inputPath = $transaction.InputPath
    $outputFile = $transaction.FinalPath
    if ($null -eq $WacOutputLayout) { $reportFolder = $transaction.OutputFolder }
} catch {
    Write-Error -Message ("Output allocation failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 5
}

# Hold the input and destination directory through probing, rendering and reporting.
try {
try { $audioStreams = @(Get-WacAudioStreams -FfprobePath $ffprobePath -InputPath $inputPath) }
catch {
    if ($WacRunContext.IsCancellationRequested) { Write-Host 'Cancelled. No audio was processed.'; exit 130 }
    Write-Error -Message ("Probe failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 4
}
try {
    $selectionArguments = @{ Streams = $audioStreams; Interactive = $interactive }
    if ($audioStreamIndexSpecified) { $selectionArguments.RequestedIndex = $AudioStreamIndex }
    $selectedStream = Select-WacAudioStream @selectionArguments
} catch {
    Write-Error -Message ("Audio selection failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 2
}
if ($null -eq $selectedStream) {
    Write-Host 'Cancelled. No audio was processed.'
    exit 130
}
if ($null -eq $selectedStream.DurationSeconds) {
    Write-Error -Message 'Selected audio duration is unavailable. Cannot verify export timing safely.' -ErrorAction Continue
    exit 4
}
Write-Host "Audio stream: $($selectedStream.Index) ($($selectedStream.Codec), $($selectedStream.Channels) channel(s), $($selectedStream.SampleRate) Hz)"
try { $outputPolicy = Get-WacOutputPolicy -InputAudio $selectedStream -BitDepth $BitDepth -Mono:$Mono -Rf64:$Rf64 }
catch {
    Write-Error -Message ("Output settings failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 2
}
if ($outputPolicy.FilterPrefix) {
    try { Test-WacRequiredFilters -FfmpegPath $ffmpegPath -FilterChain 'pan' }
    catch {
        if ($WacRunContext.IsCancellationRequested) { Write-Host 'Cancelled. No audio was processed.'; exit 130 }
        Write-Error -Message ("Dependency failed: " + $_.Exception.Message) -ErrorAction Continue
        exit 3
    }
}
try {
    $spaceEstimate = Get-WacOutputSpaceEstimate -DurationSeconds $selectedStream.DurationSeconds -OutputPolicy $outputPolicy
    $availableBytes = Assert-WacOutputSpace -Transaction $transaction -Estimate $spaceEstimate
} catch {
    Write-Error -Message ("Output space check failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 5
}
$containerName = if ($outputPolicy.Rf64) { 'RF64' } else { 'RIFF' }
Write-Host "Export: 48000 Hz, $($outputPolicy.Bits)-bit PCM, $($outputPolicy.Layout), $containerName WAV"
Write-Host "Destination space: $availableBytes bytes available; $($spaceEstimate.RequiredBytes) bytes required including headroom."


# --- EXECUTION ---
Write-Host "`nRunning WinAudioClean..." -ForegroundColor Cyan
Write-Host "Chain: $modeName" -ForegroundColor Gray

$startedAt = [DateTime]::UtcNow
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# Fast retains the original single render and argv. Accurate measures the exact
# prechain, renders with its measured values, then measures the held final PCM.
$normalization = [ordered]@{ requestedMode = $LoudnessMode; prechain = $null; analysisFilter = $null
    renderFilter = ($outputPolicy.FilterPrefix + $filterChain); finalMeasurementFilter = $null
    linearRequested = $false; fallbackReason = $null; actualType = $null
    analysis = $null; render = $null; final = $null }
$loudnessWarnings = @()
$finalLoudness = $null
$analysisFailed = $false
$loudnessTimeout = [int][math]::Min([int]::MaxValue, [math]::Max(120000, $selectedStream.DurationSeconds * 20000 + 60000))
if ($LoudnessMode -eq 'Accurate') {
    $normalization.renderFilter = $null
    $loudnessPlan = Get-WacLoudnessPlan -Profile $processingProfile -OutputPolicy $outputPolicy
    $normalization.prechain = $loudnessPlan.Prechain
    $normalization.analysisFilter = $loudnessPlan.AnalysisFilter
    $normalization.finalMeasurementFilter = $loudnessPlan.FinalMeasurementFilter
    $analysisArguments = Get-WacLoudnessArguments -InputPath $inputPath -FilterChain $loudnessPlan.AnalysisFilter -AudioStreamIndex $selectedStream.Index -OutputPolicy $outputPolicy
    $analysisArguments = Get-WacProgressArguments -ArgumentList $analysisArguments
    $progressState = Add-WacProgressStage -Stage 'Analysis' -DurationSeconds $selectedStream.DurationSeconds -EndPercent 30
    $process = Invoke-WacNativeProcess -FilePath $ffmpegPath -ArgumentList $analysisArguments -TimeoutMilliseconds $loudnessTimeout -ProgressState $progressState
    $normalization.analysis = ConvertTo-WacLoudnessStage -Process $process -DurationSeconds $selectedStream.DurationSeconds -Arguments $analysisArguments
    $analysisFailed = $normalization.analysis.status -ne 'PASSED'
    if (-not $analysisFailed) {
        $loudnessPlan = Get-WacLoudnessPlan -Profile $processingProfile -OutputPolicy $outputPolicy -Measurement $normalization.analysis.measurement
        $normalization.linearRequested = $loudnessPlan.LinearRequested
        $normalization.fallbackReason = $loudnessPlan.FallbackReason
        $normalization.renderFilter = $loudnessPlan.RenderFilter
        # The plan includes channel conversion; the existing argv builder adds
        # its prefix, so pass only the remainder to avoid applying mono twice.
        $renderChain = $loudnessPlan.RenderFilter.Substring($outputPolicy.FilterPrefix.Length)
        $argumentList = Get-WacFfmpegArguments -InputPath $inputPath -FilterChain $renderChain -OutputFile $transaction.TempPath -AudioStreamIndex $selectedStream.Index -OutputPolicy $outputPolicy
        $argumentList[[array]::IndexOf($argumentList, '-loglevel') + 1] = 'info'
        $argumentList[[array]::IndexOf($argumentList, '-stats')] = '-nostats'
        $argumentList = Get-WacProgressArguments -ArgumentList $argumentList
        $progressState = Add-WacProgressStage -Stage 'Rendering' -DurationSeconds $selectedStream.DurationSeconds -StartPercent 30 -EndPercent 80
        $process = Invoke-WacNativeProcess -FilePath $ffmpegPath -ArgumentList $argumentList -TimeoutMilliseconds $loudnessTimeout -ProgressState $progressState
        $normalization.render = ConvertTo-WacLoudnessStage -Process $process -DurationSeconds $selectedStream.DurationSeconds -Arguments $argumentList
        if ($normalization.render.status -eq 'PASSED') {
            $normalization.actualType = $normalization.render.measurement.NormalizationType
            if ($normalization.linearRequested -and $normalization.actualType -eq 'dynamic') { $normalization.fallbackReason = 'ffmpeg_dynamic_fallback' }
        } else { $loudnessWarnings += 'normalization_result_unavailable' }
        if ($normalization.fallbackReason) { $loudnessWarnings += 'normalization_fallback' }
    }
} else {
    $argumentList = Get-WacFfmpegArguments -InputPath $inputPath -FilterChain $filterChain -OutputFile $transaction.TempPath -AudioStreamIndex $selectedStream.Index -OutputPolicy $outputPolicy
    $argumentList = Get-WacProgressArguments -ArgumentList $argumentList
    $progressState = Add-WacProgressStage -Stage 'Rendering' -DurationSeconds $selectedStream.DurationSeconds -EndPercent 90
    $process = Invoke-WacNativeProcess -FilePath $ffmpegPath -ArgumentList $argumentList -ProgressState $progressState
}

# --- LOGGING ---
$applicationExitCode = 0
if ($process.Cancelled -or $WacRunContext.IsCancellationRequested) { $applicationExitCode = 130 }
elseif (-not $process.Started) { $applicationExitCode = 3 }
elseif ($analysisFailed -or $process.Error -or $process.CleanupError -or $process.TimedOut -or $null -eq $process.ExitCode -or $process.ExitCode -ne 0) { $applicationExitCode = 4 }
$validationError = $null
$verifiedAudio = $null
if ($applicationExitCode -eq 0) {
    try {
        $null = Add-WacProgressStage -Stage 'Validating' -StartPercent $(if ($LoudnessMode -eq 'Accurate') { 80 } else { 90 }) -EndPercent $(if ($LoudnessMode -eq 'Accurate') { 80 } else { 90 })
        if ($WacRunContext.IsCancellationRequested) { throw 'Processing cancelled.' }
        $outputStreams = @(Get-WacAudioStreams -FfprobePath $ffprobePath -InputPath $transaction.TempPath)
        if ($outputStreams.Count -ne 1) { throw 'Output must contain exactly one readable audio stream.' }
        $validationStream = Freeze-WacOutputTransaction -Transaction $transaction
        $verifiedAudio = Assert-WacWaveOutput -Stream $validationStream -InputAudio $selectedStream -OutputAudio $outputStreams[0] -OutputPolicy $outputPolicy
        if ($LoudnessMode -eq 'Accurate') {
            # Keep the immutable validation handle through measurement and
            # publication. FFmpeg cannot reopen a file held with DELETE access.
            $validationStream.Position = 0
            $finalArguments = Get-WacLoudnessArguments -FilterChain $loudnessPlan.FinalMeasurementFilter -OutputPolicy $outputPolicy -FromPipe
            $finalArguments = Get-WacProgressArguments -ArgumentList $finalArguments
            $progressState = Add-WacProgressStage -Stage 'Verification' -DurationSeconds $verifiedAudio.DurationSeconds -StartPercent 80 -EndPercent 95
            $finalProcess = Invoke-WacNativeProcess -FilePath $ffmpegPath -ArgumentList $finalArguments -StandardInputStream $validationStream -TimeoutMilliseconds $loudnessTimeout -ProgressState $progressState
            $normalization.final = ConvertTo-WacLoudnessStage -Process $finalProcess -DurationSeconds $verifiedAudio.DurationSeconds -Arguments $finalArguments -InputSource 'held_output_stream'
            if ($finalProcess.Cancelled -or $WacRunContext.IsCancellationRequested) { throw 'Processing cancelled.' }
            if ($normalization.final.status -eq 'PASSED') {
                $finalLoudness = ConvertTo-WacFinalLoudness -Measurement $normalization.final.measurement
            } else {
                $finalLoudness = [pscustomobject]@{
                    Measurements = [ordered]@{
                        integratedLufs = (ConvertTo-WacMeasurement -Value $null -UnavailableReason 'measurement_failed')
                        truePeakDbtp = (ConvertTo-WacMeasurement -Value $null -UnavailableReason 'measurement_failed')
                        loudnessRangeLu = (ConvertTo-WacMeasurement -Value $null -UnavailableReason 'measurement_failed') }
                    Compliance = [ordered]@{ status = 'FAILED'; reason = 'measurement_failed' } }
            }
            if ($finalLoudness.Compliance.status -ne 'PASSED') { $loudnessWarnings += 'final_loudness_' + $finalLoudness.Compliance.status.ToLowerInvariant() }
        }
        $null = Add-WacProgressStage -Stage 'Publishing' -StartPercent 95 -EndPercent 99
        if ($WacRunContext.IsCancellationRequested) { throw 'Processing cancelled.' }
        Publish-WacOutputTransaction -Transaction $transaction
        Complete-WacProgress
    } catch {
        $validationError = $_.Exception.Message
        $applicationExitCode = if ($WacRunContext.IsCancellationRequested) { 130 } else { 5 }
        Write-Error -Message ("Output validation/publication failed: " + $validationError) -ErrorAction Continue
    }
}
$stopWatch.Stop()
$status = if ($applicationExitCode -eq 0) { 'SUCCESS' } elseif ($applicationExitCode -eq 130) { 'CANCELLED' } else { 'FAILED' }
$nativeExitText = if ($null -eq $process.ExitCode) { 'not started' } else { [string]$process.ExitCode }
# Keep separate diagnostics even when the child returns a failure code.
if ($process.StandardOutput) { Write-Host $process.StandardOutput }
if ($process.StandardError) { Write-Host $process.StandardError -ForegroundColor Gray }
if ($process.Error) { Write-Error -Message $process.Error -ErrorAction Continue }
if ($process.CleanupError) { Write-Error -Message ("Native cleanup failed: " + $process.CleanupError) -ErrorAction Continue }
if ($analysisFailed) { Write-Error -Message $normalization.analysis.error -ErrorAction Continue }
$duration = $stopWatch.Elapsed.ToString("c")
# Metadata failures affect reporting only; the verified audio remains valid.
$outputSizeMB = 'N/A'
$outputBytes = $null
$metadataError = $null
try {
    if ($transaction.Published) {
        $outputFileItem = Get-Item -LiteralPath $outputFile -ErrorAction Stop
        $outputBytes = $outputFileItem.Length
        $outputSizeMB = "{0:N2} MB" -f ($outputBytes / 1MB)
    }
} catch {
    $metadataError = $_.Exception.Message
    Write-Warning ("Output size could not be read for the report: " + $metadataError)
}

# Settle owned-partial cleanup before recording the terminal processing outcome.
# Keep source and destination pinned until every report writer has closed.
$outputCleanupErrors = @(Complete-WacOutputTransaction -Transaction $transaction)
if ($outputCleanupErrors.Count -gt 0) {
    Write-Warning ($outputCleanupErrors -join ' ')
    if ($applicationExitCode -eq 0) { $applicationExitCode = 5 }
}
$reasonCodes = @()
if ($applicationExitCode -eq 130) { $reasonCodes += 'user_cancelled' }
if (-not $process.Started -and $applicationExitCode -ne 130) { $reasonCodes += 'native_start_failed' }
elseif ($process.Error -or $process.CleanupError -or $process.TimedOut -or $null -eq $process.ExitCode -or $process.ExitCode -ne 0) { $reasonCodes += 'native_processing_failed' }
if ($validationError) { $reasonCodes += 'output_validation_or_publication_failed' }
if ($analysisFailed) { $reasonCodes += 'loudness_analysis_failed' }
if ($outputCleanupErrors.Count -gt 0) { $reasonCodes += 'owned_output_cleanup_failed' }
$report = New-WacRunReport -Context @{
    Transaction = $transaction; ToolVersion = $scriptVersion; Process = $process
    ExitCode = $applicationExitCode; ReasonCodes = $reasonCodes
    StartedAt = $startedAt; ElapsedSeconds = $stopWatch.Elapsed.TotalSeconds
    Stream = $selectedStream; InputBytes = $inputFileItem.Length; OutputBytes = $outputBytes
    Mode = $Mode; ModeName = $modeName; Policy = $outputPolicy; Mono = $Mono
    Profile = $processingProfile; FilterChain = $filterChain; VerifiedAudio = $verifiedAudio
    LoudnessMode = $LoudnessMode; Normalization = $normalization; LoudnessWarnings = $loudnessWarnings; FinalLoudness = $finalLoudness
    FfmpegPath = $ffmpegPath; FfmpegVersion = $ffmpegVersion; FfprobePath = $ffprobePath; FfprobeVersion = $ffprobeVersion
    SpaceEstimate = $spaceEstimate; AvailableBytes = $availableBytes
    ValidationError = $validationError; CleanupErrors = $outputCleanupErrors; MetadataError = $metadataError
    ReportFolder = $reportFolder
}
$report.progress = [ordered]@{ stages = @(Get-WacProgressReport); completed = [bool]$transaction.Published
    cancellationRequested = $WacRunContext.IsCancellationRequested; cancellationStage = $WacRunContext.CancellationStage }
$reportDirectoryAvailable = $true
if ($null -ne $WacOutputLayout) {
    try { $report.output.organization = Get-WacOutputOrganization -Layout $WacOutputLayout }
    catch {
        $reportDirectoryAvailable = $false
        Add-WacReportFailure -Report $report -Code 'output_layout_unavailable' -Message $_.Exception.Message
        Write-Warning ('Report layout could not be verified: ' + $_.Exception.Message)
    }
}
if ($reportDirectoryAvailable) { Write-WacRunReports -Report $report -OutputFolder $reportFolder }
$applicationExitCode = $report.applicationExitCode
$status = $report.status

} finally {
    $cleanupErrors = @(Close-WacOutputTransaction -Transaction $transaction)
    if ($cleanupErrors.Count -gt 0) {
        Write-Warning ($cleanupErrors -join ' ')
        # Owned-output cleanup already settled the outcome before reporting.
        # Releasing read-only source/directory handles is a console advisory.
    }
}

# --- FEEDBACK ---
if ($status -eq "SUCCESS") {
    Write-Host "`nDONE: SUCCESS" -ForegroundColor Green
    Write-Host "Time Elapsed : $duration"
    Write-Host "Output Size  : $outputSizeMB"
    Write-Host "File saved to: $outputFile"
} elseif ($status -eq 'WARNING') {
    Write-Host "`nDONE: WARNING - Audio was published with loudness or reporting warnings." -ForegroundColor Yellow
    Write-Host ("Warnings: " + ($report.warningCodes -join ', '))
    Write-Host "File saved to: $outputFile"
} elseif ($status -eq 'CANCELLED') {
    Write-Host "`nDONE: CANCELLED" -ForegroundColor Yellow
    Write-Host 'Owned processing stopped; pending inputs were not started.'
} else {
    Write-Host "`nDONE: FAILED" -ForegroundColor Red
    Write-Host "Native exit: $nativeExitText. Application exit: $applicationExitCode. See diagnostics above."
}
$followUpDirectory = if ($null -ne $WacOutputLayout) { $WacOutputLayout.RootDirectory } else { $transaction.OutputFolder }
$followUpIdentity = if ($null -ne $WacOutputLayout) { $WacOutputLayout.Identities.Root } else { $transaction.OutputDirectoryIdentity }
Invoke-WacOutputFollowUp -Requested:$OpenOutputFolder -Interactive:$interactive -ExitCode $applicationExitCode -Published:([bool]$transaction.Published) -Directory $followUpDirectory -ExpectedDirectoryIdentity $followUpIdentity
exit $applicationExitCode

} finally {
    if ($ownsOutputLayout) {
        foreach ($message in @(Close-WacOutputLayout -Layout $WacOutputLayout)) { Write-Warning $message }
    }
    if ($script:WacProgressStages.Count -gt 0) { Write-WacProgress -State $script:WacProgressStages[$script:WacProgressStages.Count - 1] -Completed }
    if ($ownsRunContext) {
        try { $WacRunContext.Dispose() }
        catch { Write-Warning ('Console control release failed: ' + $_.Exception.Message) }
    }
}
