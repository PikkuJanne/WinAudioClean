BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $scriptPath = Join-Path $repositoryRoot 'WinAudioClean.ps1'
    . $scriptPath
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
    $reportShell = (Get-Process -Id $PID).Path
    $reportNativeFixture = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'report fixture.exe')
    $reportLevelFilters = 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'

    function New-WacRunReportSandbox {
        param([string]$ReportFault = '')
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $output = Join-Path $root 'PRIVATE_USER_TOKEN output [literal]'
        $null = [IO.Directory]::CreateDirectory($output)
        $app = Join-Path $root 'WinAudioClean.ps1'
        $source = [IO.File]::ReadAllText($scriptPath)
        if ($ReportFault) {
            # The fixture changes only this isolated script copy. No production
            # fault switch or persistent ACL/environment change is introduced.
            $injection = @'
$script:WacReportOriginalOpen = ${function:Open-WacReportWriter}
function Open-WacReportWriter {
    param([string]$Path, [switch]$CreateNew, [int]$TimeoutMilliseconds = 3000)
    $leaf = [IO.Path]::GetFileName($Path)
    $fault = $env:WAC_REPORT_TEST_FAULT
    if (($fault -eq 'json' -and $leaf.EndsWith('.json')) -or
        ($fault -eq 'text' -and $leaf -ne 'WinAudioClean_Log.txt' -and $leaf.EndsWith('.txt')) -or
        ($fault -eq 'summary' -and $leaf -eq 'WinAudioClean_Log.txt')) {
        throw [UnauthorizedAccessException]::new('Injected report permission failure')
    }
    & $script:WacReportOriginalOpen -Path $Path -CreateNew:$CreateNew -TimeoutMilliseconds $TimeoutMilliseconds
}
$script:WacReportOriginalSet = ${function:Set-WacOwnedReportContent}
function Set-WacOwnedReportContent {
    param($Writer, [string]$Content)
    $extension = [IO.Path]::GetExtension($Writer.Path)
    if (($env:WAC_REPORT_TEST_FAULT -eq 'json-write' -and $extension -eq '.json') -or
        ($env:WAC_REPORT_TEST_FAULT -eq 'text-write' -and $extension -eq '.txt')) {
        & $script:WacReportOriginalSet -Writer $Writer -Content $Content.Substring(0, [int]($Content.Length / 2))
        throw [IO.IOException]::new('Injected report write/flush failure after partial write')
    }
    & $script:WacReportOriginalSet -Writer $Writer -Content $Content
}
$script:WacReportOriginalAdd = ${function:Add-WacSummaryReportContent}
function Add-WacSummaryReportContent {
    param($Writer, [string]$Content)
    if ($env:WAC_REPORT_TEST_FAULT -eq 'summary-write') {
        $null = & $script:WacReportOriginalAdd -Writer $Writer -Content $Content.Substring(0, [int]($Content.Length / 2))
        throw [IO.IOException]::new('Injected report write/flush failure after partial append')
    }
    & $script:WacReportOriginalAdd -Writer $Writer -Content $Content
}
'@
            $source = $source.Replace('# --- CONFIGURATION ---', ($injection + "`n# --- CONFIGURATION ---"))
        }
        [IO.File]::WriteAllText($app, $source, [Text.UTF8Encoding]::new($true))
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'WinAudioClean.IO.ps1') -Destination $root
        foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
            Copy-Item -LiteralPath $reportNativeFixture -Destination (Join-Path $root $name)
        }
        $inputFile = Join-Path $root 'PRIVATE_FILENAME_TOKEN.wav'
        $prior = Join-Path $output 'prior-export.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        [IO.File]::WriteAllBytes($prior, [byte[]]@(11, 12, 13, 14))
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -inputPath {1} -OutputDirectory {2} -Mode Zoom -NonInteractive' -f
            (ConvertTo-WacTestQuotedArgument $app), (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument $output)
        [pscustomobject]@{ Root = $root; App = $app; Output = $output; Input = $inputFile; Prior = $prior; Arguments = $arguments }
    }

    function Invoke-WacRunReportCase {
        param($Sandbox, [string]$Outcome = 'success', [string]$ReportFault = '', [string]$ProbeJson = '')
        $environment = @{
            WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_SLEEP_MS = '50'
            WAC_TEST_STDOUT = 'PRIVATE_STDOUT_TOKEN source C:\PRIVATE_USER_TOKEN\PRIVATE_FILENAME_TOKEN.wav'
            WAC_TEST_STDERR = 'PRIVATE_STDERR_TOKEN title PRIVATE_TITLE_TOKEN'
            WAC_TEST_EXIT_CODE = $(if ($Outcome -eq 'encoder') { '17' } else { '0' })
            WAC_TEST_OUTPUT_MODE = $(if ($Outcome -eq 'validation') { 'short' } else { 'valid' })
            WAC_REPORT_TEST_FAULT = $ReportFault; PSMODULEPATH = $null
        }
        if ($ProbeJson) { $environment['WAC_TEST_PROBE_STDOUT'] = $ProbeJson }
        Invoke-WacTestProcess -FilePath $reportShell -Arguments $Sandbox.Arguments -WorkingDirectory $Sandbox.Root -EnvironmentVariables $environment -TimeoutMilliseconds 40000
    }

    function Assert-WacReportAudioOwnership {
        param($Sandbox, [bool]$Published)
        $files = @(Get-ChildItem -LiteralPath $Sandbox.Output -Filter '*_Cleaned_*.wav')
        $files.Count | Should -Be $(if ($Published) { 1 } else { 0 })
        if ($Published) { $files[0].Length | Should -Be 288044 }
        @(Get-ChildItem -LiteralPath $Sandbox.Output -Filter '*.partial' -Force).Count | Should -Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($Sandbox.Input)) | Should -BeExactly 'AQID'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($Sandbox.Prior)) | Should -BeExactly 'CwwNDg=='
    }
}

