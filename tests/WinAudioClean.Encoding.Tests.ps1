BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $scriptPath = Join-Path $repositoryRoot 'WinAudioClean.ps1'
    . $scriptPath
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
}

Describe 'AC-025/AC-026: explicit PCM and selected-channel policy' -Tag 'Encoding', 'Unit' {
    It 'preserves <Channels> channels with <Bits>-bit PCM at 48 kHz' -ForEach @(
        @{ Channels = 1; Layout = 'mono'; Bits = '16' }
        @{ Channels = 1; Layout = 'mono'; Bits = '24' }
        @{ Channels = 2; Layout = 'stereo'; Bits = '16' }
        @{ Channels = 2; Layout = 'stereo'; Bits = '24' }
    ) {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = $Channels; ChannelLayout = $Layout; SampleRate = 44100 }) -BitDepth $Bits
        $policy.SampleRate | Should -Be 48000
        $policy.Bits | Should -Be ([int]$Bits)
        $policy.Codec | Should -BeExactly ('pcm_s' + $Bits + 'le')
        $policy.Channels | Should -Be $Channels
        $policy.Layout | Should -BeExactly $Layout
        $policy.FilterPrefix | Should -BeNullOrEmpty
        $policy.Rf64 | Should -BeFalse
    }

    It 'infers conventional layout for <Channels> channels with a <Description> layout' -ForEach @(
        @{ Channels = 1; Layout = $null; Expected = 'mono'; Description = 'missing' }
        @{ Channels = 2; Layout = $null; Expected = 'stereo'; Description = 'missing' }
        @{ Channels = 1; Layout = ''; Expected = 'mono'; Description = 'empty' }
        @{ Channels = 2; Layout = ' '; Expected = 'stereo'; Description = 'blank' }
    ) {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = $Channels; ChannelLayout = $Layout })
        $policy.Layout | Should -BeExactly $Expected
        $policy.Channels | Should -Be $Channels
        $policy.Bits | Should -Be 16
    }

    It 'rejects unsupported or inconsistent input <Description>, including with explicit mono' -ForEach @(
        @{ Channels = 0; Layout = $null; Description = 'zero channels' }
        @{ Channels = 3; Layout = '2.1'; Description = '2.1' }
        @{ Channels = 6; Layout = '5.1'; Description = '5.1' }
        @{ Channels = 1; Layout = 'stereo'; Description = 'one channel labeled stereo' }
        @{ Channels = 2; Layout = 'mono'; Description = 'two channels labeled mono' }
        @{ Channels = 2; Layout = 'downmix'; Description = 'downmix channel positions' }
        @{ Channels = 1; Layout = 4; Description = 'numeric layout' }
    ) {
        $audio = [pscustomobject]@{ Channels = $Channels; ChannelLayout = $Layout }
        { Get-WacOutputPolicy -InputAudio $audio } | Should -Throw
        { Get-WacOutputPolicy -InputAudio $audio -Mono } | Should -Throw
    }

    It 'mixes stereo equally before the exact original processing chain only when mono is requested' {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 2; ChannelLayout = 'stereo' }) -BitDepth 24 -Mono -Rf64
        $policy.Channels | Should -Be 1
        $policy.Layout | Should -BeExactly 'mono'
        $policy.FilterPrefix | Should -BeExactly 'pan=mono|c0=0.5*c0+0.5*c1,'
        $policy.Rf64 | Should -BeTrue
        $legacy = 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
        $arguments = Get-WacFfmpegArguments -InputPath 'C:\in [1].wav' -OutputFile 'C:\out\owned.partial' -FilterChain $legacy -AudioStreamIndex 3 -OutputPolicy $policy
        $arguments[[Array]::IndexOf($arguments, '-af') + 1] | Should -BeExactly ('pan=mono|c0=0.5*c0+0.5*c1,' + $legacy)
        $arguments[[Array]::IndexOf($arguments, '-rf64') + 1] | Should -BeExactly 'always'
        $arguments[[Array]::IndexOf($arguments, '-c:a') + 1] | Should -BeExactly 'pcm_s24le'
        $arguments[[Array]::IndexOf($arguments, '-channel_layout') + 1] | Should -BeExactly 'mono'
    }

    It 'leaves an already-mono filter path unchanged under explicit mono' {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1 }) -Mono
        $policy.Channels | Should -Be 1
        $policy.FilterPrefix | Should -BeNullOrEmpty
    }

    It 'pins output encoding and keeps selected stereo channels without trimming or splitting' {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 2; ChannelLayout = 'stereo' })
        $arguments = Get-WacFfmpegArguments -InputPath 'C:\in.wav' -OutputFile 'C:\owned.partial' -FilterChain 'loudnorm=I=-12:TP=-1.5' -AudioStreamIndex 2 -OutputPolicy $policy
        foreach ($pair in @(@('-ar', '48000'), @('-c:a', 'pcm_s16le'), @('-ac', '2'), @('-channel_layout', 'stereo'), @('-rf64', 'never'), @('-map', '0:2'), @('-map_metadata', '-1'), @('-map_chapters', '-1'))) {
            $arguments[[Array]::IndexOf($arguments, $pair[0]) + 1] | Should -BeExactly $pair[1]
        }
        @($arguments | Where-Object { $_ -in @('-t', '-to', '-ss', '-fs', '-segment_time') }).Count | Should -Be 0
        $arguments[[Array]::IndexOf($arguments, '-af') + 1] | Should -BeExactly 'loudnorm=I=-12:TP=-1.5'
    }

    It 'rejects unsupported bit depth <Bits>' -ForEach @(@{ Bits = '' }, @{ Bits = '8' }, @{ Bits = '32' }, @{ Bits = '16.0' }) {
        { Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 1 }) -BitDepth $Bits } | Should -Throw
    }
}

