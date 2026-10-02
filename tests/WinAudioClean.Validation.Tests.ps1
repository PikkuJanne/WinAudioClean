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
    function ConvertTo-TestExtensibleWave {
        param($Stream, [uint16]$ExtraSize = 22)
        $bytes = $Stream.ToArray()
        $extended = [IO.MemoryStream]::new()
        $writer = [IO.BinaryWriter]::new($extended, [Text.Encoding]::ASCII, $true)
        $writer.Write($bytes, 0, 36)
        $writer.Write($ExtraSize)
        $writer.Write([uint16]16)
        $writer.Write([uint32]4)
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
    It 'rejects unsupported large-file signatures explicitly' {
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
