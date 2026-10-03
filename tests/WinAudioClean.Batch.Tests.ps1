BeforeDiscovery {
    $invalidBatchManifestCases = @(
        @{ Case = 'truncated'; Json = '{"schemaVersion":1,"inputs":' }
        @{ Case = 'trailing data'; Json = '{"schemaVersion":1,"inputs":["a.wav"]} false' }
        @{ Case = 'root array'; Json = '[]' }
        @{ Case = 'missing version'; Json = '{"inputs":["a.wav"]}' }
        @{ Case = 'unknown version'; Json = '{"schemaVersion":2,"inputs":["a.wav"]}' }
        @{ Case = 'string version'; Json = '{"schemaVersion":"1","inputs":["a.wav"]}' }
        @{ Case = 'decimal version'; Json = '{"schemaVersion":1.0,"inputs":["a.wav"]}' }
        @{ Case = 'boolean version'; Json = '{"schemaVersion":true,"inputs":["a.wav"]}' }
        @{ Case = 'wrong key case'; Json = '{"schemaVersion":1,"Inputs":["a.wav"]}' }
        @{ Case = 'unknown key'; Json = '{"schemaVersion":1,"inputs":["a.wav"],"command":"echo injected"}' }
        @{ Case = 'duplicate root key'; Json = '{"schemaVersion":1,"inputs":["a.wav"],"inputs":["b.wav"]}' }
        @{ Case = 'escaped duplicate root key'; Json = '{"schemaVersion":1,"inputs":["a.wav"],"inpu\u0074s":["b.wav"]}' }
        @{ Case = 'case-coalescing keys'; Json = '{"schemaVersion":1,"inputs":["a.wav"],"Inputs":["b.wav"]}' }
        @{ Case = 'missing inputs'; Json = '{"schemaVersion":1}' }
        @{ Case = 'null inputs'; Json = '{"schemaVersion":1,"inputs":null}' }
        @{ Case = 'scalar inputs'; Json = '{"schemaVersion":1,"inputs":"a.wav"}' }
        @{ Case = 'empty array'; Json = '{"schemaVersion":1,"inputs":[]}' }
        @{ Case = 'empty entry'; Json = '{"schemaVersion":1,"inputs":[""]}' }
        @{ Case = 'whitespace entry'; Json = '{"schemaVersion":1,"inputs":["   "]}' }
        @{ Case = 'null entry'; Json = '{"schemaVersion":1,"inputs":[null]}' }
        @{ Case = 'numeric entry'; Json = '{"schemaVersion":1,"inputs":[1]}' }
        @{ Case = 'boolean entry'; Json = '{"schemaVersion":1,"inputs":[true]}' }
        @{ Case = 'nested array'; Json = '{"schemaVersion":1,"inputs":[["a.wav"]]}' }
        @{ Case = 'object entry'; Json = '{"schemaVersion":1,"inputs":[{"path":"a.wav"}]}' }
    )
    $invalidRelativeBatchCases = @(
        @{ Case = 'pipe character'; Json = '{"schemaVersion":1,"inputs":["first.wav","bad|name.wav","third.wav"]}'; InvalidPath = 'bad|name.wav' }
        @{ Case = 'escaped NUL'; Json = '{"schemaVersion":1,"inputs":["first.wav","bad\u0000name.wav","third.wav"]}'; InvalidPath = ('bad' + [char]0 + 'name.wav') }
    )
}

BeforeAll {
    $batchRepository = Split-Path $PSScriptRoot -Parent
    . (Join-Path $batchRepository 'WinAudioClean.ps1')
    . (Join-Path $batchRepository 'WinAudioClean.Settings.ps1')
    . (Join-Path $batchRepository 'WinAudioClean.Batch.ps1')
    . (Join-Path $PSScriptRoot 'fixtures/TestProcess.ps1')
    $batchUtf8 = New-Object Text.UTF8Encoding($false, $true)
    $batchUnicode = ([string][char]0x00E4) + [char]0x00F6 + [char]0x00C5
    function New-WacBatchTestFolder {
        $folder = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($folder)
        $folder
    }
    function Write-WacBatchTestManifest {
        param([string]$Path, [object[]]$Inputs)
        $json = [ordered]@{ schemaVersion = 1; inputs = @($Inputs) } | ConvertTo-Json -Depth 5 -Compress
        [IO.File]::WriteAllText($Path, $json, $batchUtf8)
    }
    function Read-WacBatchTestJournal {
        param([string]$Path)
        $readerStream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader = New-Object IO.StreamReader($readerStream, $batchUtf8)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose(); $readerStream.Dispose() }
        foreach ($line in @($text -split '\r?\n' | Where-Object { $_.Length -gt 0 })) {
            $line | Should -Not -BeNullOrEmpty
            $line | ConvertFrom-Json
        }
    }
    function Get-WacBatchTestBytes {
        param([string]$Path)
        $readerStream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $buffer = New-Object IO.MemoryStream
        try { $readerStream.CopyTo($buffer); [Convert]::ToBase64String($buffer.ToArray()) }
        finally { $buffer.Dispose(); $readerStream.Dispose() }
    }
}