Describe 'AC-028: unavailable measurements stay explicit JSON nulls' -Tag 'RunReports', 'Unit' {
    It 'retains a finite numeric measurement' {
        $metric = ConvertTo-WacMeasurement -Value (-12.25) -UnavailableReason 'not_measured'
        $metric.value | Should -Be (-12.25)
        $metric.reason | Should -BeNullOrEmpty
        ($metric | ConvertTo-Json -Compress) | Should -Match '"value":-12.25'
    }

    It 'accepts integer schema/settings fields returned as <NumericType> by JSON readers' -ForEach @(
        @{ NumericType = 'int'; Schema = [int]1; Bits = [int]24 }
        @{ NumericType = 'long'; Schema = [long]1; Bits = [long]24 }
    ) {
        $report = [pscustomobject]@{
            schemaVersion = $Schema; status = 'SUCCESS'; processingStatus = 'SUCCESS'
            applicationExitCode = 0; nativeExitCode = 0
            settings = [pscustomobject]@{ mode = 'Raw'; bitDepth = $Bits; mono = $false; rf64 = $false }
            input = [pscustomobject]@{ durationSeconds = 3; stream = [pscustomobject]@{ index = 0; channels = 1; sampleRate = 48000 } }
            timing = [pscustomobject]@{ processingElapsedSeconds = 0.5 }
            output = [pscustomobject]@{ published = $true; validity = 'PASSED'; format = [pscustomobject]@{ sampleRate = 48000; bitDepth = 24; channels = 1; codec = 'pcm_s24le'; channelLayout = 'mono'; container = 'RIFF' } }
            measurements = [pscustomobject]@{ integratedLufs = @{ value = $null }; truePeakDbtp = @{ value = $null }; loudnessRangeLu = @{ value = $null } }
        }
        $redacted = ConvertTo-WacRedactedReport -Report $report
        $redacted.schemaVersion | Should -Be 1
        $redacted.settings.bitDepth | Should -Be 24
    }

    It 'uses null with a reason for <Description>' -ForEach @(
        @{ Description = 'missing'; Value = $null }
        @{ Description = 'NaN'; Value = [double]::NaN }
        @{ Description = 'positive infinity'; Value = [double]::PositiveInfinity }
        @{ Description = 'negative infinity'; Value = [double]::NegativeInfinity }
        @{ Description = 'unsupported diagnostic text'; Value = 'PRIVATE_UNSUPPORTED_TOKEN' }
        @{ Description = 'FFmpeg negative infinity text'; Value = '-inf' }
    ) {
        $metric = ConvertTo-WacMeasurement -Value $Value -UnavailableReason 'not_measured'
        $metric.value | Should -BeNullOrEmpty
        $metric.reason | Should -Not -BeNullOrEmpty
        $serialized = $metric | ConvertTo-Json -Compress
        $serialized | Should -Match '"value":null'
        $serialized | Should -Not -Match 'NaN|Infinity|PRIVATE_UNSUPPORTED_TOKEN'
    }
}

