BeforeAll {
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'WinAudioClean.ps1')
    $rawFilters = 'adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
    $zoomFilters = 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
    $validAudioJson = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"pcm_s16le","channels":1,"sample_rate":"48000"}]}'
}

Describe 'AC-019: dependency discovery has deterministic precedence' -Tag 'Media', 'Unit' {
    BeforeEach {
        $script:mediaRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:siblingDirectory = Join-Path $script:mediaRoot 'application [literal]'
        $script:pathDirectory = Join-Path $script:mediaRoot 'PATH tools'
        $script:overrideDirectory = Join-Path $script:mediaRoot 'explicit tools'
        foreach ($directory in @($script:siblingDirectory, $script:pathDirectory, $script:overrideDirectory)) {
            $null = [IO.Directory]::CreateDirectory($directory)
        }
        Mock Get-Command { $null } -ParameterFilter { $Name -in @('ffmpeg.exe', 'ffprobe.exe') }
    }

    It 'uses explicit <ToolName> ahead of sibling and PATH' -ForEach @(
        @{ ToolName = 'ffmpeg.exe' }, @{ ToolName = 'ffprobe.exe' }
    ) {
        $explicit = Join-Path $script:overrideDirectory $ToolName
        $sibling = Join-Path $script:siblingDirectory $ToolName
        [IO.File]::WriteAllBytes($explicit, [byte[]]@(1))
        [IO.File]::WriteAllBytes($sibling, [byte[]]@(2))

        Resolve-WacExecutable -Name $ToolName -ExplicitPath $explicit -SiblingDirectory $script:siblingDirectory |
            Should -BeExactly $explicit
        Should -Invoke Get-Command -Times 0 -Exactly -ParameterFilter { $Name -eq $ToolName }
    }

    It 'uses sibling <ToolName> without querying PATH' -ForEach @(
        @{ ToolName = 'ffmpeg.exe' }, @{ ToolName = 'ffprobe.exe' }
    ) {
        $sibling = Join-Path $script:siblingDirectory $ToolName
        [IO.File]::WriteAllBytes($sibling, [byte[]]@(1))
        Resolve-WacExecutable -Name $ToolName -SiblingDirectory $script:siblingDirectory | Should -BeExactly $sibling
        Should -Invoke Get-Command -Times 0 -Exactly -ParameterFilter { $Name -eq $ToolName }
    }

    It 'uses the first PATH application only when no sibling exists' {
        $script:firstPathTool = Join-Path $script:pathDirectory 'ffmpeg.exe'
        $script:secondPathTool = Join-Path $script:overrideDirectory 'ffmpeg.exe'
        [IO.File]::WriteAllBytes($script:firstPathTool, [byte[]]@(1))
        [IO.File]::WriteAllBytes($script:secondPathTool, [byte[]]@(2))
        Mock Get-Command {
            @([pscustomobject]@{ Source = $script:firstPathTool }, [pscustomobject]@{ Source = $script:secondPathTool })
        } -ParameterFilter { $Name -eq 'ffmpeg.exe' -and $CommandType -eq 'Application' }

        Resolve-WacExecutable -Name 'ffmpeg.exe' -SiblingDirectory $script:siblingDirectory |
            Should -BeExactly $script:firstPathTool
        Should -Invoke Get-Command -Times 1 -Exactly -ParameterFilter { $Name -eq 'ffmpeg.exe' -and $CommandType -eq 'Application' }
    }

    It 'resolves an explicit relative executable path literally' {
        $explicit = Join-Path $script:overrideDirectory 'custom [tool].exe'
        [IO.File]::WriteAllBytes($explicit, [byte[]]@(1))
        Push-Location -LiteralPath $script:mediaRoot
        try {
            Resolve-WacExecutable -Name 'ffmpeg.exe' -ExplicitPath '.\explicit tools\custom [tool].exe' -SiblingDirectory $script:siblingDirectory |
                Should -BeExactly $explicit
        } finally { Pop-Location }
    }

    It 'rejects <Description> as an explicit override without sibling or PATH fallback' -ForEach @(
        @{ Description = 'an empty override'; Value = '' }
        @{ Description = 'a blank override'; Value = '   ' }
        @{ Description = 'a URL'; Value = 'https://example.invalid/ffmpeg.exe' }
        @{ Description = 'a missing executable'; Value = 'missing.exe' }
        @{ Description = 'a non-executable file'; Value = 'tool.cmd' }
        @{ Description = 'a directory'; Value = 'directory.exe' }
    ) {
        $sibling = Join-Path $script:siblingDirectory 'ffmpeg.exe'
        [IO.File]::WriteAllBytes($sibling, [byte[]]@(1))
        $override = $Value
        if ($Value -eq 'tool.cmd') {
            $override = Join-Path $script:overrideDirectory $Value
            [IO.File]::WriteAllBytes($override, [byte[]]@(2))
        } elseif ($Value -eq 'directory.exe') {
            $override = Join-Path $script:overrideDirectory $Value
            $null = [IO.Directory]::CreateDirectory($override)
        } elseif ($Value -eq 'missing.exe') {
            $override = Join-Path $script:overrideDirectory $Value
        }
        { Resolve-WacExecutable -Name 'ffmpeg.exe' -ExplicitPath $override -SiblingDirectory $script:siblingDirectory } |
            Should -Throw
        Should -Invoke Get-Command -Times 0 -Exactly -ParameterFilter { $Name -eq 'ffmpeg.exe' }
    }

    It 'does not hide a broken sibling candidate by falling back to PATH' {
        $null = [IO.Directory]::CreateDirectory((Join-Path $script:siblingDirectory 'ffmpeg.exe'))
        { Resolve-WacExecutable -Name 'ffmpeg.exe' -SiblingDirectory $script:siblingDirectory } | Should -Throw
        Should -Invoke Get-Command -Times 0 -Exactly -ParameterFilter { $Name -eq 'ffmpeg.exe' }
    }

    It 'reports a missing dependency when sibling and PATH are absent' {
        { Resolve-WacExecutable -Name 'ffprobe.exe' -SiblingDirectory $script:siblingDirectory } | Should -Throw '*ffprobe*'
        Should -Invoke Get-Command -Times 1 -Exactly -ParameterFilter { $Name -eq 'ffprobe.exe' -and $CommandType -eq 'Application' }
    }
}

