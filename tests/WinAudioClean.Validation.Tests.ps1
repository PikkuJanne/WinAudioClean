BeforeAll {
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'WinAudioClean.ps1')

    function New-TestWave {
        param([int]$Frames = 144000, [int]$Channels = 1, [int]$Rate = 48000, [int]$Bits = 16)
        $stream = [IO.MemoryStream]::new()
        $writer = [IO.BinaryWriter]::new($stream, [Text.Encoding]::ASCII, $true)
        $align = $Channels * $Bits / 8
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([uint32](36 + $Frames * $align))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
        $writer.Write([uint32]16)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$Channels)
        $writer.Write([uint32]$Rate)
        $writer.Write([uint32]($Rate * $align))
        $writer.Write([uint16]$align)
        $writer.Write([uint16]$Bits)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([uint32]($Frames * $align))
        $writer.Write([byte[]]::new($Frames * $align))
        $writer.Dispose()
        $stream.Position = 0
        return ,$stream
    }
    function Set-TestUInt32 {
        param($Stream, [int]$Offset, [uint32]$Value)
        $Stream.Position = $Offset
        $Stream.Write([BitConverter]::GetBytes($Value), 0, 4)
    }
    function Set-TestUInt64 {
        param($Stream, [int]$Offset, [uint64]$Value)
        $Stream.Position = $Offset
        $Stream.Write([BitConverter]::GetBytes($Value), 0, 8)
    }
    function ConvertTo-TestRf64Wave {
        param($Stream)
        $bytes = $Stream.ToArray()
        $extended = [IO.MemoryStream]::new()
        $writer = [IO.BinaryWriter]::new($extended, [Text.Encoding]::ASCII, $true)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RF64'))
        $writer.Write([uint32]::MaxValue)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEds64'))
        $writer.Write([uint32]28)
        $writer.Write([uint64]($bytes.Length + 36 - 8))
        $writer.Write([uint64]($bytes.Length - 44))
        $writer.Write([uint64](($bytes.Length - 44) / [BitConverter]::ToUInt16($bytes, 32)))
        $writer.Write([uint32]0)
        $writer.Write($bytes, 12, $bytes.Length - 12)
        $writer.Dispose()
        Set-TestUInt32 $extended 76 ([uint32]::MaxValue)
        return ,$extended
    }
    function ConvertTo-TestExtensibleWave {
        param($Stream, [uint16]$ExtraSize = 22, [uint32]$Mask = 4, [uint16]$ValidBits = 0)
        $bytes = $Stream.ToArray()
        if ($ValidBits -eq 0) { $ValidBits = [BitConverter]::ToUInt16($bytes, 34) }
        $extended = [IO.MemoryStream]::new()
        $writer = [IO.BinaryWriter]::new($extended, [Text.Encoding]::ASCII, $true)
        $writer.Write($bytes, 0, 36)
        $writer.Write($ExtraSize)
        $writer.Write($ValidBits)
        $writer.Write($Mask)
        $writer.Write(([guid]'00000001-0000-0010-8000-00aa00389b71').ToByteArray())
        $writer.Write($bytes, 36, $bytes.Length - 36)
        $writer.Dispose()
        Set-TestUInt32 $extended 4 ($extended.Length - 8)
        Set-TestUInt32 $extended 16 40
        $extended.Position = 20
        $extended.Write([BitConverter]::GetBytes([uint16]65534), 0, 2)
        return ,$extended
    }
}