Describe 'AC-027: conservative output-size and available-space policy' -Tag 'Encoding', 'Unit' {
    BeforeEach {
        $stereo16 = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 2 })
    }

    It 'reserves one output file, 101 ms timing slack, a 1 MiB header and at least 64 MiB headroom' {
        $estimate = Get-WacOutputSpaceEstimate -DurationSeconds 1 -OutputPolicy $stereo16
        $estimate.DataBytes | Should -Be 211392
        $estimate.FileBytes | Should -Be 1259968
        $estimate.ReserveBytes | Should -Be 67108864
        $estimate.RequiredBytes | Should -Be 68368832
        $estimate.RequiredBytes | Should -BeOfType [long]
    }

    It 'uses ten percent headroom when greater than 64 MiB' {
        $estimate = Get-WacOutputSpaceEstimate -DurationSeconds 4000 -OutputPolicy $stereo16
        $estimate.DataBytes | Should -Be 768019392
        $estimate.FileBytes | Should -Be 769067968
        $estimate.ReserveBytes | Should -Be 76906797
        $estimate.RequiredBytes | Should -Be 845974765
    }

    It 'accepts the last safe RIFF frame estimate then rejects the next for <Channels> channels/<Bits> bits' -ForEach @(
        @{ Channels = 1; Bits = '16'; BytesPerFrame = 2 }
        @{ Channels = 2; Bits = '16'; BytesPerFrame = 4 }
        @{ Channels = 1; Bits = '24'; BytesPerFrame = 3 }
        @{ Channels = 2; Bits = '24'; BytesPerFrame = 6 }
    ) {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = $Channels }) -BitDepth $Bits
        $maxFrames = [math]::Floor((4294967295.0 - 1048576) / $BytesPerFrame)
        # Quarter-frame margin keeps binary-to-decimal conversion away from an
        # integer boundary while still testing the last/first estimated frames.
        $below = ($maxFrames - 0.25) / 48000 - 0.101
        $above = ($maxFrames + 0.25) / 48000 - 0.101
        $estimate = Get-WacOutputSpaceEstimate -DurationSeconds $below -OutputPolicy $policy
        $estimate.FileBytes | Should -Be ([long]$maxFrames * $BytesPerFrame + 1048576)
        $estimate.FileBytes | Should -BeLessOrEqual 4294967295
        { Get-WacOutputSpaceEstimate -DurationSeconds $above -OutputPolicy $policy } | Should -Throw '*Use -Rf64*'
        $policy.Rf64 = $true
        (Get-WacOutputSpaceEstimate -DurationSeconds $above -OutputPolicy $policy).FileBytes | Should -BeGreaterThan 4294967295
    }

    It 'uses 64-bit byte counts for a supported very long RF64 estimate' {
        $policy = Get-WacOutputPolicy -InputAudio ([pscustomobject]@{ Channels = 2 }) -BitDepth 24 -Rf64
        $estimate = Get-WacOutputSpaceEstimate -DurationSeconds 1000000000 -OutputPolicy $policy
        $estimate.RequiredBytes | Should -Be 316800001185431
        $estimate.RequiredBytes | Should -BeOfType [long]
    }

    It 'rejects a duration that cannot be estimated: <Description>' -ForEach @(
        @{ Description = 'zero'; Duration = 0.0 }
        @{ Description = 'negative'; Duration = -1.0 }
        @{ Description = 'NaN'; Duration = [double]::NaN }
        @{ Description = 'infinity'; Duration = [double]::PositiveInfinity }
        @{ Description = 'above supported bound'; Duration = 1000000001.0 }
    ) {
        { Get-WacOutputSpaceEstimate -DurationSeconds $Duration -OutputPolicy $stereo16 } | Should -Throw '*Cannot estimate*'
    }

    It 'rejects invalid requested format in the estimator' -ForEach @(
        @{ Field = 'SampleRate'; Value = 192000 }
        @{ Field = 'Channels'; Value = 6 }
        @{ Field = 'Bits'; Value = 32 }
    ) {
        $stereo16.$Field = $Value
        { Get-WacOutputSpaceEstimate -DurationSeconds 1 -OutputPolicy $stereo16 } | Should -Throw '*Invalid output format*'
    }

    It 'rejects one byte below the required space and accepts the exact requirement' {
        $transaction = [pscustomobject]@{ TestIdentity = 'pinned-destination' }
        $estimate = Get-WacOutputSpaceEstimate -DurationSeconds 1 -OutputPolicy $stereo16
        $script:encodingAvailableBytes = [uint64]($estimate.RequiredBytes - 1)
        Mock Get-WacAvailableOutputBytes { $script:encodingAvailableBytes }
        { Assert-WacOutputSpace -Transaction $transaction -Estimate $estimate } | Should -Throw '*Insufficient destination space*'
        $script:encodingAvailableBytes++
        Assert-WacOutputSpace -Transaction $transaction -Estimate $estimate | Should -Be $estimate.RequiredBytes
        Should -Invoke Get-WacAvailableOutputBytes -Times 2 -Exactly -ParameterFilter { $Transaction.TestIdentity -eq 'pinned-destination' }
    }

    It 'does not turn a failed destination query into an available-space result' {
        Mock Get-WacAvailableOutputBytes { throw 'injected quota query failure' }
        { Assert-WacOutputSpace -Transaction ([pscustomobject]@{}) -Estimate ([pscustomobject]@{ RequiredBytes = 100 }) } | Should -Throw '*injected quota query failure*'
    }
}

