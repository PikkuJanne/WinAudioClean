BeforeDiscovery {
    $passCases = foreach ($culture in @('en-US', 'de-DE', 'fi-FI')) {
        foreach ($choice in @('1', '2')) {
            foreach ($channel in @(@{ Channels = 1; Mono = $false }, @{ Channels = 2; Mono = $false }, @{ Channels = 2; Mono = $true })) {
                @{ Culture = $culture; Choice = $choice; Channels = $channel.Channels; Mono = $channel.Mono }
            }
        }
    }
}

BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $repositoryRoot 'WinAudioClean.ps1')
    $baseline = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs\codex\winaudioclean\BASELINE.json') | ConvertFrom-Json

    function New-WacLoudnormTestJson {
        param([hashtable]$Replace = @{}, [string]$Omit = '')
        $data = [ordered]@{
            input_i = '-21.50'; input_tp = '-7.25'; input_lra = '3.50'; input_thresh = '-31.75'
            output_i = '-12.05'; output_tp = '-1.50'; output_lra = '3.40'; output_thresh = '-22.10'
            normalization_type = 'dynamic'; target_offset = '0.05'
        }
        foreach ($name in $Replace.Keys) { $data[$name] = $Replace[$name] }
        if ($Omit) { $data.Remove($Omit) }
        $data | ConvertTo-Json -Compress
    }

    function New-WacUndefinedLoudnormTestJson {
        param([string]$Peak = '-inf', [string]$Type = 'dynamic')
        New-WacLoudnormTestJson -Replace @{
            input_i = '-inf'; input_tp = $Peak; input_lra = '0.00'; input_thresh = '-70.00'
            output_i = '-inf'; output_tp = $Peak; output_lra = '0.00'; output_thresh = '-70.00'
            normalization_type = $Type; target_offset = 'inf'
        }
    }

    function Get-WacLoudnessTestProcess {
        [pscustomobject]@{
            Started = $true; ExitCode = 0; TimedOut = $false; Error = $null; CleanupError = $null
            StandardOutput = ''; StandardError = (New-WacLoudnormTestJson)
        }
    }

    function Get-WacLoudnessTestContext {
        $presetProfile = Get-WacProcessingProfile -Choice 2
        $stream = [pscustomobject]@{ Index = 5; Channels = 2; ChannelLayout = 'stereo'; Codec = 'pcm_s16le'; SampleRate = 48000; DurationSeconds = 12 }
        $policy = Get-WacOutputPolicy -InputAudio $stream
        @{
            Transaction = [pscustomobject]@{ JobId = '1234567890abcdef1234567890abcdef'; OutputFolder = $TestDrive; Published = $true
                InputPath = 'PRIVATE_INPUT.wav'; FinalPath = 'PRIVATE_OUTPUT.wav'; TempPath = 'PRIVATE_PARTIAL' }
            Stream = $stream; Policy = $policy; Process = (Get-WacLoudnessTestProcess); Profile = $presetProfile
            Mode = 'Zoom'; ModeName = $presetProfile.ModeName; FilterChain = $presetProfile.FilterChain
            StartedAt = [DateTime]::UtcNow; ElapsedSeconds = 0.75; ToolVersion = '2.3'; ExitCode = 0
            LoudnessMode = 'Accurate'; LoudnessWarnings = @()
            Normalization = [ordered]@{ requestedMode = 'Accurate'; actualType = 'linear'; linearRequested = $true; fallbackReason = $null
                renderFilter = 'PRIVATE_RENDER_FILTER'; analysis = @{ arguments = @('PRIVATE_ARG'); process = @{ StandardError = 'PRIVATE_STDERR' } } }
        }
    }
}