Describe 'AC-023/024: validate the owned PCM bytes before publication' -Tag 'Unit', 'Output' {
    BeforeEach {
        $script:wave = New-TestWave
        $script:inputAudio = [pscustomobject]@{ Codec = 'pcm_s16le'; Channels = 1; DurationSeconds = 3.0 }
        $script:outputAudio = [pscustomobject]@{ Codec = 'pcm_s16le'; Channels = 1; DurationSeconds = 3.0; SampleRate = 48000 }
    }
    AfterEach { $script:wave.Dispose() }

    It 'accepts complete PCM and leaves the validation handle open' {
        $result = Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio
        $result.Frames | Should -Be 144000
        $result.DurationSeconds | Should -Be 3
        $script:wave.CanRead | Should -BeTrue
    }
    It 'accepts complete stereo PCM24 without imposing a new encoding default' {
        $script:wave.Dispose()
        $script:wave = New-TestWave -Channels 2 -Bits 24
        $script:inputAudio.Channels = 2
        $script:outputAudio.Channels = 2
        $script:outputAudio.Codec = 'pcm_s24le'
        (Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio).Bits | Should -Be 24
    }
    It 'accepts a complete extensible PCM format' {
        $extended = ConvertTo-TestExtensibleWave $script:wave
        try { (Assert-WacWaveOutput $extended $script:inputAudio $script:outputAudio).Frames | Should -Be 144000 }
        finally { $extended.Dispose() }
    }
    It 'rejects an extensible format claiming bytes beyond its own chunk' {
        $extended = ConvertTo-TestExtensibleWave $script:wave -ExtraSize 200
        try { { Assert-WacWaveOutput $extended $script:inputAudio $script:outputAudio } | Should -Throw '*extensible WAV format length*' }
        finally { $extended.Dispose() }
    }
    It 'rejects a zero-length or header-only output: <Length>' -ForEach @(@{ Length = 0 }, @{ Length = 44 }) {
        $script:wave.SetLength($Length)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw
    }
    It 'rejects truncated samples even when ffprobe reports plausible audio' {
        $script:wave.SetLength($script:wave.Length - 10)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*declared size*'
    }
    It 'rejects truncated data after RIFF length was repaired' {
        $script:wave.SetLength($script:wave.Length - 10)
        Set-TestUInt32 $script:wave 4 ($script:wave.Length - 8)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*chunk is truncated*'
    }
    It 'rejects a complete but implausibly short result after both lengths were repaired' {
        $script:wave.SetLength(44 + 48000 * 2)
        Set-TestUInt32 $script:wave 4 ($script:wave.Length - 8)
        Set-TestUInt32 $script:wave 40 ($script:wave.Length - 44)
        $script:outputAudio.DurationSeconds = 1
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*Output duration*'
    }
    It 'rejects mismatched probe <Field>' -ForEach @(
        @{ Field = 'Codec'; Value = 'mp3' }, @{ Field = 'Channels'; Value = 2 },
        @{ Field = 'SampleRate'; Value = 44100 }, @{ Field = 'DurationSeconds'; Value = 2.9 }
    ) {
        $script:outputAudio.$Field = $Value
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*disagree*'
    }
    It 'rejects changed selected channel count' {
        $script:inputAudio.Channels = 2
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*channel count*'
    }
    It 'enforces 10 ms PCM duration tolerance' {
        $script:inputAudio.DurationSeconds = 3.010
        (Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio).Frames | Should -Be 144000
        $script:inputAudio.DurationSeconds = 3.011
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*tolerance 0.01*'
    }
    It 'allows at most 100 ms compressed padding difference' {
        $script:inputAudio.Codec = 'mp3'
        $script:inputAudio.DurationSeconds = 3.100
        (Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio).Frames | Should -Be 144000
        $script:inputAudio.DurationSeconds = 3.101
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*tolerance 0.1*'
    }
    It 'rejects an RF64 signature without its required header' {
        $script:wave.Position = 0
        $script:wave.Write([Text.Encoding]::ASCII.GetBytes('RF64'), 0, 4)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*RF64*'
    }
    It 'rejects empty sample data' {
        $script:wave.SetLength(44)
        Set-TestUInt32 $script:wave 4 36
        Set-TestUInt32 $script:wave 40 0
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*empty*'
    }
    It 'rejects inconsistent sample alignment' {
        $script:wave.Position = 32
        $script:wave.WriteByte(3)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*PCM parameters*'
    }
}

