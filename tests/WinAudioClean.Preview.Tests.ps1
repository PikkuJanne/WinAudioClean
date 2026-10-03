BeforeDiscovery {
    $invalidPreviewStarts = @(
        @{ Value = '-1'; Case = 'negative start' }
        @{ Value = ''; Case = 'empty start' }
        @{ Value = ' '; Case = 'blank start' }
        @{ Value = $null; Case = 'null start' }
        @{ Value = '1,5'; Case = 'locale decimal start' }
        @{ Value = '1e1'; Case = 'exponent start' }
        @{ Value = 'NaN'; Case = 'NaN start' }
        @{ Value = 'Infinity'; Case = 'infinite start' }
        @{ Value = '1,volume=100'; Case = 'filter injection start' }
        @{ Value = '1 -i https://invalid.example/input'; Case = 'argument injection start' }
        @{ Value = '$(throw "injected")'; Case = 'expression start' }
        @{ Value = '120'; Case = 'start at end' }
        @{ Value = '121'; Case = 'start beyond end' }
    )
    $invalidPreviewDurations = @(
        @{ Value = '-1'; Case = 'negative duration' }
        @{ Value = '0'; Case = 'zero duration' }
        @{ Value = '60.0001'; Case = 'duration over maximum' }
        @{ Value = '0.000001'; Case = 'duration shorter than half a sample' }
        @{ Value = ''; Case = 'empty duration' }
        @{ Value = ' '; Case = 'blank duration' }
        @{ Value = $null; Case = 'null duration' }
        @{ Value = '1,5'; Case = 'locale decimal duration' }
        @{ Value = '1e1'; Case = 'exponent duration' }
        @{ Value = 'NaN'; Case = 'NaN duration' }
        @{ Value = 'Infinity'; Case = 'infinite duration' }
        @{ Value = '1,volume=100'; Case = 'filter injection duration' }
        @{ Value = '1 -i https://invalid.example/input'; Case = 'argument injection duration' }
        @{ Value = '$(throw "injected")'; Case = 'expression duration' }
    )
}

BeforeAll {
    $previewRepository = Split-Path $PSScriptRoot -Parent
    . (Join-Path $previewRepository 'WinAudioClean.ps1')
    . (Join-Path $previewRepository 'WinAudioClean.Preview.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    function New-WacPreviewTestMeasurement {
        param([double]$Integrated = -20, [double]$Peak = -3, [bool]$Available = $true, [string]$Reason)
        [pscustomobject]@{ Available = $Available; Reason = $Reason; InputI = $(if ($Available) { $Integrated } else { $null }); InputTP = $Peak }
    }
    function Write-WacPreviewTestWave {
        param([string]$Path, [int]$Frames)
        $memory = New-Object IO.MemoryStream
        $writer = New-Object IO.BinaryWriter($memory, [Text.Encoding]::ASCII, $true)
        try {
            $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
            $writer.Write([uint32](36 + $Frames * 2))
            $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
            $writer.Write([uint32]16); $writer.Write([uint16]1); $writer.Write([uint16]1)
            $writer.Write([uint32]48000); $writer.Write([uint32]96000)
            $writer.Write([uint16]2); $writer.Write([uint16]16)
            $writer.Write([Text.Encoding]::ASCII.GetBytes('data')); $writer.Write([uint32]($Frames * 2))
            $writer.Write((New-Object byte[] ($Frames * 2)))
            $writer.Flush()
            $bytes = $memory.ToArray()
            $output = [IO.File]::Open($Path, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
            try { $output.Write($bytes, 0, $bytes.Length) }
            finally { $output.Dispose() }
        } finally { $writer.Dispose(); $memory.Dispose() }
    }
}

Describe 'AC-043: preview ranges are finite bounded sample-aligned excerpts' -Tag 'Preview', 'Unit' {
    It 'rejects <Case>' -ForEach $invalidPreviewStarts {
        { Get-WacPreviewRange -InputDurationSeconds 120 -Start $Value } | Should -Throw
    }

    It 'rejects <Case>' -ForEach $invalidPreviewDurations {
        { Get-WacPreviewRange -InputDurationSeconds 120 -Duration $Value -DurationExplicit $true } | Should -Throw
    }

    It 'rejects unavailable input duration <Case>' -ForEach @(
        @{ Case = 'zero'; Value = 0.0 }; @{ Case = 'negative'; Value = -1.0 }
        @{ Case = 'NaN'; Value = [double]::NaN }; @{ Case = 'positive infinity'; Value = [double]::PositiveInfinity }
        @{ Case = 'negative infinity'; Value = [double]::NegativeInfinity }
    ) {
        { Get-WacPreviewRange -InputDurationSeconds $Value } | Should -Throw
    }

    It 'uses the implicit 45-second default and bounded five-second rolls at <Case>' -ForEach @(
        @{ Case = 'start'; Start = '0'; Duration = 45.0; WindowStart = 0.0; WindowDuration = 50.0; Pre = 0.0; Post = 5.0 }
        @{ Case = 'middle'; Start = '40'; Duration = 45.0; WindowStart = 35.0; WindowDuration = 55.0; Pre = 5.0; Post = 5.0 }
        @{ Case = 'near end'; Start = '118'; Duration = 2.0; WindowStart = 113.0; WindowDuration = 7.0; Pre = 5.0; Post = 0.0 }
    ) {
        $range = Get-WacPreviewRange -InputDurationSeconds 120 -Start $Start
        $range.StartSeconds | Should -Be ([double]$Start)
        $range.DurationSeconds | Should -Be $Duration
        $range.StartSamples | Should -Be ([long]([double]$Start * 48000))
        $range.DurationSamples | Should -Be ([long]($Duration * 48000))
        $range.WindowStartSeconds | Should -Be $WindowStart
        $range.WindowDurationSeconds | Should -Be $WindowDuration
        $range.PreRollSeconds | Should -Be $Pre
        $range.PostRollSeconds | Should -Be $Post
        $range.TrimStartSamples | Should -Be ([long]($Pre * 48000))
        $range.TrimEndSamples | Should -Be ([long](($Pre + $Duration) * 48000))
    }

    It 'clips only the implicit default for a <InputDuration>-second short file' -ForEach @(
        @{ InputDuration = 0.2 }; @{ InputDuration = 3.0 }; @{ InputDuration = 44.0 }
    ) {
        $range = Get-WacPreviewRange -InputDurationSeconds $InputDuration
        $range.DurationSeconds | Should -Be $InputDuration
        $range.WindowDurationSeconds | Should -Be $InputDuration
        $range.DurationSamples | Should -Be ([long]($InputDuration * 48000))
        $range.TrimStartSamples | Should -Be 0
        $range.TrimEndSamples | Should -Be $range.DurationSamples
        $range.DefaultDurationClipped | Should -BeTrue
    }

    It 'rejects an explicitly supplied duration beyond the remaining interval' -ForEach @(
        @{ InputDuration = 3.0; Start = '0'; Duration = '45' }
        @{ InputDuration = 120.0; Start = '118'; Duration = '3' }
    ) {
        { Get-WacPreviewRange -InputDurationSeconds $InputDuration -Start $Start -Duration $Duration -DurationExplicit $true } | Should -Throw
    }

    It 'accepts an exact explicit end boundary and the 60-second maximum' {
        $atEnd = Get-WacPreviewRange -InputDurationSeconds 120 -Start '118' -Duration '2' -DurationExplicit $true
        $atEnd.StartSeconds + $atEnd.DurationSeconds | Should -Be 120
        (Get-WacPreviewRange -InputDurationSeconds 120 -Duration '60' -DurationExplicit $true).DurationSeconds | Should -Be 60
    }

    It 'records clipping only when an implicit requested duration was actually shortened' {
        (Get-WacPreviewRange -InputDurationSeconds 120 -Duration '30').DefaultDurationClipped | Should -BeFalse
        (Get-WacPreviewRange -InputDurationSeconds 20 -Duration '30').DefaultDurationClipped | Should -BeTrue
        (Get-WacPreviewRange -InputDurationSeconds 120).DefaultDurationClipped | Should -BeFalse
    }

    It 'preserves long-file sample offsets beyond Int32 without overflow' {
        $range = Get-WacPreviewRange -InputDurationSeconds 90000 -Start '50000' -Duration '30' -DurationExplicit $true
        $range.StartSamples | Should -Be ([long]2400000000)
        $range.WindowStartSeconds | Should -Be 49995
        $range.WindowDurationSeconds | Should -Be 40
        $range.TrimStartSamples | Should -Be 240000
        $range.TrimEndSamples | Should -Be 1680000
        $ceiling = Get-WacPreviewRange -InputDurationSeconds 1000000000 -Start '999999940' -Duration '60' -DurationExplicit $true
        $ceiling.StartSamples | Should -Be ([long]47999997120000)
        $ceiling.WindowStartSeconds | Should -Be 999999935
        $ceiling.WindowDurationSeconds | Should -Be 65
        $ceiling.PreRollSeconds | Should -Be 5
        $ceiling.PostRollSeconds | Should -Be 0
    }

    It 'quantizes start and duration to 48 kHz samples using nearest rounding' {
        $range = Get-WacPreviewRange -InputDurationSeconds 1 -Start '0.000015625' -Duration '0.00003125' -DurationExplicit $true
        $range.StartSamples | Should -Be 1
        $range.DurationSamples | Should -Be 2
        $range.TrimStartSamples | Should -Be 1
        $range.TrimEndSamples | Should -Be 3
        $range.StartSeconds | Should -Be (1.0 / 48000)
        $range.DurationSeconds | Should -Be (2.0 / 48000)
    }

    It 'parses invariant fractional input in <Culture>' -ForEach @(
        @{ Culture = 'en-US' }; @{ Culture = 'de-DE' }; @{ Culture = 'fi-FI' }
    ) {
        $previousCulture = [Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($Culture)
            $range = Get-WacPreviewRange -InputDurationSeconds 120 -Start '25.5' -Duration '30.25' -DurationExplicit $true
            $range.StartSeconds | Should -Be 25.5
            $range.DurationSeconds | Should -Be 30.25
            $range.TrimStartSamples | Should -Be 240000
            $range.TrimEndSamples | Should -Be 1692000
        } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $previousCulture }
    }
}