Describe 'AC-028: per-run JSON, text, summary, console and exit agree' -Tag 'RunReports', 'Runtime', 'Native' {
    It 'reports <Outcome> without losing native diagnostics' -ForEach @(
        @{ Outcome = 'success'; Exit = 0; Native = 0; Status = 'SUCCESS'; Published = $true }
        @{ Outcome = 'encoder'; Exit = 4; Native = 17; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'validation'; Exit = 5; Native = 0; Status = 'FAILED'; Published = $false }
    ) {
        $sandbox = New-WacRunReportSandbox
        $result = Invoke-WacRunReportCase -Sandbox $sandbox -Outcome $Outcome
        $result.ExitCode | Should -Be $Exit -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput | Should -Match ('DONE: ' + $Status)
        $jsonFiles = @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json')
        $jsonFiles.Count | Should -Be 1
        $json = Get-Content -Raw -LiteralPath $jsonFiles[0].FullName | ConvertFrom-Json
        $json.schemaVersion | Should -Be 1
        $json.jobId | Should -Match '^[a-f0-9]{32}$'
        $jsonFiles[0].Name | Should -BeExactly ('WinAudioClean_' + $json.jobId + '.json')
        $json.status | Should -BeExactly $Status
        $json.processingStatus | Should -BeExactly $Status
        $json.applicationExitCode | Should -Be $Exit
        $json.nativeExitCode | Should -Be $Native
        $json.input.durationSeconds | Should -Be 3
        $json.timing.processingElapsedSeconds | Should -BeGreaterThan 0
        $json.timing.processingElapsedSeconds | Should -Not -Be $json.input.durationSeconds
        $json.timing.startedAtUtc | Should -Not -BeNullOrEmpty
        $json.timing.endedAtUtc | Should -Not -BeNullOrEmpty
        $json.output.published | Should -Be $Published
        $json.output.validity | Should -BeExactly $(if ($Published) { 'PASSED' } else { 'FAILED' })
        $json.diagnostics.standardOutput | Should -Match 'PRIVATE_STDOUT_TOKEN'
        $json.diagnostics.standardError | Should -Match 'PRIVATE_STDERR_TOKEN'
        foreach ($name in @('integratedLufs', 'truePeakDbtp', 'loudnessRangeLu')) {
            $json.measurements.$name.value | Should -BeNullOrEmpty
            $json.measurements.$name.reason | Should -BeExactly 'not_measured'
        }
        if ($Published) {
            $json.output.format.sampleRate | Should -Be 48000
            $json.output.format.bitDepth | Should -Be 16
            $json.output.format.codec | Should -BeExactly 'pcm_s16le'
            $json.output.format.channels | Should -Be 1
            $json.output.format.channelLayout | Should -BeExactly 'mono'
            $json.output.format.container | Should -BeExactly 'RIFF'
        }
        $text = Get-Content -Raw -LiteralPath (Join-Path $sandbox.Output ('WinAudioClean_' + $json.jobId + '.txt'))
        $summary = Get-Content -Raw -LiteralPath (Join-Path $sandbox.Output 'WinAudioClean_Log.txt')
        foreach ($human in @($text, $summary)) {
            $human | Should -Match ('STATUS\s+: ' + $Status + ' \(Native Exit Code: ' + $Native + '; Application Exit Code: ' + $Exit + '\)')
            $human | Should -Match ([regex]::Escape($json.jobId))
            $human | Should -Match ([regex]::Escape($reportLevelFilters))
            $human | Should -Match 'PRIVATE_STDOUT_TOKEN'
            $human | Should -Match 'PRIVATE_STDERR_TOKEN'
        }
        Assert-WacReportAudioOwnership -Sandbox $sandbox -Published $Published
    }

    It 'keeps a multiline title in JSON while preventing forged human status lines' {
        $sandbox = New-WacRunReportSandbox
        $title = "PRIVATE_TITLE_TOKEN`nSTATUS         : SUCCESS forged`r`nOTHER_FIELD: fake"
        $probe = @{ streams = @(@{ index = 0; codec_type = 'audio'; codec_name = 'pcm_s16le'; channels = 1; sample_rate = '48000'; duration = '3.000000'; tags = @{ title = $title } }) } | ConvertTo-Json -Depth 5 -Compress
        $result = Invoke-WacRunReportCase -Sandbox $sandbox -Outcome encoder -ProbeJson $probe
        $result.ExitCode | Should -Be 4
        $path = @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json')[0].FullName
        $report = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
        $report.input.stream.title | Should -BeExactly $title
        $text = Get-Content -Raw -LiteralPath ([IO.Path]::ChangeExtension($path, '.txt'))
        ([regex]::Matches($text, '(?m)^STATUS\s+:')).Count | Should -Be 1
        $text | Should -Match 'STATUS\s+: FAILED'
        $text | Should -Match 'PRIVATE_TITLE_TOKEN\\u000[aA]STATUS'
        Assert-WacReportAudioOwnership -Sandbox $sandbox -Published $false
    }
}