Describe 'AC-027: the native space query uses the held destination directory' -Tag 'Encoding', 'Transaction' {
    It 'queries a pinned junction target and rejects the transaction after close' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        # PS5.1 New-Item resolves a junction target with wildcard semantics.
        # Other suites cover bracketed runtime paths; keep this fixture portable.
        $target = Join-Path $root 'real destination'
        $null = [IO.Directory]::CreateDirectory($target)
        $junction = Join-Path $root 'destination alias'
        $null = New-Item -ItemType Junction -Path $junction -Target $target -ErrorAction Stop
        $inputFile = Join-Path $root 'source.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $junction
        try {
            $transaction.OutputFolder | Should -BeExactly $target
            # A stale property must not redirect the free-space query: the
            # implementation resolves the held directory handle itself.
            $transaction.OutputFolder = Join-Path $root 'nonexistent destination'
            $available = Get-WacAvailableOutputBytes -Transaction $transaction
            $available | Should -BeOfType [uint64]
            $available | Should -BeGreaterThan 0
        } finally {
            @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        }
        { Get-WacAvailableOutputBytes -Transaction $transaction } | Should -Throw '*pinned destination*'
        @(Get-ChildItem -LiteralPath $target -Force).Count | Should -Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) | Should -BeExactly 'AQID'
    }
}

