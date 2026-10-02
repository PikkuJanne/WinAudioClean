BeforeDiscovery {
    $numericBounds = @(
        @{ Name = 'HighpassHz'; Minimum = 20; Maximum = 200 }
        @{ Name = 'NoiseFloorDb'; Minimum = -80; Maximum = -20 }
        @{ Name = 'NoiseReductionDb'; Minimum = 0.01; Maximum = 20 }
        @{ Name = 'GateThresholdDb'; Minimum = -80; Maximum = -20 }
        @{ Name = 'GateRangeDb'; Minimum = -60; Maximum = 0 }
    )
    $boundaryCases = foreach ($bound in $numericBounds) {
        foreach ($edge in @('Minimum', 'Maximum')) {
            @{ Name = $bound.Name; Edge = $edge; Value = $bound[$edge] }
        }
    }
    $outsideCases = foreach ($bound in $numericBounds) {
        @{ Name = $bound.Name; Edge = 'below'; Value = $bound.Minimum - 0.001 }
        @{ Name = $bound.Name; Edge = 'above'; Value = $bound.Maximum + 0.001 }
    }
    $badNumberCases = foreach ($bound in $numericBounds) {
        foreach ($invalid in @(
            @{ Case = 'numeric string'; Value = '60' }
            @{ Case = 'filter injection'; Value = '60,volume=100' }
            @{ Case = 'argument injection'; Value = '60 -i https://invalid.example/input' }
            @{ Case = 'expression string'; Value = '$(throw "injected")' }
            @{ Case = 'locale decimal string'; Value = '-35,5' }
            @{ Case = 'null'; Value = $null }
            @{ Case = 'boolean'; Value = $true }
            @{ Case = 'one-element array'; Value = @(60) }
            @{ Case = 'empty array'; Value = @() }
            @{ Case = 'nested dictionary'; Value = @{ value = 60 } }
            @{ Case = 'object'; Value = [pscustomobject]@{ value = 60 } }
            @{ Case = 'NaN'; Value = [double]::NaN }
            @{ Case = 'positive infinity'; Value = [double]::PositiveInfinity }
            @{ Case = 'negative infinity'; Value = [double]::NegativeInfinity }
            @{ Case = 'single infinity'; Value = [single]::PositiveInfinity }
        )) {
            @{ Name = $bound.Name; Case = $invalid.Case; Value = $invalid.Value }
        }
    }
    $badToggleCases = foreach ($name in @('Declip', 'Declick', 'Denoise', 'Gate')) {
        foreach ($invalid in @(
            @{ Case = 'true string'; Value = 'true' }
            @{ Case = 'false string'; Value = 'false' }
            @{ Case = 'filter string'; Value = 'false,volume=100' }
            @{ Case = 'one'; Value = 1 }
            @{ Case = 'zero'; Value = 0 }
            @{ Case = 'null'; Value = $null }
            @{ Case = 'array'; Value = @($true) }
            @{ Case = 'dictionary'; Value = @{ value = $true } }
        )) {
            @{ Name = $name; Case = $invalid.Case; Value = $invalid.Value }
        }
    }
    $toggleCases = foreach ($name in @('Declip', 'Declick', 'Denoise', 'Gate')) {
        foreach ($enabled in @($false, $true)) { @{ Name = $name; Enabled = $enabled } }
    }
    $customCultureCases = foreach ($culture in @('en-US', 'de-DE', 'fi-FI')) {
        foreach ($preset in @('Original', 'Gentle')) { @{ Culture = $culture; Preset = $preset } }
    }
}

BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $repositoryRoot 'WinAudioClean.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    # These literal chains are independent expectations, not production values.
    $originalRaw = 'adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
    $originalZoom = 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
    $gentleRaw = 'highpass=f=60,afftdn=nf=-35:nr=6,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'

    function New-WacCleaningReportContext {
        param($ProcessingProfile)
        $stream = [pscustomobject]@{ Index = 0; Channels = 1; ChannelLayout = 'mono'; Codec = 'pcm_s16le'; SampleRate = 48000; DurationSeconds = 12 }
        @{
            Profile = $ProcessingProfile; FilterChain = $ProcessingProfile.FilterChain
            Mode = $(if ($ProcessingProfile.ModeChoice -eq '1') { 'Raw' } else { 'Zoom' }); ModeName = $ProcessingProfile.ModeName
            Policy = (Get-WacOutputPolicy -InputAudio $stream); Stream = $stream
            Transaction = [pscustomobject]@{ JobId = '1234567890abcdef1234567890abcdef'; InputPath = 'PRIVATE_INPUT.wav'
                FinalPath = 'PRIVATE_OUTPUT.wav'; TempPath = 'PRIVATE_PARTIAL'; OutputFolder = $TestDrive; Published = $true }
            Process = [pscustomobject]@{ Started = $true; ExitCode = 0; TimedOut = $false; StandardOutput = ''; StandardError = ''
                Error = $null; CleanupError = $null }
            StartedAt = [DateTime]::UtcNow; ElapsedSeconds = 0.5; ToolVersion = '2.3'; ExitCode = 0
        }
    }
}

Describe 'AC-040: cleaning settings have a strict typed and bounded schema' -Tag 'Cleaning', 'Unit' {
    It 'accepts the inclusive <Edge> for <Name>' -ForEach $boundaryCases {
        $options = @{}; $options[$Name] = $Value
        $settings = Get-WacCleaningSettings -Preset Original -Options $options
        $settings.$Name | Should -Be $Value
        $settings.schemaVersion | Should -Be 1
        $settings.$Name | Should -Not -BeOfType ([string])
        (Get-WacProcessingProfile -Choice 1 -CleaningOptions $options).CleaningSettings.$Name | Should -Be $Value
    }

    It 'rejects values <Edge> the <Name> range' -ForEach $outsideCases {
        $options = @{}; $options[$Name] = $Value
        { Get-WacCleaningSettings -Options $options } | Should -Throw
        { Get-WacProcessingProfile -Choice 1 -CleaningOptions $options } | Should -Throw
    }

    It 'rejects <Case> for numeric <Name>' -ForEach $badNumberCases {
        $options = @{}; $options[$Name] = $Value
        { Get-WacCleaningSettings -Options $options } | Should -Throw
        { Get-WacProcessingProfile -Choice 1 -CleaningOptions $options } | Should -Throw
    }

    It 'rejects <Case> for boolean <Name>' -ForEach $badToggleCases {
        $options = @{}; $options[$Name] = $Value
        { Get-WacCleaningSettings -Options $options } | Should -Throw
        { Get-WacProcessingProfile -Choice 1 -CleaningOptions $options } | Should -Throw
    }

    It 'accepts actual numeric scalar type <Type>' -ForEach @(
        @{ Type = 'byte'; Value = [byte]60 }
        @{ Type = 'sbyte'; Value = [sbyte]60 }
        @{ Type = 'int16'; Value = [int16]60 }
        @{ Type = 'uint16'; Value = [uint16]60 }
        @{ Type = 'int32'; Value = [int32]60 }
        @{ Type = 'uint32'; Value = [uint32]60 }
        @{ Type = 'int64'; Value = [int64]60 }
        @{ Type = 'uint64'; Value = [uint64]60 }
        @{ Type = 'single'; Value = [single]60.5 }
        @{ Type = 'double'; Value = [double]60.5 }
        @{ Type = 'decimal'; Value = [decimal]60.5 }
    ) {
        $settings = Get-WacCleaningSettings -Options @{ HighpassHz = $Value }
        $settings.HighpassHz | Should -Be $Value
        $settings.HighpassHz | Should -Not -BeOfType ([string])
    }

    It 'rejects unknown or reserved option <Name>' -ForEach @(
        @{ Name = 'FilterChain' }; @{ Name = 'highpass' }; @{ Name = 'OutputPath' }; @{ Name = 'schemaVersion' }
        @{ Name = 'NoiseReductionDb,volume=100' }; @{ Name = '' }
    ) {
        $options = @{}; $options[$Name] = 'PRIVATE_FILTER,volume=100'
        { Get-WacCleaningSettings -Options $options } | Should -Throw
        { Get-WacProcessingProfile -Choice 1 -CleaningOptions $options } | Should -Throw
    }

    It 'rejects a non-string dictionary key' {
        $options = @{}; $options[42] = $true
        { Get-WacCleaningSettings -Options $options } | Should -Throw
    }

    It 'rejects an explicitly null options dictionary' {
        { Get-WacCleaningSettings -Options $null } | Should -Throw
        { Get-WacProcessingProfile -Choice 1 -CleaningOptions $null } | Should -Throw
    }

    It 'rejects unsupported preset <Preset>' -ForEach @(
        @{ Preset = 'automatic' }; @{ Preset = 'Gentle,volume=100' }; @{ Preset = '' }
    ) {
        { Get-WacProcessingProfile -Choice 1 -Preset $Preset } | Should -Throw
        { Get-WacCleaningSettings -Preset $Preset } | Should -Throw
    }

    It 'does not mutate the caller options or retain a mutable alias' {
        $options = [ordered]@{ HighpassHz = 60; Denoise = $false }
        $profile = Get-WacProcessingProfile -Choice 1 -CleaningOptions $options
        @($options.Keys) | Should -BeExactly @('HighpassHz', 'Denoise')
        $options.HighpassHz = 200
        $profile.CleaningSettings.HighpassHz | Should -Be 60
        $profile.CleaningSettings.Denoise | Should -BeFalse
    }
}

