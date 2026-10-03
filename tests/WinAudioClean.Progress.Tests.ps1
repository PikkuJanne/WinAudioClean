BeforeDiscovery {
    $progressStageCases = @(
        @{ Stage = 'Analysis'; Start = 0; End = 30 }
        @{ Stage = 'Rendering'; Start = 30; End = 80 }
        @{ Stage = 'Verification'; Start = 80; End = 95 }
        @{ Stage = 'Rendering'; Start = 0; End = 90 }
        @{ Stage = 'preview original'; Start = 0; End = 24 }
        @{ Stage = 'preview processed'; Start = 24; End = 49 }
        @{ Stage = 'preview comparison'; Start = 49; End = 74 }
        @{ Stage = 'preview verification'; Start = 74; End = 99 }
    )
    $progressMalformedCases = @(
        @{ Case = 'unterminated final marker'; Text = "out_time_us=3000000`nprogress=end"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'time without block terminator'; Text = "out_time_us=3000000`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'human statistics'; Text = "size=100KiB time=00:00:03.00 speed=9x`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'negative time'; Text = "out_time_us=-1`nprogress=continue`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'nonfinite time'; Text = "out_time_us=NaN`nprogress=continue`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'overflow time'; Text = "out_time_us=9999999999999999999999999999999`nprogress=continue`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'expression time'; Text = 'out_time_us=$(throw "injected")' + "`nprogress=continue`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'duplicate time'; Text = "out_time_us=1000000`nout_time_us=3000000`nprogress=end`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'locale decimal time'; Text = "out_time_us=1,000000`nprogress=end`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'fractional integer time'; Text = "out_time_us=1000000.5`nprogress=end`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'missing time'; Text = "progress=end`n"; ExpectedTime = -1L; ExpectedEnd = $false }
        @{ Case = 'complete block then truncated newer block'; Text = "out_time_us=1000000`nprogress=continue`nout_time_us=3000000`nprogress=en"; ExpectedTime = 1000000L; ExpectedEnd = $false }
    )
}