Describe 'AC-037: Accurate passes share the selected signal and invariant measured values' -Tag 'Loudness', 'Unit' {
    It 'keeps Original choice <Choice>, <Channels> channels, Mono=<Mono>, selected stream 5 in <Culture>' -ForEach $passCases {
        $previousCulture = [Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($Culture)
            $presetProfile = Get-WacProcessingProfile -Choice $Choice
            $audio = [pscustomobject]@{ Channels = $Channels; ChannelLayout = $(if ($Channels -eq 1) { 'mono' } else { 'stereo' }) }
            $policy = Get-WacOutputPolicy -InputAudio $audio -Mono:$Mono
            $measurement = ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson) -DurationSeconds 12
            $plan = Get-WacLoudnessPlan -Profile $presetProfile -OutputPolicy $policy -Measurement $measurement
            $prechain = $baseline.filters.level.Replace(',loudnorm=I=-12:TP=-1.5', '')
            if ($Choice -eq '1') { $prechain = $baseline.filters.raw_clean + ',' + $prechain }
            $prechain = $policy.FilterPrefix + $prechain + ',aresample=192000'
            $plan.Prechain | Should -BeExactly $prechain
            $plan.AnalysisFilter | Should -BeExactly ($prechain + ',loudnorm=I=-12:TP=-1.5:LRA=7:print_format=json')
            $plan.RenderFilter | Should -BeExactly ($prechain + ',loudnorm=I=-12:TP=-1.5:LRA=7:measured_I=-21.5:measured_TP=-7.25:measured_LRA=3.5:measured_thresh=-31.75:offset=0.05:linear=true:print_format=json')
            $plan.FinalMeasurementFilter | Should -BeExactly 'loudnorm=I=-12:TP=-1.5:LRA=7:print_format=json'
            $plan.LinearRequested | Should -BeTrue
            $plan.FallbackReason | Should -BeNullOrEmpty
            $plan.RenderFilter | Should -Not -Match 'target_offset='
            $passOne = Get-WacLoudnessArguments -InputPath 'input.wav' -FilterChain $plan.AnalysisFilter -AudioStreamIndex 5 -OutputPolicy $policy
            # Rendering already has the full prefix in its effective chain.
            $renderPolicy = [pscustomobject]@{}
            foreach ($property in $policy.PSObject.Properties) { $renderPolicy | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value }
            $renderPolicy.FilterPrefix = ''
            $passTwo = Get-WacFfmpegArguments -InputPath 'input.wav' -FilterChain $plan.RenderFilter -AudioStreamIndex 5 -OutputPolicy $renderPolicy -OutputFile 'owned.partial'
            foreach ($arguments in @($passOne, $passTwo)) {
                $arguments[[Array]::IndexOf($arguments, '-i') + 1] | Should -BeExactly 'input.wav'
                $arguments[[Array]::IndexOf($arguments, '-map') + 1] | Should -BeExactly '0:5'
                $arguments[[Array]::IndexOf($arguments, '-ac') + 1] | Should -BeExactly ([string]$policy.Channels)
                $arguments[[Array]::IndexOf($arguments, '-channel_layout') + 1] | Should -BeExactly $policy.Layout
                $filter = $arguments[[Array]::IndexOf($arguments, '-af') + 1]
                $filter.Substring(0, $filter.LastIndexOf(',loudnorm=')) | Should -BeExactly $prechain
                ([regex]::Matches($filter, 'loudnorm=')).Count | Should -Be 1
                ([regex]::Matches($filter, 'pan=')).Count | Should -Be $(if ($Mono -and $Channels -eq 2) { 1 } else { 0 })
            }
        } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $previousCulture }
    }

    It 'measures the frozen final WAV through pipe 0 without reapplying conversion or cleaning' {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 2; ChannelLayout = 'stereo' }) -Mono
        $plan = Get-WacLoudnessPlan -Profile (Get-WacProcessingProfile -Choice 1) -OutputPolicy $policy
        $arguments = Get-WacLoudnessArguments -FilterChain $plan.FinalMeasurementFilter -AudioStreamIndex 5 -OutputPolicy $policy -FromPipe
        $arguments | Should -BeExactly @('-nostdin', '-protocol_whitelist', 'pipe', '-format_whitelist', 'wav', '-f', 'wav', '-i', 'pipe:0',
            '-map', '0:0', '-vn', '-af', 'loudnorm=I=-12:TP=-1.5:LRA=7:print_format=json', '-f', 'null', '-', '-hide_banner', '-loglevel', 'info', '-nostats')
        $arguments | Should -Not -Contain '-ac'
        $arguments | Should -Not -Contain '-channel_layout'
    }

    It 'rejects an altered or duplicated terminal normalization filter' -ForEach @(
        @{ FilterChain = 'volume=2,loudnorm=I=-12:TP=-1.5' }
        @{ FilterChain = 'loudnorm=I=-12:TP=-1.5,loudnorm=I=-12:TP=-1.5' }
        @{ FilterChain = 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-15:TP=-1.5' }
    ) {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        { Get-WacLoudnessPlan -Profile ([pscustomobject]@{ FilterChain = $FilterChain }) -OutputPolicy $policy } | Should -Throw '*terminal normalization*'
    }
}