Describe 'AC-040/041: validated options build only the chosen cleaning stages' -Tag 'Cleaning', 'Unit' {
    It 'sets <Name> to <Enabled> using an actual boolean' -ForEach $toggleCases {
        $options = @{}; $options[$Name] = $Enabled
        $profile = Get-WacProcessingProfile -Choice 1 -CleaningOptions $options
        $profile.CleaningSettings.$Name | Should -BeOfType ([bool])
        $profile.CleaningSettings.$Name | Should -Be $Enabled
        $profile.CleaningCustomized | Should -BeTrue
        $stage = switch ($Name) { 'Declip' { 'adeclip' } 'Declick' { 'adeclick' } 'Denoise' { 'afftdn=nf=-25' } 'Gate' { 'agate=range=0.056:threshold=0.0056' } }
        if ($Enabled) { $profile.FilterChain | Should -BeExactly $originalRaw }
        else { $profile.FilterChain | Should -BeExactly $originalRaw.Replace($stage + ',', '') }
    }

    It 'keeps highpass and leveling when all optional cleaning stages are disabled' {
        $profile = Get-WacProcessingProfile -Choice 1 -CleaningOptions @{ Declip = $false; Declick = $false; Denoise = $false; Gate = $false }
        $profile.FilterChain | Should -BeExactly ('highpass=f=80,' + $originalZoom)
    }

    It 'uses dB-derived linear gate coefficients for changed threshold and range' {
        $profile = Get-WacProcessingProfile -Choice 1 -CleaningOptions @{ GateThresholdDb = -40; GateRangeDb = -20 }
        $profile.FilterChain | Should -Match '(?:^|,)agate=range=0\.1:threshold=0\.01(?:,|$)'
        $profile.FilterChain | Should -Match ([regex]::Escape($originalZoom) + '$')
    }

    It 'serializes each custom value invariantly in <Culture> for <Preset>' -ForEach $customCultureCases {
        $previousCulture = [Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($Culture)
            $profile = Get-WacProcessingProfile -Choice 1 -Preset $Preset -CleaningOptions @{
                Declip = $true; Declick = $true; Denoise = $true; Gate = $true
                HighpassHz = 75.5; NoiseFloorDb = -35.5; NoiseReductionDb = 6.25; GateThresholdDb = -40; GateRangeDb = -20
            }
            $profile.FilterChain | Should -BeExactly ('adeclip,highpass=f=75.5,adeclick,afftdn=nf=-35.5:nr=6.25,agate=range=0.1:threshold=0.01,' + $originalZoom)
            $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 2; ChannelLayout = 'stereo' }) -Mono
            $plan = Get-WacLoudnessPlan -Profile $profile -OutputPolicy $policy
            $prechain = 'pan=mono|c0=0.5*c0+0.5*c1,' + $profile.FilterChain.Replace(',loudnorm=I=-12:TP=-1.5', '') + ',aresample=192000'
            $plan.Prechain | Should -BeExactly $prechain
            $plan.AnalysisFilter | Should -BeExactly ($prechain + ',loudnorm=I=-12:TP=-1.5:LRA=7:print_format=json')
            $plan.RenderFilter | Should -BeExactly ($prechain + ',loudnorm=I=-12:TP=-1.5:LRA=7:linear=false:print_format=json')
        } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $previousCulture }
    }
}