Describe 'AC-044: comparison gain is separate, common and attenuation only' -Tag 'Preview', 'Unit' {
    It 'matches <Case> at a common target with the true-peak safety margin' -ForEach @(
        @{ Case = 'normal pair'; OriginalI = -20.0; OriginalTP = -3.0; ProcessedI = -12.0; ProcessedTP = -1.5; Target = -20.0 }
        @{ Case = 'quiet source'; OriginalI = -35.0; OriginalTP = -10.0; ProcessedI = -12.0; ProcessedTP = -1.5; Target = -35.0 }
        @{ Case = 'source peak guard'; OriginalI = -23.0; OriginalTP = 0.0; ProcessedI = -12.0; ProcessedTP = -1.5; Target = -24.7 }
        @{ Case = 'fractional guard below one dB'; OriginalI = -23.0; OriginalTP = -1.3; ProcessedI = -12.0; ProcessedTP = -1.5; Target = -23.4 }
        @{ Case = 'processed peak guard'; OriginalI = -24.0; OriginalTP = -3.0; ProcessedI = -25.0; ProcessedTP = 1.0; Target = -27.7 }
        @{ Case = 'already matched'; OriginalI = -24.0; OriginalTP = -3.0; ProcessedI = -24.0; ProcessedTP = -3.0; Target = -24.0 }
    ) {
        $original = New-WacPreviewTestMeasurement -Integrated $OriginalI -Peak $OriginalTP
        $processed = New-WacPreviewTestMeasurement -Integrated $ProcessedI -Peak $ProcessedTP
        $plan = Get-WacPreviewMatchPlan -OriginalMeasurement $original -ProcessedMeasurement $processed
        $plan.Available | Should -BeTrue
        $plan.Reason | Should -BeNullOrEmpty
        $plan.CommonTargetLufs | Should -Be $Target
        [math]::Abs($plan.OriginalGainDb - ($Target - $OriginalI)) | Should -BeLessThan 0.0000001
        [math]::Abs($plan.ProcessedGainDb - ($Target - $ProcessedI)) | Should -BeLessThan 0.0000001
        $plan.OriginalGainDb | Should -BeLessOrEqual 0
        $plan.ProcessedGainDb | Should -BeLessOrEqual 0
        ($OriginalTP + $plan.OriginalGainDb) | Should -BeLessOrEqual (-1.7 + 0.0000001)
        ($ProcessedTP + $plan.ProcessedGainDb) | Should -BeLessOrEqual (-1.7 + 0.0000001)
        $plan.PeakCeilingDbtp | Should -Be (-1.5)
        foreach ($name in @('CommonTargetLufs', 'OriginalGainDb', 'ProcessedGainDb')) {
            [double]::IsNaN($plan.$name) | Should -BeFalse
            [double]::IsInfinity($plan.$name) | Should -BeFalse
        }
    }

    It 'labels unavailable <Reason> without inventing integrated loudness' -ForEach @(
        @{ Reason = 'too_short' }; @{ Reason = 'silence' }; @{ Reason = 'undefined_loudness' }
    ) {
        $original = New-WacPreviewTestMeasurement -Available $false -Reason $Reason -Peak (-0.5)
        $processed = New-WacPreviewTestMeasurement -Integrated (-12) -Peak (-1.5)
        $plan = Get-WacPreviewMatchPlan -OriginalMeasurement $original -ProcessedMeasurement $processed
        $plan.Available | Should -BeFalse
        $plan.Reason | Should -BeExactly $Reason
        $plan.CommonTargetLufs | Should -BeNullOrEmpty
        [math]::Abs($plan.OriginalGainDb + 1.2) | Should -BeLessThan 0.0000001
        [math]::Abs($plan.ProcessedGainDb + 0.2) | Should -BeLessThan 0.0000001
        ($plan | ConvertTo-Json -Depth 8) | Should -Not -Match 'NaN|Infinity'
    }

    It 'leaves silent null peaks at zero gain and gives too_short priority' {
        $original = [pscustomobject]@{ Available = $false; Reason = 'silence'; InputI = $null; InputTP = $null }
        $processed = [pscustomobject]@{ Available = $false; Reason = 'too_short'; InputI = $null; InputTP = $null }
        $plan = Get-WacPreviewMatchPlan -OriginalMeasurement $original -ProcessedMeasurement $processed
        $plan.Available | Should -BeFalse
        $plan.Reason | Should -BeExactly 'too_short'
        $plan.OriginalGainDb | Should -Be 0
        $plan.ProcessedGainDb | Should -Be 0
        $plan.CommonTargetLufs | Should -BeNullOrEmpty
    }

    It 'rejects invalid measured <Field> for <Case>' -ForEach @(
        @{ Field = 'Available'; Case = 'string availability'; Value = 'true' }
        @{ Field = 'InputI'; Case = 'numeric string'; Value = '-20' }
        @{ Field = 'InputI'; Case = 'boolean'; Value = $true }
        @{ Field = 'InputI'; Case = 'array'; Value = @(-20.0) }
        @{ Field = 'InputI'; Case = 'null'; Value = $null }
        @{ Field = 'InputI'; Case = 'NaN'; Value = [double]::NaN }
        @{ Field = 'InputI'; Case = 'infinity'; Value = [double]::PositiveInfinity }
        @{ Field = 'InputTP'; Case = 'numeric string'; Value = '-3' }
        @{ Field = 'InputTP'; Case = 'boolean'; Value = $true }
        @{ Field = 'InputTP'; Case = 'array'; Value = @(-3.0) }
        @{ Field = 'InputTP'; Case = 'null'; Value = $null }
        @{ Field = 'InputTP'; Case = 'NaN'; Value = [double]::NaN }
        @{ Field = 'InputTP'; Case = 'infinity'; Value = [double]::PositiveInfinity }
    ) {
        $original = New-WacPreviewTestMeasurement
        $processed = New-WacPreviewTestMeasurement
        $original.$Field = $Value
        { Get-WacPreviewMatchPlan -OriginalMeasurement $original -ProcessedMeasurement $processed } | Should -Throw
    }

    It 'rejects unknown unavailable reasons rather than copying an arbitrary label' {
        $original = New-WacPreviewTestMeasurement -Available $false -Reason 'PRIVATE_REASON'
        { Get-WacPreviewMatchPlan -OriginalMeasurement $original -ProcessedMeasurement (New-WacPreviewTestMeasurement) } | Should -Throw
    }
}