Describe 'AC-039: loudnorm diagnostics have a bounded strict schema' -Tag 'Loudness', 'Unit' {
    It 'extracts one real measurement block amid native diagnostics and unrelated braces' {
        $diagnostics = "Input file {recording}.wav`nnoise {ignored}`n[Parsed_loudnorm_2 @ test]`n" + (New-WacLoudnormTestJson) + "`nsize=N/A time=00:00:12.0"
        $measurement = ConvertFrom-WacLoudnormJson -StandardError $diagnostics -DurationSeconds 12
        $measurement.Available | Should -BeTrue
        $measurement.InputI | Should -Be (-21.5)
        $measurement.InputTP | Should -Be (-7.25)
        $measurement.InputLRA | Should -Be 3.5
        $measurement.InputThreshold | Should -Be (-31.75)
        $measurement.TargetOffset | Should -Be 0.05
        $measurement.NormalizationType | Should -BeExactly 'dynamic'
    }

    It 'accepts JSON numbers without using the local decimal separator' {
        $measurement = ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson -Replace @{ input_i = -21.5; target_offset = 0.05 }) -DurationSeconds 12
        $measurement.InputI | Should -Be (-21.5)
        $measurement.TargetOffset | Should -Be 0.05
    }

    It 'rejects <Case> without treating it as silence or short audio' -ForEach @(
        @{ Case = 'NaN'; Field = 'input_i'; Value = 'NaN' }
        @{ Case = 'Infinity'; Field = 'input_i'; Value = 'Infinity' }
        @{ Case = 'unpaired negative infinity'; Field = 'input_tp'; Value = '-inf' }
        @{ Case = 'unpaired infinite offset'; Field = 'target_offset'; Value = 'inf' }
        @{ Case = 'overflow exponent'; Field = 'input_i'; Value = '-1e999' }
        @{ Case = 'comma decimal'; Field = 'input_i'; Value = '-21,5' }
        @{ Case = 'thousands separator'; Field = 'input_i'; Value = '-2,150' }
        @{ Case = 'out of range integrated loudness'; Field = 'input_i'; Value = '-200' }
        @{ Case = 'out of range peak'; Field = 'input_tp'; Value = '100' }
        @{ Case = 'negative range'; Field = 'input_lra'; Value = '-0.01' }
        @{ Case = 'positive threshold'; Field = 'input_thresh'; Value = '0.01' }
        @{ Case = 'out of range offset'; Field = 'target_offset'; Value = '100' }
        @{ Case = 'unsupported normalization type'; Field = 'normalization_type'; Value = 'guessed' }
        @{ Case = 'array'; Field = 'input_i'; Value = @(-21.5) }
        @{ Case = 'null'; Field = 'input_i'; Value = $null }
    ) {
        $replacement = @{}; $replacement[$Field] = $Value
        $json = New-WacLoudnormTestJson -Replace $replacement
        { ConvertFrom-WacLoudnormJson -StandardError $json -DurationSeconds 0.2 } | Should -Throw
    }

    It 'rejects missing <Field> even on short input' -ForEach @(
        @{ Field = 'input_i' }; @{ Field = 'input_tp' }; @{ Field = 'input_lra' }; @{ Field = 'input_thresh' }
        @{ Field = 'output_i' }; @{ Field = 'output_tp' }; @{ Field = 'output_lra' }; @{ Field = 'output_thresh' }
        @{ Field = 'normalization_type' }; @{ Field = 'target_offset' }
    ) {
        { ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson -Omit $Field) -DurationSeconds 0.2 } | Should -Throw
    }

    It 'rejects malformed, duplicate, nested or oversized diagnostic blocks' -ForEach @(
        @{ Case = 'duplicate key' }; @{ Case = 'duplicate objects' }; @{ Case = 'truncated JSON' }
        @{ Case = 'nested object' }; @{ Case = 'unexpected field' }; @{ Case = 'oversized diagnostics' }
    ) {
        $json = New-WacLoudnormTestJson
        switch ($Case) {
            'duplicate key' { $json = $json.Replace('{', '{"input_i":"-20",') }
            'duplicate objects' { $json += "`n" + $json }
            'truncated JSON' { $json = $json.Substring(0, $json.Length - 1) }
            'nested object' { $json = '{"measurements":' + $json + '}' }
            'unexpected field' { $json = $json.Replace('{', '{"extra":"private",') }
            'oversized diagnostics' { $json = ('x' * 1048576) + "`n" + $json }
        }
        { ConvertFrom-WacLoudnormJson -StandardError $json -DurationSeconds 12 } | Should -Throw
    }
}