Describe 'AC-030: reporting failures preserve the primary outcome and audio' -Tag 'RunReports', 'Runtime', 'Native' {
    It 'preserves <Outcome> when <ReportFault> permission is denied' -ForEach @(
        @{ Outcome = 'success'; ReportFault = 'json'; Exit = 7; Status = 'WARNING'; Published = $true }
        @{ Outcome = 'success'; ReportFault = 'text'; Exit = 7; Status = 'WARNING'; Published = $true }
        @{ Outcome = 'success'; ReportFault = 'summary'; Exit = 7; Status = 'WARNING'; Published = $true }
        @{ Outcome = 'encoder'; ReportFault = 'json'; Exit = 4; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'encoder'; ReportFault = 'text'; Exit = 4; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'encoder'; ReportFault = 'summary'; Exit = 4; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'validation'; ReportFault = 'json'; Exit = 5; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'validation'; ReportFault = 'text'; Exit = 5; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'validation'; ReportFault = 'summary'; Exit = 5; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'success'; ReportFault = 'json-write'; Exit = 7; Status = 'WARNING'; Published = $true }
        @{ Outcome = 'success'; ReportFault = 'text-write'; Exit = 7; Status = 'WARNING'; Published = $true }
        @{ Outcome = 'success'; ReportFault = 'summary-write'; Exit = 7; Status = 'WARNING'; Published = $true }
        @{ Outcome = 'encoder'; ReportFault = 'json-write'; Exit = 4; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'encoder'; ReportFault = 'text-write'; Exit = 4; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'encoder'; ReportFault = 'summary-write'; Exit = 4; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'validation'; ReportFault = 'json-write'; Exit = 5; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'validation'; ReportFault = 'text-write'; Exit = 5; Status = 'FAILED'; Published = $false }
        @{ Outcome = 'validation'; ReportFault = 'summary-write'; Exit = 5; Status = 'FAILED'; Published = $false }
    ) {
        $sandbox = New-WacRunReportSandbox -ReportFault $ReportFault
        $summaryPath = Join-Path $sandbox.Output 'WinAudioClean_Log.txt'
        if ($ReportFault -eq 'summary-write') {
            [IO.File]::WriteAllText($summaryPath, 'PREVIOUS_SUMMARY_BYTES_MUST_SURVIVE', [Text.UTF8Encoding]::new($false))
        }
        $result = Invoke-WacRunReportCase -Sandbox $sandbox -Outcome $Outcome -ReportFault $ReportFault
        $result.ExitCode | Should -Be $Exit -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput | Should -Match ('DONE: ' + $Status)
        ($result.StandardOutput + $result.StandardError) | Should -Match 'Injected report (permission|write/flush) failure'
        $result.StandardOutput | Should -Not -Match 'DONE: SUCCESS'
        foreach ($file in @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json')) {
            $json = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
            $json.status | Should -BeExactly $Status
            $json.applicationExitCode | Should -Be $Exit
            $json.output.published | Should -Be $Published
            $json.reporting.complete | Should -BeFalse
        }
        foreach ($file in @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.txt')) {
            $text = Get-Content -Raw -LiteralPath $file.FullName
            $text | Should -Not -Match 'STATUS\s+: SUCCESS'
        }
        if ($ReportFault -notlike 'json*') {
            @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json').Count | Should -Be 1
        }
        if ($ReportFault -eq 'summary-write') {
            [IO.File]::ReadAllText($summaryPath) | Should -BeExactly 'PREVIOUS_SUMMARY_BYTES_MUST_SURVIVE'
        }
        Assert-WacReportAudioOwnership -Sandbox $sandbox -Published $Published
    }

    It 'keeps concurrent run reports unique and summary entries contiguous' {
        $sandbox = New-WacRunReportSandbox
        $pending = @()
        try {
            foreach ($token in @('CONCURRENT_FIRST_TOKEN', 'CONCURRENT_SECOND_TOKEN')) {
                $startInfo = New-Object Diagnostics.ProcessStartInfo
                $startInfo.FileName = $reportShell
                $startInfo.Arguments = $sandbox.Arguments
                $startInfo.WorkingDirectory = $sandbox.Root
                $startInfo.UseShellExecute = $false
                $startInfo.CreateNoWindow = $true
                $startInfo.RedirectStandardOutput = $true
                $startInfo.RedirectStandardError = $true
                $startInfo.RedirectStandardInput = $true
                $startInfo.EnvironmentVariables.Remove('PSMODULEPATH')
                $startInfo.EnvironmentVariables['WAC_TEST_FFMPEG_OUTPUT'] = '1'
                $startInfo.EnvironmentVariables['WAC_TEST_STDOUT'] = $token
                $startInfo.EnvironmentVariables['WAC_TEST_STDERR'] = ('stderr ' + $token)
                $startInfo.EnvironmentVariables['WAC_TEST_SLEEP_MS'] = '1000'
                $process = New-Object Diagnostics.Process
                $process.StartInfo = $startInfo
                $null = $process.Start()
                $stdout = $process.StandardOutput.ReadToEndAsync()
                $stderr = $process.StandardError.ReadToEndAsync()
                $process.StandardInput.Close()
                $pending += [pscustomobject]@{ Process = $process; Stdout = $stdout; Stderr = $stderr; Token = $token }
            }
            foreach ($child in $pending) {
                $child.Process.WaitForExit(40000) | Should -BeTrue
                $child.Stdout.Wait(5000) | Should -BeTrue
                $child.Stderr.Wait(5000) | Should -BeTrue
                $child.Process.ExitCode | Should -Be 0 -Because ($child.Stdout.Result + $child.Stderr.Result)
                $child.Stdout.Result | Should -Match 'DONE: SUCCESS'
            }
            $jsonFiles = @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json')
            $jsonFiles.Count | Should -Be 2
            $reports = @($jsonFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json })
            @($reports.jobId | Select-Object -Unique).Count | Should -Be 2
            $summary = Get-Content -Raw -LiteralPath (Join-Path $sandbox.Output 'WinAudioClean_Log.txt')
            foreach ($report in $reports) {
                $report.status | Should -BeExactly 'SUCCESS'
                $report.applicationExitCode | Should -Be 0
                $text = Get-Content -Raw -LiteralPath (Join-Path $sandbox.Output ('WinAudioClean_' + $report.jobId + '.txt'))
                $summary.Contains($text.Trim()) | Should -BeTrue -Because 'each complete per-run entry must occur contiguously in the shared summary'
                $matches = @($pending | Where-Object { $report.diagnostics.standardOutput -match $_.Token })
                $matches.Count | Should -Be 1
            }
            ([regex]::Matches($summary, 'STATUS\s+: SUCCESS')).Count | Should -Be 2
            @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*_Cleaned_*.wav').Count | Should -Be 2
            @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.partial' -Force).Count | Should -Be 0
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($sandbox.Input)) | Should -BeExactly 'AQID'
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($sandbox.Prior)) | Should -BeExactly 'CwwNDg=='
        } finally {
            foreach ($child in $pending) {
                if (-not $child.Process.HasExited) { $child.Process.Kill() }
                $child.Process.Dispose()
            }
        }
    }
}