Describe 'M3-04 structured progress and owned cancellation' -Tag 'Progress' {
BeforeAll {
    $progressRepository = Split-Path $PSScriptRoot -Parent
    . (Join-Path $progressRepository 'WinAudioClean.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\New-ProgressProcessFixture.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    Initialize-WacProgressRuntime
    $progressFixture = New-WacTestProgressExecutable -OutputPath (Join-Path $TestDrive 'structured fixture\progress child.exe')
    if (-not ('WacTestRunCanceller' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Reflection;
using System.Threading;

public sealed class WacTestRunCanceller : IDisposable
{
    private readonly Timer timer;
    public string Error { get; private set; }
    public bool Requested { get; private set; }
    public WacTestRunCanceller(object context, int milliseconds)
    {
        timer = new Timer(delegate(object ignored) {
            try { context.GetType().GetMethod("Request").Invoke(context, new object[0]); Requested = true; }
            catch (Exception error) { Error = error.ToString(); }
        }, null, milliseconds, Timeout.Infinite);
    }
    public void Dispose() { timer.Dispose(); }
}
'@
    }
    function New-WacTestProgressSnapshot {
        param([long]$Time = -1, [bool]$End = $false, [int]$Blocks = 1)
        [pscustomobject]@{ OutTimeMicroseconds = $Time; End = $End; Blocks = $Blocks; InvalidLines = 0; TruncatedLines = 0 }
    }
    function Start-WacTestProgressSurvivor {
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $progressFixture
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.EnvironmentVariables['WAC_PROGRESS_TEST_MODE'] = 'survivor'
        $info.EnvironmentVariables['WAC_PROGRESS_TEST_PID_PATH'] = ''
        $info.EnvironmentVariables['WAC_PROGRESS_TEST_READY_PATH'] = ''
        $info.EnvironmentVariables['WAC_PROGRESS_TEST_PARTIAL_PATH'] = ''
        $info.EnvironmentVariables['WAC_PROGRESS_TEST_SLEEP_MS'] = '15000'
        [Diagnostics.Process]::Start($info)
    }
}

BeforeEach {
    $savedProgressEnvironment = @{}
    foreach ($name in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
        if ([string]$name -like 'WAC_PROGRESS_TEST_*') {
            $savedProgressEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
    }
}

AfterEach {
    foreach ($name in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
        if ([string]$name -like 'WAC_PROGRESS_TEST_*') { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
    }
    foreach ($name in $savedProgressEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedProgressEnvironment[$name], 'Process')
    }
}

Describe 'AC-058: bounded stage progress without premature completion' -Tag 'Progress', 'Unit' {
    It 'keeps <Stage> within its range and preserves file position' -ForEach $progressStageCases {
        $context = New-WacRunContext
        try {
            $context.FileIndex = 2; $context.FileCount = 3
            $state = New-WacProgressState -RunContext $context -Stage $Stage -DurationSeconds 10 -StartPercent $Start -EndPercent $End
            $state.Stage | Should -BeExactly $Stage
            $state.FileIndex | Should -Be 2
            $state.FileCount | Should -Be 3
            $previous = $Start
            foreach ($time in @(0L, 1000000L, 6000000L, 2000000L, 9000000L, 10000000L, 9000000000L)) {
                $null = Update-WacProgress -State $state -Snapshot (New-WacTestProgressSnapshot -Time $time)
                $state.Percent | Should -BeGreaterOrEqual $previous
                $state.Percent | Should -BeGreaterOrEqual $Start
                $state.Percent | Should -BeLessOrEqual $End
                $state.Percent | Should -BeLessThan 100
                $previous = $state.Percent
            }
            $null = Update-WacProgress -State $state -Snapshot (New-WacTestProgressSnapshot -Time 10000000 -End $true)
            $state.StructuredEnd | Should -BeTrue
            $state.Percent | Should -Be $End
        } finally { $context.Dispose() }
    }

    It 'leaves <Case> duration indeterminate even after structured end' -ForEach @(
        @{ Case = 'unknown'; Duration = 0.0 }; @{ Case = 'negative'; Duration = -1.0 }
        @{ Case = 'NaN'; Duration = [double]::NaN }; @{ Case = 'infinite'; Duration = [double]::PositiveInfinity }
    ) {
        $context = New-WacRunContext
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds $Duration -StartPercent 0 -EndPercent 99
            foreach ($time in @(0L, 1000000L, 999999999999L)) {
                $null = Update-WacProgress -State $state -Snapshot (New-WacTestProgressSnapshot -Time $time -End $true)
                $state.Percent | Should -Be -1
            }
            $state.StructuredEnd | Should -BeTrue
        } finally { $context.Dispose() }
    }

    It 'does not infer completion from a snapshot without a measured time' {
        $context = New-WacRunContext
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $null = Update-WacProgress -State $state -Snapshot (New-WacTestProgressSnapshot -End $true)
            $state.Percent | Should -BeLessThan 100
            $state.ProcessedSeconds | Should -Be 0
        } finally { $context.Dispose() }
    }

    It 'formats progress consistently under <Culture>' -ForEach @(@{ Culture = 'de-DE' }; @{ Culture = 'fi-FI' }) {
        $oldCulture = [Threading.Thread]::CurrentThread.CurrentCulture
        $context = New-WacRunContext
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($Culture)
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 2.5 -StartPercent 0 -EndPercent 99
            $null = Update-WacProgress -State $state -Snapshot (New-WacTestProgressSnapshot -Time 1250000)
            $state.ProcessedSeconds | Should -Be 1.25
            $state.Percent | Should -BeGreaterOrEqual 49
            $state.Percent | Should -BeLessOrEqual 50
        } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $oldCulture; $context.Dispose() }
    }

    It 'isolates a closed or failing progress sink from processing state' {
        Mock Write-Progress { throw 'Injected unavailable progress sink.' }
        $context = New-WacRunContext
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $null = Update-WacProgress -State $state -Snapshot (New-WacTestProgressSnapshot -Time 5000000)
            { Write-WacProgress -State $state } | Should -Not -Throw
            $state.Percent | Should -BeGreaterOrEqual 49
            $context.IsCancellationRequested | Should -BeFalse
        } finally { $context.Dispose() }
    }

    It 'adds only structured transport flags while preserving the constructed graph' {
        $profile = Get-WacProcessingProfile -Choice '1'
        $oldArguments = @('-nostdin', '-stats', '-i', 'input [1].wav', '-af', $profile.FilterChain, '-y', 'output.wav')
        $arguments = @(Get-WacProgressArguments -ArgumentList $oldArguments)
        $arguments | Should -Contain '-nostats'
        $arguments | Should -Not -Contain '-stats'
        $arguments[[array]::IndexOf($arguments, '-progress') + 1] | Should -BeExactly 'pipe:1'
        $arguments[[array]::IndexOf($arguments, '-af') + 1] | Should -BeExactly $profile.FilterChain
        $arguments[[array]::IndexOf($arguments, '-i') + 1] | Should -BeExactly 'input [1].wav'
        $arguments[-1] | Should -BeExactly 'output.wav'
    }

    It 'rejects <Case> progress ranges before creating a false completion state' -ForEach @(
        @{ Case = 'start above publication boundary'; Start = 100; End = 100 }
        @{ Case = 'end at premature completion'; Start = 0; End = 100 }
        @{ Case = 'descending'; Start = 50; End = 40 }
    ) {
        { New-WacProgressState -Stage 'render' -DurationSeconds 10 -StartPercent $Start -EndPercent $End } | Should -Throw
    }
}

