<#
WinAudioClean.ps1
Automated Audio Cleaning & Leveling Droplet

Author: Janne Vuorela
Target OS: Windows 10/11
PowerShell: Windows PowerShell 5.1 (built-in) or PowerShell 7+
Dependencies: FFmpeg.exe and ffprobe.exe (explicit paths, sibling or PATH), .bat wrapper for drag-and-drop

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
    2) Place these five files inside:
        - WinAudioClean.ps1
        - WinAudioClean.IO.ps1
        - WinAudioClean.bat
        - ffmpeg.exe (Download from gyan.dev or similar)
        - ffprobe.exe (from the same distribution)
    3) (Optional) Create a shortcut to the .bat file on your Desktop.

USAGE
    A) Drag-and-Drop (Recommended)
        - Drag an audio file (WAV, MP3, M4A, MKV, etc.) onto WinAudioClean.bat.
        - Follow the on-screen prompts.

    B) Direct PowerShell
        - Open PowerShell.
        - Run: .\WinAudioClean.ps1 -inputPath "C:\Path\To\Audio.wav"
        - Optional: -FfmpegPath/-FfprobePath for tool paths, -AudioStreamIndex for an absolute audio track index.

NOTES
    - The Noise Gate settings use linear math, not decibels. This conversion is handled internally.
    - The script forces the output format to .wav for maximum compatibility and quality preservation.
    - Processing speed depends on CPU power and file length.

LIMITATIONS
    - Requires FFmpeg and ffprobe. Multiple audio tracks require a choice; unattended use requires -AudioStreamIndex.
    - The "Highpass" filter is set to 80Hz. Deep baritone voices might prefer 60Hz, but 80Hz is the safe standard.
    - Extremely noisy audio requires AI tools, which are outside the scope of this script.

TROUBLESHOOTING
    - Dependency failure:
        Supply explicit -FfmpegPath/-FfprobePath, put both tools next to the script, or add them to PATH.
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
    [string]$FfmpegPath,
    [string]$FfprobePath,
    [string]$AudioStreamIndex,
    [switch]$NonInteractive
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
    param([string]$InputPath, [string]$OutputFolder, [string]$Timestamp,
        [ValidatePattern('^[a-fA-F0-9]{32}$')][string]$JobId = [guid]::NewGuid().ToString('N'))

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    [IO.Path]::Combine($OutputFolder, "$fileName`_Cleaned_$Timestamp`_$JobId.wav")
}

