BeforeAll {
    $script:ioScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'WinAudioClean.IO.ps1'
    . $script:ioScript
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')

    function New-WacFailingReportStream {
        param($RealStream)
        $wrapper = [pscustomobject]@{ Real = $RealStream; CanWrite = $true; SafeFileHandle = $RealStream.SafeFileHandle }
        $wrapper | Add-Member ScriptProperty Length { $this.Real.Length }
        $wrapper | Add-Member ScriptProperty Position { $this.Real.Position } { param($Value) $this.Real.Position = $Value }
        $wrapper | Add-Member ScriptMethod Write {
            param($Bytes, $Offset, $Count)
            $this.Real.Write($Bytes, $Offset, [math]::Min(5, $Count))
            throw 'Injected partial report write failure.'
        }
        $wrapper | Add-Member ScriptMethod SetLength { param($Length) $this.Real.SetLength($Length) }
        $wrapper | Add-Member ScriptMethod Flush { param($Durable) $this.Real.Flush($Durable) }
        $wrapper | Add-Member ScriptMethod Dispose { $this.Real.Dispose() }
        $wrapper
    }
}

Describe 'AC-030: held report writers and summary rollback' -Tag 'Unit', 'Report', 'Transaction' {
    BeforeEach {
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($scratch)
        $reportPath = Join-Path $scratch 'report [1].json'
        $writers = New-Object 'System.Collections.Generic.List[object]'
    }
    AfterEach {
        foreach ($writer in $writers) { Close-WacReportWriter -Writer $writer }
    }

    It 'creates a unique report and writes UTF-8 without a BOM through its held stream' {
        $writer = Open-WacReportWriter -Path $reportPath -CreateNew
        $writers.Add($writer)
        $content = '{"text":"Janne, ' + [char]0xE4 + '"}'
        Set-WacOwnedReportContent -Writer $writer -Content $content
        $writer.CreatedNew | Should -BeTrue
        $writer.InitialLength | Should -Be 0
        $writer.Identity | Should -Match '^[0-9A-F]{48}$'
        $writer.Path | Should -BeExactly $reportPath
        $writer.Stream.Position = 0
        $firstByte = $writer.Stream.ReadByte()
        $firstByte | Should -Be 123
        Close-WacReportWriter -Writer $writer
        [IO.File]::ReadAllText($reportPath) | Should -BeExactly $content
    }
    It 'replaces only its own newly created content without stale trailing bytes' {
        $writer = Open-WacReportWriter -Path $reportPath -CreateNew
        $writers.Add($writer)
        Set-WacOwnedReportContent -Writer $writer -Content 'long original report'
        Set-WacOwnedReportContent -Writer $writer -Content 'short'
        $writer.Stream.Length | Should -Be 5
        Close-WacReportWriter -Writer $writer
        [IO.File]::ReadAllText($reportPath) | Should -BeExactly 'short'
    }
    It 'refuses to overwrite a pre-existing report file' {
        [IO.File]::WriteAllText($reportPath, 'prior report')
        { Open-WacReportWriter -Path $reportPath -CreateNew -TimeoutMilliseconds 0 } | Should -Throw
        [IO.File]::ReadAllText($reportPath) | Should -BeExactly 'prior report'
    }
    It 'rejects mutation or removal of a prior summary through the owned-file APIs' {
        [IO.File]::WriteAllText($reportPath, 'prior summary')
        $writer = Open-WacReportWriter -Path $reportPath
        $writers.Add($writer)
        { Set-WacOwnedReportContent -Writer $writer -Content 'replacement' } | Should -Throw '*exclusively created*'
        { Remove-WacOwnedReport -Writer $writer } | Should -Throw '*exclusively created*'
        Close-WacReportWriter -Writer $writer
        [IO.File]::ReadAllText($reportPath) | Should -BeExactly 'prior summary'
    }
    It 'appends and rolls back only the bytes added while it holds the summary writer' {
        [IO.File]::WriteAllText($reportPath, 'prior summary')
        $writer = Open-WacReportWriter -Path $reportPath
        $writers.Add($writer)
        $offset = Add-WacSummaryReportContent -Writer $writer -Content '-success'
        $offset | Should -Be $writer.InitialLength
        Reset-WacSummaryReport -Writer $writer -Length $offset
        $null = Add-WacSummaryReportContent -Writer $writer -Content '-warning'
        Close-WacReportWriter -Writer $writer
        [IO.File]::ReadAllText($reportPath) | Should -BeExactly 'prior summary-warning'
    }
    It 'creates a missing summary without requiring an earlier file' {
        $writer = Open-WacReportWriter -Path $reportPath
        $writers.Add($writer)
        $writer.InitialLength | Should -Be 0
        $null = Add-WacSummaryReportContent -Writer $writer -Content 'first entry'
        Close-WacReportWriter -Writer $writer
        [IO.File]::ReadAllText($reportPath) | Should -BeExactly 'first entry'
    }
    It 'preserves a prior <Name> summary encoding and BOM when appending' -ForEach @(
        @{ Name = 'UTF-8 BOM'; CodePage = 65001 }, @{ Name = 'UTF-16 LE'; CodePage = 1200 },
        @{ Name = 'UTF-16 BE'; CodePage = 1201 }, @{ Name = 'UTF-32 LE'; CodePage = 12000 },
        @{ Name = 'UTF-32 BE'; CodePage = 12001 }
    ) {
        $encoding = [Text.Encoding]::GetEncoding($CodePage)
        $prior = 'prior ' + [char]0xE4
        $added = ' appended ' + [char]0xF6
        $before = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes($prior))
        [IO.File]::WriteAllBytes($reportPath, $before)
        $writer = Open-WacReportWriter -Path $reportPath
        $writers.Add($writer)
        $writer.Encoding.CodePage | Should -Be $CodePage
        $null = Add-WacSummaryReportContent -Writer $writer -Content $added
        Close-WacReportWriter -Writer $writer
        $expected = [byte[]]($before + $encoding.GetBytes($added))
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($reportPath)) | Should -BeExactly ([Convert]::ToBase64String($expected))
    }
    It 'detects and preserves a valid UTF-8 summary without a BOM' {
        $encoding = [Text.UTF8Encoding]::new($false)
        $prior = 'prior ' + [char]0xE4
        [IO.File]::WriteAllBytes($reportPath, $encoding.GetBytes($prior))
        $writer = Open-WacReportWriter -Path $reportPath
        $writers.Add($writer)
        $writer.Encoding.CodePage | Should -Be 65001
        $null = Add-WacSummaryReportContent -Writer $writer -Content ' more'
        Close-WacReportWriter -Writer $writer
        [IO.File]::ReadAllText($reportPath, $encoding) | Should -BeExactly ($prior + ' more')
    }
    It 'detects UTF-8 when a four-byte character crosses the decoding buffer boundary' {
        $encoding = [Text.UTF8Encoding]::new($false)
        $prior = ('a' * 4093) + [char]::ConvertFromUtf32(0x1F642) + ('b' * 4095)
        [IO.File]::WriteAllBytes($reportPath, $encoding.GetBytes($prior))
        $writer = Open-WacReportWriter -Path $reportPath
        $writers.Add($writer)
        $writer.Encoding.CodePage | Should -Be 65001
        $null = Add-WacSummaryReportContent -Writer $writer -Content ' more'
        Close-WacReportWriter -Writer $writer
        [IO.File]::ReadAllText($reportPath, $encoding) | Should -BeExactly ($prior + ' more')
    }
    It 'preserves a legacy ANSI summary that is not valid UTF-8' {
        $priorCulture = [Globalization.CultureInfo]::CurrentCulture
        try {
            [Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('en-US')
            $encoding = [Text.Encoding]::GetEncoding(1252)
            $prior = 'legacy ' + [char]0xE4
            $added = ' appended ' + [char]0xF6
            $before = $encoding.GetBytes($prior)
            [IO.File]::WriteAllBytes($reportPath, $before)
            $writer = Open-WacReportWriter -Path $reportPath
            $writers.Add($writer)
            $writer.Encoding.CodePage | Should -Be 1252
            $null = Add-WacSummaryReportContent -Writer $writer -Content $added
            Close-WacReportWriter -Writer $writer
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($reportPath)) | Should -BeExactly ([Convert]::ToBase64String([byte[]]($before + $encoding.GetBytes($added))))
        } finally { [Globalization.CultureInfo]::CurrentCulture = $priorCulture }
    }
    It 'rejects rollback beyond its original summary or current end' {
        [IO.File]::WriteAllText($reportPath, 'prior summary')
        $writer = Open-WacReportWriter -Path $reportPath
        $writers.Add($writer)
        { Reset-WacSummaryReport -Writer $writer -Length 0 } | Should -Throw '*preserve all bytes*'
        { Reset-WacSummaryReport -Writer $writer -Length ($writer.InitialLength + 1) } | Should -Throw '*preserve all bytes*'
        Close-WacReportWriter -Writer $writer
        [IO.File]::ReadAllText($reportPath) | Should -BeExactly 'prior summary'
    }
    It 'restores the exact original summary bytes after an injected partial write failure' {
        [IO.File]::WriteAllBytes($reportPath, [byte[]]@(255, 254, 65, 0, 66, 0))
        $writer = Open-WacReportWriter -Path $reportPath
        $writers.Add($writer)
        $writer.Stream = New-WacFailingReportStream $writer.Stream
        { Add-WacSummaryReportContent -Writer $writer -Content 'new entry' } | Should -Throw '*Injected partial report write failure*'
        $writer.Stream.Length | Should -Be 6
        Close-WacReportWriter -Writer $writer
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($reportPath)) | Should -BeExactly '//5BAEIA'
    }
    It 'prevents another writer, rename or deletion while held and bounds contention retry' {
        $writer = Open-WacReportWriter -Path $reportPath
        $writers.Add($writer)
        $timer = [Diagnostics.Stopwatch]::StartNew()
        { Open-WacReportWriter -Path $reportPath -TimeoutMilliseconds 100 } | Should -Throw '*Cannot open report writer*'
        $timer.Stop()
        $timer.Elapsed.TotalSeconds | Should -BeLessThan 3
        { [IO.File]::Move($reportPath, ($reportPath + '.moved')) } | Should -Throw
        { [IO.File]::Delete($reportPath) } | Should -Throw
        Close-WacReportWriter -Writer $writer
        $otherWriter = Open-WacReportWriter -Path $reportPath -TimeoutMilliseconds 0
        $writers.Add($otherWriter)
        $null = Add-WacSummaryReportContent -Writer $otherWriter -Content 'after release'
    }
    It 'refuses a multiple-hardlink summary without changing its target' {
        $target = Join-Path $scratch 'existing-audio.wav'
        [IO.File]::WriteAllText($target, 'preserve existing audio')
        $null = New-Item -ItemType HardLink -Path $reportPath -Target $target -ErrorAction Stop
        { Open-WacReportWriter -Path $reportPath -TimeoutMilliseconds 0 } | Should -Throw '*multiple filesystem links*'
        [IO.File]::ReadAllText($target) | Should -BeExactly 'preserve existing audio'
    }
    It 'refuses an existing directory reparse leaf' {
        $target = Join-Path $scratch 'actual-folder'
        $null = [IO.Directory]::CreateDirectory($target)
        $null = New-Item -ItemType Junction -Path $reportPath -Target $target -ErrorAction Stop
        try { { Open-WacReportWriter -Path $reportPath -TimeoutMilliseconds 0 } | Should -Throw }
        finally { [IO.Directory]::Delete($reportPath) }
        Test-Path -LiteralPath $target -PathType Container | Should -BeTrue
    }
    It 'deletes only its held newly created report and closes idempotently' {
        $writer = Open-WacReportWriter -Path $reportPath -CreateNew
        $writers.Add($writer)
        Set-WacOwnedReportContent -Writer $writer -Content 'incomplete'
        Remove-WacOwnedReport -Writer $writer
        Close-WacReportWriter -Writer $writer
        Close-WacReportWriter -Writer $writer
        Test-Path -LiteralPath $reportPath | Should -BeFalse
        { Set-WacOwnedReportContent -Writer $writer -Content 'later' } | Should -Throw '*closed*'
    }
    It 'serializes concurrent process summary entries without interleaving' {
        $childScript = Join-Path $scratch 'append.ps1'
        $childContent = @'
param($IoPath, $ReportPath, $Label)
$ErrorActionPreference = 'Stop'
. $IoPath
$writer = Open-WacReportWriter -Path $ReportPath -TimeoutMilliseconds 5000
try { $null = Add-WacSummaryReportContent -Writer $writer -Content ($Label * 131072) }
finally { Close-WacReportWriter -Writer $writer }
'@
        [IO.File]::WriteAllText($childScript, $childContent)
        $processes = New-Object 'System.Collections.Generic.List[object]'
        try {
            foreach ($label in @('A', 'B')) {
                $startInfo = New-Object Diagnostics.ProcessStartInfo
                $startInfo.FileName = (Get-Process -Id $PID).Path
                $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $childScript, $script:ioScript, $reportPath, $label)
                $startInfo.Arguments = (@($arguments | ForEach-Object { ConvertTo-WacTestQuotedArgument $_ }) -join ' ')
                $startInfo.UseShellExecute = $false
                $startInfo.CreateNoWindow = $true
                $startInfo.RedirectStandardOutput = $true
                $startInfo.RedirectStandardError = $true
                $startInfo.EnvironmentVariables.Remove('PSMODULEPATH')
                $processes.Add([Diagnostics.Process]::Start($startInfo))
            }
            foreach ($process in $processes) {
                $process.WaitForExit(15000) | Should -BeTrue
                $process.StandardError.ReadToEnd() | Should -BeNullOrEmpty
                $process.ExitCode | Should -Be 0
            }
            $actual = [IO.File]::ReadAllText($reportPath)
            ($actual -ceq (('A' * 131072) + ('B' * 131072)) -or $actual -ceq (('B' * 131072) + ('A' * 131072))) | Should -BeTrue
        } finally {
            foreach ($process in $processes) {
                if (-not $process.HasExited) { $process.Kill(); $null = $process.WaitForExit(5000) }
                $process.Dispose()
            }
        }
    }
}