Describe 'AC-025/026: enforce the requested output format and channel policy' -Tag 'Unit', 'Output' {
    BeforeEach {
        $script:wave = New-TestWave
        $script:inputAudio = [pscustomobject]@{ Codec = 'pcm_s16le'; Channels = 1; DurationSeconds = 3.0 }
        $script:outputAudio = [pscustomobject]@{ Codec = 'pcm_s16le'; Channels = 1; DurationSeconds = 3.0; SampleRate = 48000; ChannelLayout = $null }
        $script:policy = [pscustomobject]@{ SampleRate = 48000; Bits = 16; Codec = 'pcm_s16le'; Channels = 1; Layout = 'mono'; Rf64 = $false }
    }
    AfterEach { $script:wave.Dispose() }

    It 'accepts requested <Bits>-bit <Layout> output' -ForEach @(
        @{ Bits = 16; Channels = 1; Layout = 'mono' }, @{ Bits = 24; Channels = 1; Layout = 'mono' },
        @{ Bits = 16; Channels = 2; Layout = 'stereo' }, @{ Bits = 24; Channels = 2; Layout = 'stereo' }
    ) {
        $script:wave.Dispose()
        $script:wave = New-TestWave -Bits $Bits -Channels $Channels
        $script:inputAudio.Channels = $Channels
        $script:outputAudio.Channels = $Channels
        $script:outputAudio.Codec = 'pcm_s' + $Bits + 'le'
        $script:outputAudio.ChannelLayout = $Layout
        $script:policy.Bits = $Bits
        $script:policy.Codec = $script:outputAudio.Codec
        $script:policy.Channels = $Channels
        $script:policy.Layout = $Layout
        $result = Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio -OutputPolicy $script:policy
        $result.Bits | Should -Be $Bits
        $result.Channels | Should -Be $Channels
        $script:wave.CanRead | Should -BeTrue
    }
    It 'rejects a probe/header-consistent legacy 192 kHz export' {
        $script:wave.Dispose()
        $script:wave = New-TestWave -Rate 192000 -Frames 576000
        $script:outputAudio.SampleRate = 192000
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $script:policy } | Should -Throw '*requested encoding*'
    }
    It 'rejects a probe/header-consistent wrong bit depth' {
        $script:wave.Dispose()
        $script:wave = New-TestWave -Bits 24
        $script:outputAudio.Codec = 'pcm_s24le'
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $script:policy } | Should -Throw '*requested encoding*'
    }
    It 'permits explicit mono conversion of the selected stereo track' {
        $script:inputAudio.Channels = 2
        (Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $script:policy).Channels | Should -Be 1
    }
    It 'rejects an unrequested mono conversion even if the probe agrees' {
        $script:inputAudio.Channels = 2
        $script:policy.Channels = 2
        $script:policy.Layout = 'stereo'
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $script:policy } | Should -Throw '*requested encoding*'
    }
    It 'rejects an unexpected stereo upmix' {
        $script:wave.Dispose()
        $script:wave = New-TestWave -Channels 2
        $script:policy.Channels = 2
        $script:policy.Layout = 'stereo'
        $script:outputAudio.Channels = 2
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $script:policy } | Should -Throw '*channel count changed*'
    }
    It 'rejects an inconsistent output probe layout' {
        $script:outputAudio.ChannelLayout = 'stereo'
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $script:policy } | Should -Throw '*channel layout*'
    }
    It 'accepts a conventional or unspecified mono extensible mask: <Mask>' -ForEach @(@{ Mask = 4 }, @{ Mask = 0 }) {
        $extended = ConvertTo-TestExtensibleWave $script:wave -Mask $Mask
        try { (Assert-WacWaveOutput $extended $script:inputAudio $script:outputAudio $script:policy).Channels | Should -Be 1 }
        finally { $extended.Dispose() }
    }
    It 'rejects an unexpected extensible channel mask' {
        $extended = ConvertTo-TestExtensibleWave $script:wave -Mask 1
        try { { Assert-WacWaveOutput $extended $script:inputAudio $script:outputAudio $script:policy } | Should -Throw '*channel layout*' }
        finally { $extended.Dispose() }
    }
    It 'accepts extensible stereo PCM24 with the expected FL/FR mask' {
        $script:wave.Dispose()
        $script:wave = New-TestWave -Channels 2 -Bits 24
        $script:inputAudio.Channels = 2
        $script:outputAudio.Channels = 2
        $script:outputAudio.Codec = 'pcm_s24le'
        $script:policy.Channels = 2
        $script:policy.Layout = 'stereo'
        $script:policy.Codec = 'pcm_s24le'
        $script:policy.Bits = 24
        $extended = ConvertTo-TestExtensibleWave $script:wave -Mask 3
        try { (Assert-WacWaveOutput $extended $script:inputAudio $script:outputAudio $script:policy).Bits | Should -Be 24 }
        finally { $extended.Dispose() }
    }
    It 'rejects an extensible valid-bit count different from the requested depth' {
        $extended = ConvertTo-TestExtensibleWave $script:wave -ValidBits 12
        try { { Assert-WacWaveOutput $extended $script:inputAudio $script:outputAudio $script:policy } | Should -Throw '*requested encoding*' }
        finally { $extended.Dispose() }
    }
    It 'rejects ordinary RIFF when RF64 was requested' {
        $script:policy.Rf64 = $true
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $script:policy } | Should -Throw '*RF64 policy*'
    }
    It 'treats <Name> chunk identifiers as case-sensitive' -ForEach @(
        @{ Name = 'RIFF'; Offset = 0; Text = 'riff' }, @{ Name = 'WAVE'; Offset = 8; Text = 'wave' },
        @{ Name = 'fmt '; Offset = 12; Text = 'FMT ' }, @{ Name = 'data'; Offset = 36; Text = 'DATA' }
    ) {
        $script:wave.Position = $Offset
        $script:wave.Write([Text.Encoding]::ASCII.GetBytes($Text), 0, 4)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $script:policy } | Should -Throw
    }
}