Describe 'AC-058/060: actual bounded structured pipe and separate diagnostics' -Tag 'Progress', 'Native' {
    It 'parses fragmented complete blocks and never converts diagnostic time text into progress' {
        $env:WAC_PROGRESS_TEST_TEXT = "out_time_us=1000000`nprogress=continue`nout_time_us=2000000`nprogress=end`n"
        $env:WAC_PROGRESS_TEST_CHUNK_SIZE = '1'
        $env:WAC_PROGRESS_TEST_STDERR = "out_time_us=9000000`nprogress=end`nDIAGNOSTIC_MARKER"
        $context = New-WacRunContext
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -TimeoutMilliseconds 5000
            @($result).Count | Should -Be 1
            $result.Started | Should -BeTrue -Because $result.Error
            $result.ExitCode | Should -Be 0
            $result.Error | Should -BeNullOrEmpty
            $result.Cancelled | Should -BeFalse
            $result.Progress.OutTimeMicroseconds | Should -Be 2000000
            $result.Progress.End | Should -BeTrue
            $result.Progress.Blocks | Should -Be 2
            $state.ProcessedSeconds | Should -Be 2
            $state.Percent | Should -BeLessThan 100
            $result.StandardError | Should -BeExactly $env:WAC_PROGRESS_TEST_STDERR
        } finally { $context.Dispose() }
    }

    It 'retains only complete structured blocks for <Case>' -ForEach $progressMalformedCases {
        $env:WAC_PROGRESS_TEST_TEXT = $Text
        $context = New-WacRunContext
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -TimeoutMilliseconds 5000
            $result.Started | Should -BeTrue -Because $result.Error
            $result.ExitCode | Should -Be 0
            $result.Progress.OutTimeMicroseconds | Should -Be $ExpectedTime
            $result.Progress.End | Should -Be $ExpectedEnd
            $state.Percent | Should -BeLessThan 100
            $result.TimedOut | Should -BeFalse
            $result.CleanupError | Should -BeNullOrEmpty
        } finally { $context.Dispose() }
    }

    It 'drains overlong malformed lines and a diagnostic flood without poisoning the next block' {
        $textPath = Join-Path $TestDrive 'oversized-progress.txt'
        [IO.File]::WriteAllText($textPath, ('X' * 524288) + "`nprogress=continue`nout_time_us=3000000`nprogress=end`n", [Text.UTF8Encoding]::new($false))
        $env:WAC_PROGRESS_TEST_TEXT_PATH = $textPath
        $env:WAC_PROGRESS_TEST_DIAGNOSTIC_BYTES = '524288'
        $context = New-WacRunContext
        $watch = [Diagnostics.Stopwatch]::StartNew()
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -TimeoutMilliseconds 5000
            $result.ExitCode | Should -Be 0 -Because $result.Error
            $result.TimedOut | Should -BeFalse
            $result.Progress.OutTimeMicroseconds | Should -Be 3000000
            $result.Progress.TruncatedLines | Should -BeGreaterThan 0
            $result.StandardError.Length | Should -Be (524288 + 'DIAGNOSTIC_MARKER'.Length)
            ($result.StandardError -ceq (('D' * 524288) + 'DIAGNOSTIC_MARKER')) | Should -BeTrue
            $result.CleanupError | Should -BeNullOrEmpty
            $watch.ElapsedMilliseconds | Should -BeLessThan 8000
            $state.Percent | Should -BeLessThan 100
        } finally { $context.Dispose() }
    }

    It 'applies the structured block field limit at <Fields> fields' -ForEach @(
        @{ Fields = 64; Accepted = $true }; @{ Fields = 65; Accepted = $false }
    ) {
        $middle = @(for ($index = 0; $index -lt ($Fields - 2); $index++) { 'metric' + $index + '=1' }) -join "`n"
        $env:WAC_PROGRESS_TEST_TEXT = "out_time_us=1000000`n" + $middle + "`nprogress=end`n"
        $context = New-WacRunContext
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -TimeoutMilliseconds 5000
            $result.ExitCode | Should -Be 0 -Because $result.Error
            $result.Progress.End | Should -Be $Accepted
            $result.Progress.OutTimeMicroseconds | Should -Be $(if ($Accepted) { 1000000L } else { -1L })
            $state.Percent | Should -BeLessThan 100
        } finally { $context.Dispose() }
    }

    It 'applies the structured line limit at <Characters> characters' -ForEach @(
        @{ Characters = 4096; Accepted = $true }; @{ Characters = 4097; Accepted = $false }
    ) {
        $env:WAC_PROGRESS_TEST_TEXT = 'metric=' + ('1' * ($Characters - 7)) + "`nout_time_us=1000000`nprogress=end`n"
        $context = New-WacRunContext
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -TimeoutMilliseconds 5000
            $result.ExitCode | Should -Be 0 -Because $result.Error
            $result.Progress.End | Should -Be $Accepted
            $result.Progress.OutTimeMicroseconds | Should -Be $(if ($Accepted) { 1000000L } else { -1L })
            $state.Percent | Should -BeLessThan 100
        } finally { $context.Dispose() }
    }

    It 'recovers valid progress after discarding an overflowing block' {
        $middle = @(for ($index = 0; $index -lt 63; $index++) { 'metric' + $index + '=1' }) -join "`n"
        $env:WAC_PROGRESS_TEST_TEXT = "out_time_us=9000000`n" + $middle + "`nprogress=continue`nout_time_us=2000000`nprogress=continue`nout_time_us=3000000`nprogress=end`n"
        $context = New-WacRunContext
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -TimeoutMilliseconds 5000
            $result.ExitCode | Should -Be 0 -Because $result.Error
            $result.Progress.OutTimeMicroseconds | Should -Be 3000000
            $result.Progress.End | Should -BeTrue
            $result.Progress.Blocks | Should -Be 2
            $result.Progress.InvalidLines | Should -BeGreaterThan 0
            $state.ProcessedSeconds | Should -Be 3
            $state.Percent | Should -BeLessThan 100
        } finally { $context.Dispose() }
    }

    It 'retains native nonzero status even when it emitted a completed progress block' {
        $env:WAC_PROGRESS_TEST_EXIT_CODE = '23'
        $env:WAC_PROGRESS_TEST_TEXT = "out_time_us=10000000`nprogress=end`n"
        $context = New-WacRunContext
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'render' -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -TimeoutMilliseconds 5000
            $result.ExitCode | Should -Be 23
            $result.Cancelled | Should -BeFalse
            $result.Progress.End | Should -BeTrue
            $state.Percent | Should -BeLessThan 100
            $result.StandardError | Should -BeExactly 'DIAGNOSTIC_MARKER'
        } finally { $context.Dispose() }
    }

    It 'preserves ordinary stdout behavior when no progress state is supplied' {
        $env:WAC_PROGRESS_TEST_TEXT = "ordinary stdout`n"
        $context = New-WacRunContext
        try {
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -TimeoutMilliseconds 5000
            $result.ExitCode | Should -Be 0
            $result.StandardOutput | Should -BeExactly $env:WAC_PROGRESS_TEST_TEXT
            $result.StandardError | Should -BeExactly 'DIAGNOSTIC_MARKER'
            $result.Progress | Should -BeNullOrEmpty
        } finally { $context.Dispose() }
    }
}