Describe 'AC-043: preview timeline metadata binds seeking to the selected track' -Tag 'Preview', 'Unit' {
    BeforeEach {
        $script:previewTimelineJson = '{"streams":[{"index":0,"start_time":"1.00","sample_rate":"48000","time_base":"1/1000"},{"index":5,"start_time":"5.25","sample_rate":"48000","time_base":"1/1000"}],"format":{"start_time":"-1.25","format_name":"matroska,webm"}}'
        Mock Invoke-WacNativeProcess {
            [pscustomobject]@{ Started = $true; ExitCode = 0; StandardOutput = $script:previewTimelineJson; StandardError = ''
                Error = $null; TimedOut = $false; CleanupError = $null }
        }
    }
    It 'uses the selected stream origin and retains a negative container origin only as metadata' {
        $timeline = Get-WacPreviewTimeline -FfprobePath 'unused.exe' -InputPath 'selected.wav' -AudioStreamIndex 5
        $timeline.StreamIndex | Should -Be 5
        $timeline.StreamStartSeconds | Should -Be 5.25
        $timeline.FormatStartSeconds | Should -Be (-1.25)
        $timeline.OriginReason | Should -BeExactly 'stream_start_time'
        $timeline.SampleRate | Should -Be 48000
        $timeline.TimeBase | Should -BeExactly '1/1000'
        $timeline.TimestampResolutionSeconds | Should -Be 0.001
        $timeline.SeekToleranceSamples | Should -Be 49
        $timeline.SeekToleranceSeconds | Should -Be (49.0 / 48000)
        Should -Invoke Invoke-WacNativeProcess -Times 1 -Exactly -ParameterFilter {
            $TimeoutMilliseconds -eq 15000 -and '-protocol_whitelist' -in $ArgumentList -and
            $ArgumentList[[array]::IndexOf($ArgumentList, '-protocol_whitelist') + 1] -ceq 'file' -and
            $ArgumentList[[array]::IndexOf($ArgumentList, '-i') + 1] -ceq 'selected.wav'
        }
    }

    It 'uses sample zero only when WAV does not report a presentation origin' {
        $script:previewTimelineJson = '{"streams":[{"index":5,"sample_rate":"48000"}],"format":{"format_name":"wav"}}'
        $timeline = Get-WacPreviewTimeline -FfprobePath 'unused.exe' -InputPath 'selected.wav' -AudioStreamIndex 5
        $timeline.StreamStartSeconds | Should -Be 0
        $timeline.FormatStartSeconds | Should -BeNullOrEmpty
        $timeline.OriginReason | Should -BeExactly 'wave_sample_zero_origin'
        $timeline.TimestampResolutionSeconds | Should -Be (1.0 / 48000)
        $timeline.SeekToleranceSamples | Should -Be 2
        $timeline.TimeBase | Should -BeNullOrEmpty
        $timeline.ResolutionReason | Should -BeExactly 'wave_sample_rate_resolution'
    }

    It 'rejects unsupported selected timestamp <Case>' -ForEach @(
        @{ Case = 'negative'; Value = '-0.5' }
        @{ Case = 'NaN'; Value = 'NaN' }
        @{ Case = 'infinity'; Value = 'Infinity' }
        @{ Case = 'N/A'; Value = 'N/A' }
        @{ Case = 'locale decimal'; Value = '5,25' }
        @{ Case = 'filter-like string'; Value = '5.25,volume=100' }
        @{ Case = 'JSON number'; Value = 5.25 }
        @{ Case = 'boolean'; Value = $true }
        @{ Case = 'array'; Value = @('5.25') }
        @{ Case = 'beyond supported bound'; Value = '1000000001' }
        @{ Case = 'null for non-WAV'; Value = $null }
    ) {
        $data = @{ streams = @(@{ index = 5; start_time = $Value; sample_rate = '48000'; time_base = '1/1000' }); format = @{ format_name = 'matroska,webm'; start_time = '0.0' } }
        $script:previewTimelineJson = $data | ConvertTo-Json -Depth 8 -Compress
        { Get-WacPreviewTimeline -FfprobePath 'unused.exe' -InputPath 'selected.wav' -AudioStreamIndex 5 } | Should -Throw
    }

    It 'reports finite timestamp resolution with a bounded source-position tolerance for <TimeBase>' -ForEach @(
        @{ TimeBase = '1/48000'; Resolution = (1.0 / 48000); Tolerance = 2 }
        @{ TimeBase = '1/1000'; Resolution = 0.001; Tolerance = 49 }
        @{ TimeBase = '1/101'; Resolution = (1.0 / 101); Tolerance = 477 }
    ) {
        $data = @{ streams = @(@{ index = 5; start_time = '5.25'; sample_rate = '48000'; time_base = $TimeBase }); format = @{ format_name = 'matroska,webm' } }
        $script:previewTimelineJson = $data | ConvertTo-Json -Depth 8 -Compress
        $timeline = Get-WacPreviewTimeline -FfprobePath 'unused.exe' -InputPath 'selected.wav' -AudioStreamIndex 5
        $timeline.TimestampResolutionSeconds | Should -Be $Resolution
        $timeline.SeekToleranceSamples | Should -Be $Tolerance
        $timeline.SeekToleranceSeconds | Should -Be ($Tolerance / 48000.0)
        $timeline.SeekToleranceSamples | Should -BeLessOrEqual 480
        [double]::IsInfinity($timeline.TimestampResolutionSeconds) | Should -BeFalse
    }

    It 'rejects unsupported <Field> for <Case>' -ForEach @(
        @{ Field = 'time_base'; Case = 'zero numerator'; Value = '0/1000' }
        @{ Field = 'time_base'; Case = 'zero denominator'; Value = '1/0' }
        @{ Field = 'time_base'; Case = 'negative numerator'; Value = '-1/1000' }
        @{ Field = 'time_base'; Case = 'negative denominator'; Value = '1/-1000' }
        @{ Field = 'time_base'; Case = 'fractional numerator'; Value = '1.5/1000' }
        @{ Field = 'time_base'; Case = 'exponent denominator'; Value = '1/1e3' }
        @{ Field = 'time_base'; Case = 'too coarse including one-sample allowance'; Value = '1/100' }
        @{ Field = 'time_base'; Case = 'missing non-WAV rational'; Value = $null }
        @{ Field = 'time_base'; Case = 'NaN'; Value = 'NaN' }
        @{ Field = 'time_base'; Case = 'injection'; Value = '1/1000,volume=100' }
        @{ Field = 'time_base'; Case = 'JSON number'; Value = 0.001 }
        @{ Field = 'time_base'; Case = 'array'; Value = @('1/1000') }
        @{ Field = 'sample_rate'; Case = 'zero'; Value = '0' }
        @{ Field = 'sample_rate'; Case = 'negative'; Value = '-48000' }
        @{ Field = 'sample_rate'; Case = 'fractional string'; Value = '48000.0' }
        @{ Field = 'sample_rate'; Case = 'NaN'; Value = 'NaN' }
        @{ Field = 'sample_rate'; Case = 'missing'; Value = $null }
        @{ Field = 'sample_rate'; Case = 'integer overflow'; Value = '2147483648' }
        @{ Field = 'sample_rate'; Case = 'JSON number'; Value = 48000 }
        @{ Field = 'sample_rate'; Case = 'array'; Value = @('48000') }
    ) {
        $stream = @{ index = 5; start_time = '5.25'; sample_rate = '48000'; time_base = '1/1000' }
        $stream[$Field] = $Value
        $script:previewTimelineJson = @{ streams = @($stream); format = @{ format_name = 'matroska,webm' } } | ConvertTo-Json -Depth 8 -Compress
        { Get-WacPreviewTimeline -FfprobePath 'unused.exe' -InputPath 'selected.wav' -AudioStreamIndex 5 } | Should -Throw
    }

    It 'rejects malformed or ambiguous timeline metadata for <Case>' -ForEach @(
        @{ Case = 'malformed JSON'; Json = '{malformed' }
        @{ Case = 'root array'; Json = '[{"streams":[{"index":5,"start_time":"0.0"}]}]' }
        @{ Case = 'missing streams'; Json = '{"format":{"format_name":"wav"}}' }
        @{ Case = 'missing selected stream'; Json = '{"streams":[{"index":6,"start_time":"0.0"}]}' }
        @{ Case = 'duplicate stream index'; Json = '{"streams":[{"index":5,"start_time":"0.0"},{"index":5,"start_time":"1.0"}]}' }
        @{ Case = 'string stream index'; Json = '{"streams":[{"index":"5","start_time":"0.0"}]}' }
        @{ Case = 'missing non-WAV origin'; Json = '{"streams":[{"index":5,"sample_rate":"48000","time_base":"1/1000"}],"format":{"format_name":"matroska,webm"}}' }
        @{ Case = 'invalid container timestamp'; Json = '{"streams":[{"index":5,"start_time":"0.0","sample_rate":"48000","time_base":"1/48000"}],"format":{"format_name":"wav","start_time":"NaN"}}' }
    ) {
        $script:previewTimelineJson = $Json
        { Get-WacPreviewTimeline -FfprobePath 'unused.exe' -InputPath 'selected.wav' -AudioStreamIndex 5 } | Should -Throw
    }
}