Describe 'AC-027: validate RF64 sizes and samples on the held stream' -Tag 'Unit', 'Output' {
    BeforeEach {
        $plain = New-TestWave
        try { $script:wave = ConvertTo-TestRf64Wave $plain }
        finally { $plain.Dispose() }
        $script:inputAudio = [pscustomobject]@{ Codec = 'pcm_s16le'; Channels = 1; DurationSeconds = 3.0 }
        $script:outputAudio = [pscustomobject]@{ Codec = 'pcm_s16le'; Channels = 1; DurationSeconds = 3.0; SampleRate = 48000 }
    }
    AfterEach { $script:wave.Dispose() }

    It 'accepts a complete small RF64 fixture without closing the held stream' {
        $result = Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio
        $result.Rf64 | Should -BeTrue
        $result.Frames | Should -Be 144000
        $script:wave.CanRead | Should -BeTrue
    }
    It 'enforces explicit RF64 policy for an otherwise valid RF64 output' {
        $policy = [pscustomobject]@{ SampleRate = 48000; Bits = 16; Codec = 'pcm_s16le'; Channels = 1; Layout = 'mono'; Rf64 = $true }
        (Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $policy).Rf64 | Should -BeTrue
        $policy.Rf64 = $false
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio $policy } | Should -Throw '*RF64 policy*'
    }
    It 'rejects a missing container size sentinel' {
        Set-TestUInt32 $script:wave 4 ($script:wave.Length - 8)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*RF64 header*'
    }
    It 'requires ds64 before all other chunks' {
        $script:wave.Position = 12
        $script:wave.Write([Text.Encoding]::ASCII.GetBytes('JUNK'), 0, 4)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*first 28-byte ds64*'
    }
    It 'rejects malformed ds64 chunk length: <Length>' -ForEach @(@{ Length = 0 }, @{ Length = 27 }, @{ Length = 40 }) {
        Set-TestUInt32 $script:wave 16 $Length
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*RF64 header*'
    }
    It 'rejects unsupported ds64 tables' {
        Set-TestUInt32 $script:wave 44 1
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*ds64 chunk table*'
    }
    It 'rejects 64-bit overflow in <Field>' -ForEach @(
        @{ Field = 'RIFF length'; Offset = 20 }, @{ Field = 'data length'; Offset = 28 }, @{ Field = 'sample count'; Offset = 36 }
    ) {
        Set-TestUInt64 $script:wave $Offset ([uint64]::MaxValue)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*64-bit bounds*'
        $script:wave.CanRead | Should -BeTrue
    }
    It 'rejects a 64-bit container size that disagrees with actual length' {
        Set-TestUInt64 $script:wave 20 ([uint64]4294967296)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*declared size*'
    }
    It 'bounds a large data length before seeking or addition can overflow' {
        Set-TestUInt64 $script:wave 28 ([uint64][long]::MaxValue)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*chunk is truncated*'
    }
    It 'rejects RF64 data without its sentinel' {
        Set-TestUInt32 $script:wave 76 288000
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*RF64 data size*'
    }
    It 'rejects empty sample data described by ds64' {
        Set-TestUInt64 $script:wave 28 0
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*empty*'
    }
    It 'rejects inconsistent ds64 sample count: <Frames>' -ForEach @(
        @{ Frames = [uint64]0 }, @{ Frames = [uint64]144001 }, @{ Frames = [uint64]9007199254740993 }
    ) {
        Set-TestUInt64 $script:wave 36 $Frames
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*sample count disagrees*'
    }
    It 'rejects duplicate ds64 chunks' {
        $script:wave.Position = 48
        $script:wave.Write([Text.Encoding]::ASCII.GetBytes('ds64'), 0, 4)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*duplicate RF64 ds64*'
    }
    It 'rejects a sentinel on an unlisted non-data chunk' {
        Set-TestUInt32 $script:wave 52 ([uint32]::MaxValue)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*chunk size sentinel*'
    }
    It 'rejects truncation even if the RF64 container length was repaired' {
        $script:wave.SetLength($script:wave.Length - 2)
        Set-TestUInt64 $script:wave 20 ($script:wave.Length - 8)
        { Assert-WacWaveOutput $script:wave $script:inputAudio $script:outputAudio } | Should -Throw '*chunk is truncated*'
    }
}

Describe 'Selected-stream duration metadata' -Tag 'Unit', 'Output' {
    It 'parses invariant seconds' {
        Get-WacStreamDuration ([pscustomobject]@{ duration = '12.345' }) | Should -Be 12.345
    }
    It 'uses Matroska stream end time minus its start time' {
        Get-WacStreamDuration ([pscustomobject]@{ tags = @{ DURATION = '00:00:03.500000000' }; start_time = '0.500' }) | Should -Be 3
    }
    It 'prefers direct stream duration over tags' {
        Get-WacStreamDuration ([pscustomobject]@{ duration = '2.5'; tags = @{ DURATION = '00:00:03.500' } }) | Should -Be 2.5
    }
    It 'leaves unknown or invalid timing unavailable: <Value>' -ForEach @(
        @{ Value = $null }, @{ Value = 'N/A' }, @{ Value = 'NaN' }, @{ Value = 'Infinity' },
        @{ Value = '0' }, @{ Value = '-1' }, @{ Value = '3,5' }
    ) {
        Get-WacStreamDuration ([pscustomobject]@{ duration = $Value }) | Should -BeNullOrEmpty
    }
}