Describe 'AC-038/039: final encoded input measurements control compliance and explicit fallback' -Tag 'Loudness', 'Unit' {
    It 'uses measured input fields, with peak precedence for <Case>' -ForEach @(
        @{ Case = 'target'; Integrated = '-12.00'; Peak = '-1.50'; Status = 'PASSED'; Reason = $null }
        @{ Case = 'lower loudness boundary'; Integrated = '-12.50'; Peak = '-1.30'; Status = 'PASSED'; Reason = $null }
        @{ Case = 'upper loudness boundary'; Integrated = '-11.50'; Peak = '-1.30'; Status = 'PASSED'; Reason = $null }
        @{ Case = 'quiet'; Integrated = '-12.51'; Peak = '-2.00'; Status = 'OUT_OF_TOLERANCE'; Reason = 'loudness_out_of_tolerance' }
        @{ Case = 'hot'; Integrated = '-11.49'; Peak = '-2.00'; Status = 'OUT_OF_TOLERANCE'; Reason = 'loudness_out_of_tolerance' }
        @{ Case = 'peak failure'; Integrated = '-12.00'; Peak = '-1.29'; Status = 'OUT_OF_TOLERANCE'; Reason = 'true_peak_exceeded' }
        @{ Case = 'both failures'; Integrated = '-18.00'; Peak = '-1.00'; Status = 'OUT_OF_TOLERANCE'; Reason = 'true_peak_exceeded' }
    ) {
        $measurement = ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson -Replace @{ input_i = $Integrated; input_tp = $Peak }) -DurationSeconds 12
        $result = ConvertTo-WacFinalLoudness -Measurement $measurement
        $result.Measurements.integratedLufs.value | Should -Be ([double]::Parse($Integrated, [Globalization.CultureInfo]::InvariantCulture))
        $result.Measurements.truePeakDbtp.value | Should -Be ([double]::Parse($Peak, [Globalization.CultureInfo]::InvariantCulture))
        $result.Measurements.loudnessRangeLu.value | Should -Be 3.5
        $result.Compliance.status | Should -BeExactly $Status
        $result.Compliance.reason | Should -Be $Reason
    }

    It 'records <Case> without passing infinities to render or output JSON' -ForEach @(
        @{ Case = 'silence'; Duration = 3; Peak = '-inf'; Type = 'dynamic'; Reason = 'silence'; Status = 'UNMEASURABLE'; ComplianceReason = 'silence' }
        @{ Case = 'short linear observation'; Duration = 0.2; Peak = '-1.5'; Type = 'linear'; Reason = 'too_short'; Status = 'UNMEASURABLE'; ComplianceReason = 'too_short' }
        @{ Case = 'below measurement gate'; Duration = 3; Peak = '-60.0'; Type = 'dynamic'; Reason = 'undefined_loudness'; Status = 'UNMEASURABLE'; ComplianceReason = 'undefined_loudness' }
        @{ Case = 'short peak violation'; Duration = 0.2; Peak = '-0.5'; Type = 'linear'; Reason = 'too_short'; Status = 'OUT_OF_TOLERANCE'; ComplianceReason = 'true_peak_exceeded' }
    ) {
        $measurement = ConvertFrom-WacLoudnormJson -StandardError (New-WacUndefinedLoudnormTestJson -Peak $Peak -Type $Type) -DurationSeconds $Duration
        $measurement.Available | Should -BeFalse
        $measurement.Reason | Should -BeExactly $Reason
        $measurement.NormalizationType | Should -BeExactly $Type
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        $plan = Get-WacLoudnessPlan -Profile (Get-WacProcessingProfile -Choice 2) -OutputPolicy $policy -Measurement $measurement
        $plan.RenderFilter | Should -Match ':linear=false:print_format=json$'
        $plan.RenderFilter | Should -Not -Match 'measured_|offset=|inf|NaN'
        $plan.LinearRequested | Should -BeFalse
        $plan.FallbackReason | Should -BeExactly $Reason
        $result = ConvertTo-WacFinalLoudness -Measurement $measurement
        $result.Measurements.integratedLufs.value | Should -BeNullOrEmpty
        $result.Measurements.integratedLufs.reason | Should -BeExactly $Reason
        $result.Measurements.loudnessRangeLu.value | Should -BeNullOrEmpty
        if ($Peak -eq '-inf') { $result.Measurements.truePeakDbtp.reason | Should -BeExactly $Reason }
        else {
            $result.Measurements.truePeakDbtp.value | Should -Be ([double]::Parse($Peak, [Globalization.CultureInfo]::InvariantCulture))
            $result.Measurements.truePeakDbtp.reason | Should -BeNullOrEmpty
        }
        $result.Compliance.status | Should -BeExactly $Status
        $result.Compliance.reason | Should -BeExactly $ComplianceReason
        ($result | ConvertTo-Json -Depth 10) | Should -Not -Match 'NaN|Infinity|"[+-]?inf"'
    }

    It 'marks a finite subsecond measurement too short only after checking all fields' {
        $measurement = ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson) -DurationSeconds 0.9
        $measurement.Available | Should -BeFalse
        $measurement.Reason | Should -BeExactly 'too_short'
        $measurement.InputI | Should -BeNullOrEmpty
        $measurement.InputLRA | Should -BeNullOrEmpty
        $measurement.InputTP | Should -Be (-7.25)
    }

    It 'retains finite high LRA for FFmpeg to evaluate linear feasibility' {
        $measurement = ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson -Replace @{ input_lra = '18.0'; normalization_type = 'dynamic' }) -DurationSeconds 30
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        $plan = Get-WacLoudnessPlan -Profile (Get-WacProcessingProfile -Choice 2) -OutputPolicy $policy -Measurement $measurement
        $plan.LinearRequested | Should -BeTrue
        $plan.RenderFilter | Should -Match ':measured_LRA=18:'
        $measurement.NormalizationType | Should -BeExactly 'dynamic'
    }

    It 'retains finite <Field> below FFmpeg measured parameter bounds without passing it to pass two' -ForEach @(
        @{ Field = 'input_i'; Property = 'InputI' }
        @{ Field = 'input_tp'; Property = 'InputTP' }
        @{ Field = 'input_thresh'; Property = 'InputThreshold' }
    ) {
        $replacement = @{}; $replacement[$Field] = '-120.0'
        $measurement = ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson -Replace $replacement) -DurationSeconds 12
        $measurement.Available | Should -BeTrue
        $measurement.$Property | Should -Be (-120)
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        $plan = Get-WacLoudnessPlan -Profile (Get-WacProcessingProfile -Choice 2) -OutputPolicy $policy -Measurement $measurement
        $plan.LinearRequested | Should -BeFalse
        $plan.FallbackReason | Should -BeExactly 'measurement_out_of_range'
        $plan.RenderFilter | Should -Match ':linear=false:print_format=json$'
        $plan.RenderFilter | Should -Not -Match 'measured_|offset='
        if ($Field -eq 'input_tp') {
            (ConvertTo-WacFinalLoudness -Measurement $measurement).Measurements.truePeakDbtp.value | Should -Be (-120)
        }
    }
}

