param([Parameter(Mandatory = $true)][string]$ScriptPath)

$ErrorActionPreference = 'Stop'
$script:sideEffects = 0
$blockedCommands = @(
    'Read-Host', 'Write-Host', 'Clear-Host', 'Start-Process', 'ffmpeg', 'ffmpeg.exe',
    'Add-Content', 'Set-Content', 'Out-File', 'New-Item', 'Remove-Item', 'Copy-Item',
    'Move-Item', 'Write-Output', 'Write-Error', 'Write-Warning', 'Write-Information',
    'Write-Verbose', 'Write-Debug', 'Write-Progress'
)
foreach ($command in $blockedCommands) {
    Set-Item -Path "Function:$command" -Value {
        $script:sideEffects++
        throw 'An import attempted a blocked prompt, console, process or write command.'
    }
}

$importOutput = @(. $ScriptPath *>&1)
if ($script:sideEffects -ne 0 -or $importOutput.Count -ne 0) {
    throw 'Import produced a side effect or pipeline output.'
}
foreach ($helper in @('Get-WacProcessingProfile', 'Get-WacOutputPath', 'Get-WacFfmpegArguments')) {
    $null = Get-Command -Name $helper -CommandType Function -ErrorAction Stop
}
# Reaching this sentinel proves dot-sourcing did not exit the fresh test host.
[Console]::WriteLine('WAC_IMPORT_COMPLETED')