Describe 'AC-043/045: preview commands bound one selected input and preserve mastering settings' -Tag 'Preview', 'Unit' {
    It 'uses a bounded window and exact sample trim in <Culture>' -ForEach @(
        @{ Culture = 'en-US' }; @{ Culture = 'de-DE' }; @{ Culture = 'fi-FI' }
    ) {
        $previousCulture = [Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($Culture)
            $profile = Get-WacProcessingProfile -Choice 1 -Preset Gentle
            $originalProfileJson = $profile | ConvertTo-Json -Depth 10 -Compress
            $range = Get-WacPreviewRange -InputDurationSeconds 120 -Start '25.5' -Duration '30.25' -DurationExplicit $true
            $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 2; ChannelLayout = 'stereo' }) -Mono -BitDepth 24
            $trim = Get-WacPreviewTrimFilter -Range $range
            $trim | Should -BeExactly 'aresample=48000,atrim=start_sample=240000:end_sample=1692000,asetpts=PTS-STARTPTS'
            $filter = $policy.FilterPrefix + $profile.FilterChain + ',' + $trim
            $arguments = Get-WacPreviewRenderArguments -InputPath 'input [5].wav' -FilterChain $filter -OutputFile 'owned.partial' -AudioStreamIndex 5 -OutputPolicy $policy -Range $range
            $inputIndex = [array]::IndexOf($arguments, '-i')
            [array]::IndexOf($arguments, '-ss') | Should -BeLessThan $inputIndex
            [array]::IndexOf($arguments, '-t') | Should -BeLessThan $inputIndex
            $arguments[[array]::IndexOf($arguments, '-seek_timestamp') + 1] | Should -BeExactly '1'
            $arguments[[array]::IndexOf($arguments, '-ss') + 1] | Should -BeExactly '20.5'
            $arguments[[array]::IndexOf($arguments, '-t') + 1] | Should -BeExactly '40.25'
            $arguments[$inputIndex + 1] | Should -BeExactly 'input [5].wav'
            $arguments[[array]::IndexOf($arguments, '-map') + 1] | Should -BeExactly '0:5'
            $arguments[[array]::IndexOf($arguments, '-af') + 1] | Should -BeExactly $filter
            $arguments[[array]::IndexOf($arguments, '-c:a') + 1] | Should -BeExactly 'pcm_s24le'
            $arguments[[array]::IndexOf($arguments, '-ac') + 1] | Should -BeExactly '1'
            $arguments[[array]::IndexOf($arguments, '-y') - 1] | Should -BeExactly 'owned.partial'
            $arguments | Should -Contain '-nostdin'
            $arguments | Should -Contain '-nostats'
            ($profile | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $originalProfileJson
        } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $previousCulture }
    }

    It 'uses held pipe PCM and only comparison gain for a separately matched asset' {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        $arguments = Get-WacPreviewRenderArguments -FilterChain 'volume=-0.4dB' -OutputFile 'owned-comparison.partial' -OutputPolicy $policy -FromPipe
        $arguments[[array]::IndexOf($arguments, '-i') + 1] | Should -BeExactly 'pipe:0'
        $arguments[[array]::IndexOf($arguments, '-map') + 1] | Should -BeExactly '0:0'
        $arguments[[array]::IndexOf($arguments, '-protocol_whitelist') + 1] | Should -BeExactly 'pipe'
        $arguments[[array]::IndexOf($arguments, '-format_whitelist') + 1] | Should -BeExactly 'wav'
        $arguments[[array]::IndexOf($arguments, '-af') + 1] | Should -BeExactly 'volume=-0.4dB'
        $arguments | Should -Not -Contain '-ss'
        $arguments | Should -Not -Contain '-t'
        $arguments | Should -Not -Contain '-seek_timestamp'
        ($arguments -join ' ') | Should -Not -Match 'adeclip|adeclick|afftdn|agate|loudnorm|dynaudnorm|pan='
    }

    It 'adds the selected stream timestamp origin to the source-relative seek' {
        $range = Get-WacPreviewRange -InputDurationSeconds 120 -Start '25.5' -Duration '30.25' -DurationExplicit $true
        $timeline = [pscustomobject]@{ StreamIndex = 5; StreamStartSeconds = 5.0; FormatStartSeconds = 1.0; OriginReason = 'selected_stream_start' }
        $arguments = Add-WacPreviewWindowArguments -Arguments @('-nostdin', '-i', 'input.wav') -Range $range -Timeline $timeline
        $arguments[[array]::IndexOf($arguments, '-ss') + 1] | Should -BeExactly '25.5'
        $arguments[[array]::IndexOf($arguments, '-t') + 1] | Should -BeExactly '40.25'
        $arguments[[array]::IndexOf($arguments, '-seek_timestamp') + 1] | Should -BeExactly '1'
        [array]::IndexOf($arguments, '-seek_timestamp') | Should -BeLessThan ([array]::IndexOf($arguments, '-i'))
        $range.StartSeconds | Should -Be 25.5
        $range.WindowStartSeconds | Should -Be 20.5
    }

    It 'rejects an already bounded or missing input instead of adding conflicting windows' -ForEach @(
        @{ Arguments = @('-i', 'input.wav') }
        @{ Arguments = @('-nostdin', '-ss', '1', '-i', 'input.wav') }
        @{ Arguments = @('-nostdin', '-i', 'input.wav', '-t', '1') }
        @{ Arguments = @('-nostdin', '-f', 'null', '-') }
    ) {
        $range = Get-WacPreviewRange -InputDurationSeconds 120
        { Add-WacPreviewWindowArguments -Arguments $Arguments -Range $range } | Should -Throw
    }

    It 'estimates all four preview PCM assets plus headroom for <Channels> channels and <Bits> bits' -ForEach @(
        @{ Channels = 1; Bits = '16' }; @{ Channels = 2; Bits = '24' }
    ) {
        $range = Get-WacPreviewRange -InputDurationSeconds 120
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = $Channels; ChannelLayout = $(if ($Channels -eq 1) { 'mono' } else { 'stereo' }) }) -BitDepth $Bits
        $estimate = Get-WacPreviewSpaceEstimate -Range $range -OutputPolicy $policy
        $estimate.AssetCount | Should -Be 4
        $estimate.FileBytes | Should -BeGreaterOrEqual (45 * 48000 * $Channels * ([int]$Bits / 8) * 4)
        $estimate.FileBytes | Should -Be (4 * $estimate.AssetFileBytes)
        $estimate.ReserveBytes | Should -BeGreaterOrEqual 64MB
        $estimate.RequiredBytes | Should -Be ($estimate.FileBytes + $estimate.ReserveBytes)
    }
}

