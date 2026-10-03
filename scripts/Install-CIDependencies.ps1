#requires -Version 5.1
<#
.SYNOPSIS
Explicitly downloads checksum-pinned portable CI tools into this checkout.
.DESCRIPTION
Development setup only. Uses no global installation, profile or security-policy
changes. Each invocation allocates a new ignored directory; previous tools and
failed downloads remain available for inspection. No recursive cleanup occurs.
.PARAMETER GitHubActions
Exports tool paths to this job's runner environment and PATH files.
#>
[CmdletBinding()]
param([switch]$GitHubActions)

function Install-WacCITool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Tool,
        [Parameter(Mandatory = $true)][string]$ToolRoot
    )
    if ($Tool.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        $Tool.executable -notin @('python.exe', 'pwsh.exe')) {
        throw 'Invalid pinned CI tool manifest.'
    }
    $uri = [uri]$Tool.uri
    if ($uri.Scheme -cne 'https' -or $uri.Host -notin @('www.python.org', 'github.com')) {
        throw 'CI tools require an official HTTPS download.'
    }
    $root = [IO.Path]::GetFullPath($ToolRoot)
    $stage = [IO.Path]::GetFullPath((Join-Path $root ([guid]::NewGuid().ToString('N'))))
    if (-not $stage.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'CI tool directory escaped its explicit root.'
    }
    $null = New-Item -ItemType Directory -Path $stage -ErrorAction Stop
    $archive = Join-Path $stage 'download.zip'
    $destination = Join-Path $stage 'tool'
    $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri $uri.AbsoluteUri -OutFile $archive -ErrorAction Stop
        $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($actual -cne $Tool.sha256) { throw 'CI tool SHA256 mismatch; archive was not extracted or executed.' }
        Expand-Archive -LiteralPath $archive -DestinationPath $destination -ErrorAction Stop
        $executable = Join-Path $destination $Tool.executable
        if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Pinned tool archive has no expected executable.' }
        return $executable
    }
    finally { [Net.ServicePointManager]::SecurityProtocol = $previousProtocol }
}

if ($MyInvocation.InvocationName -eq '.') { return }
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $repoRoot '.wac-local/ci/tools'
$lock = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'CIDependencies.json') | ConvertFrom-Json
if ($lock.schema_version -ne 1) { throw 'Unsupported CI dependency schema.' }
if ($GitHubActions -and ($env:GITHUB_ACTIONS -cne 'true' -or -not $env:GITHUB_ENV -or -not $env:GITHUB_PATH)) {
    throw '-GitHubActions requires a runner job environment.'
}
$null = New-Item -ItemType Directory -Path $toolRoot -Force
$pythonPath = Install-WacCITool -Tool $lock.python -ToolRoot $toolRoot
$powershellPath = Install-WacCITool -Tool $lock.powershell -ToolRoot $toolRoot
# Embeddable Python keeps its upstream isolated _pth file and stdlib-only policy.
if ($GitHubActions) {
    $encoding = [Text.UTF8Encoding]::new($false)
    [IO.File]::AppendAllText($env:GITHUB_ENV, "WAC_CI_PYTHON=$pythonPath`nWAC_CI_PS7=$powershellPath`n", $encoding)
    [IO.File]::AppendAllText($env:GITHUB_PATH, ([IO.Path]::GetDirectoryName($pythonPath) + "`n" + [IO.Path]::GetDirectoryName($powershellPath) + "`n"), $encoding)
}
[pscustomobject]@{ Python = $pythonPath; PowerShell = $powershellPath }