Describe 'AC-039: a native stage must succeed before its measurements can be used' -Tag 'Loudness', 'Unit' {
    It 'rejects <Case> even when stderr contains valid measurements' -ForEach @(
        @{ Case = 'start failure'; Field = 'Started'; Value = $false }
        @{ Case = 'native failure'; Field = 'ExitCode'; Value = 17 }
        @{ Case = 'missing exit'; Field = 'ExitCode'; Value = $null }
        @{ Case = 'timeout'; Field = 'TimedOut'; Value = $true }
        @{ Case = 'capture failure'; Field = 'Error'; Value = 'PRIVATE_CAPTURE_FAILURE' }
        @{ Case = 'cleanup failure'; Field = 'CleanupError'; Value = 'PRIVATE_CLEANUP_FAILURE' }
    ) {
        $nativeProcess = Get-WacLoudnessTestProcess
        $nativeProcess.$Field = $Value
        $stage = ConvertTo-WacLoudnessStage -Process $nativeProcess -DurationSeconds 12 -Arguments @('-map', '0:5')
        $stage.status | Should -BeExactly 'FAILED'
        $stage.measurement | Should -BeNullOrEmpty
        $stage.error | Should -BeExactly 'Loudness native process failed.'
        $stage.process.$Field | Should -Be $Value
        $stage.arguments | Should -BeExactly @('-map', '0:5')
    }

    It 'records malformed successful-process diagnostics as measurement failure' {
        $nativeProcess = Get-WacLoudnessTestProcess
        $nativeProcess.StandardError = 'PRIVATE_DIAGNOSTICS without JSON'
        $stage = ConvertTo-WacLoudnessStage -Process $nativeProcess -DurationSeconds 12 -Arguments @('-i', 'pipe:0') -InputSource 'held_output_stream'
        $stage.status | Should -BeExactly 'FAILED'
        $stage.process.ExitCode | Should -Be 0
        $stage.process.StandardError | Should -BeExactly 'PRIVATE_DIAGNOSTICS without JSON'
        $stage.measurement | Should -BeNullOrEmpty
        $stage.error | Should -Not -BeNullOrEmpty
        $stage.inputSource | Should -BeExactly 'held_output_stream'
    }

    It 'distinguishes a successful silence measurement from native or parser failure' {
        $nativeProcess = Get-WacLoudnessTestProcess
        $nativeProcess.StandardError = New-WacUndefinedLoudnormTestJson
        $stage = ConvertTo-WacLoudnessStage -Process $nativeProcess -DurationSeconds 12 -Arguments @('-i', 'pipe:0') -InputSource 'held_output_stream'
        $stage.status | Should -BeExactly 'PASSED'
        $stage.error | Should -BeNullOrEmpty
        $stage.measurement.Available | Should -BeFalse
        $stage.measurement.Reason | Should -BeExactly 'silence'
    }
}