Describe 'AC-019: dependency identity, capability and timeout checks' -Tag 'Media', 'Unit' {
    BeforeEach {
        $script:mediaNativeResult = [pscustomobject]@{
            Started = $true; ExitCode = 0; StandardOutput = ''; StandardError = ''
            Error = $null; TimedOut = $false; CleanupError = $null
        }
        Mock Invoke-WacNativeProcess { $script:mediaNativeResult }
    }

    It 'returns the first <ToolName> version line and uses a bounded native call' -ForEach @(
        @{ ToolName = 'ffmpeg' }, @{ ToolName = 'ffprobe' }
    ) {
        $script:mediaNativeResult.StandardOutput = "$ToolName version 7.1-test Copyright (c) FFmpeg developers`r`nbuilt with test compiler`r`n"
        Get-WacToolVersion -FilePath "C:\tools\$ToolName.exe" -ToolName $ToolName |
            Should -BeExactly "$ToolName version 7.1-test Copyright (c) FFmpeg developers"
        Should -Invoke Invoke-WacNativeProcess -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "C:\tools\$ToolName.exe" -and '-version' -in $ArgumentList -and $TimeoutMilliseconds -eq 15000
        }
    }

    It 'passes an explicit version timeout to the native wrapper' {
        $script:mediaNativeResult.StandardOutput = 'ffmpeg version 7.1-test'
        $null = Get-WacToolVersion -FilePath 'C:\tools\ffmpeg.exe' -ToolName ffmpeg -TimeoutMilliseconds 125
        Should -Invoke Invoke-WacNativeProcess -Times 1 -Exactly -ParameterFilter { $TimeoutMilliseconds -eq 125 }
    }

    It 'rejects a wrong or empty version banner (<Banner>)' -ForEach @(
        @{ Banner = 'ffprobe version 7.1-test' }
        @{ Banner = 'unrelated program version 7.1-test' }
        @{ Banner = '' }
    ) {
        $script:mediaNativeResult.StandardOutput = $Banner
        { Get-WacToolVersion -FilePath 'C:\tools\ffmpeg.exe' -ToolName ffmpeg } | Should -Throw
    }

    It 'rejects <Failure> even when version output looks valid' -ForEach @(
        @{ Failure = 'startup failure'; Property = 'Started'; Value = $false }
        @{ Failure = 'a nonzero exit'; Property = 'ExitCode'; Value = 8 }
        @{ Failure = 'a capture error'; Property = 'Error'; Value = 'capture failed' }
        @{ Failure = 'a timeout'; Property = 'TimedOut'; Value = $true }
        @{ Failure = 'a cleanup error'; Property = 'CleanupError'; Value = 'cleanup failed' }
    ) {
        $script:mediaNativeResult.StandardOutput = 'ffmpeg version 7.1-test'
        $script:mediaNativeResult.$Property = $Value
        { Get-WacToolVersion -FilePath 'C:\tools\ffmpeg.exe' -ToolName ffmpeg } | Should -Throw
    }

    It 'accepts Zoom when the build supplies only its two required filters' {
        $script:mediaNativeResult.StandardOutput = "Filters:`n T.C dynaudnorm A->A Dynamic Audio Normalizer`n ... loudnorm A->A Loudness normalization`n"
        @(Test-WacRequiredFilters -FfmpegPath 'C:\tools\ffmpeg.exe' -FilterChain $zoomFilters).Count | Should -Be 0
        Should -Invoke Invoke-WacNativeProcess -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'C:\tools\ffmpeg.exe' -and '-filters' -in $ArgumentList -and $TimeoutMilliseconds -eq 15000
        }
    }

    It 'accepts the FFmpeg 9 two-column capability flags' {
        $script:mediaNativeResult.StandardOutput = " TS dynaudnorm A->A Dynamic Audio Normalizer`n .. loudnorm A->A Loudness normalization`n"
        @(Test-WacRequiredFilters -FfmpegPath 'C:\tools\ffmpeg.exe' -FilterChain $zoomFilters).Count | Should -Be 0
    }

    It 'accepts Raw when every required filter is present' {
        $script:mediaNativeResult.StandardOutput = " ... adeclip A->A Declip`n ... highpass A->A Highpass`n ... adeclick A->A Declick`n ... afftdn A->A Denoise`n ... agate A->A Gate`n ... dynaudnorm A->A Normalize`n ... loudnorm A->A Loudness`n"
        @(Test-WacRequiredFilters -FfmpegPath 'C:\tools\ffmpeg.exe' -FilterChain $rawFilters -TimeoutMilliseconds 125).Count | Should -Be 0
        Should -Invoke Invoke-WacNativeProcess -Times 1 -Exactly -ParameterFilter { $TimeoutMilliseconds -eq 125 }
    }

    It 'identifies Raw-only filters missing from a Zoom-capable build' {
        $script:mediaNativeResult.StandardOutput = " ... dynaudnorm A->A Normalize`n ... loudnorm A->A Loudness`n"
        { Test-WacRequiredFilters -FfmpegPath 'C:\tools\ffmpeg.exe' -FilterChain $rawFilters } | Should -Throw '*adeclip*'
    }

    It 'does not accept a filter name substring or description as a capability' {
        $script:mediaNativeResult.StandardOutput = " ... dynaudnorm_extra A->A dynaudnorm`n ... volume A->A loudnorm`n"
        { Test-WacRequiredFilters -FfmpegPath 'C:\tools\ffmpeg.exe' -FilterChain $zoomFilters } | Should -Throw
    }

    It 'rejects a failed filter query even when its output lists the required filters' {
        $script:mediaNativeResult.StandardOutput = " ... dynaudnorm A->A Normalize`n ... loudnorm A->A Loudness`n"
        $script:mediaNativeResult.ExitCode = 5
        { Test-WacRequiredFilters -FfmpegPath 'C:\tools\ffmpeg.exe' -FilterChain $zoomFilters } | Should -Throw
    }
}

