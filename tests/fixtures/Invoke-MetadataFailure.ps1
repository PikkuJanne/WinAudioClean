param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [ValidateSet('Continue', 'Stop')][string]$CallerErrorPreference = 'Continue'
)

# Exercise the real application with one reporting read made unavailable. Input
# preflight, dependency resolution, the child process and log writes stay real.
function Get-Item {
    [CmdletBinding()]
    param([string]$LiteralPath, [switch]$Force)

    if (-not $Force -and [IO.Path]::GetExtension($LiteralPath) -eq '.wav' -and
        [IO.Path]::GetDirectoryName($LiteralPath) -eq $OutputDirectory) {
        throw 'simulated metadata access failure'
    }
    Microsoft.PowerShell.Management\Get-Item @PSBoundParameters
}

$ErrorActionPreference = $CallerErrorPreference
& $ScriptPath -inputPath $InputPath -OutputDirectory $OutputDirectory -Mode Zoom -NonInteractive
exit $LASTEXITCODE