Describe 'AC-038/039: loudness warnings stay separate from publication and report completeness' -Tag 'Loudness', 'RunReports', 'Unit' {
    It 'records a complete successful Accurate report with achieved values and separate requested targets' {
        $context = Get-WacLoudnessTestContext
        $measured = ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson -Replace @{ input_i = '-12.10'; input_tp = '-1.45' }) -DurationSeconds 12
        $context.FinalLoudness = ConvertTo-WacFinalLoudness -Measurement $measured
        $report = New-WacRunReport -Context $context
        $report.status | Should -BeExactly 'SUCCESS'
        $report.processingStatus | Should -BeExactly 'SUCCESS'
        $report.applicationExitCode | Should -Be 0
        $report.reporting.complete | Should -BeTrue
        $report.output.published | Should -BeTrue
        $report.settings.loudnessMode | Should -BeExactly 'Accurate'
        $report.settings.exactFilters | Should -BeExactly 'PRIVATE_RENDER_FILTER'
        $report.requestedTargets.integratedLufs | Should -Be (-12)
        $report.requestedTargets.truePeakDbtp | Should -Be (-1.5)
        $report.requestedTargets.loudnessRangeLu | Should -Be 7
        $report.measurements.integratedLufs.value | Should -Be (-12.1)
        $report.measurements.truePeakDbtp.value | Should -Be (-1.45)
        $report.loudnessCompliance.status | Should -BeExactly 'PASSED'
        $report.normalization.actualType | Should -BeExactly 'linear'
        $report.presetVersion | Should -BeExactly '1.0.0'
        $report.toolVersion | Should -BeExactly '2.3'
    }

    It 'keeps a published quality warning at exit 7 while every report is complete' {
        $context = Get-WacLoudnessTestContext
        $context.FinalLoudness = ConvertTo-WacFinalLoudness -Measurement (ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson) -DurationSeconds 12)
        $context.LoudnessWarnings = @('final_loudness_out_of_tolerance')
        $report = New-WacRunReport -Context $context
        $report.status | Should -BeExactly 'WARNING'
        $report.applicationExitCode | Should -Be 7
        $report.processingStatus | Should -BeExactly 'SUCCESS'
        $report.processingExitCode | Should -Be 0
        $report.nativeExitCode | Should -Be 0
        $report.output.published | Should -BeTrue
        $report.output.validity | Should -BeExactly 'PASSED'
        $report.reporting.complete | Should -BeTrue
        $report.reporting.errors.Count | Should -Be 0
        $report.loudnessCompliance.status | Should -BeExactly 'OUT_OF_TOLERANCE'
        Update-WacReportOutcome -Report $report
        $report.status | Should -BeExactly 'WARNING'
        $report.applicationExitCode | Should -Be 7
        $text = Format-WacRunReport -Report $report
        $text | Should -Match 'STATUS\s+: WARNING'
        $text | Should -Match 'LOUDNESS CHECK\s*: OUT_OF_TOLERANCE; loudness_out_of_tolerance'
        $text | Should -Match 'VALIDITY\s+: PASSED'
    }

    It 'preserves the processing failure when quality and reporting warnings coexist' {
        $context = Get-WacLoudnessTestContext
        $context.ExitCode = 4
        $context.Process.ExitCode = 17
        $context.Transaction.Published = $false
        $context.LoudnessWarnings = @('normalization_fallback')
        $report = New-WacRunReport -Context $context
        Add-WacReportFailure -Report $report -Code 'text_report_failed' -Message 'PRIVATE_WRITE_FAILURE'
        $report.status | Should -BeExactly 'FAILED'
        $report.processingStatus | Should -BeExactly 'FAILED'
        $report.applicationExitCode | Should -Be 4
        $report.nativeExitCode | Should -Be 17
        $report.output.published | Should -BeFalse
        $report.reporting.complete | Should -BeFalse
        $report.warningCodes | Should -Contain 'normalization_fallback'
        $report.warningCodes | Should -Contain 'text_report_failed'
    }

    It 'keeps Fast metrics unmeasured with no quality warning' {
        $context = Get-WacLoudnessTestContext
        $context.Remove('LoudnessMode')
        $context.Normalization = $null
        $report = New-WacRunReport -Context $context
        $report.settings.loudnessMode | Should -BeExactly 'Fast'
        $report.status | Should -BeExactly 'SUCCESS'
        $report.applicationExitCode | Should -Be 0
        $report.reporting.complete | Should -BeTrue
        $report.warningCodes.Count | Should -Be 0
        $report.loudnessCompliance.status | Should -BeExactly 'NOT_MEASURED'
        foreach ($name in @('integratedLufs', 'truePeakDbtp', 'loudnessRangeLu')) {
            $report.measurements[$name].value | Should -BeNullOrEmpty
            $report.measurements[$name].reason | Should -BeExactly 'not_measured'
        }
    }
}

