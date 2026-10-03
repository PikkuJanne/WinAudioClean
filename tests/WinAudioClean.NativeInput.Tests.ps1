Describe 'AC-038/039: held-stream input transfer and native cleanup' -Tag 'NativeInput', 'Native' {
    BeforeAll {
        . (Join-Path (Split-Path $PSScriptRoot -Parent) 'WinAudioClean.ps1')
        . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
        $inputNativeFixture = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'input fixture\stdin receiver.exe')
        if (-not ('WacTestFailingReadStream' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

public sealed class WacTestFailingReadStream : Stream
{
    public bool WasDisposed { get; private set; }
    public override bool CanRead { get { return !WasDisposed; } }
    public override bool CanSeek { get { return false; } }
    public override bool CanWrite { get { return false; } }
    public override long Length { get { throw new NotSupportedException(); } }
    public override long Position { get { throw new NotSupportedException(); } set { throw new NotSupportedException(); } }
    public override int Read(byte[] buffer, int offset, int count) { throw new IOException("Injected input read failure."); }
    public override Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken token)
    {
        var completion = new TaskCompletionSource<int>();
        completion.SetException(new IOException("Injected input read failure."));
        return completion.Task;
    }
    public override void Flush() { }
    public override long Seek(long offset, SeekOrigin origin) { throw new NotSupportedException(); }
    public override void SetLength(long value) { throw new NotSupportedException(); }
    public override void Write(byte[] buffer, int offset, int count) { throw new NotSupportedException(); }
    protected override void Dispose(bool disposing) { WasDisposed = true; base.Dispose(disposing); }
}
'@
        }
    }

    BeforeEach {
        $savedInputFixtureEnvironment = @{}
        foreach ($fixtureVariable in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
            if ([string]$fixtureVariable -like 'WAC_TEST_*') {
                $savedInputFixtureEnvironment[$fixtureVariable] = [Environment]::GetEnvironmentVariable($fixtureVariable, 'Process')
                [Environment]::SetEnvironmentVariable($fixtureVariable, $null, 'Process')
            }
        }
    }

    AfterEach {
        foreach ($fixtureVariable in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
            if ([string]$fixtureVariable -like 'WAC_TEST_*') {
                [Environment]::SetEnvironmentVariable($fixtureVariable, $null, 'Process')
            }
        }
        foreach ($fixtureVariable in $savedInputFixtureEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($fixtureVariable, $savedInputFixtureEnvironment[$fixtureVariable], 'Process')
        }
    }

    It 'preserves exact raw stdin and console encoding in an owned fresh process for <Case>' -Tag 'InputEncoding', 'CIRegression' -ForEach @(
        @{ Case = 'Utf8Empty' }, @{ Case = 'Utf8Binary' }, @{ Case = 'Utf8LeadingBomData' },
        @{ Case = 'Utf8NoBomControl' }, @{ Case = 'OemControl' }, @{ Case = 'StartupFailure' }
    ) {
        $childStart = [Diagnostics.ProcessStartInfo]::new()
        $childStart.FileName = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $childArguments = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File',
            (Join-Path $PSScriptRoot 'fixtures/Invoke-NativeInputEncodingFixture.ps1'),
            '-Repository', (Split-Path $PSScriptRoot -Parent), '-NativeFixturePath', $inputNativeFixture, '-Case', $Case)
        $childStart.Arguments = (@($childArguments | ForEach-Object { ConvertTo-WacNativeArgument -Argument $_ }) -join ' ')
        $childStart.UseShellExecute = $false
        $childStart.CreateNoWindow = $true
        $childStart.RedirectStandardInput = $true
        $childStart.RedirectStandardOutput = $true
        $childStart.RedirectStandardError = $true
        $childStart.StandardOutputEncoding = [Text.Encoding]::UTF8
        $childStart.StandardErrorEncoding = [Text.Encoding]::UTF8
        $child = [Diagnostics.Process]::new()
        $child.StartInfo = $childStart
        $childStarted = $false
        $childInput = $null
        $childOutput = $null
        $childError = $null
        try {
            $childStarted = $child.Start()
            if ($childStarted) {
                $childInput = $child.StandardInput
                $childOutput = $child.StandardOutput
                $childError = $child.StandardError
            }
            $childStarted | Should -BeTrue
            $stdout = $childOutput.ReadToEndAsync()
            $stderr = $childError.ReadToEndAsync()
            $childInput.Close()
            $child.WaitForExit(15000) | Should -BeTrue
            [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 5000) | Should -BeTrue
            $child.ExitCode | Should -Be 0 -Because $stderr.Result
            $check = $stdout.Result | ConvertFrom-Json
            $check.timed_out | Should -BeFalse
            $check.has_cleanup_error | Should -BeFalse
            $check.caller_readable | Should -BeTrue
            $check.input_encoding_equal | Should -BeTrue
            $check.input_encoding_type_equal | Should -BeTrue
            $check.after_code_page | Should -Be $check.before_code_page
            $check.after_preamble_hex | Should -BeExactly $check.before_preamble_hex
            if ($Case -eq 'StartupFailure') {
                $check.started | Should -BeFalse
                $check.exit_code | Should -BeNullOrEmpty
                $check.has_error | Should -BeTrue
            } else {
                $check.started | Should -BeTrue
                $check.exit_code | Should -Be 0
                $check.has_error | Should -BeFalse
                $check.observed_length | Should -Be $check.expected_length
                $check.observed_sha256 | Should -BeExactly $check.expected_sha256
            }
            if ($Case -in @('Utf8NoBomControl', 'OemControl')) { $check.console_reader_unchanged | Should -BeTrue }
        } finally {
            try {
                if ($childStarted -and -not $child.HasExited) { $child.Kill(); $null = $child.WaitForExit(5000) }
            } finally {
                try { if ($childInput) { $childInput.Dispose() } }
                finally {
                    try { if ($childOutput) { $childOutput.Dispose() } }
                    finally {
                        try { if ($childError) { $childError.Dispose() } }
                        finally { $child.Dispose() }
                    }
                }
            }
        }
    }

    It 'transfers input larger than pipe capacity and closes stdin at EOF without closing the caller stream' {
        $payloadLength = 1048576
        $callerStream = [IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes('S' * $payloadLength))
        $env:WAC_TEST_READ_STDIN = '1'
        try {
            $nativeResult = Invoke-WacNativeProcess -FilePath $inputNativeFixture -StandardInputStream $callerStream -TimeoutMilliseconds 5000
            @($nativeResult).Count | Should -Be 1
            $nativeResult.Started | Should -BeTrue -Because $nativeResult.Error
            $nativeResult.ExitCode | Should -Be 0
            $nativeResult.Error | Should -BeNullOrEmpty
            $nativeResult.CleanupError | Should -BeNullOrEmpty
            $nativeResult.TimedOut | Should -BeFalse
            $nativeResult.StandardOutput | Should -BeExactly ('STDIN_EOF:' + $payloadLength)
            $nativeResult.StandardError | Should -BeNullOrEmpty
            $callerStream.Position | Should -Be $payloadLength
            $callerStream.CanRead | Should -BeTrue
            $callerStream.Position = 0
            $callerStream.ReadByte() | Should -Be 83
        } finally { $callerStream.Dispose() }
    }

    It 'drains both output pipes after a large input transfer and retains every diagnostic character' {
        $payloadLength = 1048576
        $diagnosticLength = 524288
        $callerStream = [IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes('S' * $payloadLength))
        $env:WAC_TEST_READ_STDIN = '1'
        $env:WAC_TEST_STREAM_BYTES = [string]$diagnosticLength
        try {
            $nativeResult = Invoke-WacNativeProcess -FilePath $inputNativeFixture -StandardInputStream $callerStream -TimeoutMilliseconds 5000
            @($nativeResult).Count | Should -Be 1
            $nativeResult.Started | Should -BeTrue -Because $nativeResult.Error
            $nativeResult.ExitCode | Should -Be 0
            $nativeResult.Error | Should -BeNullOrEmpty
            $nativeResult.CleanupError | Should -BeNullOrEmpty
            $nativeResult.TimedOut | Should -BeFalse
            ($nativeResult.StandardOutput -ceq ('STDIN_EOF:' + $payloadLength + ('O' * $diagnosticLength) + 'STDOUT_END')) | Should -BeTrue
            ($nativeResult.StandardError -ceq (('E' * $diagnosticLength) + 'STDERR_END')) | Should -BeTrue
            $callerStream.CanRead | Should -BeTrue
        } finally { $callerStream.Dispose() }
    }

    It 'rejects an unreadable caller stream before creating the child' {
        $childRecord = Join-Path $TestDrive 'unreadable-child.pid'
        $env:WAC_TEST_PID_PATH = $childRecord
        $callerStream = [IO.File]::Open((Join-Path $TestDrive 'write-only-input.bin'), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
        try {
            $nativeResult = Invoke-WacNativeProcess -FilePath $inputNativeFixture -StandardInputStream $callerStream -TimeoutMilliseconds 3000
            @($nativeResult).Count | Should -Be 1
            $nativeResult.Started | Should -BeFalse
            $nativeResult.ExitCode | Should -BeNullOrEmpty
            $nativeResult.Error | Should -Match 'readable'
            $nativeResult.TimedOut | Should -BeFalse
            Test-Path -LiteralPath $childRecord | Should -BeFalse
            $callerStream.CanWrite | Should -BeTrue
            $callerStream.WriteByte(83)
            $callerStream.Length | Should -Be 1
        } finally { $callerStream.Dispose() }
    }

    It 'retains a source read error and stops the child without disposing the caller stream' {
        $callerStream = [WacTestFailingReadStream]::new()
        $env:WAC_TEST_READ_STDIN = '1'
        $failureWatch = [Diagnostics.Stopwatch]::StartNew()
        try {
            $nativeResult = Invoke-WacNativeProcess -FilePath $inputNativeFixture -StandardInputStream $callerStream -TimeoutMilliseconds 3000 -StreamCloseTimeoutMilliseconds 1000
            @($nativeResult).Count | Should -Be 1
            $nativeResult.Started | Should -BeTrue
            $nativeResult.ExitCode | Should -Not -BeNullOrEmpty
            $nativeResult.Error | Should -Match 'Injected input read failure'
            $nativeResult.TimedOut | Should -BeFalse
            $failureWatch.ElapsedMilliseconds | Should -BeLessThan 8000
            $callerStream.WasDisposed | Should -BeFalse
        } finally { $callerStream.Dispose() }
    }

    It 'does not treat an early native exit zero as success when the input copy failed' {
        $callerStream = [IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes('S' * 4194304))
        $env:WAC_TEST_STDOUT = 'EARLY_EXIT'
        $env:WAC_TEST_EXIT_CODE = '0'
        $failureWatch = [Diagnostics.Stopwatch]::StartNew()
        try {
            $nativeResult = Invoke-WacNativeProcess -FilePath $inputNativeFixture -StandardInputStream $callerStream -TimeoutMilliseconds 3000 -StreamCloseTimeoutMilliseconds 1000
            @($nativeResult).Count | Should -Be 1
            $nativeResult.Started | Should -BeTrue
            $nativeResult.ExitCode | Should -Be 0
            $nativeResult.Error | Should -Not -BeNullOrEmpty
            $nativeResult.TimedOut | Should -BeFalse
            $nativeResult.StandardOutput | Should -BeExactly 'EARLY_EXIT'
            $failureWatch.ElapsedMilliseconds | Should -BeLessThan 8000
            $callerStream.CanRead | Should -BeTrue
        } finally { $callerStream.Dispose() }
    }

    It 'times out an unread input pipe, drains diagnostics and preserves an unrelated process' {
        $callerStream = [IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes('S' * 4194304))
        $childRecord = Join-Path $TestDrive 'unread-input-child.pid'
        $env:WAC_TEST_SLEEP_MS = '15000'
        $env:WAC_TEST_PID_PATH = $childRecord
        $env:WAC_TEST_STREAM_BYTES = '524288'
        $sentinelInfo = [Diagnostics.ProcessStartInfo]::new()
        $sentinelInfo.FileName = $inputNativeFixture
        $sentinelInfo.UseShellExecute = $false
        $sentinelInfo.CreateNoWindow = $true
        $sentinelInfo.EnvironmentVariables['WAC_TEST_PID_PATH'] = ''
        $sentinelInfo.EnvironmentVariables['WAC_TEST_STREAM_BYTES'] = '0'
        $sentinelProcess = [Diagnostics.Process]::Start($sentinelInfo)
        $timeoutWatch = [Diagnostics.Stopwatch]::StartNew()
        try {
            $nativeResult = Invoke-WacNativeProcess -FilePath $inputNativeFixture -StandardInputStream $callerStream -TimeoutMilliseconds 1000 -StreamCloseTimeoutMilliseconds 1000
            @($nativeResult).Count | Should -Be 1
            $nativeResult.Started | Should -BeTrue
            $nativeResult.TimedOut | Should -BeTrue
            $nativeResult.Error | Should -Match 'timed out'
            $nativeResult.ExitCode | Should -Not -BeNullOrEmpty
            ($nativeResult.StandardOutput -ceq (('O' * 524288) + 'STDOUT_END')) | Should -BeTrue
            ($nativeResult.StandardError -ceq (('E' * 524288) + 'STDERR_END')) | Should -BeTrue
            $nativeResult.CleanupError | Should -Not -Match 'deadline|did not finish|exceeded'
            $childProcessId = [int][IO.File]::ReadAllText($childRecord)
            Get-Process -Id $childProcessId -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            $sentinelProcess.HasExited | Should -BeFalse
            $timeoutWatch.ElapsedMilliseconds | Should -BeLessThan 8000
            $callerStream.CanRead | Should -BeTrue
            $callerStream.Position = 0
            $callerStream.ReadByte() | Should -Be 83
        } finally {
            $callerStream.Dispose()
            if (-not $sentinelProcess.HasExited) { $sentinelProcess.Kill() }
            $null = $sentinelProcess.WaitForExit(5000)
            $sentinelProcess.Dispose()
        }
    }
}