Describe 'AC-059/060: active owned cancellation and bounded stream cleanup' -Tag 'Progress', 'Cancellation', 'Native' {
    It 'cancels the owned <Stage> process while an independent job stays alive' -ForEach @(
        @{ Stage = 'analysis' }; @{ Stage = 'render' }; @{ Stage = 'verification' }
    ) {
        $pidPath = Join-Path $TestDrive ('cancel-' + $Stage + '.pid')
        $env:WAC_PROGRESS_TEST_PID_PATH = $pidPath
        $env:WAC_PROGRESS_TEST_SLEEP_MS = '15000'
        $context = New-WacRunContext
        $survivor = Start-WacTestProgressSurvivor
        $timer = [WacTestRunCanceller]::new($context, 750)
        $watch = [Diagnostics.Stopwatch]::StartNew()
        try {
            $state = New-WacProgressState -RunContext $context -Stage $Stage -DurationSeconds 10 -StartPercent 0 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -TimeoutMilliseconds 5000 -StreamCloseTimeoutMilliseconds 1000
            $result.Started | Should -BeTrue -Because $result.Error
            $result.Cancelled | Should -BeTrue
            $result.TimedOut | Should -BeFalse
            $timer.Requested | Should -BeTrue
            $timer.Error | Should -BeNullOrEmpty
            $result.OwnedProcessId | Should -Be ([int][IO.File]::ReadAllText($pidPath))
            Get-Process -Id $result.OwnedProcessId -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            $survivor.HasExited | Should -BeFalse
            $result.CleanupError | Should -BeNullOrEmpty
            $watch.ElapsedMilliseconds | Should -BeLessThan 8000
            $state.Percent | Should -BeLessThan 100
        } finally {
            $timer.Dispose(); $context.Dispose()
            if (-not $survivor.HasExited) { $survivor.Kill() }
            $null = $survivor.WaitForExit(5000); $survivor.Dispose()
        }
    }

    It 'returns cancellation before startup without creating a native record' {
        $pidPath = Join-Path $TestDrive 'not-started-cancel.pid'
        $env:WAC_PROGRESS_TEST_PID_PATH = $pidPath
        $context = New-WacRunContext
        try {
            Request-WacCancellation -RunContext $context
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -TimeoutMilliseconds 5000
            $result.Cancelled | Should -BeTrue
            $result.Started | Should -BeFalse
            $result.OwnedProcessId | Should -BeNullOrEmpty
            Test-Path -LiteralPath $pidPath | Should -BeFalse
        } finally { $context.Dispose() }
    }

    It 'honours a prerequested borrowed context during ordinary application inspection' {
        $root = Join-Path $TestDrive 'prerequested application'
        $output = Join-Path $root 'output'
        $null = [IO.Directory]::CreateDirectory($output)
        foreach ($name in @('WinAudioClean.ps1', 'WinAudioClean.IO.ps1')) {
            Copy-Item -LiteralPath (Join-Path $progressRepository $name) -Destination $root
        }
        $source = Join-Path $root 'synthetic source.wav'
        $writer = [IO.BinaryWriter]::new([IO.File]::Open($source, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write))
        try {
            $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $writer.Write([uint32]96036)
            $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $writer.Write([uint32]16)
            $writer.Write([uint16]1); $writer.Write([uint16]1); $writer.Write([uint32]48000); $writer.Write([uint32]96000)
            $writer.Write([uint16]2); $writer.Write([uint16]16)
            $writer.Write([Text.Encoding]::ASCII.GetBytes('data')); $writer.Write([uint32]96000)
            $writer.Write([byte[]](New-Object byte[] 96000))
        } finally { $writer.Dispose() }
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $foreign = Join-Path $output 'prior.wav'
        [IO.File]::WriteAllBytes($foreign, [byte[]](11, 12, 13))
        $pidPath = Join-Path $root 'unexpected-native.pid'
        $driver = Join-Path $root 'Invoke-Precancelled.ps1'
        $driverCode = @'
param([string]$Application, [string]$InputFile, [string]$OutputFolder, [string]$Executable)
. $Application
$context = New-WacRunContext
try {
    Request-WacCancellation -RunContext $context
    & $Application -inputPath $InputFile -OutputDirectory $OutputFolder -Mode Zoom -IgnoreSavedSettings -NonInteractive -FfmpegPath $Executable -FfprobePath $Executable -WacRunContext $context
    $resultCode = $LASTEXITCODE
} finally { $context.Dispose() }
exit $resultCode
'@
        [IO.File]::WriteAllText($driver, $driverCode, [Text.UTF8Encoding]::new($false))
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -Application {1} -InputFile {2} -OutputFolder {3} -Executable {4}' -f
            (ConvertTo-WacTestQuotedArgument $driver), (ConvertTo-WacTestQuotedArgument (Join-Path $root 'WinAudioClean.ps1')),
            (ConvertTo-WacTestQuotedArgument $source), (ConvertTo-WacTestQuotedArgument $output), (ConvertTo-WacTestQuotedArgument $progressFixture)
        $result = Invoke-WacTestProcess -FilePath (Get-Process -Id $PID).Path -Arguments $arguments -WorkingDirectory $root -EnvironmentVariables @{
            WAC_PROGRESS_TEST_PID_PATH = $pidPath; PSMODULEPATH = $null
        }
        $result.ExitCode | Should -Be 130 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput | Should -Not -Match 'DONE: SUCCESS'
        Test-Path -LiteralPath $pidPath | Should -BeFalse
        @(Get-ChildItem -LiteralPath $output -File).Count | Should -Be 1
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($foreign)) | Should -BeExactly 'CwwN'
        (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash | Should -BeExactly $sourceHash
    }

    It 'cancels an unread input pipe without disposing the caller-held source' {
        $env:WAC_PROGRESS_TEST_SLEEP_MS = '15000'
        $env:WAC_PROGRESS_TEST_DIAGNOSTIC_BYTES = '524288'
        $context = New-WacRunContext
        $input = [IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes('S' * 4194304))
        $timer = [WacTestRunCanceller]::new($context, 750)
        $watch = [Diagnostics.Stopwatch]::StartNew()
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'verification' -DurationSeconds 10 -StartPercent 85 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -StandardInputStream $input -TimeoutMilliseconds 5000 -StreamCloseTimeoutMilliseconds 1000
            $result.Cancelled | Should -BeTrue
            $result.TimedOut | Should -BeFalse
            Get-Process -Id $result.OwnedProcessId -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            $result.StandardError.Contains('DIAGNOSTIC_MARKER') | Should -BeTrue -Because 'the independent diagnostic pipe must drain before cleanup completes'
            $result.Error | Should -BeNullOrEmpty -Because 'the requested cancellation owns the aborted transfer outcome'
            $result.CleanupError | Should -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'CancellationInputError'
            $watch.ElapsedMilliseconds | Should -BeLessThan 8000
            $input.CanRead | Should -BeTrue
            $input.Position = 0
            $input.ReadByte() | Should -Be 83
        } finally { $timer.Dispose(); $context.Dispose(); $input.Dispose() }
    }

    It 'keeps early exit zero distinguishable from a failed held-input transfer' {
        $context = New-WacRunContext
        $input = [IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes('S' * 4194304))
        try {
            $state = New-WacProgressState -RunContext $context -Stage 'verification' -DurationSeconds 10 -StartPercent 85 -EndPercent 99
            $result = Invoke-WacNativeProcess -FilePath $progressFixture -RunContext $context -ProgressState $state -StandardInputStream $input -TimeoutMilliseconds 5000 -StreamCloseTimeoutMilliseconds 1000
            $result.ExitCode | Should -Be 0
            $result.Error | Should -Not -BeNullOrEmpty
            $result.Cancelled | Should -BeFalse
            $result.CancellationInputError | Should -BeNullOrEmpty
            $input.CanRead | Should -BeTrue
            $state.Percent | Should -BeLessThan 100
        } finally { $context.Dispose(); $input.Dispose() }
    }
}
}