Describe 'AC-025/AC-027: the application rejects settings and space before rendering' -Tag 'Encoding', 'Runtime', 'Native' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
        $encodingNativeFixture = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'encoding fixture.exe')
        $encodingShell = (Get-Process -Id $PID).Path
    }

    It 'fails safely before render for <Description>' -ForEach @(
        @{ Description = 'insufficient space'; Injection = 'zero'; Channels = 1; Layout = 'mono'; Duration = '3'; Extra = ''; Exit = 5; Diagnostic = 'Insufficient destination space' }
        @{ Description = 'unavailable space query'; Injection = 'error'; Channels = 1; Layout = 'mono'; Duration = '3'; Extra = ''; Exit = 5; Diagnostic = 'injected destination query failure' }
        @{ Description = 'RIFF oversized estimate'; Injection = ''; Channels = 2; Layout = 'stereo'; Duration = '30000'; Extra = ''; Exit = 5; Diagnostic = 'Use -Rf64' }
        @{ Description = 'multichannel input'; Injection = ''; Channels = 6; Layout = '5.1'; Duration = '3'; Extra = ''; Exit = 2; Diagnostic = 'Only mono and stereo' }
        @{ Description = 'multichannel input with mono requested'; Injection = ''; Channels = 6; Layout = '5.1'; Duration = '3'; Extra = '-Mono'; Exit = 2; Diagnostic = 'Only mono and stereo' }
        @{ Description = 'mismatched layout'; Injection = ''; Channels = 2; Layout = 'mono'; Duration = '3'; Extra = ''; Exit = 2; Diagnostic = 'Unsupported channel layout' }
        @{ Description = 'unsupported bit depth'; Injection = ''; Channels = 1; Layout = 'mono'; Duration = '3'; Extra = '-BitDepth 32'; Exit = 2; Diagnostic = 'Bit depth must be 16 or 24' }
        @{ Description = 'missing explicit mono filter'; Injection = ''; Channels = 2; Layout = 'stereo'; Duration = '3'; Extra = '-Mono'; Exit = 3; Diagnostic = 'lacks filters.*pan' }
    ) {
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $output = Join-Path $scratch 'output'
        $null = [IO.Directory]::CreateDirectory($output)
        $app = Join-Path $scratch 'WinAudioClean.ps1'
        $source = [IO.File]::ReadAllText($scriptPath)
        if ($Injection) {
            $marker = "if (`$MyInvocation.InvocationName -eq '.') { return }"
            $source.Contains($marker) | Should -BeTrue
            $override = if ($Injection -eq 'zero') {
                'function Get-WacAvailableOutputBytes { param($Transaction) [uint64]0 }'
            } else {
                'function Get-WacAvailableOutputBytes { param($Transaction) throw ''injected destination query failure'' }'
            }
            # Inject only this test-owned copy, after the definitions and before
            # the real main body. Runtime source has no environment test hooks.
            $source = $source.Replace($marker, ($marker + [Environment]::NewLine + $override))
        }
        [IO.File]::WriteAllText($app, $source, [Text.UTF8Encoding]::new($false))
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'WinAudioClean.IO.ps1') -Destination $scratch
        Copy-Item -LiteralPath $encodingNativeFixture -Destination (Join-Path $scratch 'ffmpeg.exe')
        Copy-Item -LiteralPath $encodingNativeFixture -Destination (Join-Path $scratch 'ffprobe.exe')
        $inputFile = Join-Path $scratch 'source.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $priorFile = Join-Path $output 'prior.wav'
        [IO.File]::WriteAllBytes($priorFile, [byte[]]@(4, 5, 6))
        $renderArguments = Join-Path $scratch 'render-arguments.json'
        $metadata = @{ streams = @(@{ index = 0; codec_type = 'audio'; codec_name = 'pcm_s16le'; channels = $Channels; channel_layout = $Layout; sample_rate = '48000'; duration = $Duration }) } | ConvertTo-Json -Depth 4 -Compress
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -inputPath {1} -OutputDirectory {2} -Mode Zoom -NonInteractive {3}' -f
            (ConvertTo-WacTestQuotedArgument $app), (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument $output), $Extra
        $result = Invoke-WacTestProcess -FilePath $encodingShell -Arguments $arguments -WorkingDirectory $scratch -EnvironmentVariables @{
            PSMODULEPATH = $null; WAC_TEST_ARGV_PATH = $renderArguments; WAC_TEST_PROBE_STDOUT = $metadata
            WAC_TEST_FILTERS_STDOUT = " ... dynaudnorm A->A Fixture`n ... loudnorm A->A Fixture`n"
            WAC_TEST_EXIT_CODE = '0'; WAC_TEST_FFMPEG_OUTPUT = '1'
        }
        $result.ExitCode | Should -Be $Exit -Because ($result.StandardOutput + $result.StandardError)
        ($result.StandardOutput + $result.StandardError) | Should -Match $Diagnostic
        ($result.StandardOutput + $result.StandardError) | Should -Not -Match 'DONE: SUCCESS'
        Test-Path -LiteralPath $renderArguments | Should -BeFalse
        @(Get-ChildItem -LiteralPath $output -Force).Count | Should -Be 1
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) | Should -BeExactly 'AQID'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($priorFile)) | Should -BeExactly 'BAUG'
    }
}