function Get-WacFfmpegArguments {
    param([string]$InputPath, [string]$FilterChain, [string]$OutputFile,
        [Parameter(Mandatory = $true)][ValidateRange(0, 2147483647)][int]$AudioStreamIndex)

    # Runtime passes only the exclusively created, held transaction partial.
    # -y lets FFmpeg fill that owned file; it never receives the final path.
    @('-nostdin') + (Get-WacLocalMediaArguments) + @('-i', $InputPath,
        '-map', ('0:' + $AudioStreamIndex.ToString([Globalization.CultureInfo]::InvariantCulture)), '-vn', '-af', $FilterChain, '-f', 'wav', $OutputFile,
        '-y', '-hide_banner', '-loglevel', 'error', '-stats')
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
        [Parameter(Mandatory = $true)]$OutputAudio)

    # Read the same object held against writes/deletion through publication.
    # Chunk lengths and frame alignment detect truncation that ffprobe can accept.
    if (-not $Stream.CanSeek -or $Stream.Length -lt 44) { throw 'Output WAV is empty or truncated.' }
    $reader = [IO.BinaryReader]::new($Stream, [Text.Encoding]::ASCII, $true)
    try {
        $Stream.Position = 0
        $signature = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        if ($signature -ne 'RIFF') { throw 'Output must be a RIFF WAV; RF64/large-file policy is not supported yet.' }
        $riffLength = [long]$reader.ReadUInt32() + 8
        if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ne 'WAVE' -or $riffLength -ne $Stream.Length) {
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
            $next = $Stream.Position + $length + ($length % 2)
            if ($next -gt $riffLength) { throw 'Output WAV chunk is truncated.' }
            if ($name -eq 'fmt ') {
                if ($null -ne $format -or $length -lt 16) { throw 'Invalid WAV format chunk.' }
                $tag = $reader.ReadUInt16()
                $channels = $reader.ReadUInt16()
                $rate = $reader.ReadUInt32()
                $byteRate = $reader.ReadUInt32()
                $align = $reader.ReadUInt16()
                $bits = $reader.ReadUInt16()
                if ($tag -eq 65534) {
                    if ($length -lt 40) { throw 'Invalid extensible WAV format.' }
                    $extraSize = $reader.ReadUInt16()
                    if ($extraSize -lt 22 -or $extraSize -gt ($length - 18)) { throw 'Invalid extensible WAV format length.' }
                    $validBits = $reader.ReadUInt16()
                    $null = $reader.ReadUInt32()
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
                $format = [pscustomobject]@{ Channels = [int]$channels; SampleRate = [int]$rate; BlockAlign = [int]$align; Bits = [int]$bits }
            } elseif ($name -eq 'data') {
                if ($seenData -or $length -eq 0) { throw 'Output WAV has empty or duplicate sample data.' }
                $seenData = $true
                $dataBytes = $length
            }
            $Stream.Position = $next
        }
        if ($null -eq $format -or -not $seenData -or $dataBytes % $format.BlockAlign -ne 0) {
            throw 'Output WAV has missing or incomplete PCM samples.'
        }
        $frames = $dataBytes / $format.BlockAlign
        $seconds = $frames / $format.SampleRate
        $expectedCodec = if ($format.Bits -eq 8) { 'pcm_u8' } else { 'pcm_s' + $format.Bits + 'le' }
        if ($OutputAudio.Codec -ne $expectedCodec -or $OutputAudio.Channels -ne $format.Channels -or
            $OutputAudio.SampleRate -ne $format.SampleRate -or $InputAudio.Channels -ne $format.Channels -or
            $null -eq $OutputAudio.DurationSeconds -or [math]::Abs($OutputAudio.DurationSeconds - $seconds) -gt 0.001) {
            throw 'Output probe and PCM samples disagree, or selected channel count changed.'
        }
        # PCM timing target is 10 ms; compressed headers may include codec padding.
        $tolerance = if ($InputAudio.Codec -like 'pcm_*') { 0.010 } else { 0.100 }
        if ($null -eq $InputAudio.DurationSeconds -or $InputAudio.DurationSeconds -le 0 -or
            [math]::Abs($InputAudio.DurationSeconds - $seconds) -gt ($tolerance + 0.000001)) {
            throw "Output duration $seconds s differs from selected input duration $($InputAudio.DurationSeconds) s (tolerance $tolerance s)."
        }
        [pscustomobject]@{ Frames = [long]$frames; DurationSeconds = $seconds; Channels = $format.Channels; SampleRate = $format.SampleRate; Bits = $format.Bits }
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
        try { $answer = Read-Host 'Audio stream index (Q to cancel)' }
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
$interactive = Test-WacInteractive -NonInteractive:$NonInteractive

# Validate before displaying the menu or starting any native process. Reading a
# file here proves accessibility; bounded media probing follows below.
try {
    $inputFileItem = Get-WacInputFile -Path $inputPath
    $inputPath = $inputFileItem.FullName
    if ($PSBoundParameters.ContainsKey('Mode') -and $Mode -notin @('Raw', 'Zoom')) {
        throw 'Invalid mode. Supply -Mode Raw or -Mode Zoom.'
    }
    if ($PSBoundParameters.ContainsKey('AudioStreamIndex')) {
        $parsedIndex = 0
        if ($AudioStreamIndex -notmatch '^[0-9]+$' -or -not [int]::TryParse($AudioStreamIndex, [ref]$parsedIndex)) {
            throw 'Audio stream index must be a nonnegative absolute stream index shown by ffprobe.'
        }
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
    $resolveArguments = @{ Name = 'ffmpeg.exe'; SiblingDirectory = $PSScriptRoot }
    if ($PSBoundParameters.ContainsKey('FfmpegPath')) { $resolveArguments.ExplicitPath = $FfmpegPath }
    $ffmpegPath = Resolve-WacExecutable @resolveArguments
    $resolveArguments = @{ Name = 'ffprobe.exe'; SiblingDirectory = [IO.Path]::GetDirectoryName($ffmpegPath) }
    if ($PSBoundParameters.ContainsKey('FfprobePath')) { $resolveArguments.ExplicitPath = $FfprobePath }
    $ffprobePath = Resolve-WacExecutable @resolveArguments
    $ffmpegVersion = Get-WacToolVersion -FilePath $ffmpegPath -ToolName ffmpeg
    $ffprobeVersion = Get-WacToolVersion -FilePath $ffprobePath -ToolName ffprobe
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
Write-Host "FFmpeg: $ffmpegPath ($ffmpegVersion)" -ForegroundColor Gray
Write-Host "FFprobe: $ffprobePath ($ffprobeVersion)" -ForegroundColor Gray

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

try { Test-WacRequiredFilters -FfmpegPath $ffmpegPath -FilterChain $filterChain }
catch {
    Write-Error -Message ("Dependency failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 3
}
$transaction = $null
$applicationExitCode = 0
try {
    $transaction = New-WacOutputTransaction -InputPath $inputPath -OutputFolder $outFolder
    $inputPath = $transaction.InputPath
    $outputFile = $transaction.FinalPath
    $logFile = [IO.Path]::Combine($transaction.OutputFolder, 'WinAudioClean_Log.txt')
} catch {
    Write-Error -Message ("Output allocation failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 5
}

# Hold the input and destination directory through probing, rendering and reporting.
try {
try { $audioStreams = @(Get-WacAudioStreams -FfprobePath $ffprobePath -InputPath $inputPath) }
catch {
    Write-Error -Message ("Probe failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 4
}
try {
    $selectionArguments = @{ Streams = $audioStreams; Interactive = $interactive }
    if ($PSBoundParameters.ContainsKey('AudioStreamIndex')) { $selectionArguments.RequestedIndex = $AudioStreamIndex }
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

$inputSizeMB = "{0:N2} MB" -f ($inputFileItem.Length / 1MB)

# --- EXECUTION ---
Write-Host "`nRunning WinAudioClean..." -ForegroundColor Cyan
Write-Host "Chain: $modeName" -ForegroundColor Gray

$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# FFmpeg Command
$argumentList = Get-WacFfmpegArguments -InputPath $inputPath -FilterChain $filterChain -OutputFile $transaction.TempPath -AudioStreamIndex $selectedStream.Index
$process = Invoke-WacNativeProcess -FilePath $ffmpegPath -ArgumentList $argumentList

$stopWatch.Stop()

# --- LOGGING ---
$applicationExitCode = 0
if (-not $process.Started) { $applicationExitCode = 3 }
elseif ($process.Error -or $process.CleanupError -or $process.TimedOut -or $null -eq $process.ExitCode -or $process.ExitCode -ne 0) { $applicationExitCode = 4 }
$validationError = $null
$verifiedAudio = $null
if ($applicationExitCode -eq 0) {
    try {
        $outputStreams = @(Get-WacAudioStreams -FfprobePath $ffprobePath -InputPath $transaction.TempPath)
        if ($outputStreams.Count -ne 1) { throw 'Output must contain exactly one readable audio stream.' }
        $validationStream = Freeze-WacOutputTransaction -Transaction $transaction
        $verifiedAudio = Assert-WacWaveOutput -Stream $validationStream -InputAudio $selectedStream -OutputAudio $outputStreams[0]
        Publish-WacOutputTransaction -Transaction $transaction
    } catch {
        $validationError = $_.Exception.Message
        $applicationExitCode = 5
        Write-Error -Message ("Output validation/publication failed: " + $validationError) -ErrorAction Continue
    }
}
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
# caller's ErrorActionPreference. Only a published file has report metadata.
$outputSizeMB = 'N/A'
$metadataError = $null
try {
    if ($transaction.Published) {
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
JOB ID         : $($transaction.JobId)
PARTIAL FILE   : $($transaction.TempPath)
PUBLISHED      : $($transaction.Published)
VERIFIED AUDIO : $($verifiedAudio.DurationSeconds) s; $($verifiedAudio.Frames) frames; $($verifiedAudio.SampleRate) Hz; $($verifiedAudio.Bits) bits

ACTIVE FILTERS : $filterChain
EXECUTABLE     : $ffmpegPath
FFMPEG VERSION : $ffmpegVersion
FFPROBE        : $ffprobePath
FFPROBE VERSION: $ffprobeVersion
AUDIO STREAM   : $($selectedStream.Index) (absolute index; map 0:$($selectedStream.Index))
INPUT AUDIO    : $($selectedStream.Codec); $($selectedStream.Channels) channel(s); $($selectedStream.SampleRate) Hz
INPUT DURATION : $($selectedStream.DurationSeconds) s (selected stream)
INPUT POLICY   : file protocol; WAV, MP3, FLAC, Ogg, MOV/MP4, Matroska/WebM, AAC, AIFF, ASF, AVI
PROCESS ERROR  : $($process.Error)
CLEANUP ERROR  : $($process.CleanupError)
REPORT ERROR   : $metadataError
OUTPUT ERROR   : $validationError
STANDARD OUTPUT:
$($process.StandardOutput)
STANDARD ERROR:
$($process.StandardError)
================================================================================
"@

# Write to Log
$reportGuard = $null
try {
    $reportGuard = Open-WacReportGuard -Path $logFile
    Add-Content -LiteralPath $reportGuard.Path -Value $logEntry -ErrorAction Stop
}
catch {
    # Reporting failure must neither hide native failure nor delete audio.
    Write-Warning ("Report could not be written: " + $_.Exception.Message)
    if ($applicationExitCode -eq 0) {
        $applicationExitCode = 7
        $status = 'WARNING'
    }
} finally {
    if ($null -ne $reportGuard) { Close-WacReportGuard -Guard $reportGuard }
}

} finally {
    $cleanupErrors = @(Close-WacOutputTransaction -Transaction $transaction)
    if ($cleanupErrors.Count -gt 0) {
        Write-Warning ($cleanupErrors -join ' ')
        if ($applicationExitCode -eq 0) { $applicationExitCode = 5; $status = 'FAILED' }
    }
}

# --- FEEDBACK ---
if ($status -eq "SUCCESS") {
    Write-Host "`nDONE: SUCCESS" -ForegroundColor Green
    Write-Host "Time Elapsed : $duration"
    Write-Host "Output Size  : $outputSizeMB"
    Write-Host "File saved to: $outputFile"
} elseif ($status -eq 'WARNING') {
    Write-Host "`nDONE: WARNING - Audio was published, but reporting was incomplete." -ForegroundColor Yellow
    Write-Host "File saved to: $outputFile"
} else {
    Write-Host "`nDONE: FAILED" -ForegroundColor Red
    Write-Host "Native exit: $nativeExitText. Application exit: $applicationExitCode. See diagnostics above."
}
exit $applicationExitCode