Describe 'AC-020/AC-021: structured audio probing validates native outcome and schema' -Tag 'Media', 'Unit' {
    BeforeEach {
        $script:mediaNativeResult = [pscustomobject]@{
            Started = $true; ExitCode = 0; StandardOutput = $validAudioJson; StandardError = ''
            Error = $null; TimedOut = $false; CleanupError = $null
        }
        Mock Invoke-WacNativeProcess { $script:mediaNativeResult }
    }

    It 'retains absolute indexes and metadata when video precedes two audio streams' {
        $script:mediaNativeResult.StandardOutput = @'
{"streams":[{"index":0,"codec_type":"video"},{"index":1,"codec_type":"audio","codec_name":"pcm_s16le","channels":1,"sample_rate":"48000","tags":{"language":"eng","title":"First track"}},{"index":4,"codec_type":"audio","codec_name":"aac","channels":2,"sample_rate":"44100","tags":{"language":"fin","title":"Second & [literal] track"}}]}
'@
        $streams = @(Get-WacAudioStreams -FfprobePath 'C:\tools\ffprobe.exe' -InputPath 'C:\audio\two [tracks].mkv')
        $streams.Count | Should -Be 2
        $streams[0].Index | Should -Be 1
        $streams[0].Codec | Should -BeExactly 'pcm_s16le'
        $streams[0].Channels | Should -Be 1
        [string]$streams[0].SampleRate | Should -BeExactly '48000'
        $streams[0].Language | Should -BeExactly 'eng'
        $streams[0].Title | Should -BeExactly 'First track'
        $streams[1].Index | Should -Be 4
        $streams[1].Channels | Should -Be 2
        $streams[1].Language | Should -BeExactly 'fin'
        $streams[1].Title | Should -BeExactly 'Second & [literal] track'
    }

    It 'accepts a single audio stream without optional tags or channel layout' {
        $streams = @(Get-WacAudioStreams -FfprobePath 'C:\tools\ffprobe.exe' -InputPath 'C:\audio\one.wav')
        $streams.Count | Should -Be 1
        $streams[0].Index | Should -Be 0
        $streams[0].Language | Should -BeNullOrEmpty
        $streams[0].Title | Should -BeNullOrEmpty
    }

    It 'passes literal input, JSON selection, local restrictions and a finite probe timeout' {
        $null = Get-WacAudioStreams -FfprobePath 'C:\tools\ffprobe.exe' -InputPath 'C:\audio\one & [1].wav' -TimeoutMilliseconds 125
        Should -Invoke Invoke-WacNativeProcess -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'C:\tools\ffprobe.exe' -and $TimeoutMilliseconds -eq 125 -and
            'C:\audio\one & [1].wav' -in $ArgumentList -and 'json' -in $ArgumentList -and
            '-protocol_whitelist' -in $ArgumentList -and 'file' -in $ArgumentList -and '-format_whitelist' -in $ArgumentList
        }
    }

    It 'uses a bounded default probe timeout' {
        $null = Get-WacAudioStreams -FfprobePath 'C:\tools\ffprobe.exe' -InputPath 'C:\audio\one.wav'
        Should -Invoke Invoke-WacNativeProcess -Times 1 -Exactly -ParameterFilter { $TimeoutMilliseconds -gt 0 }
    }

    It 'rejects metadata whose UTF-8 byte size exceeds the limit even below one million characters' {
        $largeTitle = ([string][char]0x00e4) * 600000
        $script:mediaNativeResult.StandardOutput = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000","tags":{"title":"' + $largeTitle + '"}}]}'
        $script:mediaNativeResult.StandardOutput.Length | Should -BeLessThan 1MB
        [Text.Encoding]::UTF8.GetByteCount($script:mediaNativeResult.StandardOutput) | Should -BeGreaterThan 1MB
        { Get-WacAudioStreams -FfprobePath 'C:\tools\ffprobe.exe' -InputPath 'C:\audio\one.wav' } |
            Should -Throw '*metadata exceeds 1 MiB*'
    }

    It 'rejects metadata with more than 256 streams before accepting audio metadata' {
        $manyStreams = @(foreach ($index in 0..256) {
            [ordered]@{ index = $index; codec_type = 'audio'; codec_name = 'aac'; channels = 1; sample_rate = '48000' }
        })
        $script:mediaNativeResult.StandardOutput = @{ streams = $manyStreams } | ConvertTo-Json -Compress -Depth 4
        { Get-WacAudioStreams -FfprobePath 'C:\tools\ffprobe.exe' -InputPath 'C:\audio\one.wav' } |
            Should -Throw '*at most 256*'
    }

    It 'rejects <Failure> before trusting plausible JSON' -ForEach @(
        @{ Failure = 'startup failure'; Property = 'Started'; Value = $false }
        @{ Failure = 'nonzero probe exit'; Property = 'ExitCode'; Value = 8 }
        @{ Failure = 'capture failure'; Property = 'Error'; Value = 'capture failed' }
        @{ Failure = 'timeout'; Property = 'TimedOut'; Value = $true }
        @{ Failure = 'cleanup failure'; Property = 'CleanupError'; Value = 'cleanup failed' }
    ) {
        $script:mediaNativeResult.$Property = $Value
        { Get-WacAudioStreams -FfprobePath 'C:\tools\ffprobe.exe' -InputPath 'C:\audio\one.wav' } | Should -Throw
    }

    It 'rejects <Description> without returning invented stream metadata' -ForEach @(
        @{ Description = 'malformed JSON'; Json = '{broken' }
        @{ Description = 'empty output'; Json = '' }
        @{ Description = 'a null root'; Json = 'null' }
        @{ Description = 'an array root'; Json = '[{"streams":[]}]' }
        @{ Description = 'a string root'; Json = '"streams"' }
        @{ Description = 'a missing streams array'; Json = '{}' }
        @{ Description = 'a null streams property'; Json = '{"streams":null}' }
        @{ Description = 'an object in place of a streams array'; Json = '{"streams":{"index":0,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000"}}' }
        @{ Description = 'a non-object stream'; Json = '{"streams":[1]}' }
        @{ Description = 'a missing index'; Json = '{"streams":[{"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'a null index'; Json = '{"streams":[{"index":null,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'a negative index'; Json = '{"streams":[{"index":-1,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'a fractional index'; Json = '{"streams":[{"index":0.5,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'a string index'; Json = '{"streams":[{"index":"0","codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'a boolean index'; Json = '{"streams":[{"index":true,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'an out-of-range index'; Json = '{"streams":[{"index":2147483648,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'duplicate stream indexes'; Json = '{"streams":[{"index":0,"codec_type":"video"},{"index":0,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'a missing codec type'; Json = '{"streams":[{"index":0,"codec_name":"aac","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'an empty audio codec'; Json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"","channels":1,"sample_rate":"48000"}]}' }
        @{ Description = 'missing channel count'; Json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"aac","sample_rate":"48000"}]}' }
        @{ Description = 'zero channels'; Json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"aac","channels":0,"sample_rate":"48000"}]}' }
        @{ Description = 'fractional channels'; Json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"aac","channels":1.5,"sample_rate":"48000"}]}' }
        @{ Description = 'missing sample rate'; Json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"aac","channels":1}]}' }
        @{ Description = 'zero sample rate'; Json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"0"}]}' }
        @{ Description = 'a fractional sample rate'; Json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":"48000.5"}]}' }
        @{ Description = 'a numeric sample rate instead of ffprobe text'; Json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"aac","channels":1,"sample_rate":48000}]}' }
    ) {
        $script:mediaNativeResult.StandardOutput = $Json
        { Get-WacAudioStreams -FfprobePath 'C:\tools\ffprobe.exe' -InputPath 'C:\audio\one.wav' } | Should -Throw
    }

    It 'rejects <Description> before a cleaning process can be requested' -ForEach @(
        @{ Description = 'a video-only container'; Json = '{"streams":[{"index":0,"codec_type":"video"}]}' }
        @{ Description = 'a container with no streams'; Json = '{"streams":[]}' }
    ) {
        $script:mediaNativeResult.StandardOutput = $Json
        { Get-WacAudioStreams -FfprobePath 'C:\tools\ffprobe.exe' -InputPath 'C:\audio\no-audio.mkv' } | Should -Throw '*audio*'
    }
}

