# Optional excerpt workflow. Importing defines helpers only. Main/IO helpers
# are supplied by the original entry point or explicitly imported in tests.
function ConvertTo-WacPreviewSeconds {
    param([string]$Value, [ValidateSet('Start', 'Duration')][string]$Name)
    $number = 0.0
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt 64 -or
        $Value -cnotmatch '\A[0-9]+(?:\.[0-9]+)?\z' -or
        -not [double]::TryParse($Value, [Globalization.NumberStyles]::AllowDecimalPoint,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$number) -or
        [double]::IsNaN($number) -or [double]::IsInfinity($number) -or
        ($Name -eq 'Start' -and ($number -lt 0 -or $number -ge 1000000000)) -or
        ($Name -eq 'Duration' -and ($number -le 0 -or $number -gt 60))) {
        throw 'Preview requires invariant decimal seconds: start >= 0 and duration > 0 through 60.'
    }
    $number
}

function Get-WacPreviewRange {
    param([double]$InputDurationSeconds, [string]$Start = '0',
        [string]$Duration = '45', [bool]$DurationExplicit = $false)
    if ([double]::IsNaN($InputDurationSeconds) -or [double]::IsInfinity($InputDurationSeconds) -or
        $InputDurationSeconds -le 0 -or $InputDurationSeconds -gt 1000000000) {
        throw 'Selected audio duration is unavailable or outside the supported preview range.'
    }
    $startValue = ConvertTo-WacPreviewSeconds -Value $Start -Name Start
    $durationValue = ConvertTo-WacPreviewSeconds -Value $Duration -Name Duration
    if ($startValue -ge $InputDurationSeconds) { throw 'Preview start must be before the selected audio ends.' }
    $remaining = $InputDurationSeconds - $startValue
    if ($DurationExplicit -and $durationValue -gt ($remaining + 0.000000001)) {
        throw 'Explicit preview duration extends beyond the selected audio.'
    }
    $requestedDuration = $durationValue
    $durationValue = [math]::Min($durationValue, $remaining)
    $totalSamples = [long][math]::Round($InputDurationSeconds * 48000, 0, [MidpointRounding]::AwayFromZero)
    $startSamples = [long][math]::Round($startValue * 48000, 0, [MidpointRounding]::AwayFromZero)
    $samples = [long][math]::Round($durationValue * 48000, 0, [MidpointRounding]::AwayFromZero)
    $samples = [long][math]::Min($samples, ($totalSamples - $startSamples))
    if ($samples -le 0 -or $startSamples -ge $totalSamples) { throw 'Preview range is shorter than one output sample.' }
    $windowStart = [math]::Max([long]0, [long]($startSamples - 240000))
    $windowEnd = [long][math]::Min($totalSamples, ($startSamples + $samples + 240000))
    $trimStart = $startSamples - $windowStart
    [pscustomobject]@{
        StartSeconds = $startSamples / 48000.0; DurationSeconds = $samples / 48000.0
        StartSamples = $startSamples; DurationSamples = $samples
        WindowStartSeconds = $windowStart / 48000.0; WindowDurationSeconds = ($windowEnd - $windowStart) / 48000.0
        TrimStartSamples = $trimStart; TrimEndSamples = ($trimStart + $samples)
        PreRollSeconds = $trimStart / 48000.0; PostRollSeconds = ($windowEnd - $startSamples - $samples) / 48000.0
        RequestedStartSeconds = $startValue; RequestedDurationSeconds = $requestedDuration
        DurationExplicit = $DurationExplicit; DefaultDurationClipped = (-not $DurationExplicit -and $durationValue -lt $requestedDuration)
    }
}

function Test-WacPreviewNumber {
    param($Value)
    ($Value -is [double] -or $Value -is [single] -or $Value -is [int] -or
        $Value -is [long] -or $Value -is [decimal]) -and
        -not [double]::IsNaN([double]$Value) -and -not [double]::IsInfinity([double]$Value)
}

function Get-WacPreviewMatchPlan {
    param([Parameter(Mandatory = $true)]$OriginalMeasurement,
        [Parameter(Mandatory = $true)]$ProcessedMeasurement)
    $measurements = @($OriginalMeasurement, $ProcessedMeasurement)
    foreach ($measurement in $measurements) {
        if ($measurement.Available -isnot [bool]) { throw 'Preview measurement availability must be Boolean.' }
        if ($null -ne $measurement.InputTP -and -not (Test-WacPreviewNumber $measurement.InputTP)) {
            throw 'Preview true peak must be a finite numeric value or null.'
        }
        if ($measurement.Available -and
            (-not (Test-WacPreviewNumber $measurement.InputI) -or -not (Test-WacPreviewNumber $measurement.InputTP))) {
            throw 'Available preview measurements require finite integrated loudness and true peak.'
        }
        if (-not $measurement.Available -and $measurement.Reason -cnotin @('too_short', 'silence', 'undefined_loudness')) {
            throw 'Unsupported unavailable preview measurement reason.'
        }
    }
    $available = $OriginalMeasurement.Available -and $ProcessedMeasurement.Available
    $target = $null; $reason = $null
    if ($available) {
        $target = (@($OriginalMeasurement.InputI, $ProcessedMeasurement.InputI,
            ($OriginalMeasurement.InputI - $OriginalMeasurement.InputTP - 1.7),
            ($ProcessedMeasurement.InputI - $ProcessedMeasurement.InputTP - 1.7)) | Measure-Object -Minimum).Minimum
        $originalGain = [math]::Min(0.0, ($target - $OriginalMeasurement.InputI))
        $processedGain = [math]::Min(0.0, ($target - $ProcessedMeasurement.InputI))
    } else {
        foreach ($candidate in @('too_short', 'silence', 'undefined_loudness')) {
            if (@($measurements | Where-Object { $_.Reason -ceq $candidate }).Count -gt 0) { $reason = $candidate; break }
        }
        $originalGain = if ($null -eq $OriginalMeasurement.InputTP) { 0.0 } else {
            [math]::Min(0.0, (-1.7 - $OriginalMeasurement.InputTP))
        }
        $processedGain = if ($null -eq $ProcessedMeasurement.InputTP) { 0.0 } else {
            [math]::Min(0.0, (-1.7 - $ProcessedMeasurement.InputTP))
        }
    }
    [pscustomobject]@{
        Available = [bool]$available; Reason = $reason; CommonTargetLufs = $target
        OriginalGainDb = [double]$originalGain; ProcessedGainDb = [double]$processedGain
        PeakCeilingDbtp = -1.5; HeadroomTargetDbtp = -1.7
    }
}

