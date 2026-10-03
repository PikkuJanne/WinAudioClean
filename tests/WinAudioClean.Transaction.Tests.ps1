BeforeAll {
    $ioScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'WinAudioClean.IO.ps1'
    . $ioScript
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    function Write-WacTestPartial {
        param($Transaction, [byte[]]$Bytes)
        $writer = [IO.File]::Open($Transaction.TempPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
        try { $writer.Write($Bytes, 0, $Bytes.Length) }
        finally { $writer.Dispose() }
    }
    function New-WacTestLink {
        param([string]$Kind, [string]$Path, [string]$Target)
        # PS5.1 expands wildcards in New-Item -Target. Later versions treat
        # link targets literally, so escape only the older provider boundary.
        $linkTarget = if ($PSVersionTable.PSVersion.Major -le 5) { [WildcardPattern]::Escape($Target) } else { $Target }
        New-Item -ItemType $Kind -Path $Path -Target $linkTarget -ErrorAction Stop
    }
}

Describe 'AC-022/AC-023/AC-024: owned output allocation, publication and cleanup' -Tag 'Transaction', 'Unit' {
    BeforeEach {
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($scratch)
        $inputFile = Join-Path $scratch 'speaker [1].wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(11, 22, 33, 44))
        $destination = Join-Path $scratch 'output [literal]'
        $null = [IO.Directory]::CreateDirectory($destination)
        $transactions = New-Object 'System.Collections.Generic.List[object]'
    }

    AfterEach {
        foreach ($transaction in $transactions) { $null = @(Close-WacOutputTransaction -Transaction $transaction) }
    }

    It 'allocates an exclusively owned partial in the final destination' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination -Timestamp '20261002-121314' -JobId ('a' * 32)
        $transactions.Add($transaction)
        $transaction.JobId | Should -BeExactly ('a' * 32)
        $transaction.TempPath | Should -BeExactly (Join-Path $destination ('.wac-' + ('a' * 32) + '.partial'))
        $transaction.FinalPath | Should -BeExactly (Join-Path $destination ('speaker [1]_Cleaned_20261002-121314_' + ('a' * 32) + '.wav'))
        $transaction.TempIdentity | Should -Match '^[0-9A-F]{48}$'
        $transaction.TempIdentity | Should -Not -Be $transaction.InputIdentity
        Test-Path -LiteralPath $transaction.TempPath | Should -BeTrue
        Test-Path -LiteralPath $transaction.FinalPath | Should -BeFalse
        $transaction.Published | Should -BeFalse
        $transaction.InputLock.CanRead | Should -BeTrue
        $transaction.TempHandle.CanWrite | Should -BeTrue
    }

    It 'allows the encoder to overwrite only the reserved partial while preventing its rename' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        Write-WacTestPartial -Transaction $transaction -Bytes ([byte[]]@(1, 2, 3))
        $transaction.TempHandle.Length | Should -Be 3
        { [IO.File]::Move($transaction.TempPath, ($transaction.TempPath + '.moved')) } | Should -Throw
    }

    It 'pins the physical output directory against rename until the transaction closes' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        { [IO.Directory]::Move($destination, ($destination + '-moved')) } | Should -Throw
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        [IO.Directory]::Move($destination, ($destination + '-moved'))
        Test-Path -LiteralPath ($destination + '-moved') | Should -BeTrue
    }

    It 'never overwrites a preexisting partial reservation' {
        $jobId = 'b' * 32
        $partial = Join-Path $destination ('.wac-' + $jobId + '.partial')
        [IO.File]::WriteAllBytes($partial, [byte[]]@(7, 8, 9))
        {
            # A mutant may unexpectedly allocate. Retain its handles for the
            # normal AfterEach cleanup before the assertion reports the defect.
            $unexpected = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination -JobId $jobId
            $transactions.Add($unexpected)
        } | Should -Throw
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($partial)) | Should -BeExactly 'BwgJ'
        # A failed allocation releases its source lock.
        $handle = [IO.File]::Open($inputFile, 'Open', 'Write', 'None')
        $handle.Dispose()
    }

    It 'rejects a partial path that is the input itself' {
        $jobId = 'c' * 32
        $sameInput = Join-Path $destination ('.wac-' + $jobId + '.partial')
        [IO.File]::WriteAllBytes($sameInput, [byte[]]@(7, 8, 9))
        { New-WacOutputTransaction -InputPath $sameInput -OutputFolder $destination -JobId $jobId } | Should -Throw
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($sameInput)) | Should -BeExactly 'BwgJ'
    }

    It 'allocates unique names for rapid same-input runs and equal stems while all jobs remain open' {
        $secondInput = Join-Path $scratch 'speaker [1].mp3'
        [IO.File]::WriteAllBytes($secondInput, [byte[]]@(55, 66))
        foreach ($path in @($inputFile, $inputFile, $secondInput, $secondInput)) {
            $transactions.Add((New-WacOutputTransaction -InputPath $path -OutputFolder $destination -Timestamp '20261002-121314'))
        }
        @($transactions | ForEach-Object { $_.TempPath } | Sort-Object -Unique).Count | Should -Be 4
        @($transactions | ForEach-Object { $_.FinalPath } | Sort-Object -Unique).Count | Should -Be 4
        foreach ($transaction in $transactions) {
            Write-WacTestPartial -Transaction $transaction -Bytes ([byte[]]@(1, 2, 3))
            $null = Freeze-WacOutputTransaction -Transaction $transaction
            Publish-WacOutputTransaction -Transaction $transaction
        }
        @(Get-ChildItem -LiteralPath $destination -Filter '*.wav').Count | Should -Be 4
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) | Should -BeExactly 'CxYhLA=='
    }

    It 'freezes the exact owned bytes against writers and external rename until publication' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        Write-WacTestPartial -Transaction $transaction -Bytes ([byte[]]@(1, 2, 3))
        $stream = Freeze-WacOutputTransaction -Transaction $transaction
        $stream | Should -BeOfType [IO.FileStream]
        $stream.ReadByte() | Should -Be 1
        { [IO.File]::WriteAllBytes($transaction.TempPath, [byte[]]@(9)) } | Should -Throw
        { [IO.File]::Move($transaction.TempPath, ($transaction.TempPath + '.moved')) } | Should -Throw
        Publish-WacOutputTransaction -Transaction $transaction
        $transaction.Published | Should -BeTrue
        Test-Path -LiteralPath $transaction.TempPath | Should -BeFalse
        # Read through the same retained handle after the rename.
        $stream.Position = 0
        $stream.ReadByte() | Should -Be 1
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($transaction.FinalPath)) | Should -BeExactly 'AQID'
    }

    It 'refuses publication without freezing the output' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        { Publish-WacOutputTransaction -Transaction $transaction } | Should -Throw
        Test-Path -LiteralPath $transaction.FinalPath | Should -BeFalse
    }

    It 'rejects another publish or freeze after successful publication' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        Write-WacTestPartial -Transaction $transaction -Bytes ([byte[]]@(1, 2, 3))
        $null = Freeze-WacOutputTransaction -Transaction $transaction
        Publish-WacOutputTransaction -Transaction $transaction
        { Publish-WacOutputTransaction -Transaction $transaction } | Should -Throw
        { Freeze-WacOutputTransaction -Transaction $transaction } | Should -Throw
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($transaction.FinalPath)) | Should -BeExactly 'AQID'
    }

    It 'does not replace a final file created after allocation' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        Write-WacTestPartial -Transaction $transaction -Bytes ([byte[]]@(1, 2, 3))
        $null = Freeze-WacOutputTransaction -Transaction $transaction
        [IO.File]::WriteAllBytes($transaction.FinalPath, [byte[]]@(9, 8, 7))
        { Publish-WacOutputTransaction -Transaction $transaction } | Should -Throw
        $transaction.Published | Should -BeFalse
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        Test-Path -LiteralPath $transaction.TempPath | Should -BeFalse
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($transaction.FinalPath)) | Should -BeExactly 'CQgH'
    }

    It 'retains input and prior export when either is hardlinked to the final name' -ForEach @(
        @{ AliasTarget = 'input' }, @{ AliasTarget = 'prior export' }
    ) {
        $prior = Join-Path $destination 'prior.wav'
        [IO.File]::WriteAllBytes($prior, [byte[]]@(9, 8, 7))
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        $target = if ($AliasTarget -eq 'input') { $inputFile } else { $prior }
        $null = New-WacTestLink -Kind HardLink -Path $transaction.FinalPath -Target $target
        Write-WacTestPartial -Transaction $transaction -Bytes ([byte[]]@(1, 2, 3))
        $null = Freeze-WacOutputTransaction -Transaction $transaction
        { Publish-WacOutputTransaction -Transaction $transaction } | Should -Throw
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) | Should -BeExactly 'CxYhLA=='
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($prior)) | Should -BeExactly 'CQgH'
        Test-Path -LiteralPath $transaction.FinalPath | Should -BeTrue
    }

    It 'protects input hardlink and shared-log aliases until the transaction closes' {
        $log = Join-Path $destination 'WinAudioClean_Log.txt'
        $null = New-WacTestLink -Kind HardLink -Path $log -Target $inputFile
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        { Add-Content -LiteralPath $log -Value 'must not enter audio' -ErrorAction Stop } | Should -Throw
        { [IO.File]::Delete($inputFile) } | Should -Throw
        Write-WacTestPartial -Transaction $transaction -Bytes ([byte[]]@(1))
        $null = Freeze-WacOutputTransaction -Transaction $transaction
        Publish-WacOutputTransaction -Transaction $transaction
        { Add-Content -LiteralPath $log -Value 'still protected during reporting' -ErrorAction Stop } | Should -Throw
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) | Should -BeExactly 'CxYhLA=='
    }

    It 'removes only its own partial on normal failure and preserves unrelated crash leftovers' {
        $oldPartial = Join-Path $destination ('.wac-' + ('d' * 32) + '.partial')
        [IO.File]::WriteAllBytes($oldPartial, [byte[]]@(9, 8, 7))
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        Write-WacTestPartial -Transaction $transaction -Bytes ([byte[]]@(1, 2, 3))
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        Test-Path -LiteralPath $transaction.TempPath | Should -BeFalse
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($oldPartial)) | Should -BeExactly 'CQgH'
        Test-Path -LiteralPath $transaction.FinalPath | Should -BeFalse
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
    }

    It 'retains a foreign file replacing the partial between render and freeze' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        $transaction.TempHandle.Dispose()
        $transaction.TempHandle = $null
        $movedOriginal = $transaction.TempPath + '.owned-moved'
        [IO.File]::Move($transaction.TempPath, $movedOriginal)
        [IO.File]::WriteAllBytes($transaction.TempPath, [byte[]]@(9, 8, 7))
        { Freeze-WacOutputTransaction -Transaction $transaction } | Should -Throw '*ownership changed*'
        $diagnostics = @(Close-WacOutputTransaction -Transaction $transaction)
        $diagnostics.Count | Should -Be 1
        $diagnostics[0] | Should -Match 'Ownership no longer matches'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($transaction.TempPath)) | Should -BeExactly 'CQgH'
        Test-Path -LiteralPath $movedOriginal | Should -BeTrue
        Test-Path -LiteralPath $transaction.FinalPath | Should -BeFalse
    }

    It 'rejects tampered publication paths outside the pinned output directory' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        $null = Freeze-WacOutputTransaction -Transaction $transaction
        $transaction.FinalPath = Join-Path $scratch 'outside.wav'
        { Publish-WacOutputTransaction -Transaction $transaction } | Should -Throw '*Publication paths*'
        Test-Path -LiteralPath $transaction.FinalPath | Should -BeFalse
    }

    It 'reports a cleanup sharing failure and still releases the input lock' {
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination
        $transactions.Add($transaction)
        $blockingReader = [IO.File]::Open($transaction.TempPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $diagnostics = @(Close-WacOutputTransaction -Transaction $transaction)
            $diagnostics.Count | Should -Be 1
            $diagnostics[0] | Should -Match 'Partial cleanup incomplete'
            Test-Path -LiteralPath $transaction.TempPath | Should -BeTrue
            $writer = [IO.File]::Open($inputFile, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None)
            $writer.Dispose()
        } finally { $blockingReader.Dispose() }
    }

    It 'returns a resolved input path so changing its junction cannot change the rendered file' {
        $inputDirectory = Join-Path $scratch 'input folder'
        $otherDirectory = Join-Path $scratch 'other input folder'
        $null = [IO.Directory]::CreateDirectory($inputDirectory)
        $null = [IO.Directory]::CreateDirectory($otherDirectory)
        $realInput = Join-Path $inputDirectory 'source.wav'
        [IO.File]::WriteAllBytes($realInput, [byte[]]@(1, 2, 3))
        [IO.File]::WriteAllBytes((Join-Path $otherDirectory 'source.wav'), [byte[]]@(9, 8, 7))
        $junction = Join-Path $scratch 'input junction'
        $null = New-WacTestLink -Kind Junction -Path $junction -Target $inputDirectory
        $transaction = New-WacOutputTransaction -InputPath (Join-Path $junction 'source.wav') -OutputFolder $destination
        $transactions.Add($transaction)
        $transaction.InputPath | Should -BeExactly $realInput
        [IO.Directory]::Delete($junction)
        $null = New-WacTestLink -Kind Junction -Path $junction -Target $otherDirectory
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($transaction.InputPath)) | Should -BeExactly 'AQID'
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        [IO.Directory]::Delete($junction)
    }

    It 'resolves a junction destination and retains that physical target if the junction changes' {
        $otherDestination = Join-Path $scratch 'other output'
        $null = [IO.Directory]::CreateDirectory($otherDestination)
        $junction = Join-Path $scratch 'output junction'
        $null = New-WacTestLink -Kind Junction -Path $junction -Target $destination
        $transaction = New-WacOutputTransaction -InputPath $inputFile -OutputFolder $junction
        $transactions.Add($transaction)
        $transaction.OutputFolder | Should -BeExactly $destination
        [IO.Directory]::Delete($junction)
        $null = New-WacTestLink -Kind Junction -Path $junction -Target $otherDestination
        Write-WacTestPartial -Transaction $transaction -Bytes ([byte[]]@(1, 2, 3))
        $null = Freeze-WacOutputTransaction -Transaction $transaction
        Publish-WacOutputTransaction -Transaction $transaction
        @(Close-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
        Test-Path -LiteralPath $transaction.FinalPath | Should -BeTrue
        @(Get-ChildItem -LiteralPath $otherDestination -Force).Count | Should -Be 0
        [IO.Directory]::Delete($junction)
    }

    It 'rejects unsafe identifiers before allocating partial files' -ForEach @(
        @{ JobId = 'short' }, @{ JobId = '../outside' }, @{ JobId = ('z' * 32) }
    ) {
        { New-WacOutputTransaction -InputPath $inputFile -OutputFolder $destination -JobId $JobId } | Should -Throw
        @(Get-ChildItem -LiteralPath $destination -Force).Count | Should -Be 0
    }
}