Describe 'AC-041: no-extra-options profiles preserve Original Raw and Zoom' -Tag 'Cleaning', 'Unit' {
    It 'retains Original Raw identity, exact baseline text and typed defaults' {
        $profile = Get-WacProcessingProfile -Choice 1
        $profile.PresetId | Should -BeExactly 'original'
        $profile.PresetVersion | Should -BeExactly '1.0.0'
        $profile.PresetExperimental | Should -BeFalse
        $profile.CleaningCustomized | Should -BeFalse
        $profile.ModeChoice | Should -BeExactly '1'
        $profile.FilterChain | Should -BeExactly $originalRaw
        $profile.CleaningSettings.schemaVersion | Should -Be 1
        foreach ($name in @('Declip', 'Declick', 'Denoise', 'Gate')) { $profile.CleaningSettings.$name | Should -BeTrue }
        $profile.CleaningSettings.HighpassHz | Should -Be 80
        $profile.CleaningSettings.NoiseFloorDb | Should -Be (-25)
        $profile.CleaningSettings.NoiseReductionDb | Should -Be 12
        $profile.CleaningSettings.GateThresholdDb | Should -Be (-45)
        $profile.CleaningSettings.GateRangeDb | Should -Be (-25)
    }

    It 'retains Original Zoom with no cleaning stages' {
        $profile = Get-WacProcessingProfile -Choice 2
        $profile.FilterChain | Should -BeExactly $originalZoom
        $profile.PresetId | Should -BeExactly 'original'
        $profile.PresetVersion | Should -BeExactly '1.0.0'
        $profile.PresetExperimental | Should -BeFalse
        $profile.CleaningCustomized | Should -BeFalse
        $profile.ModeChoice | Should -BeExactly '2'
    }

    It 'makes Gentle an explicit experimental candidate while keeping the leveling chain' {
        $profile = Get-WacProcessingProfile -Choice 1 -Preset Gentle
        $profile.PresetId | Should -BeExactly 'gentle'
        $profile.PresetVersion | Should -BeExactly '0.1.0'
        $profile.PresetExperimental | Should -BeTrue
        $profile.CleaningCustomized | Should -BeFalse
        $profile.FilterChain | Should -BeExactly $gentleRaw
        $profile.CleaningSettings.Declip | Should -BeFalse
        $profile.CleaningSettings.Declick | Should -BeFalse
        $profile.CleaningSettings.Denoise | Should -BeTrue
        $profile.CleaningSettings.Gate | Should -BeFalse
        $profile.CleaningSettings.HighpassHz | Should -Be 60
        $profile.CleaningSettings.NoiseFloorDb | Should -Be (-35)
        $profile.CleaningSettings.NoiseReductionDb | Should -Be 6
    }

    It 'marks explicit built-in value overrides customized without changing the original graph' {
        $profile = Get-WacProcessingProfile -Choice 1 -CleaningOptions @{ HighpassHz = 80; NoiseReductionDb = 12; GateThresholdDb = -45; GateRangeDb = -25 }
        $profile.FilterChain | Should -BeExactly $originalRaw
        $profile.CleaningCustomized | Should -BeTrue
    }

    It 'accepts an explicitly empty Original options dictionary for Zoom' {
        (Get-WacProcessingProfile -Choice 2 -Preset Original -CleaningOptions @{}).FilterChain | Should -BeExactly $originalZoom
    }

    It 'rejects <Case> for Zoom' -ForEach @(
        @{ Case = 'Gentle'; Preset = 'Gentle'; Options = @{} }
        @{ Case = 'declipping'; Preset = 'Original'; Options = @{ Declip = $false } }
        @{ Case = 'numeric change'; Preset = 'Original'; Options = @{ HighpassHz = 60 } }
        @{ Case = 'explicit original value'; Preset = 'Original'; Options = @{ HighpassHz = 80 } }
        @{ Case = 'unknown setting'; Preset = 'Original'; Options = @{ FilterChain = 'volume=100' } }
    ) {
        { Get-WacProcessingProfile -Choice 2 -Preset $Preset -CleaningOptions $Options } | Should -Throw
    }
}