function ConvertTo-WacPreviewTimestamp {
    param($Value)
    $number = 0.0
    if ($Value -isnot [string] -or $Value.Length -gt 64 -or
        $Value -cnotmatch '\A-?[0-9]+(?:\.[0-9]+)?\z' -or
        -not [double]::TryParse($Value, [Globalization.NumberStyles]::AllowLeadingSign -bor [Globalization.NumberStyles]::AllowDecimalPoint,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$number) -or
        [double]::IsNaN($number) -or [double]::IsInfinity($number) -or [math]::Abs($number) -gt 1000000000) {
        throw 'Unsupported preview timeline: timestamp must be a finite bounded decimal value.'
    }
    $number
}

function Get-WacPreviewTimeline {
    param([string]$FfprobePath, [string]$InputPath, [int]$AudioStreamIndex)
    $arguments = @('-v', 'error') + (Get-WacLocalMediaArguments) + @('-show_entries',
        'stream=index,start_time,time_base,sample_rate:format=start_time,format_name', '-of', 'json', '-i', $InputPath)
    $process = Invoke-WacNativeProcess -FilePath $FfprobePath -ArgumentList $arguments -TimeoutMilliseconds 15000
    Assert-WacPreviewProcess -Process $process
    if ([string]::IsNullOrWhiteSpace($process.StandardOutput) -or
        [Text.Encoding]::UTF8.GetByteCount($process.StandardOutput) -gt 1MB -or
        -not $process.StandardOutput.TrimStart().StartsWith('{')) { throw 'Invalid preview timeline metadata.' }
    try { $metadata = ConvertFrom-Json -InputObject $process.StandardOutput -ErrorAction Stop }
    catch { throw 'Invalid preview timeline JSON.' }
    if ($null -eq $metadata -or $metadata.streams -isnot [Array] -or $metadata.streams.Count -gt 256) {
        throw 'Invalid preview timeline streams array.'
    }
    $seen = @{}; $selected = $null
    foreach ($stream in $metadata.streams) {
        if ($null -eq $stream -or ($stream.index -isnot [int] -and $stream.index -isnot [long]) -or
            $stream.index -lt 0 -or $stream.index -gt [int]::MaxValue -or $seen.ContainsKey([string]$stream.index)) {
            throw 'Invalid preview timeline stream index.'
        }
        $seen[[string]$stream.index] = $true
        if ($stream.index -eq $AudioStreamIndex) { $selected = $stream }
    }
    if ($null -eq $selected) { throw 'Selected preview stream is absent from timeline metadata.' }
    $formatStart = $null
    if ($null -ne $metadata.format.start_time) { $formatStart = ConvertTo-WacPreviewTimestamp -Value $metadata.format.start_time }
    $reason = 'stream_start_time'
    if ($null -ne $selected.start_time) { $streamStart = ConvertTo-WacPreviewTimestamp -Value $selected.start_time }
    elseif ($metadata.format.format_name -ceq 'wav') {
        # RIFF/RF64 WAV carries ordered samples, not a presentation timestamp.
        # Sample zero defines its origin; other missing origins fail closed.
        $streamStart = 0.0; $reason = 'wave_sample_zero_origin'
    } else { throw 'Unsupported preview timeline: selected stream has no start timestamp.' }
    if ($streamStart -lt 0) { throw 'Unsupported preview timeline: negative stream origins require a separately verified seek policy.' }
    $sampleRate = 0
    if ($selected.sample_rate -isnot [string] -or $selected.sample_rate -cnotmatch '\A[0-9]{1,10}\z' -or
        -not [int]::TryParse($selected.sample_rate, [ref]$sampleRate) -or $sampleRate -le 0) {
        throw 'Unsupported preview timeline: selected stream sample rate is unavailable or invalid.'
    }
    $timeBase = $selected.time_base; $resolutionReason = 'stream_time_base'
    if ($null -eq $timeBase -and $metadata.format.format_name -ceq 'wav') {
        $resolution = 1.0 / $sampleRate; $resolutionReason = 'wave_sample_rate_resolution'
    } else {
        $numerator = 0; $denominator = 0
        if ($timeBase -isnot [string] -or $timeBase -cnotmatch '\A([0-9]{1,10})/([0-9]{1,10})\z' -or
            -not [int]::TryParse($Matches[1], [ref]$numerator) -or
            -not [int]::TryParse($Matches[2], [ref]$denominator) -or $numerator -le 0 -or $denominator -le 0) {
            throw 'Unsupported preview timeline: timestamp resolution is unavailable or invalid.'
        }
        $resolution = [double]$numerator / $denominator
    }
    # Container packet timestamps can round the sample chosen by an accurate
    # seek. Disclose one clock tick plus one output sample; never compensate
    # from a guessed packet grid, and reject uncertainty above 10 milliseconds.
    $seekTolerance = [math]::Ceiling(48000.0 * $resolution) + 1.0
    if ($seekTolerance -gt 480.0) { throw 'Unsupported preview timeline: seek uncertainty exceeds 10 milliseconds.' }
    [pscustomobject]@{ StreamIndex = $AudioStreamIndex; StreamStartSeconds = $streamStart
        FormatStartSeconds = $formatStart; OriginReason = $reason; SampleRate = $sampleRate; TimeBase = $timeBase
        TimestampResolutionSeconds = $resolution; SeekToleranceSamples = [int]$seekTolerance
        SeekToleranceSeconds = ($seekTolerance / 48000.0); ResolutionReason = $resolutionReason }
}