Describe 'AC-043/045: CLI preview arguments fail before dependency and output side effects' -Tag 'Preview', 'EntryPoint' {
    BeforeAll {
        $previewShell = (Get-Process -Id $PID).Path
        $previewAppFolder = Join-Path $TestDrive 'isolated preview app'
        $null = [IO.Directory]::CreateDirectory($previewAppFolder)
        foreach ($name in @('WinAudioClean.ps1', 'WinAudioClean.IO.ps1', 'WinAudioClean.Preview.ps1')) {
            Copy-Item -LiteralPath (Join-Path $previewRepository $name) -Destination (Join-Path $previewAppFolder $name)
        }
        $previewApp = Join-Path $previewAppFolder 'WinAudioClean.ps1'
        $previewInput = Join-Path $previewAppFolder 'synthetic input [1].wav'
        [IO.File]::WriteAllBytes($previewInput, [byte[]](1, 2, 3, 4))
        $previewMissingDependency = Join-Path $previewAppFolder 'missing dependency.exe'
        $previewDriver = Join-Path $previewAppFolder 'Invoke-PreviewCase.ps1'
        $driverCode = @'
param([string]$AppPath, [string]$InputFile, [string]$OutputFolder, [string]$MissingDependency, [string]$Case)
$options = @{ inputPath = $InputFile; OutputDirectory = $OutputFolder; FfmpegPath = $MissingDependency; FfprobePath = $MissingDependency; Mode = 'Zoom'; NonInteractive = $true }
switch ($Case) {
    'start without preview' { $options.PreviewStartSeconds = '1' }
    'duration without preview' { $options.PreviewDurationSeconds = '30' }
    'negative start' { $options.Preview = $true; $options.PreviewStartSeconds = '-1' }
    'empty start' { $options.Preview = $true; $options.PreviewStartSeconds = '' }
    'locale decimal start' { $options.Preview = $true; $options.PreviewStartSeconds = '1,5' }
    'infinite start' { $options.Preview = $true; $options.PreviewStartSeconds = 'Infinity' }
    'zero duration' { $options.Preview = $true; $options.PreviewDurationSeconds = '0' }
    'duration beyond maximum' { $options.Preview = $true; $options.PreviewDurationSeconds = '61' }
    'injected duration' { $options.Preview = $true; $options.PreviewDurationSeconds = '1,volume=100' }
    'expression duration' { $options.Preview = $true; $options.PreviewDurationSeconds = '$(throw "injected")' }
    default { throw 'Unknown test case.' }
}

& $AppPath @options
exit $LASTEXITCODE
'@
        [IO.File]::WriteAllText($previewDriver, $driverCode, (New-Object Text.UTF8Encoding($true)))
    }

    It 'returns configuration exit 2 before native startup for <Case>' -ForEach @(
        @{ Case = 'start without preview' }; @{ Case = 'duration without preview' }
        @{ Case = 'negative start' }; @{ Case = 'empty start' }; @{ Case = 'locale decimal start' }; @{ Case = 'infinite start' }
        @{ Case = 'zero duration' }; @{ Case = 'duration beyond maximum' }; @{ Case = 'injected duration' }; @{ Case = 'expression duration' }
    ) {
        $outputFolder = Join-Path $previewAppFolder ('new output ' + $Case)
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -AppPath {1} -InputFile {2} -OutputFolder {3} -MissingDependency {4} -Case {5}' -f
            (ConvertTo-WacTestQuotedArgument $previewDriver), (ConvertTo-WacTestQuotedArgument $previewApp),
            (ConvertTo-WacTestQuotedArgument $previewInput), (ConvertTo-WacTestQuotedArgument $outputFolder),
            (ConvertTo-WacTestQuotedArgument $previewMissingDependency), (ConvertTo-WacTestQuotedArgument $Case)
        $result = Invoke-WacTestProcess -FilePath $previewShell -Arguments $arguments -WorkingDirectory $previewAppFolder
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        $compactError = $result.StandardError -replace '\s', ''
        $compactError | Should -Match 'Preflightfailed:'
        $compactError | Should -Not -Match 'Dependencyfailed:'
        Test-Path -LiteralPath $outputFolder | Should -BeFalse
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($previewInput)) | Should -BeExactly 'AQIDBA=='
        @(Get-ChildItem -LiteralPath $previewAppFolder -Filter '*.partial' -Force).Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $previewAppFolder -Filter '*_Cleaned_*.wav').Count | Should -Be 0
    }
}