Describe 'AC-020: stream selection is explicit for ambiguous containers' -Tag 'Media', 'Unit' {
    BeforeEach {
        $script:mediaStreams = @(
            [pscustomobject]@{ Index = 0; Codec = 'pcm_s16le'; Channels = 1; SampleRate = '48000'; Language = ''; Title = 'First' }
            [pscustomobject]@{ Index = 4; Codec = 'aac'; Channels = 2; SampleRate = '44100'; Language = 'fin'; Title = 'Second' }
        )
        $script:mediaAnswers = New-Object 'System.Collections.Generic.Queue[string]'
        Mock Write-Host { }
        Mock Read-Host {
            if ($script:mediaAnswers.Count -eq 0) { throw 'Unexpected extra stream prompt.' }
            $script:mediaAnswers.Dequeue()
        }
    }

    It 'automatically selects the sole audio stream without prompting' {
        (Select-WacAudioStream -Streams @($script:mediaStreams[1])).Index | Should -Be 4
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'selects explicit absolute index <Index> without prompting' -ForEach @(
        @{ Index = '0'; Expected = 0 }, @{ Index = '4'; Expected = 4 }
    ) {
        (Select-WacAudioStream -Streams $script:mediaStreams -RequestedIndex $Index).Index | Should -Be $Expected
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'rejects invalid explicit index <Index> rather than interpreting an audio ordinal' -ForEach @(
        @{ Index = '' }, @{ Index = '-1' }, @{ Index = '1' }, @{ Index = '0.5' },
        @{ Index = '0:a:0' }, @{ Index = 'word' }, @{ Index = '2147483648' }
    ) {
        { Select-WacAudioStream -Streams $script:mediaStreams -RequestedIndex $Index -Interactive $true } | Should -Throw
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'rejects unattended ambiguity without reading the host' {
        { Select-WacAudioStream -Streams $script:mediaStreams } | Should -Throw
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'retries empty, invalid and nonexistent indexes until a valid absolute index is entered' {
        foreach ($answer in @('', 'word', '1', '4')) { $script:mediaAnswers.Enqueue($answer) }
        (Select-WacAudioStream -Streams $script:mediaStreams -Interactive $true).Index | Should -Be 4
        Should -Invoke Read-Host -Times 4 -Exactly
    }

    It 'returns no selection for cancellation <Answer>' -ForEach @(
        @{ Answer = 'q' }, @{ Answer = 'cancel' }
    ) {
        $script:mediaAnswers.Enqueue($Answer)
        Select-WacAudioStream -Streams $script:mediaStreams -Interactive $true | Should -BeNullOrEmpty
        Should -Invoke Read-Host -Times 1 -Exactly
    }

    It 'returns no selection when the host reports end of input' {
        Mock Read-Host { $null }
        Select-WacAudioStream -Streams $script:mediaStreams -Interactive $true | Should -BeNullOrEmpty
        Should -Invoke Read-Host -Times 1 -Exactly
    }

    It 'reports a host read failure without retrying indefinitely' {
        Mock Read-Host { throw 'The host cannot read input.' }
        { Select-WacAudioStream -Streams $script:mediaStreams -Interactive $true } | Should -Throw
        Should -Invoke Read-Host -Times 1 -Exactly
    }
}

Describe 'AC-020/AC-021: command construction enforces local media and exact stream mapping' -Tag 'Media', 'Unit' {
    It 'restricts protocols and explicitly allowlists ordinary media demuxers' {
        $arguments = @(Get-WacLocalMediaArguments)
        $arguments | Should -BeExactly @(
            '-protocol_whitelist', 'file', '-format_whitelist',
            'wav,mp3,flac,ogg,mov,matroska,webm,aac,aiff,asf,avi'
        )
    }

    It 'maps absolute index <Index> and places restrictions before the input' -ForEach @(
        @{ Index = 0 }, @{ Index = 4 }
    ) {
        $arguments = @(Get-WacFfmpegArguments -InputPath 'C:\audio\input [1].mkv' -FilterChain $zoomFilters -OutputFile 'C:\output\one.wav' -AudioStreamIndex $Index)
        $inputPosition = [Array]::IndexOf($arguments, '-i')
        $protocolPosition = [Array]::IndexOf($arguments, '-protocol_whitelist')
        $formatPosition = [Array]::IndexOf($arguments, '-format_whitelist')
        $mapPosition = [Array]::IndexOf($arguments, '-map')
        $inputPosition | Should -BeGreaterThan $protocolPosition
        $inputPosition | Should -BeGreaterThan $formatPosition
        $protocolPosition | Should -BeGreaterOrEqual 0
        $formatPosition | Should -BeGreaterOrEqual 0
        $arguments[$protocolPosition + 1] | Should -BeExactly 'file'
        $arguments[$formatPosition + 1] | Should -BeExactly 'wav,mp3,flac,ogg,mov,matroska,webm,aac,aiff,asf,avi'
        $arguments[$inputPosition + 1] | Should -BeExactly 'C:\audio\input [1].mkv'
        $mapPosition | Should -BeGreaterThan $inputPosition
        $arguments[$mapPosition + 1] | Should -BeExactly "0:$Index"
        @($arguments | Where-Object { $_ -eq '-map' }).Count | Should -Be 1
        $arguments | Should -Contain '-nostdin'
        $arguments | Should -Contain '-vn'
        $arguments[([Array]::IndexOf($arguments, '-af') + 1)] | Should -BeExactly $zoomFilters
    }

    It 'rejects a negative absolute stream index before process startup' {
        { Get-WacFfmpegArguments -InputPath 'input.wav' -FilterChain $zoomFilters -OutputFile 'output.wav' -AudioStreamIndex -1 } | Should -Throw
    }
}

Describe 'AC-021: real probe processes fail safely and terminate within their deadline' -Tag 'Media', 'Native' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
        . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
        $probeFixture = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'media native\ffprobe.exe')
        $ffmpegFixture = Join-Path (Split-Path $probeFixture -Parent) 'ffmpeg.exe'
        Copy-Item -LiteralPath $probeFixture -Destination $ffmpegFixture
        $inspectionVariables = @(foreach ($phase in @('PROBE', 'VERSION', 'FILTERS')) {
            foreach ($setting in @('STDOUT', 'STDERR', 'EXIT_CODE', 'SLEEP_MS', 'ARGV_PATH', 'PID_PATH')) {
                'WAC_TEST_' + $phase + '_' + $setting
            }
        })
    }

    BeforeEach {
        $savedInspectionEnvironment = @{}
        foreach ($name in $inspectionVariables) {
            $savedInspectionEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            # PS7.6/.NET preserves empty environment values; passing $null to
            # this .NET string overload can bind as empty. Remove explicitly.
            Remove-Item -LiteralPath ('Env:' + $name) -ErrorAction SilentlyContinue
        }
    }

    AfterEach {
        foreach ($name in $inspectionVariables) {
            if ($null -eq $savedInspectionEnvironment[$name]) {
                Remove-Item -LiteralPath ('Env:' + $name) -ErrorAction SilentlyContinue
            } else {
                [Environment]::SetEnvironmentVariable($name, $savedInspectionEnvironment[$name], 'Process')
            }
        }
    }

    It 'resolves actual PATH application <ToolName> when the sibling candidate is absent' -ForEach @(
        @{ ToolName = 'ffmpeg.exe' }, @{ ToolName = 'ffprobe.exe' }
    ) {
        $savedPath = $env:PATH
        $toolDirectory = Split-Path $probeFixture -Parent
        try {
            $env:PATH = $toolDirectory
            Resolve-WacExecutable -Name $ToolName -SiblingDirectory (Join-Path $TestDrive 'absent-sibling-directory') |
                Should -BeExactly (Join-Path $toolDirectory $ToolName)
        } finally { $env:PATH = $savedPath }
    }

    It 'finds ffprobe adjacent to an explicit FFmpeg executable in the actual application' {
        $appDirectory = Join-Path $TestDrive 'explicit-tools-app'
        $null = [IO.Directory]::CreateDirectory($appDirectory)
        $app = Join-Path $appDirectory 'WinAudioClean.ps1'
        Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'WinAudioClean.ps1') -Destination $app
        # A broken script-sibling probe exposes a wiring error: selected FFmpeg's
        # companion must win without a second explicit tool path or PATH entry.
        [IO.File]::WriteAllText((Join-Path $appDirectory 'ffprobe.exe'), 'invalid sibling executable')
        $inputFile = Join-Path $appDirectory 'input.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $outputDirectory = Join-Path $appDirectory 'output'
        $currentShell = (Get-Process -Id $PID).Path
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -inputPath {1} -OutputDirectory {2} -Mode Zoom -NonInteractive -FfmpegPath {3}' -f
            (ConvertTo-WacTestQuotedArgument $app), (ConvertTo-WacTestQuotedArgument $inputFile),
            (ConvertTo-WacTestQuotedArgument $outputDirectory), (ConvertTo-WacTestQuotedArgument $ffmpegFixture)
        $result = Invoke-WacTestProcess -FilePath $currentShell -Arguments $arguments -WorkingDirectory $appDirectory -EnvironmentVariables @{
            PATH = ''; WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_EXIT_CODE = '0'
            WAC_TEST_STDOUT = ''; WAC_TEST_STDERR = ''
        }
        $result.ExitCode | Should -Be 0 -Because ("stdout: {0}; stderr: {1}" -f $result.StandardOutput, $result.StandardError)
        $log = Get-Content -Raw -LiteralPath (Join-Path $outputDirectory 'WinAudioClean_Log.txt')
        $log | Should -Match ('FFPROBE\s+: ' + [regex]::Escape($probeFixture))
        $log | Should -Match ('EXECUTABLE\s+: ' + [regex]::Escape($ffmpegFixture))
        $result.StandardOutput | Should -Match 'DONE: SUCCESS'
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter '*.wav').Count | Should -Be 1
    }

    It 'passes JSON and local-only input arguments to the actual ffprobe process' {
        $argvPath = Join-Path $TestDrive 'actual-probe-argv.json'
        $env:WAC_TEST_PROBE_ARGV_PATH = $argvPath
        $streams = @(Get-WacAudioStreams -FfprobePath $probeFixture -InputPath 'C:\audio\space [1] & literal.wav' -TimeoutMilliseconds 10000)
        $streams.Count | Should -Be 1
        $streams[0].Index | Should -Be 0
        $arguments = Get-Content -Raw -LiteralPath $argvPath -Encoding UTF8 | ConvertFrom-Json
        $arguments[([Array]::IndexOf($arguments, '-i') + 1)] | Should -BeExactly 'C:\audio\space [1] & literal.wav'
        $arguments[([Array]::IndexOf($arguments, '-of') + 1)] | Should -BeExactly 'json'
        $arguments[([Array]::IndexOf($arguments, '-protocol_whitelist') + 1)] | Should -BeExactly 'file'
        $arguments[([Array]::IndexOf($arguments, '-format_whitelist') + 1)] | Should -BeExactly 'wav,mp3,flac,ogg,mov,matroska,webm,aac,aiff,asf,avi'
    }

    It 'rejects malformed JSON emitted by an actual successful probe process' {
        $env:WAC_TEST_PROBE_STDOUT = '{this is malformed JSON'
        { Get-WacAudioStreams -FfprobePath $probeFixture -InputPath 'C:\audio\one.wav' -TimeoutMilliseconds 10000 } |
            Should -Throw '*Invalid probe JSON*'
    }

    It 'rejects a real nonzero probe exit despite its valid JSON and retains its diagnostic' {
        $env:WAC_TEST_PROBE_EXIT_CODE = '17'
        $env:WAC_TEST_PROBE_STDERR = 'PROBE_FAILURE_DETAIL'
        { Get-WacAudioStreams -FfprobePath $probeFixture -InputPath 'C:\audio\one.wav' -TimeoutMilliseconds 10000 } |
            Should -Throw '*native exit: 17*PROBE_FAILURE_DETAIL*'
    }

    It 'times out and reaps the actual <Phase> child without accepting its pre-timeout output' -ForEach @(
        @{ Phase = 'PROBE' }, @{ Phase = 'VERSION' }, @{ Phase = 'FILTERS' }
    ) {
        $pidPath = Join-Path $TestDrive ($Phase + '-timeout.pid')
        [Environment]::SetEnvironmentVariable(('WAC_TEST_' + $Phase + '_PID_PATH'), $pidPath, 'Process')
        [Environment]::SetEnvironmentVariable(('WAC_TEST_' + $Phase + '_SLEEP_MS'), '15000', 'Process')
        $watch = [Diagnostics.Stopwatch]::StartNew()
        if ($Phase -eq 'PROBE') {
            { Get-WacAudioStreams -FfprobePath $probeFixture -InputPath 'C:\audio\one.wav' -TimeoutMilliseconds 500 } |
                Should -Throw '*timeout: True*'
        } elseif ($Phase -eq 'VERSION') {
            { Get-WacToolVersion -FilePath $ffmpegFixture -ToolName ffmpeg -TimeoutMilliseconds 500 } |
                Should -Throw '*timeout: True*'
        } else {
            { Test-WacRequiredFilters -FfmpegPath $ffmpegFixture -FilterChain $zoomFilters -TimeoutMilliseconds 500 } |
                Should -Throw '*timeout: True*'
        }
        $watch.Stop()
        $watch.ElapsedMilliseconds | Should -BeLessThan 8000
        $childId = [int][IO.File]::ReadAllText($pidPath)
        Get-Process -Id $childId -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}