function Add-WacPreviewWindowArguments {
    param([string[]]$Arguments, [Parameter(Mandatory = $true)]$Range, $Timeline)
    $inputIndex = [array]::IndexOf($Arguments, '-i')
    if ($inputIndex -lt 1 -or $Arguments -contains '-ss' -or $Arguments -contains '-t' -or $Arguments -contains '-seek_timestamp') { throw 'Preview requires one unbounded file input to restrict.' }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $origin = if ($null -eq $Timeline) { 0.0 } else { $Timeline.StreamStartSeconds }
    if (-not (Test-WacPreviewNumber $origin) -or $origin -lt 0 -or $origin -gt 1000000000) { throw 'Unsupported preview timeline origin.' }
    $absoluteSeek = [double]$origin + $Range.WindowStartSeconds
    @($Arguments[0..($inputIndex - 1)]) + @('-seek_timestamp', '1', '-ss', $absoluteSeek.ToString('0.###############', $culture),
        '-t', $Range.WindowDurationSeconds.ToString('0.###############', $culture)) + @($Arguments[$inputIndex..($Arguments.Count - 1)])
}

function Get-WacPreviewTrimFilter {
    param([Parameter(Mandatory = $true)]$Range)
    $culture = [Globalization.CultureInfo]::InvariantCulture
    'aresample=48000,atrim=start_sample=' + $Range.TrimStartSamples.ToString($culture) +
        ':end_sample=' + $Range.TrimEndSamples.ToString($culture) + ',asetpts=PTS-STARTPTS'
}

function Get-WacPreviewRenderArguments {
    param([string]$InputPath, [Parameter(Mandatory = $true)][string]$FilterChain,
        [Parameter(Mandatory = $true)][string]$OutputFile, [int]$AudioStreamIndex = 0,
        [Parameter(Mandatory = $true)]$OutputPolicy, $Range, $Timeline, [switch]$FromPipe)
    if ($FromPipe) {
        $arguments = @('-nostdin', '-protocol_whitelist', 'pipe', '-format_whitelist', 'wav', '-f', 'wav', '-i', 'pipe:0',
            '-map', '0:0', '-vn', '-af', $FilterChain)
    } else {
        $arguments = @('-nostdin') + (Get-WacLocalMediaArguments) + @('-i', $InputPath,
            '-map', ('0:' + $AudioStreamIndex.ToString([Globalization.CultureInfo]::InvariantCulture)), '-vn', '-af', $FilterChain)
        $arguments = Add-WacPreviewWindowArguments -Arguments $arguments -Range $Range -Timeline $Timeline
    }
    $arguments + @('-ar', '48000', '-c:a', $OutputPolicy.Codec, '-ac', [string]$OutputPolicy.Channels,
        '-channel_layout', $OutputPolicy.Layout, '-map_metadata', '-1', '-map_chapters', '-1',
        '-f', 'wav', '-rf64', $(if ($OutputPolicy.Rf64) { 'always' } else { 'never' }),
        $OutputFile, '-y', '-hide_banner', '-loglevel', 'info', '-nostats')
}

function Get-WacPreviewSpaceEstimate {
    param([Parameter(Mandatory = $true)]$Range, [Parameter(Mandatory = $true)]$OutputPolicy)
    $single = Get-WacOutputSpaceEstimate -DurationSeconds $Range.DurationSeconds -OutputPolicy $OutputPolicy
    $fileBytes = [long]($single.FileBytes * 4)
    $reserveBytes = [long][math]::Max([double]64MB, [math]::Ceiling($fileBytes * 0.1))
    [pscustomobject]@{ AssetCount = 4; AssetFileBytes = $single.FileBytes; FileBytes = $fileBytes
        ReserveBytes = $reserveBytes; RequiredBytes = ($fileBytes + $reserveBytes) }
}

function Assert-WacPreviewProcess {
    param([Parameter(Mandatory = $true)]$Process)
    if (($Process.PSObject.Properties['Cancelled'] -and $Process.Cancelled) -or
        ($null -ne $script:WacRunContext -and $script:WacRunContext.IsCancellationRequested)) {
        $exception = New-Object IO.IOException 'Preview processing cancelled.'
        $exception.Data['WacExitCode'] = 130
        throw $exception
    }
    if (-not $Process.Started) {
        $exception = New-Object IO.IOException 'Preview dependency could not start.'
        $exception.Data['WacExitCode'] = 3
        throw $exception
    }
    if ($Process.Error -or $Process.CleanupError -or $Process.TimedOut -or
        $null -eq $Process.ExitCode -or $Process.ExitCode -ne 0) {
        $nativeExit = if ($null -eq $Process.ExitCode) { 'unavailable' } else { [string]$Process.ExitCode }
        $message = 'Preview native processing failed (native exit ' + $nativeExit + '; timeout ' +
            [string][bool]$Process.TimedOut + '; transport error reported ' + [string][bool]$Process.Error +
            '; cleanup error reported ' + [string][bool]$Process.CleanupError + ').'
        $exception = New-Object IO.IOException $message
        $exception.Data['WacExitCode'] = 4
        throw $exception
    }
}