Describe 'AC-052/054: explicit input lists are ordered bounded data' -Tag 'Batch', 'Unit' {
    It 'preserves character-rich paths and repeated explicit entries in order without execution' {
        $folder = New-WacBatchTestFolder
        $path = Join-Path $folder 'inputs.json'
        $sentinel = Join-Path $folder 'executed.txt'
        $inputs = @('spaces and [draft].wav', "speaker's $batchUnicode (take 1) & guest.wav",
            '%WAC_BATCH_PERCENT%!literal!.wav', 'spaces and [draft].wav',
            ('$(Set-Content -LiteralPath ''' + $sentinel + ''' -Value executed).wav'))
        Write-WacBatchTestManifest -Path $path -Inputs $inputs
        $actual = @(Read-WacInputList -Path $path)
        $actual.Count | Should -Be $inputs.Count
        for ($index = 0; $index -lt $inputs.Count; $index++) {
            $actual[$index] | Should -BeExactly (Join-Path $folder $inputs[$index])
        }
        Test-Path -LiteralPath $sentinel | Should -BeFalse
    }

    It 'anchors relative entries beside the manifest rather than the calling working directory' {
        $folder = New-WacBatchTestFolder
        $cwd = New-WacBatchTestFolder
        $path = Join-Path $folder 'inputs.json'
        Write-WacBatchTestManifest -Path $path -Inputs @('recording.wav')
        [IO.File]::WriteAllBytes((Join-Path $folder 'recording.wav'), [byte[]](1, 2))
        [IO.File]::WriteAllBytes((Join-Path $cwd 'recording.wav'), [byte[]](9, 9))
        Push-Location -LiteralPath $cwd
        try { @(Read-WacInputList -Path $path)[0] | Should -BeExactly (Join-Path $folder 'recording.wav') }
        finally { Pop-Location }
    }

    It 'preserves invalid filesystem/URL strings for separate per-item failures' {
        $folder = New-WacBatchTestFolder
        $path = Join-Path $folder 'inputs.json'
        $inputs = @('https://invalid.example/audio.wav', 'FileSystem::C:\audio.wav', '\\server\audio.wav')
        Write-WacBatchTestManifest -Path $path -Inputs $inputs
        $actual = @(Read-WacInputList -Path $path)
        for ($index = 0; $index -lt $inputs.Count; $index++) { $actual[$index] | Should -BeExactly $inputs[$index] }
    }

    It 'anchors a relative <Case> entry as exact string data without preventing valid neighbors from being anchored' -Tag 'BatchInvalidPath' -ForEach $invalidRelativeBatchCases {
        $folder = New-WacBatchTestFolder
        $path = Join-Path $folder 'inputs.json'
        [IO.File]::WriteAllText($path, $Json, $batchUtf8)
        $before = Get-WacBatchTestBytes -Path $path
        $actual = @(Read-WacInputList -Path $path)
        $actual.Count | Should -Be 3
        $actual[0] | Should -BeExactly (Join-Path $folder 'first.wav')
        $actual[1] | Should -BeOfType [string]
        $actual[1] | Should -BeExactly ($folder + [IO.Path]::DirectorySeparatorChar + $InvalidPath)
        $actual[2] | Should -BeExactly (Join-Path $folder 'third.wav')
        Get-WacBatchTestBytes -Path $path | Should -BeExactly $before
    }

    It 'rejects <Case> manifests without changing their bytes' -ForEach $invalidBatchManifestCases {
        $path = Join-Path (New-WacBatchTestFolder) 'inputs.json'
        [IO.File]::WriteAllText($path, $Json, $batchUtf8)
        $before = Get-WacBatchTestBytes -Path $path
        { Read-WacInputList -Path $path } | Should -Throw
        Get-WacBatchTestBytes -Path $path | Should -BeExactly $before
    }

    It 'rejects malformed UTF8 and UTF16 bytes' -ForEach @(
        @{ Bytes = [byte[]](0xC3, 0x28) }; @{ Bytes = [byte[]](0xFF, 0xFE, 0x7B, 0, 0x7D, 0) }
    ) {
        $path = Join-Path (New-WacBatchTestFolder) 'inputs.json'
        [IO.File]::WriteAllBytes($path, $Bytes)
        { Read-WacInputList -Path $path } | Should -Throw
    }

    It 'accepts exactly 1 MiB including a UTF8 BOM and rejects the next byte' {
        $path = Join-Path (New-WacBatchTestFolder) 'inputs.json'
        $json = '{"schemaVersion":1,"inputs":["a.wav"]}'
        $payload = $batchUtf8.GetBytes($json + (' ' * (1048576 - 3 - $batchUtf8.GetByteCount($json))))
        [IO.File]::WriteAllBytes($path, ([byte[]](239, 187, 191) + $payload))
        (Get-Item -LiteralPath $path).Length | Should -Be 1048576
        @(Read-WacInputList -Path $path).Count | Should -Be 1
        [IO.File]::AppendAllText($path, ' ', $batchUtf8)
        { Read-WacInputList -Path $path } | Should -Throw '*1 MiB*'
    }

    It 'materializes all 1024 entries including payload beyond a CMD command line and rejects 1025' {
        $path = Join-Path (New-WacBatchTestFolder) 'inputs.json'
        $inputs = @(1..1024 | ForEach-Object { 'recording {0:D4} [draft] %literal%!.wav' -f $_ })
        Write-WacBatchTestManifest -Path $path -Inputs $inputs
        (Get-Item -LiteralPath $path).Length | Should -BeGreaterThan 8191
        $actual = @(Read-WacInputList -Path $path)
        $actual.Count | Should -Be 1024
        [IO.Path]::GetFileName($actual[0]) | Should -BeExactly $inputs[0]
        [IO.Path]::GetFileName($actual[1023]) | Should -BeExactly $inputs[1023]
        Write-WacBatchTestManifest -Path $path -Inputs ($inputs + @('overflow.wav'))
        { Read-WacInputList -Path $path } | Should -Throw '*1024*'
    }

    It 'accepts the direct list ceiling without deduplicating and rejects count/byte excess' {
        $inputs = @('same.wav') * 1024
        @(Resolve-WacBatchInputs -Parameters @{ InputPaths = $inputs }).Count | Should -Be 1024
        { Resolve-WacBatchInputs -Parameters @{ InputPaths = ($inputs + 'overflow.wav') } } | Should -Throw '*1024*'
        { Resolve-WacBatchInputs -Parameters @{ InputPaths = @(('x' * 1048576)) } } | Should -Throw '*1 MiB*'
    }

    It 'rejects <Case> input-source combinations before materializing a queue' -ForEach @(
        @{ Case = 'neither source'; Parameters = @{} }
        @{ Case = 'both sources'; Parameters = @{ InputPaths = @('a.wav'); InputListPath = 'missing.json' } }
        @{ Case = 'legacy input with list'; Parameters = @{ inputPath = 'a.wav'; InputPaths = @('a.wav') } }
        @{ Case = 'null array'; Parameters = @{ InputPaths = $null } }
        @{ Case = 'empty array'; Parameters = @{ InputPaths = @() } }
        @{ Case = 'empty item'; Parameters = @{ InputPaths = @('') } }
        @{ Case = 'numeric item'; Parameters = @{ InputPaths = @(1) } }
    ) {
        { Resolve-WacBatchInputs -Parameters $Parameters } | Should -Throw
    }

    It 'accepts a real PSBoundParametersDictionary without ambiguous Contains overloads' {
        function Invoke-WacBoundBatchQueue {
            [CmdletBinding()]
            param([string[]]$InputPaths, [string]$InputListPath)
            Resolve-WacBatchInputs -Parameters $PSBoundParameters
        }
        @(Invoke-WacBoundBatchQueue -InputPaths @('a.wav', 'b.wav')).Count | Should -Be 2
        $path = Join-Path (New-WacBatchTestFolder) 'inputs.json'
        Write-WacBatchTestManifest -Path $path -Inputs @('a.wav')
        @(Invoke-WacBoundBatchQueue -InputListPath $path).Count | Should -Be 1
    }
}

Describe 'AC-053: held JSONL journal retains completed records when a suffix append fails' -Tag 'Batch', 'Unit', 'OutputSafety' {
    It 'flushes independent compact UTF8 records with escaped diagnostic newlines and no BOM' {
        $path = Join-Path (New-WacBatchTestFolder) 'results.jsonl'
        $writer = Open-WacReportWriter -Path $path -CreateNew
        try {
            Add-WacBatchRecord -Writer $writer -Record @{ type = 'batch'; schemaVersion = 1 }
            Add-WacBatchRecord -Writer $writer -Record @{ type = 'item'; diagnostics = @("$batchUnicode`r`nsecond line") }
            [Convert]::FromBase64String((Get-WacBatchTestBytes -Path $path))[0] | Should -Be 0x7B
            $records = @(Read-WacBatchTestJournal -Path $path)
            $records.Count | Should -Be 2
            $records[1].diagnostics[0] | Should -BeExactly "$batchUnicode`r`nsecond line"
        } finally { Close-WacReportWriter -Writer $writer }
    }

    It 'rolls back only the newly written suffix after an actual partial stream write' {
        $path = Join-Path (New-WacBatchTestFolder) 'results.jsonl'
        $writer = Open-WacReportWriter -Path $path -CreateNew
        try {
            Add-WacBatchRecord -Writer $writer -Record @{ type = 'batch'; schemaVersion = 1 }
            $before = Get-WacBatchTestBytes -Path $path
            $stream = $writer.Stream
            $wrapper = [pscustomobject]@{ Real = $stream; CanWrite = $true; SafeFileHandle = $stream.SafeFileHandle }
            $wrapper | Add-Member ScriptProperty Length { $this.Real.Length }
            $wrapper | Add-Member ScriptProperty Position { $this.Real.Position } { param($Value) $this.Real.Position = $Value }
            $wrapper | Add-Member ScriptMethod Write {
                param($Bytes, $Offset, $Count)
                $this.Real.Write($Bytes, $Offset, [Math]::Min(5, $Count))
                throw 'injected batch partial-write failure'
            }
            $wrapper | Add-Member ScriptMethod SetLength { param($Length) $this.Real.SetLength($Length) }
            $wrapper | Add-Member ScriptMethod Flush { param($Durable) $this.Real.Flush($Durable) }
            $writer.Stream = $wrapper
            { Add-WacBatchRecord -Writer $writer -Record @{ type = 'item'; index = 1 } } | Should -Throw '*partial-write failure*'
            Get-WacBatchTestBytes -Path $path | Should -BeExactly $before
            $writer.Stream = $stream
            Add-WacBatchRecord -Writer $writer -Record @{ type = 'summary'; exitCode = 5 }
            @(Read-WacBatchTestJournal -Path $path).Count | Should -Be 2
        } finally { $writer.Stream = $stream; Close-WacReportWriter -Writer $writer }
    }

    It 'refuses to append batch records to a pre-existing nonexclusive writer' {
        $path = Join-Path (New-WacBatchTestFolder) 'foreign.jsonl'
        [IO.File]::WriteAllText($path, 'foreign journal', $batchUtf8)
        $writer = Open-WacReportWriter -Path $path
        try { { Add-WacBatchRecord -Writer $writer -Record @{ type = 'batch' } } | Should -Throw '*exclusively created*' }
        finally { Close-WacReportWriter -Writer $writer }
        [IO.File]::ReadAllText($path) | Should -BeExactly 'foreign journal'
    }
}

Describe 'AC-053: sequential batch orchestration freezes choices and aggregates per-item outcomes' -Tag 'Batch', 'Unit' {
    BeforeEach {
        $batchFolder = New-WacBatchTestFolder
        $batchResultPath = Join-Path $batchFolder 'results.jsonl'
        $batchInputs = @('first.wav', 'second.wav', 'third.wav')
        $batchParameters = @{ BatchResultPath = $batchResultPath; NonInteractive = $true }
        $batchResolved = Resolve-WacSettings -Explicit @{ Mode = 'Zoom'; OutputDirectory = $batchFolder }
        $script:batchInvocations = New-Object 'System.Collections.Generic.List[object]'
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:batchInvocations.Add($Arguments)
            [pscustomobject]@{ ExitCode = 0; Diagnostics = @() }
        }
    }

    It 'runs ordered repeated entries with one mode selection and frozen child settings' {
        $batchResolved.Values.Mode = $null
        Mock Test-WacInteractive { $true }
        Mock Read-WacMode { 'Zoom' }
        $result = Invoke-WacBatch -Inputs @('a.wav', 'a.wav', 'b.wav') -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be 0
        Should -Invoke Read-WacMode -Times 1 -Exactly
        $script:batchInvocations.Count | Should -Be 3
        @($script:batchInvocations | ForEach-Object { $_.inputPath }) -join ',' | Should -BeExactly 'a.wav,a.wav,b.wav'
        foreach ($arguments in $script:batchInvocations) {
            $arguments.Mode | Should -BeExactly 'Zoom'
            $arguments.IgnoreSavedSettings | Should -BeTrue
            $arguments.OutputDirectory | Should -BeExactly $batchFolder
            $arguments.Contains('InputPaths') | Should -BeFalse
        }
        $batchResolved.Values.Mode | Should -BeNullOrEmpty
        $records = @(Read-WacBatchTestJournal -Path $result.ResultPath)
        $records.Count | Should -Be 5
        $records[0].origins.Mode | Should -BeExactly 'Interactive'
        $records[4].counts.success | Should -Be 3
    }

    It 'retains captured choices when the isolated saved config changes after the first child' {
        $config = Join-Path $batchFolder 'isolated settings.json'
        $null = Save-WacSettings -Path $config -Values @{ Mode = 'Raw'; Preset = 'Gentle'; OutputDirectory = $batchFolder }
        $batchResolved = Resolve-WacSettings -Saved (Read-WacSettings -Path $config)
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:batchInvocations.Add($Arguments)
            if ($script:batchInvocations.Count -eq 1) {
                $null = Save-WacSettings -Path $config -Values @{ Mode = 'Zoom'; OutputDirectory = $batchFolder }
            }
            [pscustomobject]@{ ExitCode = 0; Diagnostics = @() }
        }
        $result = Invoke-WacBatch -Inputs $batchInputs -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be 0
        (Read-WacSettings -Path $config).Mode | Should -BeExactly 'Zoom'
        foreach ($arguments in $script:batchInvocations) {
            $arguments.Mode | Should -BeExactly 'Raw'
            $arguments.Preset | Should -BeExactly 'Gentle'
            $arguments.IgnoreSavedSettings | Should -BeTrue
            $arguments.Contains('SettingsPath') | Should -BeFalse
        }
        $records = @(Read-WacBatchTestJournal -Path $result.ResultPath)
        $records[0].settings.mode | Should -BeExactly 'Raw'
    }

    It 'rejects an omitted unattended mode before journal allocation, output creation or children' {
        $batchResolved.Values.Mode = $null
        $batchResolved.Values.OutputDirectory = Join-Path $batchFolder 'uncreated output'
        Mock Test-WacInteractive { $false }
        { Invoke-WacBatch -Inputs $batchInputs -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1' } | Should -Throw '*mode is required*'
        Should -Invoke Invoke-WacBatchItem -Times 0 -Exactly
        Test-Path -LiteralPath $batchResultPath | Should -BeFalse
        Test-Path -LiteralPath $batchResolved.Values.OutputDirectory | Should -BeFalse
    }

    It 'rejects a journal path equal to a missing requested input before creating it or starting children' {
        $batchInputs = @($batchResultPath, 'second.wav')
        $result = Invoke-WacBatch -Inputs $batchInputs -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be 5
        Should -Invoke Invoke-WacBatchItem -Times 0 -Exactly
        Test-Path -LiteralPath $batchResultPath | Should -BeFalse
    }

    It 'retains an ordinary one-item exit <Code>' -ForEach @(@{Code=0},@{Code=2},@{Code=3},@{Code=4},@{Code=5},@{Code=7},@{Code=130}) {
        Mock Invoke-WacBatchItem { [pscustomobject]@{ ExitCode = $Code; Diagnostics = @('bounded diagnostic') } }
        $result = Invoke-WacBatch -Inputs @('a.wav') -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be $Code
        $records = @(Read-WacBatchTestJournal -Path $result.ResultPath)
        $records[1].exitCode | Should -Be $Code
        $records[2].exitCode | Should -Be $Code
        $result.ReportingComplete | Should -BeTrue
    }

    It 'continues after a per-item failure and records multi-item failure code 6' {
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:batchInvocations.Add($Arguments)
            $code = if ($Arguments.inputPath -eq 'second.wav') { 2 } else { 0 }
            [pscustomobject]@{ ExitCode = $code; Diagnostics = @('item diagnostic') }
        }
        $result = Invoke-WacBatch -Inputs $batchInputs -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be 6
        $script:batchInvocations.Count | Should -Be 3
        $records = @(Read-WacBatchTestJournal -Path $result.ResultPath)
        @($records[1..3] | ForEach-Object { $_.status }) -join ',' | Should -BeExactly 'SUCCESS,FAILED,SUCCESS'
        $records[4].counts.success | Should -Be 2
        $records[4].counts.failed | Should -Be 1
    }

    It 'records warning-only batches as code 7' {
        Mock Invoke-WacBatchItem { [pscustomobject]@{ ExitCode = 7; Diagnostics = @('warning') } }
        $result = Invoke-WacBatch -Inputs $batchInputs -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be 7
        $records = @(Read-WacBatchTestJournal -Path $result.ResultPath)
        $records[4].counts.warning | Should -Be 3
    }

    It 'stops after child cancellation and records later entries as not started' {
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:batchInvocations.Add($Arguments)
            [pscustomobject]@{ ExitCode = 130; Diagnostics = @('cancelled') }
        }
        $result = Invoke-WacBatch -Inputs $batchInputs -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be 130
        $script:batchInvocations.Count | Should -Be 1
        $records = @(Read-WacBatchTestJournal -Path $result.ResultPath)
        $records[1].status | Should -BeExactly 'CANCELLED'
        $records[2].status | Should -BeExactly 'NOT_STARTED'
        $records[2].exitCode | Should -BeNullOrEmpty
        $records[4].counts.cancelled | Should -Be 1
        $records[4].counts.notStarted | Should -Be 2
    }

    It 'cancels the common menu before any child while preserving every not-started entry' {
        $batchResolved.Values.Mode = $null
        Mock Test-WacInteractive { $true }
        Mock Read-WacMode { $null }
        $result = Invoke-WacBatch -Inputs $batchInputs -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be 130
        Should -Invoke Invoke-WacBatchItem -Times 0 -Exactly
        Should -Invoke Read-WacMode -Times 1 -Exactly
        $records = @(Read-WacBatchTestJournal -Path $result.ResultPath)
        $records[4].counts.notStarted | Should -Be 3
    }

    It 'fails result allocation before starting any child and preserves foreign bytes' {
        [IO.File]::WriteAllBytes($batchResultPath, [byte[]](4, 5, 6))
        $result = Invoke-WacBatch -Inputs $batchInputs -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be 5
        $result.ReportingComplete | Should -BeFalse
        Should -Invoke Invoke-WacBatchItem -Times 0 -Exactly
        Get-WacBatchTestBytes -Path $batchResultPath | Should -BeExactly 'BAUG'
    }

    It 'stops new jobs after <Stage> persistence failure and retains prior records and exports' -ForEach @(
        @{ Stage = 'first item'; FailedType = 'item'; ExpectedJobs = 1; ExpectedRecords = 1 }
        @{ Stage = 'summary'; FailedType = 'summary'; ExpectedJobs = 3; ExpectedRecords = 4 }
    ) {
        $batchOriginalAppender = (Get-Command Add-WacBatchRecord).ScriptBlock
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:batchInvocations.Add($Arguments)
            [IO.File]::WriteAllBytes((Join-Path $batchFolder ($Arguments.inputPath + '.export')), [byte[]](4, 5, 6))
            [pscustomobject]@{ ExitCode = 0; Diagnostics = @() }
        }
        Mock Add-WacBatchRecord {
            param($Writer, $Record)
            if ($Record.type -eq $FailedType) { throw 'injected journal persistence failure' }
            & $batchOriginalAppender -Writer $Writer -Record $Record
        }
        $result = Invoke-WacBatch -Inputs $batchInputs -Parameters $batchParameters -ResolvedSettings $batchResolved -ApplicationPath 'unused.ps1'
        $result.ExitCode | Should -Be 5
        $result.ReportingComplete | Should -BeFalse
        $script:batchInvocations.Count | Should -Be $ExpectedJobs
        @(Read-WacBatchTestJournal -Path $result.ResultPath).Count | Should -Be $ExpectedRecords
        @(Get-ChildItem -LiteralPath $batchFolder -Filter '*.export').Count | Should -Be $ExpectedJobs
    }
}

Describe 'AC-052/053/054: isolated batch entry points run actual single-file children' -Tag 'Batch', 'EntryPoint', 'Runtime' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'fixtures/New-NativeProcessFixture.ps1')
        $batchNative = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'batch native fixture.exe')
        $batchShell = (Get-Process -Id $PID).Path
        function New-WacBatchSandbox {
            $folder = New-WacBatchTestFolder
            foreach ($name in @('WinAudioClean.ps1', 'WinAudioClean.IO.ps1', 'WinAudioClean.Settings.ps1', 'WinAudioClean.Batch.ps1')) {
                [IO.File]::Copy((Join-Path $batchRepository $name), (Join-Path $folder $name))
            }
            foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) { [IO.File]::Copy($batchNative, (Join-Path $folder $name)) }
            $cwd = Join-Path $folder 'different cwd'
            $null = [IO.Directory]::CreateDirectory($cwd)
            [pscustomobject]@{ Root = $folder; App = Join-Path $folder 'WinAudioClean.ps1'; Config = Join-Path $folder 'settings.json'
                Manifest = Join-Path $folder 'inputs.json'; Output = Join-Path $folder 'output'; Result = Join-Path $folder 'results.jsonl'
                Cwd = $cwd; RenderArgv = Join-Path $folder 'last render.json'; NativePid = Join-Path $folder 'native.pid' }
        }
        function Invoke-WacBatchCase {
            param($Sandbox, [string]$Case = 'manifest', [hashtable]$ExtraEnvironment = @{})
            $driver = Join-Path $PSScriptRoot 'fixtures/Invoke-BatchCase.ps1'
            $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -ApplicationPath {1} -SettingsPath {2} -ManifestPath {3} -OutputDirectory {4} -ResultPath {5} -Case {6}' -f
                (ConvertTo-WacTestQuotedArgument $driver), (ConvertTo-WacTestQuotedArgument $Sandbox.App),
                (ConvertTo-WacTestQuotedArgument $Sandbox.Config), (ConvertTo-WacTestQuotedArgument $Sandbox.Manifest),
                (ConvertTo-WacTestQuotedArgument $Sandbox.Output), (ConvertTo-WacTestQuotedArgument $Sandbox.Result),
                (ConvertTo-WacTestQuotedArgument $Case)
            $environment = @{ WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_ARGV_PATH = $Sandbox.RenderArgv
                WAC_TEST_VERSION_PID_PATH = $Sandbox.NativePid; WAC_TEST_FILTERS_PID_PATH = $Sandbox.NativePid
                WAC_TEST_PROBE_PID_PATH = $Sandbox.NativePid; PSModulePath = $null }
            foreach ($name in $ExtraEnvironment.Keys) { $environment[$name] = $ExtraEnvironment[$name] }
            Invoke-WacTestProcess -FilePath $batchShell -Arguments $arguments -WorkingDirectory $Sandbox.Cwd -EnvironmentVariables $environment -TimeoutMilliseconds 60000
        }
    }

    It 'processes valid-missing-valid in manifest order with durable results and unchanged sources/config' {
        $sandbox = New-WacBatchSandbox
        foreach ($name in @('first.wav', 'third.wav')) { [IO.File]::WriteAllBytes((Join-Path $sandbox.Root $name), [byte[]](1, 2, 3, 4)) }
        [IO.File]::WriteAllBytes((Join-Path $sandbox.Cwd 'first.wav'), [byte[]](9, 9))
        Write-WacBatchTestManifest -Path $sandbox.Manifest -Inputs @('first.wav', 'missing.wav', 'third.wav')
        $result = Invoke-WacBatchCase -Sandbox $sandbox
        $result.ExitCode | Should -Be 6 -Because ($result.StandardOutput + $result.StandardError)
        $records = @(Read-WacBatchTestJournal -Path $sandbox.Result)
        $records.Count | Should -Be 5
        @($records[1..3] | ForEach-Object { $_.status }) -join ',' | Should -BeExactly 'SUCCESS,FAILED,SUCCESS'
        for ($index = 1; $index -le 3; $index++) { $records[$index].index | Should -Be $index }
        $records[1].inputPath | Should -BeExactly (Join-Path $sandbox.Root 'first.wav')
        $records[2].exitCode | Should -Be 2
        $records[4].exitCode | Should -Be 6
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav').Count | Should -Be 2
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json').Count | Should -Be 2
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.partial' -Force).Count | Should -Be 0
        Get-WacBatchTestBytes -Path (Join-Path $sandbox.Root 'first.wav') | Should -BeExactly 'AQIDBA=='
        Get-WacBatchTestBytes -Path (Join-Path $sandbox.Cwd 'first.wav') | Should -BeExactly 'CQk='
        Test-Path -LiteralPath $sandbox.Config | Should -BeFalse
        $result.StandardOutput | Should -Not -Match 'Enter selection|Press any key'
    }

    It 'continues valid-relative <Case>-valid as success/failure2/success with a complete durable journal' -Tag 'BatchInvalidPath' -ForEach $invalidRelativeBatchCases {
        $sandbox = New-WacBatchSandbox
        foreach ($name in @('first.wav', 'third.wav')) { [IO.File]::WriteAllBytes((Join-Path $sandbox.Root $name), [byte[]](1, 2, 3, 4)) }
        [IO.File]::WriteAllText($sandbox.Manifest, $Json, $batchUtf8)
        $manifestBefore = Get-WacBatchTestBytes -Path $sandbox.Manifest
        $result = Invoke-WacBatchCase -Sandbox $sandbox
        $result.ExitCode | Should -Be 6 -Because ($result.StandardOutput + $result.StandardError)
        $records = @(Read-WacBatchTestJournal -Path $sandbox.Result)
        $records.Count | Should -Be 5
        @($records[1..3] | ForEach-Object { $_.status }) -join ',' | Should -BeExactly 'SUCCESS,FAILED,SUCCESS'
        for ($index = 1; $index -le 3; $index++) { $records[$index].index | Should -Be $index }
        $records[1].inputPath | Should -BeExactly (Join-Path $sandbox.Root 'first.wav')
        $records[2].inputPath | Should -BeExactly ($sandbox.Root + [IO.Path]::DirectorySeparatorChar + $InvalidPath)
        $records[2].exitCode | Should -Be 2
        $records[2].diagnostics.Count | Should -BeGreaterThan 0
        $records[3].inputPath | Should -BeExactly (Join-Path $sandbox.Root 'third.wav')
        $records[4].exitCode | Should -Be 6
        $records[4].counts.success | Should -Be 2
        $records[4].counts.failed | Should -Be 1
        $records[4].reportingComplete | Should -BeTrue
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav').Count | Should -Be 2
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json').Count | Should -Be 2
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.partial' -Force).Count | Should -Be 0
        foreach ($name in @('first.wav', 'third.wav')) { Get-WacBatchTestBytes -Path (Join-Path $sandbox.Root $name) | Should -BeExactly 'AQIDBA==' }
        Get-WacBatchTestBytes -Path $sandbox.Manifest | Should -BeExactly $manifestBefore
        Test-Path -LiteralPath $sandbox.Config | Should -BeFalse
    }

    It 'preserves repeated direct-list requests and creates one export/result for each' {
        $sandbox = New-WacBatchSandbox
        $inputFile = Join-Path $sandbox.Root "repeated [draft] $batchUnicode & guest.wav"
        [IO.File]::WriteAllBytes($inputFile, [byte[]](1, 2, 3, 4))
        Write-WacBatchTestManifest -Path $sandbox.Manifest -Inputs @($inputFile, $inputFile)
        $result = Invoke-WacBatchCase -Sandbox $sandbox -Case 'direct list'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $records = @(Read-WacBatchTestJournal -Path $sandbox.Result)
        $records[1].inputPath | Should -BeExactly $inputFile
        $records[2].inputPath | Should -BeExactly $inputFile
        $records[3].counts.success | Should -Be 2
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav').Count | Should -Be 2
    }

    It 'uses isolated saved choices once and <Case> without autosaving' -ForEach @(
        @{ Case = 'saved choices'; ExpectedMode = 'Zoom'; ExpectedPreset = 'Original' }
        @{ Case = 'explicit overrides'; ExpectedMode = 'Raw'; ExpectedPreset = 'Gentle' }
    ) {
        $sandbox = New-WacBatchSandbox
        [IO.File]::WriteAllBytes((Join-Path $sandbox.Root 'first.wav'), [byte[]](1, 2, 3, 4))
        Write-WacBatchTestManifest -Path $sandbox.Manifest -Inputs @('first.wav', 'first.wav')
        $saved = @{ Mode = 'Zoom'; OutputDirectory = $sandbox.Output }
        if ($Case -eq 'explicit overrides') {
            $saved.Mode = 'Raw'; $saved.Preset = 'Gentle'; $saved.Mono = $true; $saved.Rf64 = $true
            $saved.CleaningOptions = @{ Gate = $true; Declip = $true }
        }
        $null = Save-WacSettings -Path $sandbox.Config -Values $saved
        $before = Get-WacBatchTestBytes -Path $sandbox.Config
        $result = Invoke-WacBatchCase -Sandbox $sandbox -Case $Case
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $records = @(Read-WacBatchTestJournal -Path $sandbox.Result)
        $records[0].settings.mode | Should -BeExactly $ExpectedMode
        $records[0].settings.preset | Should -BeExactly $ExpectedPreset
        if ($Case -eq 'explicit overrides') {
            $records[0].settings.mono | Should -BeFalse
            $records[0].settings.rf64 | Should -BeFalse
            @($records[0].settings.cleaningOptions.PSObject.Properties).Count | Should -Be 0
        }
        Get-WacBatchTestBytes -Path $sandbox.Config | Should -BeExactly $before
        $result.StandardOutput | Should -Not -Match 'Enter selection|Select Processing Mode'
    }

    It 'rejects <Case> before native/journal work' -ForEach @(
        @{ Case = 'both lists' }; @{ Case = 'legacy conflict' }; @{ Case = 'preview conflict' }
        @{ Case = 'range conflict' }; @{ Case = 'result without list' }; @{ Case = 'corrupt saved' }
    ) {
        $sandbox = New-WacBatchSandbox
        Write-WacBatchTestManifest -Path $sandbox.Manifest -Inputs @('missing.wav')
        if ($Case -eq 'corrupt saved') { [IO.File]::WriteAllText($sandbox.Config, '{"schemaVersion":1,"settings":{"preset":"invalid"}}', $batchUtf8) }
        $result = Invoke-WacBatchCase -Sandbox $sandbox -Case $Case
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.Result | Should -BeFalse
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
        Test-Path -LiteralPath $sandbox.RenderArgv | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
    }

    It 'retains one-item native failure code4 and persistent failure diagnostics' {
        $sandbox = New-WacBatchSandbox
        [IO.File]::WriteAllBytes((Join-Path $sandbox.Root 'first.wav'), [byte[]](1, 2, 3, 4))
        Write-WacBatchTestManifest -Path $sandbox.Manifest -Inputs @('first.wav')
        $result = Invoke-WacBatchCase -Sandbox $sandbox -ExtraEnvironment @{ WAC_TEST_EXIT_CODE = '9'; WAC_TEST_STDERR = (('D' * 5000) + ' batch controlled native failure') }
        $result.ExitCode | Should -Be 4 -Because ($result.StandardOutput + $result.StandardError)
        $records = @(Read-WacBatchTestJournal -Path $sandbox.Result)
        $records[1].status | Should -BeExactly 'FAILED'
        $records[1].exitCode | Should -Be 4
        $records[1].diagnostics.Count | Should -BeGreaterThan 0
        ($records[1].diagnostics -join '') | Should -Match 'batch controlled native failure'
        ($records[1].diagnostics -join '').Length | Should -BeLessOrEqual 4096
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav').Count | Should -Be 0
    }

    It 'preserves an occupied result path before native processing or input mutation' {
        $sandbox = New-WacBatchSandbox
        $inputFile = Join-Path $sandbox.Root 'first.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]](1, 2, 3, 4))
        Write-WacBatchTestManifest -Path $sandbox.Manifest -Inputs @('first.wav')
        [IO.File]::WriteAllBytes($sandbox.Result, [byte[]](4, 5, 6))
        $result = Invoke-WacBatchCase -Sandbox $sandbox
        $result.ExitCode | Should -Be 5 -Because ($result.StandardOutput + $result.StandardError)
        Get-WacBatchTestBytes -Path $sandbox.Result | Should -BeExactly 'BAUG'
        Get-WacBatchTestBytes -Path $inputFile | Should -BeExactly 'AQIDBA=='
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
    }
}