Describe 'AC-040: Accurate accepts only reconstructed validated profiles' -Tag 'Cleaning', 'Loudness', 'Unit' {
    It 'supports the validated <Preset> preset in analysis and measured rendering' -ForEach @(
        @{ Preset = 'Original' }; @{ Preset = 'Gentle' }
    ) {
        $profile = Get-WacProcessingProfile -Choice 1 -Preset $Preset
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        $measurement = [pscustomobject]@{ Available = $true; InputI = -21.5; InputTP = -7.25; InputLRA = 3.5; InputThreshold = -31.75; TargetOffset = 0.05 }
        $plan = Get-WacLoudnessPlan -Profile $profile -OutputPolicy $policy -Measurement $measurement
        $expected = $profile.FilterChain.Replace(',loudnorm=I=-12:TP=-1.5', '') + ',aresample=192000'
        $plan.Prechain | Should -BeExactly $expected
        $plan.AnalysisFilter | Should -BeExactly ($expected + ',loudnorm=I=-12:TP=-1.5:LRA=7:print_format=json')
        $plan.RenderFilter | Should -BeExactly ($expected + ',loudnorm=I=-12:TP=-1.5:LRA=7:measured_I=-21.5:measured_TP=-7.25:measured_LRA=3.5:measured_thresh=-31.75:offset=0.05:linear=true:print_format=json')
    }

    It 'rejects a profile with tampered <Field>' -ForEach @(
        @{ Field = 'FilterChain'; Value = 'volume=100,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5' }
        @{ Field = 'PresetId'; Value = 'other' }
        @{ Field = 'PresetVersion'; Value = '99.0.0' }
        @{ Field = 'ModeChoice'; Value = '2' }
        @{ Field = 'CleaningSettings'; Value = @{ schemaVersion = 1; HighpassHz = '60,volume=100' } }
    ) {
        $profile = Get-WacProcessingProfile -Choice 1 -Preset Gentle
        $profile.$Field = $Value
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        { Get-WacLoudnessPlan -Profile $profile -OutputPolicy $policy } | Should -Throw
    }

    It 'rejects modified effective settings that no longer describe the graph' {
        $profile = Get-WacProcessingProfile -Choice 1 -Preset Gentle
        $profile.CleaningSettings.HighpassHz = 200
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        { Get-WacLoudnessPlan -Profile $profile -OutputPolicy $policy } | Should -Throw
    }

    It 'rejects a false customization flag on settings changed from the base preset' {
        $profile = Get-WacProcessingProfile -Choice 1 -CleaningOptions @{ HighpassHz = 60 }
        $profile.CleaningCustomized = $false
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        { Get-WacLoudnessPlan -Profile $profile -OutputPolicy $policy } | Should -Throw
    }

    It 'rejects a true customization flag for Zoom' {
        $profile = Get-WacProcessingProfile -Choice 2
        $profile.CleaningCustomized = $true
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        { Get-WacLoudnessPlan -Profile $profile -OutputPolicy $policy } | Should -Throw
    }

    It 'rejects a case-duplicate option dictionary' {
        $options = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
        $options.Add('GateThresholdDb', -45.0)
        $options.Add('gateThresholdDb', -45.0)
        { Get-WacCleaningSettings -Options $options } | Should -Throw
    }

    It 'rejects an effective schema with case-duplicate keys replacing a required field' {
        $profile = Get-WacProcessingProfile -Choice 1
        $effective = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
        foreach ($key in $profile.CleaningSettings.Keys) {
            if ($key -ne 'GateRangeDb') { $effective.Add($key, $profile.CleaningSettings[$key]) }
        }
        $effective.Add('gateThresholdDb', -45.0)
        $profile.CleaningSettings = $effective
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        { Get-WacLoudnessPlan -Profile $profile -OutputPolicy $policy } | Should -Throw
    }

    It 'rejects a fake profile containing only a previously allowlisted Original graph' {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        { Get-WacLoudnessPlan -Profile ([pscustomobject]@{ FilterChain = $originalRaw }) -OutputPolicy $policy } | Should -Throw
    }

    It 'rejects a fake profile with arbitrary filter-like identity strings' {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1; ChannelLayout = 'mono' })
        $profile = [pscustomobject]@{ PresetId = 'original,volume=100'; PresetVersion = '1.0.0'; ModeChoice = '1'; FilterChain = $originalRaw; CleaningSettings = (Get-WacCleaningSettings) }
        { Get-WacLoudnessPlan -Profile $profile -OutputPolicy $policy } | Should -Throw
    }
}

