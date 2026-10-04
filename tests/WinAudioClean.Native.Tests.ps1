BeforeDiscovery {
    $nativeArgumentCases = @(
        @{ Description = 'spaces'; Value = 'C:\audio input\meeting sample.wav' }
        @{ Description = 'square brackets'; Value = 'C:\audio\meeting [draft].wav' }
        @{ Description = 'apostrophe'; Value = "C:\audio\speaker's recording.wav" }
        @{ Description = 'Unicode'; Value = 'C:\audio\meeting äöÅ.wav' }
        @{ Description = 'ampersand'; Value = 'C:\audio\speaker & guest.wav' }
        @{ Description = 'percent signs'; Value = 'C:\audio\meeting %PATH%.wav' }
        @{ Description = 'exclamation marks'; Value = 'C:\audio\meeting !PATH!.wav' }
        @{ Description = 'parentheses'; Value = 'C:\audio\meeting (take 1).wav' }
        @{ Description = 'empty argument'; Value = '' }
        @{ Description = 'embedded quotes'; Value = 'say "hello" to the child' }
        @{ Description = 'a quote alone'; Value = '"' }
        @{ Description = 'trailing backslash after spaces'; Value = 'C:\folder with spaces\' }
        @{ Description = 'multiple trailing backslashes'; Value = 'C:\folder with spaces\\' }
        @{ Description = 'backslashes before an embedded quote'; Value = 'before\\\"after' }
    )
}

Describe 'AC-016/AC-017/AC-018: real native process arguments, results and streams' -Tag 'Native' {
    BeforeAll {
        . (Join-Path (Split-Path $PSScriptRoot -Parent) 'WinAudioClean.ps1')
        . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
        $nativeFixture = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'native fixture folder\argument echo.exe')
        $fixtureVariables = @(
            'WAC_TEST_ARGV_PATH', 'WAC_TEST_PID_PATH', 'WAC_TEST_EXIT_CODE',
            'WAC_TEST_STDOUT', 'WAC_TEST_STDERR', 'WAC_TEST_STREAM_BYTES',
            'WAC_TEST_SLEEP_MS', 'WAC_TEST_FFMPEG_OUTPUT', 'WAC_TEST_OUTPUT_PATH',
            'WAC_TEST_BLOCK_LOG', 'WAC_TEST_READ_STDIN', 'WAC_TEST_READ_STDIN_BYTES'
        )
    }

    BeforeEach {
        $savedNativeEnvironment = @{}
        foreach ($name in $fixtureVariables) {
            $savedNativeEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
    }

    AfterEach {
        foreach ($name in $fixtureVariables) {
            [Environment]::SetEnvironmentVariable($name, $savedNativeEnvironment[$name], 'Process')
        }
    }

    It 'preserves <Description> in actual child argv' -ForEach $nativeArgumentCases {
        $recordPath = Join-Path $TestDrive ('argv-' + [guid]::NewGuid().ToString('N') + '.json')
        $env:WAC_TEST_ARGV_PATH = $recordPath
        $expected = @('before', $Value, 'after')

        $result = Invoke-WacNativeProcess -FilePath $nativeFixture -ArgumentList $expected -TimeoutMilliseconds 10000
        $result.Started | Should -BeTrue -Because $result.Error
        $result.ExitCode | Should -Be 0
        $result.Error | Should -BeNullOrEmpty
        $result.CleanupError | Should -BeNullOrEmpty
        $result.TimedOut | Should -BeFalse
        $received = Get-Content -Raw -LiteralPath $recordPath -Encoding UTF8 | ConvertFrom-Json
        $received.Count | Should -Be $expected.Count
        for ($index = 0; $index -lt $expected.Count; $index++) {
            $received[$index] | Should -BeExactly $expected[$index]
        }
    }

    It 'starts with no child arguments and no render timeout' {
        $recordPath = Join-Path $TestDrive 'empty-argv.json'
        $env:WAC_TEST_ARGV_PATH = $recordPath
        $result = Invoke-WacNativeProcess -FilePath $nativeFixture -ArgumentList @()
        $result.Started | Should -BeTrue -Because $result.Error
        $result.ExitCode | Should -Be 0
        $result.Error | Should -BeNullOrEmpty
        $result.TimedOut | Should -BeFalse
        $result.StandardOutput | Should -BeNullOrEmpty
        $result.StandardError | Should -BeNullOrEmpty
        [IO.File]::ReadAllText($recordPath) | Should -BeExactly '[]'
    }

    It 'keeps native nonzero status and both diagnostic streams' {
        $env:WAC_TEST_EXIT_CODE = '7'
        $env:WAC_TEST_STDOUT = "stdout detail`r`n"
        $env:WAC_TEST_STDERR = "stderr failure detail äöÅ`r`n"
        $result = Invoke-WacNativeProcess -FilePath $nativeFixture -ArgumentList @() -TimeoutMilliseconds 10000
        $result.Started | Should -BeTrue -Because $result.Error
        $result.ExitCode | Should -Be 7
        $result.TimedOut | Should -BeFalse
        $result.Error | Should -BeNullOrEmpty
        $result.StandardOutput | Should -BeExactly "stdout detail`r`n"
        $result.StandardError | Should -BeExactly "stderr failure detail äöÅ`r`n"
    }

    It 'closes child stdin so a reader receives EOF without waiting for input' {
        $env:WAC_TEST_READ_STDIN = '1'
        $result = Invoke-WacNativeProcess -FilePath $nativeFixture -ArgumentList @() -TimeoutMilliseconds 3000
        $result.Started | Should -BeTrue -Because $result.Error
        $result.ExitCode | Should -Be 0
        $result.Error | Should -BeNullOrEmpty
        $result.CleanupError | Should -BeNullOrEmpty
        $result.TimedOut | Should -BeFalse
        $result.StandardOutput | Should -BeExactly 'STDIN_EOF:0'
        $result.StandardError | Should -BeNullOrEmpty
    }

    It 'returns structured startup failure for <Description>' -ForEach @(
        @{ Description = 'a missing executable'; CreateInvalidFile = $false }
        @{ Description = 'a file that is not an executable'; CreateInvalidFile = $true }
    ) {
        $badExecutable = Join-Path $TestDrive ('invalid-' + [guid]::NewGuid().ToString('N') + '.exe')
        if ($CreateInvalidFile) { [IO.File]::WriteAllBytes($badExecutable, [byte[]](1, 2, 3, 4)) }
        $result = Invoke-WacNativeProcess -FilePath $badExecutable -ArgumentList @() -TimeoutMilliseconds 10000
        $result.Started | Should -BeFalse
        $result.ExitCode | Should -BeNullOrEmpty
        $result.Error | Should -Not -BeNullOrEmpty
        $result.TimedOut | Should -BeFalse
        $result.StandardOutput | Should -BeNullOrEmpty
        $result.StandardError | Should -BeNullOrEmpty
        if ($CreateInvalidFile) {
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($badExecutable)) | Should -BeExactly 'AQIDBA=='
        }
    }

    It 'rejects a NUL argument before starting the child' {
        $recordPath = Join-Path $TestDrive 'rejected-nul-argv.json'
        $env:WAC_TEST_ARGV_PATH = $recordPath
        $result = Invoke-WacNativeProcess -FilePath $nativeFixture -ArgumentList @('before' + [char]0 + 'after') -TimeoutMilliseconds 10000
        $result.Started | Should -BeFalse
        $result.ExitCode | Should -BeNullOrEmpty
        $result.Error | Should -Match 'NUL'
        $result.TimedOut | Should -BeFalse
        Test-Path -LiteralPath $recordPath | Should -BeFalse
    }

    It 'rejects an excessive command line before starting the child' {
        $recordPath = Join-Path $TestDrive 'rejected-long-argv.json'
        $env:WAC_TEST_ARGV_PATH = $recordPath
        $result = Invoke-WacNativeProcess -FilePath $nativeFixture -ArgumentList @('x' * 32768) -TimeoutMilliseconds 10000
        $result.Started | Should -BeFalse
        $result.ExitCode | Should -BeNullOrEmpty
        $result.Error | Should -Match 'command.*limit'
        $result.TimedOut | Should -BeFalse
        Test-Path -LiteralPath $recordPath | Should -BeFalse
    }

    It 'fully drains simultaneous streams that each exceed pipe capacity' {
        $streamLength = 524288
        $env:WAC_TEST_STREAM_BYTES = [string]$streamLength
        $result = Invoke-WacNativeProcess -FilePath $nativeFixture -ArgumentList @() -TimeoutMilliseconds 10000
        $result.Started | Should -BeTrue -Because $result.Error
        $result.ExitCode | Should -Be 0
        $result.Error | Should -BeNullOrEmpty
        $result.TimedOut | Should -BeFalse
        $result.StandardOutput.Length | Should -Be ($streamLength + 'STDOUT_END'.Length)
        $result.StandardError.Length | Should -Be ($streamLength + 'STDERR_END'.Length)
        $result.CleanupError | Should -BeNullOrEmpty
        # Compare every character without printing megabytes on assertion failure.
        ($result.StandardOutput -ceq (('O' * $streamLength) + 'STDOUT_END')) | Should -BeTrue
        ($result.StandardError -ceq (('E' * $streamLength) + 'STDERR_END')) | Should -BeTrue
    }

    It 'terminates the timed-out child and retains prior diagnostics' {
        $pidPath = Join-Path $TestDrive 'timed-child.pid'
        $env:WAC_TEST_PID_PATH = $pidPath
        $env:WAC_TEST_SLEEP_MS = '15000'
        $env:WAC_TEST_STDOUT = 'BEFORE_TIMEOUT'
        $result = Invoke-WacNativeProcess -FilePath $nativeFixture -ArgumentList @() -TimeoutMilliseconds 1500
        $result.Started | Should -BeTrue -Because $result.Error
        $result.TimedOut | Should -BeTrue
        $result.Error | Should -Not -BeNullOrEmpty
        $result.CleanupError | Should -BeNullOrEmpty
        $result.StandardOutput | Should -BeExactly 'BEFORE_TIMEOUT'
        $childId = [int][IO.File]::ReadAllText($pidPath)
        Get-Process -Id $childId -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        # A fresh run succeeds after cancellation, proving the wrapper remains usable.
        $env:WAC_TEST_SLEEP_MS = $null
        $retry = Invoke-WacNativeProcess -FilePath $nativeFixture -ArgumentList @() -TimeoutMilliseconds 10000
        $retry.Started | Should -BeTrue -Because $retry.Error
        $retry.ExitCode | Should -Be 0
        $retry.TimedOut | Should -BeFalse
    }
}