function Get-WacPreviewAssetMeasurement {
    param([Parameter(Mandatory = $true)]$Transaction,
        [Parameter(Mandatory = $true)]$InputAudio, [Parameter(Mandatory = $true)]$OutputPolicy,
        [string]$FfmpegPath, [string]$FfprobePath, [int]$TimeoutMilliseconds = 120000,
        [string]$ProgressLabel = 'Preview measurement', [int]$ProgressStart = 0, [int]$ProgressEnd = 95)
    $null = Add-WacProgressStage -Stage 'Preview validating' -StartPercent $ProgressStart -EndPercent $ProgressStart
    $outputs = @(Get-WacAudioStreams -FfprobePath $FfprobePath -InputPath $Transaction.TempPath)
    if ($outputs.Count -ne 1) { throw 'Preview output must contain one audio stream.' }
    $held = Freeze-WacOutputTransaction -Transaction $Transaction
    $verified = Assert-WacWaveOutput -Stream $held -InputAudio $InputAudio -OutputAudio $outputs[0] -OutputPolicy $OutputPolicy
    $arguments = Get-WacLoudnessArguments -FilterChain 'loudnorm=I=-12:TP=-1.5:LRA=7:print_format=json' -OutputPolicy $OutputPolicy -FromPipe
    $held.Position = 0
    $arguments = Get-WacProgressArguments -ArgumentList $arguments
    $progressState = Add-WacProgressStage -Stage $ProgressLabel -DurationSeconds $verified.DurationSeconds -StartPercent $ProgressStart -EndPercent $ProgressEnd
    $process = Invoke-WacNativeProcess -FilePath $FfmpegPath -ArgumentList $arguments -StandardInputStream $held -TimeoutMilliseconds $TimeoutMilliseconds -ProgressState $progressState
    Assert-WacPreviewProcess -Process $process
    $stage = ConvertTo-WacLoudnessStage -Process $process -DurationSeconds $verified.DurationSeconds -Arguments $arguments -InputSource 'held_output_stream'
    if ($stage.status -ne 'PASSED') {
        $exception = New-Object IO.IOException 'Preview encoded-file measurement could not be parsed.'
        $exception.Data['WacExitCode'] = 4
        throw $exception
    }
    if ($verified.Frames -ne [long][math]::Round($InputAudio.DurationSeconds * 48000, 0, [MidpointRounding]::AwayFromZero)) {
        throw 'Preview does not contain the exact requested output sample count; no padding is applied.'
    }
    $metrics = (ConvertTo-WacFinalLoudness -Measurement $stage.measurement).Measurements
    [pscustomobject]@{ VerifiedAudio = $verified; MeasurementStage = $stage; Measurements = $metrics }
}

function Remove-WacPreviewOwnedAsset {
    param([Parameter(Mandatory = $true)]$Transaction)
    # Publication keeps the immutable READ+DELETE handle. Never reopen a path,
    # infer ownership from its name or delete a foreign replacement.
    if (-not $Transaction.Published) { return }
    if ($null -eq $Transaction.ValidationHandle -or $Transaction.ValidationHandle.SafeFileHandle.IsClosed -or
        [WinAudioClean.NativeFileIO]::Identity($Transaction.ValidationHandle.SafeFileHandle) -ne $Transaction.TempIdentity -or
        $Transaction.TempIdentity -eq $Transaction.InputIdentity) { throw 'Published preview ownership is unavailable; file retained.' }
    [WinAudioClean.NativeFileIO]::DeleteOwned($Transaction.ValidationHandle)
    $Transaction.Published = $false
    # Complete must close this already-delete-pending handle rather than trying
    # to reacquire the former temporary path.
    $Transaction.OutputCompleted = $true
    $Transaction.ValidationHandle.Dispose()
    $Transaction.ValidationHandle = $null
}

function Get-WacPreviewAlignment {
    param([Parameter(Mandatory = $true)]$ProcessingProfile)
    $reference = $null; $reason = 'not_calibrated_for_custom_graph'
    if ($ProcessingProfile.ModeChoice -eq '2') { $reference = 0.0; $reason = 'zoom_fixture_reference' }
    elseif (-not $ProcessingProfile.CleaningCustomized) { $reference = 0.025; $reason = 'original_or_gentle_raw_fixture_reference' }
    elseif (-not $ProcessingProfile.CleaningSettings.Declip -and -not $ProcessingProfile.CleaningSettings.Declick -and
        -not $ProcessingProfile.CleaningSettings.Denoise -and -not $ProcessingProfile.CleaningSettings.Gate -and
        $ProcessingProfile.CleaningSettings.HighpassHz -eq 80) { $reference = 0.0; $reason = 'all_cleaning_stages_off_fixture_reference' }
    [ordered]@{
        compensationSamples = 0; filterDelayPolicy = 'preserved'
        referenceDelaySeconds = $reference; referenceReason = $reason
        intervalNote = 'Both assets select the same requested source positions. Stateful waveform delay is preserved, not compensated. Reference delay is approximate on the recorded FFmpeg build; custom graphs require separate checks.'
    }
}

function Write-WacPreviewReports {
    param([Parameter(Mandatory = $true)][System.Collections.IDictionary]$Report,
        [Parameter(Mandatory = $true)][string]$OutputFolder)
    $writers = [ordered]@{}
    $paths = [ordered]@{
        json = [IO.Path]::Combine($OutputFolder, ('WinAudioClean_Preview_' + $Report.jobId + '.json'))
        text = [IO.Path]::Combine($OutputFolder, ('WinAudioClean_Preview_' + $Report.jobId + '.txt'))
    }
    try {
        foreach ($kind in $paths.Keys) { $writers[$kind] = Open-WacReportWriter -Path $paths[$kind] -CreateNew }
        $Report.reporting.paths = $paths
        $assetLines = @($Report.assets.Keys | ForEach-Object { $_ + ': ' + $Report.assets[$_].path }) -join "`r`n"
        $text = @"
WinAudioClean PREVIEW: $($Report.status) / exit $($Report.applicationExitCode)
Range: $($Report.range.startSeconds) s for $($Report.range.durationSeconds) s (selected stream $($Report.input.streamIndex))
Context: $($Report.range.preRollSeconds) s before / $($Report.range.postRollSeconds) s after
Source-position seek uncertainty: up to $($Report.timeline.seekToleranceSamples) output samples ($($Report.timeline.seekToleranceSeconds) s); container timestamp resolution is $($Report.timeline.timestampResolutionSeconds) s. No seek or graph-delay compensation is applied.
Preset: $($Report.presetName) ($($Report.presetId) $($Report.presetVersion)); mode $($Report.settings.mode); loudness $($Report.settings.loudnessMode)
Alignment: $($Report.alignment.intervalNote)
Matching: $($Report.matching.status); reason $($Report.matching.reason); target $($Report.matching.commonTargetLufs) LUFS
Comparison gains: original $($Report.matching.originalGainDb) dB / processed $($Report.matching.processedGainDb) dB; attenuation only
Metrics describe these encoded excerpts and comparison files, never the full recording.
Boundary limits: $($Report.boundaryNotice)
$assetLines
Playback is explicit: open the comparison files yourself. Nothing has been uploaded.
Detailed settings, arguments and native diagnostics are in the local JSON; inspect it before sharing.
"@
        Set-WacOwnedReportContent -Writer $writers.json -Content (($Report | ConvertTo-Json -Depth 16) + "`r`n")
        Set-WacOwnedReportContent -Writer $writers.text -Content ($text + "`r`n")
        [pscustomobject]@{ JsonPath = $paths.json; TextPath = $paths.text }
    } catch {
        foreach ($writer in $writers.Values) {
            try { Remove-WacOwnedReport -Writer $writer }
            catch { Write-Warning ('Preview report rollback incomplete: ' + $_.Exception.Message) }
        }
        throw
    } finally {
        foreach ($writer in $writers.Values) {
            # Content was durably flushed above. Release advisories must not
            # replace that outcome or a primary write error, or skip a writer.
            try { Close-WacReportWriter -Writer $writer }
            catch { Write-Warning ('Preview report handle release failed: ' + $_.Exception.Message) -WarningAction Continue }
        }
    }
}