Describe 'AC-043/044/045: preview orchestration retains ownership through faults and cancellation' -Tag 'Preview', 'Runtime', 'OutputSafety' {
    BeforeAll {
        $realPreviewPublish = ${function:Publish-WacOutputTransaction}
        $realPreviewWriteReports = ${function:Write-WacPreviewReports}
        $realPreviewComplete = ${function:Complete-WacOutputTransaction}
    }
    BeforeEach {
        $previewCaseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $previewCaseOutput = Join-Path $previewCaseRoot 'output'
        $null = [IO.Directory]::CreateDirectory($previewCaseOutput)
        $previewCaseInput = Join-Path $previewCaseRoot 'source.wav'
        $previewPrior = Join-Path $previewCaseOutput 'prior.wav'
        $previewForeignPartial = Join-Path $previewCaseOutput '.wac-foreign.partial'
        [IO.File]::WriteAllBytes($previewCaseInput, [byte[]](1, 2, 3))
        [IO.File]::WriteAllBytes($previewPrior, [byte[]](11, 12, 13))
        [IO.File]::WriteAllBytes($previewForeignPartial, [byte[]](7, 8, 9))
        $script:previewFault = $Fault
        $script:previewExpectedDuration = $(if ($Fault -eq 'short-preview') { 0.2 } else { 3.0 })
        $script:previewCalls = New-Object 'System.Collections.Generic.List[object]'
        $script:previewRenderCount = 0; $script:previewMeasurementCount = 0; $script:previewPublicationCount = 0
        $script:previewPublishSentinel = $null
        Mock Get-WacAudioStreams {
            param([string]$InputPath)
            [pscustomobject]@{ Index = $(if ($InputPath.EndsWith('.partial')) { 0 } else { 5 }); Codec = 'pcm_s16le'
                Channels = 1; ChannelLayout = 'mono'; SampleRate = 48000; DurationSeconds = $script:previewExpectedDuration }
        }
        Mock Select-WacAudioStream {
            param($Streams)
            if ($script:previewFault -eq 'cancel') { return $null }
            $Streams[0]
        }
        Mock Get-WacPreviewTimeline {
            [pscustomobject]@{ StreamIndex = 5; StreamStartSeconds = 0.0; FormatStartSeconds = $null; OriginReason = 'stream_start_time'
                SampleRate = 48000; TimeBase = '1/48000'; TimestampResolutionSeconds = (1.0 / 48000)
                SeekToleranceSamples = 2; SeekToleranceSeconds = (2.0 / 48000); ResolutionReason = 'stream_time_base' }
        }
        Mock Invoke-WacNativeProcess {
            param([string[]]$ArgumentList, [System.IO.Stream]$StandardInputStream)
            $measurement = 'null' -in $ArgumentList
            $script:previewCalls.Add([pscustomobject]@{ Arguments = @($ArgumentList); Measurement = $measurement
                HadHeldInput = ($null -ne $StandardInputStream); InputPosition = $(if ($null -ne $StandardInputStream) { $StandardInputStream.Position } else { $null }) })
            $result = [pscustomobject]@{ Started = $true; ExitCode = 0; StandardOutput = ''; StandardError = ''
                Error = $null; TimedOut = $false; CleanupError = $null }
            if ($null -ne $StandardInputStream) {
                if (-not $StandardInputStream.CanRead -or $StandardInputStream.Position -ne 0) { throw 'Expected the rewound held excerpt stream.' }
                $null = $StandardInputStream.ReadByte()
            }
            if ($measurement) {
                $script:previewMeasurementCount++
                if ($script:previewFault -eq 'measurement-malformed') { $result.StandardError = '{malformed'; return $result }
                if ($script:previewFault -eq 'measurement-exit') { $result.ExitCode = 19; return $result }
                $integrated = if ($script:previewMeasurementCount -eq 2) { '-12.00' } else { '-20.00' }
                $peak = switch ($script:previewMeasurementCount) { 1 { '-3.00' } 2 { '-1.50' } 3 { '-3.00' } default { '-9.50' } }
                if ($script:previewFault -eq 'comparison-peak' -and $script:previewMeasurementCount -eq 4) { $peak = '-1.00' }
                $data = [ordered]@{ input_i = $integrated; input_tp = $peak; input_lra = '2.00'; input_thresh = '-30.00'
                    output_i = '-12.00'; output_tp = '-1.50'; output_lra = '2.00'; output_thresh = '-22.00'
                    normalization_type = 'linear'; target_offset = '0.00' }
                if ($script:previewFault -eq 'silence') {
                    $data.input_i = '-inf'; $data.input_tp = '-inf'; $data.input_lra = '0.00'; $data.input_thresh = '-70.00'
                    $data.output_i = '-inf'; $data.output_tp = '-inf'; $data.output_lra = '0.00'; $data.output_thresh = '-70.00'; $data.target_offset = 'inf'
                }
                $result.StandardError = $data | ConvertTo-Json -Compress
            } else {
                $script:previewRenderCount++
                if ($script:previewFault -eq 'render-start') { $result.Started = $false; $result.ExitCode = $null; $result.Error = 'Injected start failure'; return $result }
                if ($script:previewFault -eq 'render-exit') { $result.ExitCode = 19; return $result }
                $path = $ArgumentList[[array]::IndexOf($ArgumentList, '-y') - 1]
                $frames = [int]($script:previewExpectedDuration * 48000)
                if ($script:previewFault -eq 'one-sample-short') { $frames-- }
                Write-WacPreviewTestWave -Path $path -Frames $frames
            }
            $result
        }
        Mock Publish-WacOutputTransaction {
            param($Transaction)
            $script:previewPublicationCount++
            if ($script:previewFault -eq 'publication-race' -and $script:previewPublicationCount -eq 2) {
                $script:previewPublishSentinel = $Transaction.FinalPath
                [IO.File]::WriteAllBytes($Transaction.FinalPath, [byte[]](9, 8, 7))
            }
            & $realPreviewPublish -Transaction $Transaction
        }
        Mock Write-WacPreviewReports {
            param($Report, [string]$OutputFolder)
            if ($script:previewFault -eq 'report-failure') { throw 'Injected preview report failure.' }
            & $realPreviewWriteReports -Report $Report -OutputFolder $OutputFolder
        }
    }

    It 'persists owned cleanup diagnostics before releasing pins and retains primary <Exit>' -ForEach @(
        @{ Fault = 'render-exit'; Exit = 4; Status = 'FAILED' }
        @{ Fault = 'one-sample-short'; Exit = 5; Status = 'FAILED' }
        @{ Fault = 'native-cancellation'; Exit = 130; Status = 'CANCELLED' }
    ) {
        $priorContext = $script:WacRunContext
        $context = New-WacRunContext
        $script:WacRunContext = $context
        $script:previewCompletedTransactions = New-Object 'System.Collections.Generic.List[object]'
        $script:previewCompletedBeforeReport = $false
        $script:previewPinsHeldAtReport = $false
        $script:previewInjectedCleanupDiagnostic = $false
        if ($Fault -eq 'native-cancellation') {
            Mock Invoke-WacNativeProcess {
                Request-WacCancellation -RunContext $script:WacRunContext
                [pscustomobject]@{ Started = $true; ExitCode = 19; StandardOutput = ''; StandardError = ''
                    Error = $null; TimedOut = $false; CleanupError = $null; Cancelled = $true }
            }
        }
        Mock Complete-WacOutputTransaction {
            param($Transaction)
            # Complete real owned cleanup first, then inject a disclosed failure
            # diagnostic. A late Close must not be the first settlement point.
            if (-not $Transaction.OutputCompleted) { $script:previewCompletedTransactions.Add($Transaction) }
            & $realPreviewComplete -Transaction $Transaction
            if (-not $script:previewInjectedCleanupDiagnostic) {
                $script:previewInjectedCleanupDiagnostic = $true
                'Injected owned-output cleanup diagnostic.'
            }
        }
        Mock Write-WacPreviewReports {
            param($Report, [string]$OutputFolder)
            $script:previewCompletedBeforeReport = $script:previewCompletedTransactions.Count -eq 4 -and
                @($script:previewCompletedTransactions | Where-Object { -not $_.OutputCompleted }).Count -eq 0
            $script:previewPinsHeldAtReport = $script:previewCompletedTransactions.Count -eq 4 -and
                @($script:previewCompletedTransactions | Where-Object {
                    $null -eq $_.InputLock -or -not $_.InputLock.CanRead -or
                    $null -eq $_.OutputDirectoryHandle -or $_.OutputDirectoryHandle.IsClosed
                }).Count -eq 0
            & $realPreviewWriteReports -Report $Report -OutputFolder $OutputFolder
        }
        try {
            $result = Invoke-WacPreview -InputPath $previewCaseInput -OutputFolder $previewCaseOutput -FfmpegPath 'unused.exe' -FfprobePath 'unused.exe' -ProcessingProfile (Get-WacProcessingProfile -Choice 2)
            $result.ExitCode | Should -Be $Exit
            $result.Status | Should -BeExactly $Status
            $script:previewCompletedBeforeReport | Should -BeTrue
            $script:previewPinsHeldAtReport | Should -BeTrue
            $result.CleanupErrors | Should -Contain 'Injected owned-output cleanup diagnostic.'
            $json = Get-Content -Raw -LiteralPath $result.ReportPaths.JsonPath | ConvertFrom-Json
            $json.applicationExitCode | Should -Be $Exit
            $json.status | Should -BeExactly $Status
            $json.diagnostics.cleanupErrors | Should -Contain 'Injected owned-output cleanup diagnostic.'
            $json.progress.completed | Should -BeFalse
            @($json.assets.PSObject.Properties).Count | Should -Be 0
            @(Get-ChildItem -LiteralPath $previewCaseOutput -Filter '*.partial' -Force).Count | Should -Be 1
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($previewForeignPartial)) | Should -BeExactly 'BwgJ'
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($previewPrior)) | Should -BeExactly 'CwwN'
            $released = [IO.File]::Open($previewCaseInput, 'Open', 'ReadWrite', 'None')
            $released.Dispose()
        } finally { $context.Dispose(); $script:WacRunContext = $priorContext }
    }

    It 'retains all published assets and snapshots a request after the fourth publication' {
        $priorContext = $script:WacRunContext
        $context = New-WacRunContext
        $script:WacRunContext = $context
        Mock Publish-WacOutputTransaction {
            param($Transaction)
            $script:previewPublicationCount++
            & $realPreviewPublish -Transaction $Transaction
            if ($script:previewPublicationCount -eq 4) { Request-WacCancellation -RunContext $script:WacRunContext }
        }
        try {
            $result = Invoke-WacPreview -InputPath $previewCaseInput -OutputFolder $previewCaseOutput -FfmpegPath 'unused.exe' -FfprobePath 'unused.exe' -ProcessingProfile (Get-WacProcessingProfile -Choice 2)
            $result.ExitCode | Should -Be 0
            $result.Status | Should -BeExactly 'SUCCESS'
            $script:previewPublicationCount | Should -Be 4
            @(Get-ChildItem -LiteralPath $previewCaseOutput -Filter '*_Preview_*.wav').Count | Should -Be 4
            $json = Get-Content -Raw -LiteralPath $result.ReportPaths.JsonPath | ConvertFrom-Json
            $json.progress.completed | Should -BeTrue
            $json.progress.cancellationRequested | Should -BeTrue
            $json.progress.cancellationStage | Should -BeExactly 'Preview publishing'
            $json.progress.stages[-1].percent | Should -Be 100
            @($json.assets.PSObject.Properties).Count | Should -Be 4
            $result.CleanupErrors.Count | Should -Be 0
        } finally { $context.Dispose(); $script:WacRunContext = $priorContext }
    }

    It 'handles <Fault> with exit <Exit>, <AssetCount> completed or foreign preview assets and no full export' -ForEach @(
        @{ Fault = 'valid'; Exit = 0; AssetCount = 4; Status = 'SUCCESS' }
        @{ Fault = 'cancel'; Exit = 130; AssetCount = 0; Status = 'CANCELLED' }
        @{ Fault = 'range-invalid'; Exit = 2; AssetCount = 0; Status = 'FAILED' }
        @{ Fault = 'render-start'; Exit = 3; AssetCount = 0; Status = 'FAILED' }
        @{ Fault = 'render-exit'; Exit = 4; AssetCount = 0; Status = 'FAILED' }
        @{ Fault = 'measurement-malformed'; Exit = 4; AssetCount = 0; Status = 'FAILED' }
        @{ Fault = 'measurement-exit'; Exit = 4; AssetCount = 0; Status = 'FAILED' }
        @{ Fault = 'one-sample-short'; Exit = 5; AssetCount = 0; Status = 'FAILED' }
        @{ Fault = 'comparison-peak'; Exit = 5; AssetCount = 0; Status = 'FAILED' }
        @{ Fault = 'publication-race'; Exit = 5; AssetCount = 1; Status = 'FAILED' }
        @{ Fault = 'report-failure'; Exit = 7; AssetCount = 4; Status = 'WARNING' }
        @{ Fault = 'silence'; Exit = 7; AssetCount = 4; Status = 'WARNING' }
        @{ Fault = 'short-preview'; Exit = 7; AssetCount = 4; Status = 'WARNING' }
    ) {
        $profile = Get-WacProcessingProfile -Choice 2
        $profileBefore = $profile | ConvertTo-Json -Depth 10 -Compress
        $result = Invoke-WacPreview -InputPath $previewCaseInput -OutputFolder $previewCaseOutput -FfmpegPath 'unused.exe' -FfprobePath 'unused.exe' -ProcessingProfile $profile -Start $(if ($Fault -eq 'range-invalid') { '3' } else { '0' })
        @($result).Count | Should -Be 1
        $result.ExitCode | Should -Be $Exit -Because $result.Error
        $result.Status | Should -BeExactly $Status
        $result.CleanupErrors.Count | Should -Be 0
        ($profile | ConvertTo-Json -Depth 10 -Compress) | Should -BeExactly $profileBefore
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($previewCaseInput)) | Should -BeExactly 'AQID'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($previewPrior)) | Should -BeExactly 'CwwN'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($previewForeignPartial)) | Should -BeExactly 'BwgJ'
        @(Get-ChildItem -LiteralPath $previewCaseOutput -Filter '*_Preview_*.wav').Count | Should -Be $AssetCount
        @(Get-ChildItem -LiteralPath $previewCaseOutput -Filter '*_Cleaned_*.wav').Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $previewCaseOutput -Filter '*.partial' -Force).Count | Should -Be 1
        # All source/output handles must have been released on every terminal path.
        $sourceHandle = [IO.File]::Open($previewCaseInput, 'Open', 'ReadWrite', 'None')
        $sourceHandle.Dispose()
        if ($Fault -in @('cancel', 'range-invalid')) { $script:previewCalls.Count | Should -Be 0 }
        if ($Fault -eq 'publication-race') {
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($script:previewPublishSentinel)) | Should -BeExactly 'CQgH'
            @(Get-ChildItem -LiteralPath $previewCaseOutput -Filter 'WinAudioClean_Preview_*').Count | Should -Be 2
            $failureReport = Get-Content -Raw -LiteralPath $result.ReportPaths.JsonPath | ConvertFrom-Json
            $failureReport.status | Should -BeExactly 'FAILED'
            $failureReport.applicationExitCode | Should -Be 5
            $failureReport.progress.completed | Should -BeFalse
            @($failureReport.assets.PSObject.Properties).Count | Should -Be 0
        }
        if ($Fault -in @('valid', 'silence', 'short-preview', 'report-failure')) {
            $script:previewCalls.Count | Should -Be 8
            $script:previewRenderCount | Should -Be 4
            $script:previewMeasurementCount | Should -Be 4
            $result.Report.reportType | Should -BeExactly 'preview'
            $result.Report.assets.Count | Should -Be 4
            $result.Report.range.durationSeconds | Should -Be $script:previewExpectedDuration
            foreach ($call in $script:previewCalls) {
                $inputValue = $call.Arguments[[array]::IndexOf($call.Arguments, '-i') + 1]
                if ($inputValue -eq 'pipe:0') { $call.HadHeldInput | Should -BeTrue; $call.InputPosition | Should -Be 0 }
                else {
                    $call.Arguments[[array]::IndexOf($call.Arguments, '-t') + 1] | Should -BeExactly $script:previewExpectedDuration.ToString('0.###############', [Globalization.CultureInfo]::InvariantCulture)
                    $call.Arguments[[array]::IndexOf($call.Arguments, '-map') + 1] | Should -BeExactly '0:5'
                }
            }
            foreach ($role in @('CompareOriginal', 'CompareProcessed')) {
                $result.Report.assets[$role].gainDb | Should -BeLessOrEqual 0
                $result.Report.assets[$role].exactFilters | Should -Not -Match 'loudnorm|dynaudnorm|adeclip|afftdn|pan='
            }
            if ($Fault -eq 'report-failure') {
                $result.Report.reporting.complete | Should -BeFalse
                $result.Report.warningCodes | Should -Contain 'preview_reporting_failed'
                $result.ReportPaths | Should -BeNullOrEmpty
            } else {
                $result.Report.reporting.complete | Should -BeTrue
                @(Get-ChildItem -LiteralPath $previewCaseOutput -Filter 'WinAudioClean_Preview_*').Count | Should -Be 2
                Test-Path -LiteralPath $result.ReportPaths.JsonPath | Should -BeTrue
                Test-Path -LiteralPath $result.ReportPaths.TextPath | Should -BeTrue
                $json = Get-Content -Raw -LiteralPath $result.ReportPaths.JsonPath | ConvertFrom-Json
                $json.applicationExitCode | Should -Be $Exit
                ($json | ConvertTo-Json -Depth 20) | Should -Not -Match 'NaN|Infinity'
                if ($Fault -eq 'valid') { $json.matching.status | Should -BeExactly 'PASSED' }
                if ($Fault -in @('silence', 'short-preview')) {
                    $json.matching.status | Should -BeExactly 'UNMEASURABLE'
                    $json.matching.reason | Should -BeExactly $(if ($Fault -eq 'silence') { 'silence' } else { 'too_short' })
                    $json.matching.commonTargetLufs | Should -BeNullOrEmpty
                }
            }
        }
    }
}