Describe 'AC-040/041: invalid CLI cleaning fails before output or dependency side effects' -Tag 'Cleaning', 'EntryPoint' {
    BeforeAll {
        $currentShell = (Get-Process -Id $PID).Path
        $appFolder = Join-Path $TestDrive 'isolated cleaning app'
        $null = [IO.Directory]::CreateDirectory($appFolder)
        foreach ($name in @('WinAudioClean.ps1', 'WinAudioClean.IO.ps1')) {
            Copy-Item -LiteralPath (Join-Path $repositoryRoot $name) -Destination (Join-Path $appFolder $name)
        }
        $appPath = Join-Path $appFolder 'WinAudioClean.ps1'
        $inputFile = Join-Path $appFolder 'synthetic input [1].wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]](1, 2, 3, 4))
        $missingDependency = Join-Path $appFolder 'missing dependency.exe'
        $driverPath = Join-Path $appFolder 'Invoke-CleaningCase.ps1'
        $driverCode = @'
param([string]$AppPath, [string]$InputFile, [string]$OutputFolder, [string]$MissingDependency, [string]$Case)
$preset = 'Original'
$mode = 'Raw'
$options = @{}
switch ($Case) {
    'unknown preset' { $preset = 'Original,volume=100' }
    'Gentle Zoom' { $preset = 'Gentle'; $mode = 'Zoom' }
    'custom Zoom' { $mode = 'Zoom'; $options = @{ HighpassHz = 60 } }
    'injected numeric option' { $options = @{ HighpassHz = '60,volume=100' } }
    'string boolean option' { $options = @{ Denoise = 'false' } }
    'unknown option' { $options = @{ FilterChain = 'volume=100' } }
    'null options' { $options = $null }
    default { throw 'Unknown test case.' }
}
& $AppPath -inputPath $InputFile -Mode $mode -Preset $preset -CleaningOptions $options -OutputDirectory $OutputFolder -FfmpegPath $MissingDependency -FfprobePath $MissingDependency -NonInteractive
exit $LASTEXITCODE
'@
        [IO.File]::WriteAllText($driverPath, $driverCode, (New-Object Text.UTF8Encoding($true)))
    }

    It 'returns configuration exit 2 before native startup for <Case>' -ForEach @(
        @{ Case = 'unknown preset' }; @{ Case = 'Gentle Zoom' }; @{ Case = 'custom Zoom' }
        @{ Case = 'injected numeric option' }; @{ Case = 'string boolean option' }
        @{ Case = 'unknown option' }; @{ Case = 'null options' }
    ) {
        $outputFolder = Join-Path $appFolder ('new output ' + $Case)
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -AppPath {1} -InputFile {2} -OutputFolder {3} -MissingDependency {4} -Case {5}' -f
            (ConvertTo-WacTestQuotedArgument $driverPath), (ConvertTo-WacTestQuotedArgument $appPath),
            (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument $outputFolder),
            (ConvertTo-WacTestQuotedArgument $missingDependency), (ConvertTo-WacTestQuotedArgument $Case)
        $result = Invoke-WacTestProcess -FilePath $currentShell -Arguments $arguments -WorkingDirectory $appFolder
        $result.ExitCode | Should -Be 2
        # PS5.1 can wrap the error message mid-word after a long script path.
        $compactError = $result.StandardError -replace '\s', ''
        $compactError | Should -Match 'Preflightfailed:'
        $compactError | Should -Not -Match 'Dependencyfailed:'
        $result.StandardOutput | Should -Not -Match 'Running WinAudioClean|Enter selection|Select Processing Mode'
        Test-Path -LiteralPath $outputFolder | Should -BeFalse
        Test-Path -LiteralPath $missingDependency | Should -BeFalse
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) | Should -BeExactly 'AQIDBA=='
        @(Get-ChildItem -LiteralPath $appFolder -Filter 'WinAudioClean_*.json').Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $appFolder -Filter '*.partial').Count | Should -Be 0
    }
}