Describe 'AC-029/038: support export keeps typed loudness facts and fixed labels only' -Tag 'Loudness', 'RunReports', 'Unit' {
    It 'retains allowed loudness modes, observed type, fallback and finite metrics without native stages' {
        $context = Get-WacLoudnessTestContext
        $context.Normalization.actualType = 'dynamic'
        $context.Normalization.fallbackReason = 'ffmpeg_dynamic_fallback'
        $context.FinalLoudness = ConvertTo-WacFinalLoudness -Measurement (ConvertFrom-WacLoudnormJson -StandardError (New-WacLoudnormTestJson) -DurationSeconds 12)
        $safe = ConvertTo-WacRedactedReport -Report (New-WacRunReport -Context $context)
        $safe.settings.loudnessMode | Should -BeExactly 'Accurate'
        $safe.normalization.requestedMode | Should -BeExactly 'Accurate'
        $safe.normalization.actualType | Should -BeExactly 'dynamic'
        $safe.normalization.linearRequested | Should -BeTrue
        $safe.normalization.fallbackReason | Should -BeExactly 'ffmpeg_dynamic_fallback'
        $safe.loudnessCompliance.status | Should -BeExactly 'OUT_OF_TOLERANCE'
        $safe.loudnessCompliance.reason | Should -BeExactly 'loudness_out_of_tolerance'
        $safe.measurements.integratedLufs.value | Should -Be (-21.5)
        $safe.measurements.truePeakDbtp.value | Should -Be (-7.25)
        $safe.measurements.loudnessRangeLu.value | Should -Be 3.5
        ($safe | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE_|analysis|arguments|renderFilter|standardError'
    }

    It 'retains approved unavailable metric reason <Reason>' -ForEach @(
        @{ Reason = 'not_measured' }; @{ Reason = 'unavailable' }; @{ Reason = 'too_short' }; @{ Reason = 'silence' }
        @{ Reason = 'undefined_loudness' }; @{ Reason = 'measurement_failed' }; @{ Reason = 'nonfinite' }; @{ Reason = 'not_numeric' }
    ) {
        $report = New-WacRunReport -Context (Get-WacLoudnessTestContext)
        $report.measurements.integratedLufs = @{ value = $null; reason = $Reason }
        $safe = ConvertTo-WacRedactedReport -Report $report
        $safe.measurements.integratedLufs.value | Should -BeNullOrEmpty
        $safe.measurements.integratedLufs.reason | Should -BeExactly $Reason
    }

    It 'rejects nonnumeric or nonfinite metric <Case> without accepting a supplied reason' -ForEach @(
        @{ Case = 'numeric string'; Value = '-12.0'; Reason = 'not_numeric' }
        @{ Case = 'private string'; Value = 'PRIVATE_NUMBER'; Reason = 'not_numeric' }
        @{ Case = 'boolean'; Value = $true; Reason = 'not_numeric' }
        @{ Case = 'NaN'; Value = [double]::NaN; Reason = 'nonfinite' }
        @{ Case = 'infinity'; Value = [double]::PositiveInfinity; Reason = 'nonfinite' }
    ) {
        $report = New-WacRunReport -Context (Get-WacLoudnessTestContext)
        $report.measurements.integratedLufs = @{ value = $Value; reason = 'PRIVATE_REASON' }
        $safe = ConvertTo-WacRedactedReport -Report $report
        $safe.measurements.integratedLufs.value | Should -BeNullOrEmpty
        $safe.measurements.integratedLufs.reason | Should -BeExactly $Reason
        ($safe | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE_|NaN|Infinity'
    }

    It 'drops arbitrary labels and native-stage strings from a malicious report' {
        $report = New-WacRunReport -Context (Get-WacLoudnessTestContext)
        $report.settings.loudnessMode = 'PRIVATE_MODE'
        $report.normalization.requestedMode = 'PRIVATE_REQUEST'
        $report.normalization.actualType = 'PRIVATE_TYPE'
        $report.normalization.linearRequested = 'PRIVATE_BOOLEAN'
        $report.normalization.fallbackReason = 'PRIVATE_FALLBACK'
        $report.loudnessCompliance.status = 'PRIVATE_STATUS'
        $report.loudnessCompliance.reason = 'PRIVATE_COMPLIANCE_REASON'
        $report.measurements.integratedLufs.reason = 'PRIVATE_METRIC_REASON'
        $safe = ConvertTo-WacRedactedReport -Report $report
        $safe.settings.loudnessMode | Should -BeNullOrEmpty
        $safe.normalization.requestedMode | Should -BeNullOrEmpty
        $safe.normalization.actualType | Should -BeNullOrEmpty
        $safe.normalization.linearRequested | Should -BeNullOrEmpty
        $safe.normalization.fallbackReason | Should -BeNullOrEmpty
        $safe.loudnessCompliance.status | Should -BeNullOrEmpty
        $safe.loudnessCompliance.reason | Should -BeNullOrEmpty
        ($safe | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE_|analysis|arguments|renderFilter'
    }
}
