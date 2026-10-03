param([Parameter(Mandatory = $true)][string]$TestRepository,
    [Parameter(Mandatory = $true)][string]$ModuleRoot,
    [Parameter(Mandatory = $true)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $ModuleRoot 'Pester/5.7.1/Pester.psd1') -Force
$selectedFiles = @('WinAudioClean.ps1', 'WinAudioClean.IO.ps1', 'WinAudioClean.Preview.ps1',
    'tests/WinAudioClean.Preview.Tests.ps1', 'tests/WinAudioClean.PreviewReportClose.Tests.ps1',
    'tests/fixtures/ReportCloseFault.ps1')
$sourceHashes = @($selectedFiles | ForEach-Object {
    [ordered]@{ path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $TestRepository $_) -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$configuration = New-PesterConfiguration
$configuration.Run.Path = @((Join-Path $TestRepository 'tests/WinAudioClean.Preview.Tests.ps1'),
    (Join-Path $TestRepository 'tests/WinAudioClean.PreviewReportClose.Tests.ps1'))
$configuration.Filter.Tag = @('ReportCloseFault')
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $configuration
$changed = @($sourceHashes | Where-Object {
    $_.sha256 -cne (Get-FileHash -LiteralPath (Join-Path $TestRepository $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()
})
$record = [ordered]@{
    schemaVersion = 1; scope = 'Preview post-dispose release advisory; held FileStream closes before injected fault'
    psVersion = $PSVersionTable.PSVersion.ToString(); psEdition = $PSVersionTable.PSEdition
    pesterVersion = (Get-Module Pester).Version.ToString(); tag = 'ReportCloseFault'
    passed = $result.PassedCount; failed = $result.FailedCount; skipped = $result.SkippedCount
    notRun = $result.NotRunCount; total = $result.TotalCount; sourceStable = ($changed.Count -eq 0)
    sourceHashes = $sourceHashes; cases = @($result.Tests | Where-Object Executed | ForEach-Object {
        [ordered]@{ name = $_.ExpandedName; result = $_.Result; error = @(($_.ErrorRecord | ForEach-Object { $_.Exception.Message })) }
    })
}
$json = $record | ConvertTo-Json -Depth 10
$json = $json.Replace($TestRepository, '<TEST_REPOSITORY>').Replace($env:USERPROFILE, '<USERPROFILE>')
[IO.File]::WriteAllText($OutputPath, $json + "`r`n", [Text.UTF8Encoding]::new($false))
if ($result.FailedCount -gt 0 -or $result.PassedCount -eq 0 -or $changed.Count -gt 0) { exit 1 }
exit 0