function Invoke-WacPreview {
    param([Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputFolder,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)]$ProcessingProfile,
        [ValidateSet('Fast', 'Accurate')][string]$LoudnessMode = 'Fast',
        [ValidateSet('16', '24')][string]$BitDepth = '16', [switch]$Mono, [switch]$Rf64,
        [string]$Start = '0', [string]$Duration = '45', [bool]$DurationExplicit = $false,
        [string]$AudioStreamIndex, [bool]$Interactive = $false,
        [string]$ToolVersion = '2.3', [string]$FfmpegVersion, [string]$FfprobeVersion,
        [string]$ReportFolder, $OutputLayout)
    $script:WacProgressStages = New-Object 'System.Collections.Generic.List[object]'
    $transactions = [ordered]@{}; $assets = [ordered]@{}; $stages = [ordered]@{}; $primary = $null
    $warnings = New-Object 'System.Collections.Generic.List[string]'
    $cleanupErrors = New-Object 'System.Collections.Generic.List[string]'
    $exitCode = 5; $status = 'FAILED'; $errorText = $null; $report = $null; $reportPaths = $null
    $success = $false; $startedAt = [DateTime]::UtcNow
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        if ($null -ne $OutputLayout) {
            Assert-WacOutputLayout -Layout $OutputLayout
            if ($OutputFolder -ine $OutputLayout.MediaDirectory -or $ReportFolder -ine $OutputLayout.ReportDirectory) {
                throw 'Preview directories must match the held output layout.'
            }
        } elseif ($PSBoundParameters.ContainsKey('ReportFolder')) { throw 'Separate preview reports require a held output layout.' }
        # Allocation pins the input before probing and retains those locks until
        # reports finish. The other three assets hold the same source identity.
        $transactions.Original = New-WacOutputTransaction -InputPath $InputPath -OutputFolder $OutputFolder
        $primary = $transactions.Original; $InputPath = $primary.InputPath; $OutputFolder = $primary.OutputFolder
        if ($null -eq $OutputLayout) { $ReportFolder = $OutputFolder }
        $previewId = $primary.JobId
        $exitCode = 4
        $streams = @(Get-WacAudioStreams -FfprobePath $FfprobePath -InputPath $InputPath)
        $exitCode = 2
        $selection = @{ Streams = $streams; Interactive = $Interactive }
        if ($PSBoundParameters.ContainsKey('AudioStreamIndex')) { $selection.RequestedIndex = $AudioStreamIndex }
        $selected = Select-WacAudioStream @selection
        if ($null -eq $selected) {
            $exitCode = 130; $status = 'CANCELLED'
        } else {
            $range = Get-WacPreviewRange -InputDurationSeconds $selected.DurationSeconds -Start $Start -Duration $Duration -DurationExplicit $DurationExplicit
            $timeline = Get-WacPreviewTimeline -FfprobePath $FfprobePath -InputPath $InputPath -AudioStreamIndex $selected.Index
            $policy = Get-WacOutputPolicy -InputAudio $selected -BitDepth $BitDepth -Mono:$Mono -Rf64:$Rf64
            # Profile validation is shared with Accurate even for a Fast preview;
            # no caller-supplied graph can enter this optional workflow.
            $plan = Get-WacLoudnessPlan -Profile $ProcessingProfile -OutputPolicy $policy
            $exitCode = 5
            foreach ($role in @('Processed', 'CompareOriginal', 'CompareProcessed')) {
                $transactions[$role] = New-WacOutputTransaction -InputPath $InputPath -OutputFolder $OutputFolder
                if ($transactions[$role].InputIdentity -ne $primary.InputIdentity -or
                    $transactions[$role].OutputDirectoryIdentity -ne $primary.OutputDirectoryIdentity) {
                    throw 'Preview assets do not share the pinned source and destination identities.'
                }
            }
            $stem = [IO.Path]::GetFileNameWithoutExtension($InputPath)
            foreach ($role in $transactions.Keys) {
                $transactions[$role].FinalPath = [IO.Path]::Combine($OutputFolder, ($stem + '_Preview_' + $previewId + '_' + $role + '.wav'))
            }
            $estimate = Get-WacPreviewSpaceEstimate -Range $range -OutputPolicy $policy
            $availableBytes = Assert-WacOutputSpace -Transaction $primary -Estimate $estimate
            $timeout = [int][math]::Min([double][int]::MaxValue, [math]::Max(120000.0, $range.WindowDurationSeconds * 20000 + 60000))
            $expectedAudio = [pscustomobject]@{ Codec = $policy.Codec; Channels = $policy.Channels
                ChannelLayout = $policy.Layout; DurationSeconds = $range.DurationSeconds }
            $trim = Get-WacPreviewTrimFilter -Range $range
            $originalFilter = $policy.FilterPrefix + $trim
            $renderFilter = $policy.FilterPrefix + $ProcessingProfile.FilterChain
            $normalization = [ordered]@{ requestedMode = $LoudnessMode; scope = 'bounded_context_window'
                prechain = $null; analysisFilter = $null; renderFilter = $renderFilter
                linearRequested = $false; actualType = $null; fallbackReason = $null }
            if ($LoudnessMode -eq 'Accurate') {
                $arguments = Get-WacLoudnessArguments -InputPath $InputPath -FilterChain $plan.AnalysisFilter -AudioStreamIndex $selected.Index -OutputPolicy $policy
                $arguments = Add-WacPreviewWindowArguments -Arguments $arguments -Range $range -Timeline $timeline
                $exitCode = 4
                $arguments = Get-WacProgressArguments -ArgumentList $arguments
                $progressState = Add-WacProgressStage -Stage 'Preview analysis' -DurationSeconds $range.WindowDurationSeconds -EndPercent 15
                $process = Invoke-WacNativeProcess -FilePath $FfmpegPath -ArgumentList $arguments -TimeoutMilliseconds $timeout -ProgressState $progressState
                $stages.Analysis = ConvertTo-WacLoudnessStage -Process $process -DurationSeconds $range.WindowDurationSeconds -Arguments $arguments
                Assert-WacPreviewProcess -Process $process
                if ($stages.Analysis.status -ne 'PASSED') { throw 'Preview context analysis could not be parsed.' }
                $plan = Get-WacLoudnessPlan -Profile $ProcessingProfile -OutputPolicy $policy -Measurement $stages.Analysis.measurement
                $renderFilter = $plan.RenderFilter
                $normalization.prechain = $plan.Prechain; $normalization.analysisFilter = $plan.AnalysisFilter
                $normalization.renderFilter = $plan.RenderFilter; $normalization.linearRequested = $plan.LinearRequested
                $normalization.fallbackReason = $plan.FallbackReason
                if ($plan.FallbackReason) { $warnings.Add('normalization_fallback') }
            }
            $previewBase = if ($LoudnessMode -eq 'Accurate') { 15 } else { 0 }
            $previewSpan = (95 - $previewBase) / 8.0
            $previewStep = 0
            foreach ($role in @('Original', 'Processed')) {
                $filter = if ($role -eq 'Original') { $originalFilter } else { $renderFilter + ',' + $trim }
                $arguments = Get-WacPreviewRenderArguments -InputPath $InputPath -FilterChain $filter -OutputFile $transactions[$role].TempPath -AudioStreamIndex $selected.Index -OutputPolicy $policy -Range $range -Timeline $timeline
                $exitCode = 4
                $arguments = Get-WacProgressArguments -ArgumentList $arguments
                $progressStart = [int][math]::Floor($previewBase + $previewStep * $previewSpan); $previewStep++
                $progressEnd = [int][math]::Floor($previewBase + $previewStep * $previewSpan)
                $progressState = Add-WacProgressStage -Stage ("Preview $role rendering") -DurationSeconds $expectedAudio.DurationSeconds -StartPercent $progressStart -EndPercent $progressEnd
                $process = Invoke-WacNativeProcess -FilePath $FfmpegPath -ArgumentList $arguments -TimeoutMilliseconds $timeout -ProgressState $progressState
                $stages[$role] = [ordered]@{ arguments = @($arguments); inputSource = 'bounded_file_window'; process = $process }
                Assert-WacPreviewProcess -Process $process
                if ($role -eq 'Processed' -and $LoudnessMode -eq 'Accurate') {
                    $diagnostic = ConvertTo-WacLoudnessStage -Process $process -DurationSeconds $range.WindowDurationSeconds -Arguments $arguments
                    $stages.Processed.normalization = $diagnostic
                    if ($diagnostic.status -eq 'PASSED') {
                        $normalization.actualType = $diagnostic.measurement.NormalizationType
                        if ($normalization.linearRequested -and $normalization.actualType -eq 'dynamic') {
                            $normalization.fallbackReason = 'ffmpeg_dynamic_fallback'; $warnings.Add('normalization_fallback')
                        }
                    } else { $warnings.Add('normalization_result_unavailable') }
                }
                $exitCode = 5
                $progressStart = $progressEnd; $previewStep++
                $progressEnd = [int][math]::Floor($previewBase + $previewStep * $previewSpan)
                $inspection = Get-WacPreviewAssetMeasurement -Transaction $transactions[$role] -InputAudio $expectedAudio -OutputPolicy $policy -FfmpegPath $FfmpegPath -FfprobePath $FfprobePath -TimeoutMilliseconds $timeout -ProgressLabel ("Preview $role measurement") -ProgressStart $progressStart -ProgressEnd $progressEnd
                $assets[$role] = [ordered]@{ path = $transactions[$role].FinalPath; gainDb = 0.0; exactFilters = $filter
                    format = [ordered]@{ sampleRate = 48000; bitDepth = $policy.Bits; codec = $policy.Codec; channels = $policy.Channels
                        channelLayout = $policy.Layout; container = $(if ($policy.Rf64) { 'RF64' } else { 'RIFF' }) }
                    durationSeconds = $inspection.VerifiedAudio.DurationSeconds; frames = $inspection.VerifiedAudio.Frames
                    measurements = $inspection.Measurements; measurementStage = $inspection.MeasurementStage }
            }
            $match = Get-WacPreviewMatchPlan -OriginalMeasurement $assets.Original.measurementStage.measurement -ProcessedMeasurement $assets.Processed.measurementStage.measurement
            if (-not $match.Available) { $warnings.Add('comparison_unmeasurable') }
            foreach ($pair in @(@('CompareOriginal', 'Original', $match.OriginalGainDb), @('CompareProcessed', 'Processed', $match.ProcessedGainDb))) {
                $role = $pair[0]; $sourceRole = $pair[1]; $gain = [double]$pair[2]
                $filter = 'volume=' + $gain.ToString('0.###############', [Globalization.CultureInfo]::InvariantCulture) + 'dB,aresample=48000'
                $arguments = Get-WacPreviewRenderArguments -FilterChain $filter -OutputFile $transactions[$role].TempPath -OutputPolicy $policy -FromPipe
                $sourceStream = $transactions[$sourceRole].ValidationHandle; $sourceStream.Position = 0
                $exitCode = 4
                $arguments = Get-WacProgressArguments -ArgumentList $arguments
                $progressStart = $progressEnd; $previewStep++
                $progressEnd = [int][math]::Floor($previewBase + $previewStep * $previewSpan)
                $progressState = Add-WacProgressStage -Stage ("Preview $sourceRole comparison") -DurationSeconds $expectedAudio.DurationSeconds -StartPercent $progressStart -EndPercent $progressEnd
                $process = Invoke-WacNativeProcess -FilePath $FfmpegPath -ArgumentList $arguments -StandardInputStream $sourceStream -TimeoutMilliseconds $timeout -ProgressState $progressState
                $stages[$role] = [ordered]@{ arguments = @($arguments); inputSource = 'held_excerpt_stream'; process = $process }
                Assert-WacPreviewProcess -Process $process
                $exitCode = 5
                $progressStart = $progressEnd; $previewStep++
                $progressEnd = [int][math]::Floor($previewBase + $previewStep * $previewSpan)
                $inspection = Get-WacPreviewAssetMeasurement -Transaction $transactions[$role] -InputAudio $expectedAudio -OutputPolicy $policy -FfmpegPath $FfmpegPath -FfprobePath $FfprobePath -TimeoutMilliseconds $timeout -ProgressLabel ("Preview $role measurement") -ProgressStart $progressStart -ProgressEnd $progressEnd
                $assets[$role] = [ordered]@{ path = $transactions[$role].FinalPath; gainDb = $gain; exactFilters = $filter
                    format = $assets[$sourceRole].format; durationSeconds = $inspection.VerifiedAudio.DurationSeconds; frames = $inspection.VerifiedAudio.Frames
                    measurements = $inspection.Measurements; measurementStage = $inspection.MeasurementStage }
            }
            $comparisonOriginal = $assets.CompareOriginal.measurementStage.measurement
            $comparisonProcessed = $assets.CompareProcessed.measurementStage.measurement
            $difference = $null; $matchingStatus = 'UNMEASURABLE'; $matchingReason = $match.Reason
            foreach ($measurement in @($comparisonOriginal, $comparisonProcessed)) {
                if ($null -ne $measurement.InputTP -and $measurement.InputTP -gt -1.5) {
                    throw 'Preview comparison exceeds the true-peak ceiling; assets will be rolled back.'
                }
            }
            if ($match.Available -and $comparisonOriginal.Available -and $comparisonProcessed.Available) {
                $difference = [math]::Abs($comparisonOriginal.InputI - $comparisonProcessed.InputI)
                # The meter reports two decimals; permit only binary rounding
                # noise at the stated 0.2 LU boundary, not additional tolerance.
                $matchingStatus = if ($difference -le (0.2 + 0.000000001)) { 'PASSED' } else { 'OUT_OF_TOLERANCE' }
                $matchingReason = if ($matchingStatus -eq 'PASSED') { $null } else { 'comparison_loudness_difference' }
                if ($matchingStatus -ne 'PASSED') { $warnings.Add('comparison_out_of_tolerance') }
            } elseif ($match.Available) {
                $matchingReason = 'undefined_after_attenuation'; $warnings.Add('comparison_unmeasurable')
            }
            $exitCode = 5
            $null = Add-WacProgressStage -Stage 'Preview publishing' -StartPercent 95 -EndPercent 99
            foreach ($role in $transactions.Keys) {
                if ($null -ne $script:WacRunContext -and $script:WacRunContext.IsCancellationRequested) {
                    $exception = New-Object IO.IOException 'Preview processing cancelled.'; $exception.Data['WacExitCode'] = 130; throw $exception
                }
                Publish-WacOutputTransaction -Transaction $transactions[$role]
            }
            Complete-WacProgress
            # Once every validated asset is published, report failure retains
            # the completed comparison. Settle output handles before reporting
            # while keeping all source/destination pins through report writing.
            $success = $true
            foreach ($transaction in $transactions.Values) {
                foreach ($message in @(Complete-WacOutputTransaction -Transaction $transaction)) { $cleanupErrors.Add($message) }
            }
            if ($cleanupErrors.Count -gt 0) { $warnings.Add('owned_output_cleanup_failed') }
            $status = if ($warnings.Count -gt 0) { 'WARNING' } else { 'SUCCESS' }
            $exitCode = if ($warnings.Count -gt 0) { 7 } else { 0 }
            $rangeRecord = [ordered]@{}
            foreach ($property in $range.PSObject.Properties) {
                $name = $property.Name.Substring(0, 1).ToLowerInvariant() + $property.Name.Substring(1)
                $rangeRecord[$name] = $property.Value
            }
            $report = [ordered]@{ schemaVersion = 1; reportType = 'preview'; jobId = $previewId; toolVersion = $ToolVersion
                status = $status; applicationExitCode = $exitCode; startedAtUtc = $startedAt.ToString('o'); endedAtUtc = [DateTime]::UtcNow.ToString('o')
                input = [ordered]@{ path = $InputPath; streamIndex = $selected.Index; durationSeconds = $selected.DurationSeconds }
                presetId = $ProcessingProfile.PresetId; presetName = $ProcessingProfile.PresetName; presetVersion = $ProcessingProfile.PresetVersion
                presetExperimental = $ProcessingProfile.PresetExperimental; presetCustomized = $ProcessingProfile.CleaningCustomized
                settings = [ordered]@{ mode = $(if ($ProcessingProfile.ModeChoice -eq '1') { 'Raw' } else { 'Zoom' }); loudnessMode = $LoudnessMode
                    cleaning = $ProcessingProfile.CleaningSettings; bitDepth = $policy.Bits; mono = [bool]$Mono; rf64 = [bool]$Rf64; fullProfileFilters = $ProcessingProfile.FilterChain }
                range = $rangeRecord; timeline = [ordered]@{ streamIndex = $timeline.StreamIndex; streamStartSeconds = $timeline.StreamStartSeconds
                    formatStartSeconds = $timeline.FormatStartSeconds; originReason = $timeline.OriginReason
                    absoluteSeekSeconds = ($timeline.StreamStartSeconds + $range.WindowStartSeconds); seekTimestamp = $true
                    sampleRate = $timeline.SampleRate; timeBase = $timeline.TimeBase; timestampResolutionSeconds = $timeline.TimestampResolutionSeconds
                    seekToleranceSamples = $timeline.SeekToleranceSamples; seekToleranceSeconds = $timeline.SeekToleranceSeconds
                    resolutionReason = $timeline.ResolutionReason
                    positionNote = 'Requested range positions and exact output frame counts are separate from timestamp seek uncertainty. Both file renders seek identically; no source-position or graph-delay compensation is applied.' }
                alignment = (Get-WacPreviewAlignment -ProcessingProfile $ProcessingProfile)
                boundaryNotice = 'Five-second context is bounded by the selected audio ends. Stateful warmup, EOF flushing and window normalization can differ from a full render; no full-recording loudness or listening approval is implied.'
                normalization = $normalization; stages = $stages; assets = $assets
                matching = [ordered]@{ available = $match.Available; reason = $matchingReason; status = $matchingStatus
                    commonTargetLufs = $match.CommonTargetLufs; originalGainDb = $match.OriginalGainDb; processedGainDb = $match.ProcessedGainDb
                    peakCeilingDbtp = $match.PeakCeilingDbtp; headroomTargetDbtp = $match.HeadroomTargetDbtp; pairDifferenceLu = $difference; toleranceLu = 0.2 }
                warningCodes = @($warnings.ToArray()); dependencies = [ordered]@{
                    ffmpeg = [ordered]@{ path = $FfmpegPath; version = $FfmpegVersion }; ffprobe = [ordered]@{ path = $FfprobePath; version = $FfprobeVersion } }
                space = [ordered]@{ estimatedFileBytes = $estimate.FileBytes; reserveBytes = $estimate.ReserveBytes; requiredBytes = $estimate.RequiredBytes; availableBytes = $availableBytes }
                reporting = [ordered]@{ complete = $true; paths = $null; errors = @() }
                privacy = 'Local preview reports may contain paths, media metadata and native diagnostics. Nothing is uploaded. Playback is explicit.' }
            $report.progress = [ordered]@{ stages = @(Get-WacProgressReport); completed = $true
                cancellationRequested = ($null -ne $script:WacRunContext -and $script:WacRunContext.IsCancellationRequested)
                cancellationStage = $(if ($null -ne $script:WacRunContext) { $script:WacRunContext.CancellationStage } else { $null }) }
            try {
                if ($null -ne $OutputLayout) { $report.outputOrganization = Get-WacOutputOrganization -Layout $OutputLayout }
                $reportPaths = Write-WacPreviewReports -Report $report -OutputFolder $ReportFolder
            }
            catch {
                $errorText = $_.Exception.Message
                $warnings.Add('preview_reporting_failed'); $status = 'WARNING'; $exitCode = 7
                $report.status = $status; $report.applicationExitCode = $exitCode
                $report.warningCodes = @($warnings.ToArray()); $report.reporting.complete = $false
                $report.reporting.errors = @($errorText); $report.reporting.paths = $null
            }
        }
    } catch {
        $errorText = $_.Exception.Message; $status = 'FAILED'
        if ($_.Exception.Data.Contains('WacExitCode')) { $exitCode = [int]$_.Exception.Data['WacExitCode'] }
        elseif ($exitCode -in @(0, 7)) { $exitCode = 5 }
        if ($exitCode -eq 130 -or ($null -ne $script:WacRunContext -and $script:WacRunContext.IsCancellationRequested)) { $status = 'CANCELLED'; $exitCode = 130 }
    } finally {
        $watch.Stop()
        if (-not $success) {
            foreach ($transaction in $transactions.Values) {
                try { Remove-WacPreviewOwnedAsset -Transaction $transaction }
                catch { $cleanupErrors.Add($_.Exception.Message) }
            }
            foreach ($transaction in $transactions.Values) {
                foreach ($message in @(Complete-WacOutputTransaction -Transaction $transaction)) { $cleanupErrors.Add($message) }
            }
        }
        if (-not $success -and $transactions.Count -gt 0) {
            $report = [ordered]@{ schemaVersion = 1; reportType = 'preview'; jobId = $transactions.Original.JobId; toolVersion = $ToolVersion
                status = $status; applicationExitCode = $exitCode; startedAtUtc = $startedAt.ToString('o'); endedAtUtc = [DateTime]::UtcNow.ToString('o')
                input = [ordered]@{ path = $InputPath }; assets = [ordered]@{}; stages = $stages
                progress = [ordered]@{ stages = @(Get-WacProgressReport); completed = $false
                    cancellationRequested = ($null -ne $script:WacRunContext -and $script:WacRunContext.IsCancellationRequested)
                    cancellationStage = $(if ($null -ne $script:WacRunContext) { $script:WacRunContext.CancellationStage } else { $null }) }
                diagnostics = [ordered]@{ error = $errorText; cleanupErrors = @($cleanupErrors.ToArray()) }
                reporting = [ordered]@{ complete = $true; paths = $null; errors = @() } }
            try {
                if ($null -ne $OutputLayout) { $report.outputOrganization = Get-WacOutputOrganization -Layout $OutputLayout }
                $reportPaths = Write-WacPreviewReports -Report $report -OutputFolder $ReportFolder
            }
            catch { $report.reporting.complete = $false; $report.reporting.errors = @($_.Exception.Message) }
        }
        foreach ($transaction in $transactions.Values) {
            foreach ($message in @(Close-WacOutputTransaction -Transaction $transaction)) { $cleanupErrors.Add($message) }
        }
    }
    [pscustomobject]@{ ExitCode = $exitCode; Status = $status; Report = $report; ReportPaths = $reportPaths
        Error = $errorText; CleanupErrors = @($cleanupErrors.ToArray())
        OutputDirectory = $(if ($null -ne $primary) { $primary.OutputFolder } else { $OutputFolder })
        OutputDirectoryIdentity = $(if ($null -ne $primary) { $primary.OutputDirectoryIdentity } else { $null }) }
}