Describe 'AC-028/030: finish output cleanup before reporting while retaining source protection' -Tag 'Unit', 'Transaction', 'Report' {
    BeforeEach {
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($scratch)
        $inputPath = Join-Path $scratch 'source.wav'
        [IO.File]::WriteAllText($inputPath, 'source audio')
        $outputFolder = Join-Path $scratch 'output'
        $null = [IO.Directory]::CreateDirectory($outputFolder)
        $transaction = New-WacOutputTransaction -InputPath $inputPath -OutputFolder $outputFolder
    }
    AfterEach { $null = @(Close-WacOutputTransaction -Transaction $transaction) }

    It 'cleans the owned partial and holds input/destination until final close' {
        @(Complete-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        Test-Path -LiteralPath $transaction.TempPath | Should -BeFalse
        $transaction.Closed | Should -BeFalse
        $transaction.OutputCompleted | Should -BeTrue
        { [IO.File]::WriteAllText($inputPath, 'unsafe') } | Should -Throw
        { [IO.Directory]::Move($outputFolder, ($outputFolder + '-moved')) } | Should -Throw
        { Freeze-WacOutputTransaction -Transaction $transaction } | Should -Throw
        @(Complete-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        [IO.File]::ReadAllText($inputPath) | Should -BeExactly 'source audio'
    }
    It 'surfaces cleanup failure once before reporting and preserves the blocking partial' {
        $blocker = [IO.File]::Open($transaction.TempPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $errors = @(Complete-WacOutputTransaction -Transaction $transaction)
            $errors.Count | Should -Be 1
            $errors[0] | Should -Match 'Partial cleanup incomplete'
            $transaction.InputLock.CanRead | Should -BeTrue
            $transaction.OutputDirectoryHandle.IsClosed | Should -BeFalse
            Test-Path -LiteralPath $transaction.TempPath | Should -BeTrue
        } finally { $blocker.Dispose() }
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        Test-Path -LiteralPath $transaction.TempPath | Should -BeTrue
    }
}
