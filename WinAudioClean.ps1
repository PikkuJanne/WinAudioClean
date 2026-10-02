<#
WinAudioClean.ps1
Automated Audio Cleaning & Leveling Droplet

Author: Janne Vuorela
Target OS: Windows 10/11
PowerShell: Windows PowerShell 5.1 (built-in) or PowerShell 7+
Dependencies: FFmpeg.exe (must be in the same folder), .bat wrapper for drag-and-drop

SYNOPSIS
    A "drop-and-forget" audio post-production tool.
    Takes a raw audio file, cleans it using physics-based signal processing (De-clip/De-click/Denoise),
    and levels it to broadcast standards (-12dB RMS) using a loudness chain.

WHAT THIS IS (AND ISN'T)
    - A codified version of a specific Adobe Audition "Speech Volume Leveler" workflow.
    - Designed to be a robust "black box" that just works for 95% of spoken word audio.
    - Favors consistency over granular control.
    - Not an AI-based voice isolator.
    - Not a multi-track editor, it processes single mixed files.

FEATURES
    - Text User Interface (TUI):
        Simple prompt asking if the source is a "Raw Recording" or "Zoom/Teams" meeting.
        Prevents over-processing of audio that is already noise-cancelled by VoIP software.
    - Robust Cleaning Chain (Mode 1):
        1. De-Clipper: Reconstructs peaks damaged by digital distortion.
        2. Highpass Filter (80Hz): Removes AC hum, traffic rumble, and desk thumps.
        3. De-Clicker: Smooths out mouth noises and lip smacks.
        4. FFT Denoiser: Profiling-free noise reduction for steady background hiss.
        5. Noise Gate: Silences breath and room tone between speech (Linear scale).
    - Broadcast Leveling (Mode 1 & 2):
        Uses Dynamic Audio Normalizer (dynaudnorm) to chase peaks and boost quiet sections (85% leveling).
        Finishes with a Loudness Limiter (loudnorm) targeting exactly -12 LUFS/dB.
    - Report Logging:
        Generates a verbose log file in the Music folder.
        Tracks input/output file sizes, duration, and the exact FFmpeg filter chain used for every run.
    - Non-Destructive:
        Never overwrites the original. Saves a new file with a timestamp and "_Cleaned" suffix.

MY INTENDED USAGE
    - I keep WinAudioClean shortcut on my Desktop.
    - When I finish a voice recording or download a Zoom meeting:
        1. I drag the audio file onto the shortcut (.bat) file.
        2. I type "1" for raw mic audio or "2" for a meeting.
        3. I wait for the green "SUCCESS" text.
        4. I find the polished file in my Music folder, ready for upload.

SETUP
    1) Create a folder (e.g., C:\Tools\WinAudioClean\).
    2) Place these three files inside:
        - WinAudioClean.ps1
        - WinAudioClean.bat
        - ffmpeg.exe (Download from gyan.dev or similar)
    3) (Optional) Create a shortcut to the .bat file on your Desktop.

USAGE
    A) Drag-and-Drop (Recommended)
        - Drag an audio file (WAV, MP3, M4A, MKV, etc.) onto WinAudioClean.bat.
        - Follow the on-screen prompts.

    B) Direct PowerShell
        - Open PowerShell.
        - Run: .\WinAudioClean.ps1 -inputPath "C:\Path\To\Audio.wav"

NOTES
    - The Noise Gate settings use linear math, not decibels. This conversion is handled internally.
    - The script forces the output format to .wav for maximum compatibility and quality preservation.
    - Processing speed depends on CPU power and file length.

LIMITATIONS
    - Requires FFmpeg to be present, cannot run without it.
    - The "Highpass" filter is set to 80Hz. Deep baritone voices might prefer 60Hz, but 80Hz is the safe standard.
    - Extremely noisy audio requires AI tools, which are outside the scope of this script.