Describe 'AC-005: transaction helper import has no side effects' -Tag 'Transaction', 'Import' {
    It 'defines functions without compiling native declarations, writing files or starting a child' {
        $scratch = Join-Path $TestDrive 'import-check'
        $null = [IO.Directory]::CreateDirectory($scratch)
        $quotedPath = "'" + $ioScript.Replace("'", "''") + "'"
        $code = @"
function Add-Type { throw 'Import attempted native compilation.' }
function Start-Process { throw 'Import attempted process startup.' }
`$output = @(. $quotedPath *>&1)
if (`$output.Count -ne 0) { throw 'Import produced output.' }
if ('WinAudioClean.NativeFileIO' -as [type]) { throw 'Import loaded native declarations.' }
`$null = Get-Command New-WacOutputTransaction -CommandType Function -ErrorAction Stop
[Console]::WriteLine('TRANSACTION_IMPORT_OK')
"@
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
        $currentShell = (Get-Process -Id $PID).Path
        $result = Invoke-WacTestProcess -FilePath $currentShell -Arguments ('-NoLogo -NoProfile -NonInteractive -EncodedCommand ' + $encoded) -WorkingDirectory $scratch
        $result.ExitCode | Should -Be 0
        $result.StandardOutput.Trim() | Should -BeExactly 'TRANSACTION_IMPORT_OK'
        $result.StandardError | Should -BeNullOrEmpty
        @(Get-ChildItem -LiteralPath $scratch -Force).Count | Should -Be 0
    }
}

Describe 'AC-023: report writes cannot follow filesystem aliases into existing audio' -Tag 'Transaction', 'Unit' {
    It 'allows Add-Content on a new or existing singly linked report while its guard is held' -ForEach @(
        @{ Existing = $false }, @{ Existing = $true }
    ) {
        $report = Join-Path $TestDrive ('guarded-report-' + [guid]::NewGuid().ToString('N') + '.txt')
        if ($Existing) { [IO.File]::WriteAllText($report, "original report`r`n") }
        $guard = Open-WacReportGuard -Path $report
        try {
            Add-Content -LiteralPath $guard.Path -Value 'new report entry' -ErrorAction Stop
            { [IO.File]::Delete($report) } | Should -Throw
        } finally { Close-WacReportGuard -Guard $guard }
        $text = [IO.File]::ReadAllText($report)
        $text | Should -Match 'new report entry'
        if ($Existing) { $text | Should -Match 'original report' }
        $guard.Handle | Should -BeNullOrEmpty
    }

    It 'refuses a report hardlink to a prior audio export without changing either path' {
        $prior = Join-Path $TestDrive ('prior-export-' + [guid]::NewGuid().ToString('N') + '.wav')
        $report = Join-Path $TestDrive ('linked-report-' + [guid]::NewGuid().ToString('N') + '.txt')
        [IO.File]::WriteAllBytes($prior, [byte[]]@(1, 2, 3, 4))
        $null = New-WacTestLink -Kind HardLink -Path $report -Target $prior
        { Open-WacReportGuard -Path $report } | Should -Throw '*multiple filesystem links*'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($prior)) | Should -BeExactly 'AQIDBA=='
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($report)) | Should -BeExactly 'AQIDBA=='
    }

    It 'does not redirect a held report guard when its directory junction changes' {
        $base = Join-Path $TestDrive ('report-directories-' + [guid]::NewGuid().ToString('N'))
        $first = Join-Path $base 'first'
        $second = Join-Path $base 'second'
        $null = [IO.Directory]::CreateDirectory($first)
        $null = [IO.Directory]::CreateDirectory($second)
        $junction = Join-Path $base 'alias'
        $null = New-WacTestLink -Kind Junction -Path $junction -Target $first
        $guard = Open-WacReportGuard -Path (Join-Path $junction 'report.txt')
        try {
            [IO.Directory]::Delete($junction)
            $null = New-WacTestLink -Kind Junction -Path $junction -Target $second
            Add-Content -LiteralPath $guard.Path -Value 'belongs to first directory' -ErrorAction Stop
        } finally {
            Close-WacReportGuard -Guard $guard
            [IO.Directory]::Delete($junction)
        }
        [IO.File]::ReadAllText((Join-Path $first 'report.txt')) | Should -Match 'belongs to first directory'
        @(Get-ChildItem -LiteralPath $second -Force).Count | Should -Be 0
    }
}
