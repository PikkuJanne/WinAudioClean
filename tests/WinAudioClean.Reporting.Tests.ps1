BeforeDiscovery {
    $reportingCases = foreach ($shellName in @('powershell.exe', 'pwsh.exe')) {
        $command = Get-Command -Name $shellName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        foreach ($nativeExit in @(0, 9)) {
            foreach ($callerPreference in @('Continue', 'Stop')) {
                @{
                    ShellName = $shellName; ShellPath = $command.Source; Unavailable = ($null -eq $command)
                    NativeExit = $nativeExit; CallerPreference = $callerPreference
                }
            }
        }
    }
}

BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $scriptPath = Join-Path $repositoryRoot 'WinAudioClean.ps1'
    $metadataFixture = Join-Path $PSScriptRoot 'fixtures\Invoke-MetadataFailure.ps1'
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
    $nativeFixture = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'reporting native fixture.exe')
}

Describe 'AC-017: metadata reporting failures preserve native outcome' -Tag 'Reporting', 'Runtime', 'Native' {
    It 'handles native exit <NativeExit> with caller <CallerPreference> in <ShellName>' -ForEach $reportingCases {
        if ($Unavailable) {
            Set-ItResult -Skipped -Because "$ShellName is unavailable on this machine; this shell was not tested."
            return
        }
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $outputDirectory = Join-Path $scratch 'output [literal]'
        $null = [IO.Directory]::CreateDirectory($outputDirectory)
        $app = Join-Path $scratch 'WinAudioClean.ps1'
        Copy-Item -LiteralPath $scriptPath -Destination $app
        Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $scratch 'ffmpeg.exe')
        Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $scratch 'ffprobe.exe')
        $inputFile = Join-Path $scratch 'recording.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $outputFile = Join-Path $outputDirectory 'recording_Cleaned_20261002-1200.wav'
        if ($NativeExit -ne 0) {
            # Existing output is test-owned; native failure must retain it.
            [IO.File]::WriteAllBytes($outputFile, [byte[]]@(11, 12, 13, 14))
        }
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -ScriptPath {1} -InputPath {2} -OutputDirectory {3} -CallerErrorPreference {4}' -f
            (ConvertTo-WacTestQuotedArgument $metadataFixture), (ConvertTo-WacTestQuotedArgument $app),
            (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument $outputDirectory), $CallerPreference
        $result = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $scratch -EnvironmentVariables @{
            WAC_TEST_EXIT_CODE = [string]$NativeExit; WAC_TEST_FFMPEG_OUTPUT = '1'
            WAC_TEST_STDOUT = 'Native stdout retained'; WAC_TEST_STDERR = 'Native stderr retained'
        }

        $expectedExit = if ($NativeExit -eq 0) { 7 } else { 4 }
        $expectedStatus = if ($NativeExit -eq 0) { 'WARNING' } else { 'FAILED' }
        $result.ExitCode | Should -Be $expectedExit -Because (
            "the child must preserve the native/reporting outcome. Captured stdout:`n{0}`nCaptured stderr:`n{1}" -f
            $result.StandardOutput, $result.StandardError)
        $result.StandardError | Should -BeNullOrEmpty
        $result.StandardOutput | Should -Match 'Output size could not be read for the report'
        $result.StandardOutput | Should -Match 'simulated metadata access failure'
        $result.StandardOutput | Should -Match "DONE: $expectedStatus"
        $result.StandardOutput | Should -Not -Match 'DONE: SUCCESS'
        $log = Get-Content -Raw -LiteralPath (Join-Path $outputDirectory 'WinAudioClean_Log.txt')
        $log | Should -Match "STATUS\s+: $expectedStatus \(Native Exit Code: $NativeExit; Application Exit Code: $expectedExit\)"
        $log | Should -Match 'OUTPUT SIZE\s+: N/A'
        $log | Should -Match 'REPORT ERROR\s+: simulated metadata access failure'
        $log | Should -Match 'Native stdout retained'
        $log | Should -Match 'Native stderr retained'
        $expectedOutput = if ($NativeExit -eq 0) { 'UklGRgECAwQ=' } else { 'CwwNDg==' }
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputFile)) | Should -BeExactly $expectedOutput
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) | Should -BeExactly 'AQID'
    }
}
