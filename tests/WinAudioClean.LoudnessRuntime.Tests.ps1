BeforeAll {
    $loudnessRepo = Split-Path $PSScriptRoot -Parent
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
    $loudnessNative = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'loudness-native.exe')
    $loudnessShell = (Get-Process -Id $PID).Path
}

Describe 'AC-039: measured stage failures preserve publication and warning contracts' -Tag 'LoudnessRuntime', 'Runtime', 'Native' {
    It 'handles <Fault> with exit <Exit> and final publication <Published>' -ForEach @(
        @{ Fault = 'analysis-malformed'; Exit = 4; Published = $false; Compliance = 'NOT_MEASURED'; Calls = 1 }
        @{ Fault = 'analysis-exit'; Exit = 4; Published = $false; Compliance = 'NOT_MEASURED'; Calls = 1 }
        @{ Fault = 'analysis-start'; Exit = 3; Published = $false; Compliance = 'NOT_MEASURED'; Calls = 1 }
        @{ Fault = 'render-malformed'; Exit = 7; Published = $true; Compliance = 'PASSED'; Calls = 3 }
        @{ Fault = 'final-malformed'; Exit = 7; Published = $true; Compliance = 'FAILED'; Calls = 3 }
        @{ Fault = 'final-exit'; Exit = 7; Published = $true; Compliance = 'FAILED'; Calls = 3 }
        @{ Fault = 'final-silence'; Exit = 7; Published = $true; Compliance = 'UNMEASURABLE'; Calls = 3 }
        @{ Fault = 'final-peak'; Exit = 7; Published = $true; Compliance = 'OUT_OF_TOLERANCE'; Calls = 3 }
        @{ Fault = 'render-dynamic'; Exit = 7; Published = $true; Compliance = 'PASSED'; Calls = 3 }
        @{ Fault = 'valid'; Exit = 0; Published = $true; Compliance = 'PASSED'; Calls = 3 }
    ) {
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $output = Join-Path $caseRoot 'output'
        $null = [IO.Directory]::CreateDirectory($output)
        $app = Join-Path $caseRoot 'WinAudioClean.ps1'
        $source = [IO.File]::ReadAllText((Join-Path $loudnessRepo 'WinAudioClean.ps1'))
        # Fault only the native boundary in an isolated copy. The real runtime
        # controls all pass ordering, publication, reports and terminal status.
        $injection = @'
$script:LoudnessOriginalInvoke = ${function:Invoke-WacNativeProcess}
function Invoke-WacNativeProcess {
    param([string]$FilePath, [string[]]$ArgumentList, [int]$TimeoutMilliseconds = 0,
        [System.IO.Stream]$StandardInputStream)
    if ('-af' -notin $ArgumentList) {
        $result = & $script:LoudnessOriginalInvoke -FilePath $FilePath -ArgumentList $ArgumentList -TimeoutMilliseconds $TimeoutMilliseconds
        if ('-filters' -in $ArgumentList) { $result.StandardOutput += "`n ... aresample A->A Fixture filter`n" }
        return $result
    }
    $stage = if ($null -ne $StandardInputStream) { 'final' } elseif ('null' -in $ArgumentList) { 'analysis' } else { 'render' }
    [IO.File]::AppendAllText($env:WAC_LOUDNESS_TRACE, ($stage + "`n"))
    if ($stage -eq 'render') {
        $result = & $script:LoudnessOriginalInvoke -FilePath $FilePath -ArgumentList $ArgumentList -TimeoutMilliseconds $TimeoutMilliseconds
    } else {
        $result = [pscustomobject]@{ Started = $true; ExitCode = 0; StandardOutput = ''; StandardError = ''; Error = $null; TimedOut = $false; CleanupError = $null }
    }
    if ($stage -eq 'final') {
        if (-not $StandardInputStream.CanRead -or $StandardInputStream.Position -ne 0) { throw 'Final measurement must receive the rewound held stream.' }
        $null = $StandardInputStream.ReadByte()
    }
    $result.StandardError = '{"input_i":"-12.00","input_tp":"-1.50","input_lra":"2.00","input_thresh":"-22.00","output_i":"-12.00","output_tp":"-1.50","output_lra":"2.00","output_thresh":"-22.00","normalization_type":"linear","target_offset":"0.00"}'
    $fault = $env:WAC_LOUDNESS_FAULT
    if ($fault -eq ($stage + '-malformed')) { $result.StandardError = '{"input_i":"NaN"}' }
    if ($fault -eq ($stage + '-exit')) { $result.ExitCode = 19 }
    if ($fault -eq ($stage + '-start')) { $result.Started = $false; $result.ExitCode = $null; $result.Error = 'Injected native start failure' }
    if ($stage -eq 'render' -and $fault -eq 'render-dynamic') { $result.StandardError = $result.StandardError.Replace('"linear"', '"dynamic"') }
    if ($stage -eq 'final' -and $fault -eq 'final-peak') { $result.StandardError = $result.StandardError.Replace('"input_tp":"-1.50"', '"input_tp":"-0.50"') }
    if ($stage -eq 'final' -and $fault -eq 'final-silence') {
        $result.StandardError = '{"input_i":"-inf","input_tp":"-inf","input_lra":"0.00","input_thresh":"-70.00","output_i":"-inf","output_tp":"-inf","output_lra":"0.00","output_thresh":"-70.00","normalization_type":"linear","target_offset":"inf"}'
    }
    $result
}
'@
        $source = $source.Replace('# --- CONFIGURATION ---', ($injection + "`n# --- CONFIGURATION ---"))
        [IO.File]::WriteAllText($app, $source, [Text.UTF8Encoding]::new($true))
        Copy-Item -LiteralPath (Join-Path $loudnessRepo 'WinAudioClean.IO.ps1') -Destination $caseRoot
        foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) { Copy-Item -LiteralPath $loudnessNative -Destination (Join-Path $caseRoot $name) }
        $inputFile = Join-Path $caseRoot 'source.wav'
        $prior = Join-Path $output 'prior.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        [IO.File]::WriteAllBytes($prior, [byte[]]@(11, 12, 13))
        $trace = Join-Path $caseRoot 'stages.txt'
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -inputPath {1} -OutputDirectory {2} -Mode Zoom -LoudnessMode Accurate -NonInteractive' -f
            (ConvertTo-WacTestQuotedArgument $app), (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument $output)
        $result = Invoke-WacTestProcess -FilePath $loudnessShell -Arguments $arguments -WorkingDirectory $caseRoot -EnvironmentVariables @{
            WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_EXIT_CODE = '0'; WAC_LOUDNESS_TRACE = $trace; WAC_LOUDNESS_FAULT = $Fault; PSMODULEPATH = $null
        } -TimeoutMilliseconds 40000
        $result.ExitCode | Should -Be $Exit -Because ($result.StandardOutput + $result.StandardError)
        @(Get-Content -LiteralPath $trace).Count | Should -Be $Calls
        $reports = @(Get-ChildItem -LiteralPath $output -Filter 'WinAudioClean_*.json')
        $reports.Count | Should -Be 1
        $report = Get-Content -Raw -LiteralPath $reports[0].FullName | ConvertFrom-Json
        $report.output.published | Should -Be $Published
        $report.applicationExitCode | Should -Be $Exit
        $report.processingExitCode | Should -Be $(if ($Published) { 0 } else { $Exit })
        $report.reporting.complete | Should -BeTrue
        if (-not $Published) {
            $report.normalization.renderFilter | Should -BeNullOrEmpty
            $report.settings.exactFilters | Should -BeNullOrEmpty
        } else {
            $report.normalization.render.arguments | Should -Contain '-nostats'
            $report.normalization.render.arguments | Should -Not -Contain '-stats'
        }
        $report.loudnessCompliance.status | Should -BeExactly $Compliance
        $report.status | Should -BeExactly $(if ($Exit -eq 0) { 'SUCCESS' } elseif ($Exit -eq 7) { 'WARNING' } else { 'FAILED' })
        if ($Fault -eq 'render-malformed') {
            $report.normalization.actualType | Should -BeNullOrEmpty
            $report.warningCodes | Should -Contain 'normalization_result_unavailable'
        }
        if ($Fault -eq 'render-dynamic') { $report.normalization.fallbackReason | Should -BeExactly 'ffmpeg_dynamic_fallback' }
        if ($Compliance -eq 'FAILED') {
            $report.measurements.integratedLufs.value | Should -BeNullOrEmpty
            $report.measurements.integratedLufs.reason | Should -BeExactly 'measurement_failed'
            $report.normalization.final.error | Should -Not -BeNullOrEmpty
        }
        if ($Fault -eq 'final-peak') { $report.loudnessCompliance.reason | Should -BeExactly 'true_peak_exceeded' }
        @(Get-ChildItem -LiteralPath $output -Filter '*_Cleaned_*.wav').Count | Should -Be $(if ($Published) { 1 } else { 0 })
        @(Get-ChildItem -LiteralPath $output -Filter '*.partial' -Force).Count | Should -Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) | Should -BeExactly 'AQID'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($prior)) | Should -BeExactly 'CwwN'
        $text = Get-Content -Raw -LiteralPath ([IO.Path]::ChangeExtension($reports[0].FullName, '.txt'))
        $text | Should -Match ('LOUDNESS CHECK\s+: ' + $Compliance)
    }
}