Describe 'AC-040/041: detailed reports describe effective cleaning without changing safe export policy' -Tag 'Cleaning', 'RunReports', 'Unit' {
    It 'records typed <Preset> effective settings and explicit candidate/customization flags' -ForEach @(
        @{ Preset = 'Original'; Experimental = $false }
        @{ Preset = 'Gentle'; Experimental = $true }
    ) {
        $profile = Get-WacProcessingProfile -Choice 1 -Preset $Preset -CleaningOptions @{ HighpassHz = 75.5; Denoise = $false }
        $report = New-WacRunReport -Context (New-WacCleaningReportContext -ProcessingProfile $profile)
        $report.schemaVersion | Should -Be 1
        $report.presetId | Should -BeExactly $profile.PresetId
        $report.presetVersion | Should -BeExactly $profile.PresetVersion
        $report.presetExperimental | Should -Be $Experimental
        $report.presetCustomized | Should -BeTrue
        $report.settings.cleaning.schemaVersion | Should -Be 1
        $report.settings.cleaning.HighpassHz | Should -Be 75.5
        $report.settings.cleaning.Denoise | Should -BeOfType ([bool])
        $report.settings.cleaning.Denoise | Should -BeFalse
        $report.settings.exactFilters | Should -BeExactly $profile.FilterChain
        $roundTrip = $report | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $roundTrip.settings.cleaning.HighpassHz | Should -Be 75.5
        $roundTrip.settings.cleaning.Denoise | Should -BeOfType ([bool])
        $safe = ConvertTo-WacRedactedReport -Report $report
        ($safe | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE_|presetExperimental|presetCustomized|cleaning|exactFilters|highpass|afftdn'
    }

    It 'records no effective cleaning for the Original Zoom path' {
        $profile = Get-WacProcessingProfile -Choice 2
        $report = New-WacRunReport -Context (New-WacCleaningReportContext -ProcessingProfile $profile)
        $report.settings.cleaning | Should -BeNullOrEmpty
        $report.presetExperimental | Should -BeFalse
        $report.presetCustomized | Should -BeFalse
        $report.settings.exactFilters | Should -BeExactly $originalZoom
    }
}