Describe 'AC-029: explicit support export removes sensitive local fields' -Tag 'RunReports', 'Runtime', 'Native' {
    It 'exports an allowlisted report without tools or processing and refuses overwrite' {
        $sandbox = New-WacRunReportSandbox
        $result = Invoke-WacRunReportCase -Sandbox $sandbox -Outcome 'success'
        $result.ExitCode | Should -Be 0
        $reportPath = @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json')[0].FullName
        $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
        $report.input | Add-Member -NotePropertyName containerTitle -NotePropertyValue 'PRIVATE_CONTAINER_TITLE_TOKEN' -Force
        $report.input.stream.title = 'PRIVATE_STREAM_TITLE_TOKEN'
        $report.toolVersion = 'PRIVATE_TOOL_VERSION_TOKEN'
        $report.dependencies.ffmpeg.version = 'PRIVATE_FFMPEG_VERSION_TOKEN'
        $report.dependencies.ffprobe.version = 'PRIVATE_FFPROBE_VERSION_TOKEN'
        $report.settings.exactFilters = 'PRIVATE_FILTER_TOKEN C:\PRIVATE_USER_TOKEN\filter.txt'
        $report | Add-Member -NotePropertyName unknownPrivateField -NotePropertyValue 'PRIVATE_EXTRA_TOKEN https://private.invalid/token' -Force
        [IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($reportPath))
        # An isolated export-only installation contains only the two scripts.
        $exportRoot = Join-Path $sandbox.Root 'export-only'
        $null = [IO.Directory]::CreateDirectory($exportRoot)
        foreach ($name in @('WinAudioClean.ps1', 'WinAudioClean.IO.ps1')) {
            Copy-Item -LiteralPath (Join-Path $repositoryRoot $name) -Destination $exportRoot
        }
        $diagnostic = Join-Path $sandbox.Root 'diagnostic.json'
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -ExportDiagnostic {1} -DiagnosticOutputPath {2}' -f
            (ConvertTo-WacTestQuotedArgument (Join-Path $exportRoot 'WinAudioClean.ps1')), (ConvertTo-WacTestQuotedArgument $reportPath), (ConvertTo-WacTestQuotedArgument $diagnostic)
        $exported = Invoke-WacTestProcess -FilePath $reportShell -Arguments $arguments -WorkingDirectory $exportRoot -EnvironmentVariables @{ PSMODULEPATH = $null; PATH = $exportRoot }
        $exported.ExitCode | Should -Be 0 -Because ($exported.StandardOutput + $exported.StandardError)
        ($exported.StandardOutput + $exported.StandardError) | Should -Match '(?i)review|inspect'
        $redacted = Get-Content -Raw -LiteralPath $diagnostic
        $redacted | Should -Not -Match 'PRIVATE_|private\.invalid|standardOutput|standardError'
        $redacted | Should -Not -Match ([regex]::Escape($sandbox.Root))
        $parsed = $redacted | ConvertFrom-Json
        $parsed.schemaVersion | Should -Be 1
        $parsed.status | Should -BeExactly 'SUCCESS'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($reportPath)) | Should -BeExactly $before
        $diagnosticBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($diagnostic))
        $repeat = Invoke-WacTestProcess -FilePath $reportShell -Arguments $arguments -WorkingDirectory $exportRoot -EnvironmentVariables @{ PSMODULEPATH = $null; PATH = $exportRoot }
        $repeat.ExitCode | Should -Not -Be 0
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($diagnostic)) | Should -BeExactly $diagnosticBefore
        $arrayPath = Join-Path $sandbox.Root 'array-root.json'
        [IO.File]::WriteAllText($arrayPath, ('[' + [IO.File]::ReadAllText($reportPath) + ']'), [Text.UTF8Encoding]::new($false))
        $arrayOutput = Join-Path $sandbox.Root 'array-redacted.json'
        $arrayArguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -ExportDiagnostic {1} -DiagnosticOutputPath {2}' -f
            (ConvertTo-WacTestQuotedArgument (Join-Path $exportRoot 'WinAudioClean.ps1')), (ConvertTo-WacTestQuotedArgument $arrayPath), (ConvertTo-WacTestQuotedArgument $arrayOutput)
        $arrayResult = Invoke-WacTestProcess -FilePath $reportShell -Arguments $arrayArguments -WorkingDirectory $exportRoot -EnvironmentVariables @{ PSMODULEPATH = $null; PATH = $exportRoot }
        $arrayResult.ExitCode | Should -Be 2
        Test-Path -LiteralPath $arrayOutput | Should -BeFalse
        Assert-WacReportAudioOwnership -Sandbox $sandbox -Published $true
    }
}
