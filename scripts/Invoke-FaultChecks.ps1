#requires -Version 5.1
<#
.SYNOPSIS
Proves existing regression tests detect three representative runtime defects.
.DESCRIPTION
Runs one existing Pester test for each defect before and after changing only a
copied source tree. Native exit uses the installed C# fixture, not a mocked exit.
Scratch ownership/cleanup use held ordinary filesystem identities. No media,
preferences, dependency downloads, application entry point or user output is used.
.PARAMETER ModuleRoot
Existing pinned Pester module location; defaults to .wac-local/Modules.
.PARAMETER ReportPath
Fresh JSON file directly beneath repository .wac-local. Existing files are refused.
#>
[CmdletBinding()]
param([string]$ModuleRoot, [string]$ReportPath)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ModuleRoot) { $ModuleRoot = Join-Path $repoRoot '.wac-local/Modules' }
$pesterManifest = Join-Path $ModuleRoot 'Pester/5.7.1/Pester.psd1'
if (-not (Test-Path -LiteralPath $pesterManifest -PathType Leaf)) { throw 'Pinned Pester 5.7.1 is required; no dependency is installed by this runner.' }
if ((Test-ModuleManifest -Path $pesterManifest).Version -ne [version]'5.7.1') { throw 'Unexpected Pester manifest version.' }
$compilerPath = @(
    (Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe')
    (Join-Path $env:WINDIR 'Microsoft.NET/Framework/v4.0.30319/csc.exe')
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $compilerPath) { throw 'The installed Windows .NET Framework C# compiler is required; no dependency is installed by this runner.' }
. (Join-Path $repoRoot 'tests/fixtures/TestProcess.ps1')
if (-not ('WinAudioClean.Tests.FaultCheckScratch' -as [type])) {
    Add-Type -Path (Join-Path $repoRoot 'tests/fixtures/FaultCheckScratch.cs') -ErrorAction Stop
}

$cases = @(
    [pscustomobject]@{
        Id = 'overwrite'; Acceptance = @('AC-022', 'AC-023', 'AC-024'); Source = 'WinAudioClean.IO.ps1'
        Before = '$transaction.TempHandle = [IO.File]::Open($transaction.TempPath, [IO.FileMode]::CreateNew,'
        After = '$transaction.TempHandle = [IO.File]::Open($transaction.TempPath, [IO.FileMode]::Create,'
        TestPath = 'tests/WinAudioClean.Transaction.Tests.ps1'
        Filter = '*never overwrites a preexisting partial reservation'
        ExpectedFailure = '*exception to be thrown*'
        Defect = 'Opening an occupied partial reservation with Create truncates foreign bytes instead of rejecting it.'
    }
    [pscustomobject]@{
        Id = 'bad-exit'; Acceptance = @('AC-017'); Source = 'WinAudioClean.ps1'
        Before = '$result.ExitCode = $process.ExitCode'
        After = '$result.ExitCode = 0'
        TestPath = 'tests/WinAudioClean.Native.Tests.ps1'
        Filter = '*keeps native nonzero status and both diagnostic streams'
        ExpectedFailure = '*Expected 7, but got 0*'
        Defect = 'Losing the real native exit code converts a fixture exit 7 into apparent success 0.'
    }
    [pscustomobject]@{
        Id = 'wrong-sample-rate'; Acceptance = @('AC-025'); Source = 'WinAudioClean.ps1'
        Before = "'-ar', '48000', '-c:a', `$OutputPolicy.Codec"
        After = "'-ar', '44100', '-c:a', `$OutputPolicy.Codec"
        TestPath = 'tests/WinAudioClean.Encoding.Tests.ps1'
        Filter = '*pins output encoding and keeps selected stereo channels without trimming or splitting'
        ExpectedFailure = '*48000*44100*'
        Defect = 'Changing the ordinary render encoder argv to 44100 violates the explicit 48 kHz output contract.'
    }
)

$sourcePaths = @(
    @(Get-ChildItem -LiteralPath $repoRoot -Filter 'WinAudioClean*.ps1' -File | ForEach-Object { $_.Name })
    'tests/WinAudioClean.Transaction.Tests.ps1'; 'tests/WinAudioClean.Native.Tests.ps1'; 'tests/WinAudioClean.Encoding.Tests.ps1'
    'tests/fixtures/TestProcess.ps1'; 'tests/fixtures/New-NativeProcessFixture.ps1'; 'tests/fixtures/NativeProcessFixture.cs'
)
$evidencePaths = @($sourcePaths) + @('scripts/Invoke-FaultChecks.ps1', 'tests/fixtures/FaultCheckScratch.cs', 'tests/WinAudioClean.FaultChecks.Tests.ps1')
function Get-WacFaultHashes {
    param([string[]]$Paths)
    $hashes = [ordered]@{}
    foreach ($relative in $Paths) { $hashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $repoRoot $relative) -Algorithm SHA256).Hash }
    $hashes
}
function ConvertTo-WacFaultSanitized {
    param([string]$Value, [string]$ScratchRoot)
    $result = $Value.Replace($ScratchRoot, '<scratch>').Replace($ScratchRoot.Replace('\', '\\'), '<scratch>')
    $result = $result.Replace($repoRoot, '<repo>').Replace($repoRoot.Replace('\', '\\'), '<repo>')
    if ($env:USERPROFILE) { $result = $result.Replace($env:USERPROFILE, '<user-profile>').Replace($env:USERPROFILE.Replace('\', '\\'), '<user-profile>') }
    foreach ($name in @('USERNAME', 'COMPUTERNAME', 'USERDOMAIN')) {
        $literal = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($literal) { $result = [regex]::Replace($result, [regex]::Escape($literal), '<local-identity>', 'IgnoreCase') }
    }
    $result
}

$childSource = @'
param([string]$TestPath, [string]$Filter, [string]$OutputPath, [string]$PesterManifest, [string]$TempRoot)
$ErrorActionPreference = 'Stop'
if (-not [IO.Path]::GetTempPath().TrimEnd('\').Equals($TempRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Child temporary directory is not the explicitly isolated scratch directory.'
}
Import-Module -Name $PesterManifest -Force -ErrorAction Stop
$configuration = New-PesterConfiguration
$configuration.Run.Path = @($TestPath)
$configuration.Filter.FullName = @($Filter)
$configuration.Run.PassThru = $true
$configuration.Run.Exit = $false
$configuration.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $configuration
$tests = @(foreach ($test in $result.Tests | Where-Object { $_.Executed }) {
    [ordered]@{ name = $test.ExpandedPath; result = $test.Result; errors = @($test.ErrorRecord | ForEach-Object { $_.ToString() }) }
})
$summary = [ordered]@{
    pesterVersion = (Get-Module Pester).Version.ToString(); shellVersion = $PSVersionTable.PSVersion.ToString()
    passed = $result.PassedCount; failed = $result.FailedCount; skipped = $result.SkippedCount
    failedContainers = $result.FailedContainersCount; failedBlocks = $result.FailedBlocksCount
    tests = $tests
}
[IO.File]::WriteAllText($OutputPath, ($summary | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0 -or $result.FailedBlocksCount -gt 0) { exit 1 }
if ($result.PassedCount -ne 1 -or $result.SkippedCount -ne 0) { exit 2 }
exit 0
'@

$started = [DateTime]::UtcNow.ToString('o')
$beforeHashes = Get-WacFaultHashes -Paths $evidencePaths
$revision = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot establish tested Git revision.' }
$hostExe = Join-Path $PSHOME $(if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' })
$owner = [WinAudioClean.Tests.FaultCheckScratch]::Create($repoRoot)
$reportStream = $null
$records = New-Object 'System.Collections.Generic.List[object]'
$report = [ordered]@{
    schemaVersion = 1; task = 'WAC-M4-01'; acceptance = 'AC-068'; status = 'running'
    sourceRevision = $revision; startedUtc = $started; shellVersion = $PSVersionTable.PSVersion.ToString()
    hostSha256 = (Get-FileHash -LiteralPath $hostExe -Algorithm SHA256).Hash
    command = $(if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-FaultChecks.ps1' } else { 'pwsh -NoProfile -File scripts/Invoke-FaultChecks.ps1' })
    pesterVersion = '5.7.1'
    pesterManifestSha256 = (Get-FileHash -LiteralPath $pesterManifest -Algorithm SHA256).Hash
    pesterModuleSha256 = (Get-FileHash -LiteralPath (Join-Path ([IO.Path]::GetDirectoryName($pesterManifest)) 'Pester.psm1') -Algorithm SHA256).Hash
    nativeCompiler = [ordered]@{
        path = $compilerPath; fileVersion = (Get-Item -LiteralPath $compilerPath).VersionInfo.FileVersion
        sha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
    }
    sourceHashesBefore = $beforeHashes; cases = $records
    limits = @('Representative copy-only defects; not exhaustive mutation coverage.', 'Wrong sample rate is an encoder argv contract check, not a real FFmpeg/media render.', 'Synthetic native fixture only; no user audio/settings/application invocation.')
}
try {
    if (-not $ReportPath) { $ReportPath = Join-Path $owner.LocalRoot ('faultchecks-result-' + [guid]::NewGuid().ToString('N') + '.json') }
    $ReportPath = [IO.Path]::GetFullPath($ReportPath)
    if (-not [string]::Equals([IO.Path]::GetDirectoryName($ReportPath), $owner.LocalRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'ReportPath must be a fresh file directly beneath repository .wac-local.'
    }
    $reportStream = [IO.File]::Open($ReportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    foreach ($parameterName in @('ModuleRoot', 'ReportPath')) {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $report.command += ' -' + $parameterName + ' "' + [string]$PSBoundParameters[$parameterName] + '"'
        }
    }
    $childPath = Join-Path $owner.Root 'Invoke-SelectedPester.ps1'
    [IO.File]::WriteAllText($childPath, $childSource, (New-Object Text.UTF8Encoding($false)))
    $report.childHarnessSha256 = (Get-FileHash -LiteralPath $childPath -Algorithm SHA256).Hash
    foreach ($case in $cases) {
        $caseRecord = [ordered]@{
            id = $case.Id; acceptance = $case.Acceptance; defect = $case.Defect
            source = $case.Source; before = $case.Before; after = $case.After; testPath = $case.TestPath; filter = $case.Filter
            phases = New-Object 'System.Collections.Generic.List[object]'
        }
        $records.Add($caseRecord)
        foreach ($phase in @('baseline', 'mutant')) {
            $copyRoot = Join-Path $owner.Root ($case.Id + '-' + $phase)
            foreach ($relative in $sourcePaths) {
                $target = Join-Path $copyRoot $relative
                $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
                [IO.File]::Copy((Join-Path $repoRoot $relative), $target, $false)
            }
            $copyHashes = [ordered]@{}
            foreach ($relative in $sourcePaths) {
                $copyHashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $copyRoot $relative) -Algorithm SHA256).Hash
                if ($copyHashes[$relative] -ne $beforeHashes[$relative]) { throw ('Copied source changed before execution: ' + $relative) }
            }
            $mutationPath = Join-Path $copyRoot $case.Source
            if ($phase -eq 'mutant') {
                $source = [IO.File]::ReadAllText($mutationPath)
                $anchorCount = [regex]::Matches($source, [regex]::Escape($case.Before)).Count
                # The bad-exit assignment has a normal and a finally cleanup occurrence.
                $expectedMatches = if ($case.Id -eq 'bad-exit') { 2 } else { 1 }
                if ($anchorCount -ne $expectedMatches) { throw ('Mutation anchor count changed: ' + $case.Id + ' / ' + $anchorCount) }
                [IO.File]::WriteAllText($mutationPath, $source.Replace($case.Before, $case.After), (New-Object Text.UTF8Encoding($false)))
            }
            $testedHash = (Get-FileHash -LiteralPath $mutationPath -Algorithm SHA256).Hash
            $tempRoot = Join-Path $copyRoot 'temp'
            $null = [IO.Directory]::CreateDirectory($tempRoot)
            $resultPath = Join-Path $copyRoot 'result.json'
            $arguments = '-NoProfile -ExecutionPolicy Bypass -File ' + (ConvertTo-WacTestQuotedArgument $childPath) +
                ' -TestPath ' + (ConvertTo-WacTestQuotedArgument (Join-Path $copyRoot $case.TestPath)) +
                ' -Filter ' + (ConvertTo-WacTestQuotedArgument $case.Filter) +
                ' -OutputPath ' + (ConvertTo-WacTestQuotedArgument $resultPath) +
                ' -PesterManifest ' + (ConvertTo-WacTestQuotedArgument $pesterManifest) +
                ' -TempRoot ' + (ConvertTo-WacTestQuotedArgument $tempRoot)
            $process = Invoke-WacTestProcess -FilePath $hostExe -Arguments $arguments -WorkingDirectory $copyRoot -TimeoutMilliseconds 120000 -EnvironmentVariables @{ TEMP = $tempRoot; TMP = $tempRoot }
            if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw ('Selected Pester did not produce evidence: ' + $process.StandardError + $process.StandardOutput) }
            $summary = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $phaseRecord = [ordered]@{
                phase = $phase; exitCode = $process.ExitCode; result = $summary; testedSourceSha256 = $testedHash
                baselineCopyHashes = $copyHashes; selectedCommand = (ConvertTo-WacFaultSanitized -Value ($hostExe + ' ' + $arguments) -ScratchRoot $owner.Root)
                stdout = (ConvertTo-WacFaultSanitized -Value $process.StandardOutput -ScratchRoot $owner.Root)
                stderr = (ConvertTo-WacFaultSanitized -Value $process.StandardError -ScratchRoot $owner.Root)
            }
            $caseRecord.phases.Add($phaseRecord)
            foreach ($relative in $sourcePaths) {
                $expectedHash = if ($relative -eq $case.Source) { $testedHash } else { $copyHashes[$relative] }
                if ((Get-FileHash -LiteralPath (Join-Path $copyRoot $relative) -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Tested copied source changed during execution.' }
            }
            if ($summary.failedContainers -ne 0 -or $summary.failedBlocks -ne 0 -or $summary.skipped -ne 0 -or @($summary.tests).Count -ne 1) { throw 'Mutation failed for a fixture/container/selection reason.' }
            if ($phase -eq 'baseline') {
                if ($process.ExitCode -ne 0 -or $summary.passed -ne 1 -or $summary.failed -ne 0) { throw ('Baseline regression failed: ' + $case.Id) }
            }
            else {
                $failureText = @($summary.tests[0].errors) -join ' '
                if ($process.ExitCode -ne 1 -or $summary.failed -ne 1 -or $summary.passed -ne 0 -or $failureText -notlike $case.ExpectedFailure) { throw ('Relevant test did not detect the intended mutation: ' + $case.Id + ' / ' + $failureText) }
            }
            Write-Information -InformationAction Continue -MessageData ($case.Id + ' ' + $phase + ': exit ' + $process.ExitCode + ', passed ' + $summary.passed + ', failed ' + $summary.failed)
        }
    }
    $report.status = 'pass'
}
catch {
    $report.status = 'fail'
    $report.error = $_.ToString()
}
finally {
    try { $owner.RemoveTree(); $report.cleanup = 'passed: held identities removed; no path-recursive fallback' }
    catch { $report.status = 'fail'; $report.cleanup = 'refused/failed; scratch retained: ' + $_.ToString() }
    $report.sourceHashesAfter = Get-WacFaultHashes -Paths $evidencePaths
    $report.sourceUnchanged = (($report.sourceHashesAfter | ConvertTo-Json -Compress) -eq ($beforeHashes | ConvertTo-Json -Compress))
    if (-not $report.sourceUnchanged) { $report.status = 'fail' }
    $report.finishedUtc = [DateTime]::UtcNow.ToString('o')
    try {
        if ($reportStream) {
            $json = ConvertTo-WacFaultSanitized -Value ($report | ConvertTo-Json -Depth 20) -ScratchRoot $owner.Root
            $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
            $reportStream.Write($bytes, 0, $bytes.Length)
            $reportStream.Flush()
        }
    }
    finally {
        if ($reportStream) { $reportStream.Dispose() }
        $owner.Dispose()
    }
}
Write-Information -InformationAction Continue -MessageData ('Fault checks ' + $report.status + ': ' + $ReportPath)
if ($report.status -ne 'pass') { throw ('Fault checks failed; inspect the report. ' + $report.error + ' ' + $report.cleanup) }
