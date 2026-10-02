#requires -Version 5.1
<#
.SYNOPSIS
Runs local development checks without downloading or installing dependencies.
.PARAMETER Level
Quick runs parser/analyzer checks, plan validation and the small unit/import suite.
Targeted runs the same checks plus explicitly selected Pester paths and/or tags.
Full runs those checks, every Pester test and the Python governance helper suite.
.PARAMETER Path
One or more test files or folders, relative to the repository root or absolute.
Only accepted with Targeted. Wildcards are not expanded by this runner.
.PARAMETER Tag
Pester tags to select. Only accepted with Targeted.
.PARAMETER ModuleRoot
Optional folder holding the pinned modules, useful for an isolated test worktree.
.PARAMETER PythonPath
Python executable for development-only governance checks. Defaults to python.
.PARAMETER AnalyzerWarnings
Print every non-gating analyzer warning/information finding for inspection.
#>
[CmdletBinding()]
param(
    [ValidateSet('Quick', 'Targeted', 'Full')]
    [string]$Level = 'Quick',
    [string[]]$Path,
    [string[]]$Tag,
    [string]$ModuleRoot,
    [string]$PythonPath = 'python',
    [switch]$AnalyzerWarnings
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ($Level -eq 'Targeted' -and -not $Path -and -not $Tag) {
    throw 'Targeted requires an explicit -Path and/or -Tag filter.'
}
if ($Level -ne 'Targeted' -and ($Path -or $Tag)) {
    throw '-Path and -Tag are only accepted with -Level Targeted; Quick and Full have fixed scope.'
}
foreach ($value in @($Path) + @($Tag)) {
    if ($null -ne $value -and [string]::IsNullOrWhiteSpace($value)) { throw 'Path/tag filters cannot be empty.' }
}
if (-not $ModuleRoot) { $ModuleRoot = Join-Path $repoRoot '.wac-local/Modules' }
$dependencies = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'DevDependencies.psd1')
foreach ($dependency in $dependencies.Modules) {
    $manifestPath = Join-Path (Join-Path (Join-Path $ModuleRoot $dependency.Name) $dependency.Version) ($dependency.Name + '.psd1')
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Missing $($dependency.Name) $($dependency.Version). Explicitly run scripts/Install-DevDependencies.ps1 first."
    }
    $loaded = Get-Module -Name $dependency.Name
    if ($loaded -and @($loaded | Where-Object { $_.Version -ne [version]$dependency.Version }).Count -gt 0) {
        throw "A different $($dependency.Name) version is already loaded. Use a fresh -NoProfile PowerShell process."
    }
    $module = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    if ($module.Version -ne [version]$dependency.Version -or $module.Name -ne $dependency.Name) {
        throw "Unexpected module manifest: $manifestPath"
    }
    Import-Module -Name $manifestPath -Force -ErrorAction Stop
    Write-Information -InformationAction Continue -MessageData "Development module: $($dependency.Name) $($dependency.Version)"
}
$python = Get-Command -Name $PythonPath -CommandType Application -ErrorAction Stop | Select-Object -First 1
$testRoot = Join-Path $repoRoot 'tests'
$testPaths = @($testRoot)
if ($Path) {
    $testPaths = @(foreach ($testPath in $Path) {
        if ([IO.Path]::IsPathRooted($testPath)) { $candidate = $testPath }
        else { $candidate = Join-Path $repoRoot $testPath }
        if (-not (Test-Path -LiteralPath $candidate)) { throw "Test path does not exist: $testPath" }
        (Get-Item -LiteralPath $candidate).FullName
    })
}

# Scan only maintained PowerShell source; downloaded modules and generated fixtures stay outside scope.
$sourceFiles = @(Get-ChildItem -LiteralPath $repoRoot -File | Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' })
foreach ($folder in @('scripts', 'tests')) {
    $sourceFiles += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot $folder) -Recurse -File |
        Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' })
}
$sourceFiles = @($sourceFiles | Sort-Object FullName -Unique)
foreach ($file in $sourceFiles) {
    $parseTokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$parseTokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        $parseErrors | ForEach-Object { Write-Information -InformationAction Continue -MessageData "$($file.Name):$($_.Extent.StartLineNumber): $($_.Message)" }
        throw "PowerShell parse failed: $($file.Name)"
    }
}
Write-Information -InformationAction Continue -MessageData "PowerShell parser passed ($($sourceFiles.Count) files; shell $($PSVersionTable.PSVersion))."

# All Error findings gate, as do these concrete safety rules at any severity.
# Other defaults remain enabled and visible via -AnalyzerWarnings; no suppression attributes/baseline.
$safetyRules = @(
    'PSUseCompatibleSyntax',
    'PSAvoidUsingInvokeExpression',
    'PSAvoidUsingEmptyCatchBlock',
    'PSAvoidUsingPlainTextForPassword',
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    'PSAvoidUsingUsernameAndPasswordParams',
    'PSAvoidUsingBrokenHashAlgorithms'
)
$findings = @(foreach ($file in $sourceFiles) {
    Invoke-ScriptAnalyzer -Path $file.FullName -Settings (Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1')
})
$gatingFindings = @($findings | Where-Object { $_.Severity -eq 'Error' -or $_.RuleName -in $safetyRules })
if ($gatingFindings.Count -gt 0) {
    $gatingFindings | Format-Table ScriptName, Line, RuleName, Message -Wrap | Out-Host
    throw "PSScriptAnalyzer found $($gatingFindings.Count) gating issue(s)."
}
if ($AnalyzerWarnings -and $findings.Count -gt 0) {
    $findings | Format-Table ScriptName, Line, RuleName, Message -Wrap | Out-Host
}
Write-Information -InformationAction Continue -MessageData "Static gate passed; $($findings.Count) non-gating analyzer finding(s). Use -AnalyzerWarnings to inspect."

$planRoot = Join-Path $repoRoot 'docs/codex/winaudioclean'
& $python.Source (Join-Path $planRoot 'tools/handoff.py') validate-plan --plan-root $planRoot
if ($LASTEXITCODE -ne 0) { throw "Plan validation failed (exit $LASTEXITCODE)." }

$configuration = New-PesterConfiguration
$configuration.Run.Path = $testPaths
$configuration.Run.PassThru = $true
$configuration.Run.Exit = $false
$configuration.Output.Verbosity = 'Detailed'
if ($Level -eq 'Quick') { $configuration.Filter.Tag = @('Quick', 'Unit', 'Import') }
elseif ($Tag) { $configuration.Filter.Tag = $Tag }
$result = Invoke-Pester -Configuration $configuration
if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0 -or $result.FailedBlocksCount -gt 0) {
    throw "Pester failed: $($result.FailedCount) test(s), $($result.FailedContainersCount) container(s), $($result.FailedBlocksCount) block(s)."
}
if (($result.PassedCount + $result.SkippedCount + $result.InconclusiveCount) -eq 0) {
    throw 'No tests matched the selected scope.'
}
if ($result.PassedCount -eq 0) { throw 'The selected scope ran no passing tests; all were skipped or inconclusive.' }

if ($Level -eq 'Full') {
    & $python.Source -m unittest discover -s (Join-Path $planRoot 'tests') -v
    if ($LASTEXITCODE -ne 0) { throw "Governance helper tests failed (exit $LASTEXITCODE)." }
}
Write-Information -InformationAction Continue -MessageData "$Level passed: $($result.PassedCount) Pester passed, $($result.SkippedCount) skipped, $($result.NotRunCount) outside scope."