TROUBLESHOOTING
    - "FFmpeg.exe not found!":
        The script cannot see ffmpeg.exe. Ensure it is in the exact same folder as the .ps1 script.
    - Red "FAILED" text:
        Check the console output immediately above the failure message. FFmpeg usually prints the specific reason (e.g., corrupt input file).

LICENSE / WARRANTY
    - Personal automation tool, provided as-is.
    - Logic based on standard audio engineering practices.
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)][string]$inputPath,
    [string]$Mode,
    [string]$OutputDirectory = [Environment]::GetFolderPath('MyMusic'),
    [switch]$NonInteractive
)

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
    param([string]$Path)

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

function Read-WacMode {
    while ($true) {
        try { $choice = Read-Host "`nEnter selection (1 or 2; Q to cancel)" }
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

function Get-WacProcessingProfile {
    param([string]$Choice)

    $cleanFilters = "adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056"
    $levelFilters = "dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5"

    if ($Choice -eq '1') {
        [pscustomobject]@{ ModeName = 'RAW (Clean+Level)'; FilterChain = "$cleanFilters,$levelFilters" }
    } elseif ($Choice -eq '2') {
        [pscustomobject]@{ ModeName = 'ZOOM (Level Only)'; FilterChain = $levelFilters }
    } else {
        throw 'Invalid processing choice. Expected 1 (Raw) or 2 (Zoom).'
    }
}

function Get-WacOutputPath {
    param([string]$InputPath, [string]$OutputFolder, [string]$Timestamp)

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    "$OutputFolder\$fileName`_Cleaned_$Timestamp.wav"
}

function Get-WacFfmpegArguments {
    param([string]$InputPath, [string]$FilterChain, [string]$OutputFile)

    # Preserve filters/encoding and -y until the export-safety task. The native
    # wrapper quotes each argument; no path is interpolated into shell code.
    @('-nostdin', '-i', $InputPath, '-vn', '-af', $FilterChain, $OutputFile,
        '-y', '-hide_banner', '-loglevel', 'error', '-stats')
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

function Invoke-WacNativeProcess {
    param(
        [string]$FilePath,
        [AllowEmptyCollection()][string[]]$ArgumentList = @(),
        [ValidateRange(0, 2147483647)][int]$TimeoutMilliseconds = 0,
        [ValidateRange(1, 60000)][int]$StreamCloseTimeoutMilliseconds = 5000
    )

    $result = [pscustomobject]@{
        Started = $false; ExitCode = $null; StandardOutput = ''; StandardError = ''
        Error = $null; TimedOut = $false; CleanupError = $null
    }
    $process = $null
    $stdoutReader = $null
    $stderrReader = $null
    $stdinWriter = $null
    $stdoutTask = $null
    $stderrTask = $null
    try {
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
        $result.Started = $process.Start()
        if (-not $result.Started) { throw 'The native process did not start.' }
        # Both readers start before waiting, so neither full pipe can block the
        # child. No script callbacks or PowerShell runspace are needed to drain.
        $stdoutReader = $process.StandardOutput
        $stderrReader = $process.StandardError
        $stdinWriter = $process.StandardInput
        $stdoutTask = $stdoutReader.ReadToEndAsync()
        $stderrTask = $stderrReader.ReadToEndAsync()
        $stdinWriter.Close()
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(100)) {
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
        $readers = [System.Threading.Tasks.Task[]]@($stdoutTask, $stderrTask)
        if (-not [System.Threading.Tasks.Task]::WaitAll($readers, $StreamCloseTimeoutMilliseconds)) {
            throw "Native output streams did not close within $StreamCloseTimeoutMilliseconds ms."
        }
        $result.StandardOutput = $stdoutTask.Result
        $result.StandardError = $stderrTask.Result
    } catch {
        if (-not $result.Error) { $result.Error = $_.Exception.Message }
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
            if ($null -ne $stdoutTask -and $stdoutTask.Status -eq 'RanToCompletion') { $result.StandardOutput = $stdoutTask.Result }
            if ($null -ne $stderrTask -and $stderrTask.Status -eq 'RanToCompletion') { $result.StandardError = $stderrTask.Result }
            # Process.Dispose does not own readers accessed through these
            # properties. Dispose them explicitly, including incomplete reads.
            foreach ($stream in @($stdinWriter, $stdoutReader, $stderrReader)) {
                if ($null -ne $stream) {
                    try { $stream.Dispose() }
                    catch { $result.CleanupError = $_.Exception.Message }
                }
            }
            try { $process.Dispose() }
            catch { $result.CleanupError = $_.Exception.Message }
        }
    }
    $result
}

# Dot-sourcing exposes only helpers. Normal -File, &, and .bat calls still run below.
if ($MyInvocation.InvocationName -eq '.') { return }

# --- CONFIGURATION ---
$scriptVersion = "2.3"
$ffmpegPath = "$PSScriptRoot\ffmpeg.exe"
$interactive = Test-WacInteractive -NonInteractive:$NonInteractive

# Validate before displaying the menu or starting any native process. Reading a
# file here proves accessibility only; media probing belongs to the probe task.
try {
    $inputFileItem = Get-WacInputFile -Path $inputPath
    $inputPath = $inputFileItem.FullName
    if ($PSBoundParameters.ContainsKey('Mode') -and $Mode -notin @('Raw', 'Zoom')) {
        throw 'Invalid mode. Supply -Mode Raw or -Mode Zoom.'
    }
    $outFolder = Get-WacOutputDirectory -Path $OutputDirectory
    if (-not $Mode -and -not $interactive) {
        throw 'A mode is required for unattended use. Supply -Mode Raw or -Mode Zoom with -NonInteractive.'
    }
} catch {
    Write-Error -Message ("Preflight failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 2
}
try {
    if (Test-Path -LiteralPath $ffmpegPath -PathType Leaf) {
        $ffmpegPath = (Get-Item -LiteralPath $ffmpegPath -ErrorAction Stop).FullName
    } else {
        $ffmpegCommand = Get-Command 'ffmpeg.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $ffmpegCommand) { throw 'FFmpeg.exe not found! Put it next to this script or on PATH.' }
        $ffmpegPath = $ffmpegCommand.Source
    }
} catch {
    Write-Error -Message ("Dependency failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 3
}
$logFile = "$outFolder\WinAudioClean_Log.txt"

# --- TUI: HEADER ---
if ($interactive) { Clear-Host }
Write-Host "WinAudioClean $scriptVersion" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Gray
Write-Host "Input: " -NoNewline; Write-Host $inputPath -ForegroundColor Yellow

# --- TUI: SELECTION ---
if (-not $Mode) {
    Write-Host "`nSelect Processing Mode:" -ForegroundColor White
    Write-Host "[1] RAW RECORDING (Clean + Level)" -ForegroundColor Green
    Write-Host "    -> Use for mic recordings. Removes hiss, rumble, clicks, and levels volume."
    Write-Host "[2] ZOOM/TEAMS (Level Only)" -ForegroundColor Magenta
    Write-Host "    -> Use for meeting audio. Preserves existing noise cancellation."
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
$choice = if ($Mode -eq 'Raw') { '1' } else { '2' }
$processingProfile = Get-WacProcessingProfile -Choice $choice
$modeName = $processingProfile.ModeName
$filterChain = $processingProfile.FilterChain

$inputSizeMB = "{0:N2} MB" -f ($inputFileItem.Length / 1MB)

$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$outputFile = Get-WacOutputPath -InputPath $inputPath -OutputFolder $outFolder -Timestamp $timestamp

# --- EXECUTION ---
Write-Host "`nRunning WinAudioClean..." -ForegroundColor Cyan
Write-Host "Chain: $modeName" -ForegroundColor Gray

$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# FFmpeg Command
$argumentList = Get-WacFfmpegArguments -InputPath $inputPath -FilterChain $filterChain -OutputFile $outputFile
$process = Invoke-WacNativeProcess -FilePath $ffmpegPath -ArgumentList $argumentList

$stopWatch.Stop()

# --- LOGGING ---
$applicationExitCode = 0
if (-not $process.Started) { $applicationExitCode = 3 }
elseif ($process.Error -or $process.CleanupError -or $process.ExitCode -ne 0) { $applicationExitCode = 4 }
$status = if ($applicationExitCode -eq 0) { 'SUCCESS' } else { 'FAILED' }
$nativeExitText = if ($null -eq $process.ExitCode) { 'not started' } else { [string]$process.ExitCode }
# Keep separate diagnostics even when the child returns a failure code.
if ($process.StandardOutput) { Write-Host $process.StandardOutput }
if ($process.StandardError) { Write-Host $process.StandardError -ForegroundColor Gray }
if ($process.Error) { Write-Error -Message $process.Error -ErrorAction Continue }
if ($process.CleanupError) { Write-Error -Message ("Native cleanup failed: " + $process.CleanupError) -ErrorAction Continue }
$duration = $stopWatch.Elapsed.ToString("mm\:ss\.ff")
$logDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Failure to read report metadata must have the same result under either
# caller's ErrorActionPreference. Complete output validation belongs to M1-04.
$outputSizeMB = 'N/A'
$metadataError = $null
try {
    if (Test-Path -LiteralPath $outputFile -ErrorAction Stop) {
        $outputFileItem = Get-Item -LiteralPath $outputFile -ErrorAction Stop
        $outputSizeMB = "{0:N2} MB" -f ($outputFileItem.Length / 1MB)
    }
} catch {
    $metadataError = $_.Exception.Message
    Write-Warning ("Output size could not be read for the report: " + $metadataError)
    if ($applicationExitCode -eq 0) { $applicationExitCode = 7; $status = 'WARNING' }
}

# Construct Verbose Log Entry
$logEntry = @"
================================================================================
LOG DATE       : $logDate
--------------------------------------------------------------------------------
STATUS         : $status (Native Exit Code: $nativeExitText; Application Exit Code: $applicationExitCode)
MODE           : $modeName
DURATION       : $duration

INPUT FILE     : $inputPath
INPUT SIZE     : $inputSizeMB
OUTPUT FILE    : $outputFile
OUTPUT SIZE    : $outputSizeMB

ACTIVE FILTERS : $filterChain
EXECUTABLE     : $ffmpegPath
PROCESS ERROR  : $($process.Error)
CLEANUP ERROR  : $($process.CleanupError)
REPORT ERROR   : $metadataError
STANDARD OUTPUT:
$($process.StandardOutput)
STANDARD ERROR:
$($process.StandardError)
================================================================================
"@

# Write to Log
try { Add-Content -LiteralPath $logFile -Value $logEntry -ErrorAction Stop }
catch {
    # Reporting failure must neither hide native failure nor delete audio.
    Write-Warning ("Report could not be written: " + $_.Exception.Message)
    if ($applicationExitCode -eq 0) {
        $applicationExitCode = 7
        $status = 'WARNING'
    }
}

# --- FEEDBACK ---
if ($status -eq "SUCCESS") {
    Write-Host "`nDONE: SUCCESS" -ForegroundColor Green
    Write-Host "Time Elapsed : $duration"
    Write-Host "Output Size  : $outputSizeMB"
    Write-Host "File saved to: $outputFile"
} elseif ($status -eq 'WARNING') {
    Write-Host "`nDONE: WARNING - FFmpeg completed, but reporting was incomplete." -ForegroundColor Yellow
    Write-Host "Requested output: $outputFile"
} else {
    Write-Host "`nDONE: FAILED" -ForegroundColor Red
    Write-Host "Native exit: $nativeExitText. Application exit: $applicationExitCode. See diagnostics above."
}
exit $applicationExitCode
