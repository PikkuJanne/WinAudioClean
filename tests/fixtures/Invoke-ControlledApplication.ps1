param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][ValidateSet('1', '2')][string]$Choice,
    [int]$ProcessExitCode = 0
)

# Test doubles exercise processing/report wiring after real filesystem preflight.
# Only disposable synthetic input and a destination are created; no audio runs.
$ErrorActionPreference = 'Stop'
$wacFixtureState = [pscustomobject]@{
    Choice = $Choice
    ProcessExitCode = $ProcessExitCode
    ProcessCalls = @()
    LogCalls = @()
    HostMessages = @()
}
function Clear-Host { }
function Read-Host { throw 'Unattended application unexpectedly prompted.' }
function Write-Host {
    param($Object, $ForegroundColor, [switch]$NoNewline)
    $wacFixtureState.HostMessages += [string]$Object
}
function Test-Path {
    param($LiteralPath, $PathType)
    if ([System.IO.Path]::GetFileName($LiteralPath) -eq 'ffmpeg.exe') { return $true }
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function Get-Date {
    param($Format)
    if ($Format -eq 'yyyyMMdd-HHmm') { return '20261002-1200' }
    if ($Format -eq 'yyyy-MM-dd HH:mm:ss') { return '2026-10-02 12:00:00' }
    throw 'Unexpected date format in controlled execution.'
}
function Start-Process {
    param($FilePath, $ArgumentList, [switch]$Wait, [switch]$NoNewWindow, [switch]$PassThru)
    $wacFixtureState.ProcessCalls += [pscustomobject]@{
        FileName = [System.IO.Path]::GetFileName($FilePath)
        Arguments = $ArgumentList
        Wait = [bool]$Wait
        NoNewWindow = [bool]$NoNewWindow
        PassThru = [bool]$PassThru
    }
    [pscustomobject]@{ ExitCode = $wacFixtureState.ProcessExitCode }
}
function Add-Content {
    param($LiteralPath, $Value)
    $wacFixtureState.LogCalls += [pscustomobject]@{
        FileName = [System.IO.Path]::GetFileName($LiteralPath)
        Value = $Value
    }
}
function Set-Content { throw 'Unexpected file write in controlled execution.' }
function Out-File { throw 'Unexpected file write in controlled execution.' }
function New-Item { throw 'Unexpected file write in controlled execution.' }
function Remove-Item { throw 'Unexpected file removal in controlled execution.' }
function ffmpeg { throw 'Unexpected direct FFmpeg invocation.' }
function ffmpeg.exe { throw 'Unexpected direct FFmpeg invocation.' }

$scratch = (Get-Location).ProviderPath
$inputFile = [System.IO.Path]::Combine($scratch, 'meeting sample.wav')
$outputDirectory = [System.IO.Path]::Combine($scratch, 'output [literal]')
[System.IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
try {
    $mode = if ($Choice -eq '1') { 'Raw' } else { 'Zoom' }
    & $ScriptPath -inputPath $inputFile -Mode $mode -OutputDirectory $outputDirectory -NonInteractive
} finally {
    [System.IO.File]::Delete($inputFile)
    if ([System.IO.Directory]::Exists($outputDirectory)) { [System.IO.Directory]::Delete($outputDirectory) }
}

# Redact temporary paths before child output or test diagnostics.
$result = [pscustomobject]@{
    Processes = $wacFixtureState.ProcessCalls
    Logs = $wacFixtureState.LogCalls
    HostMessages = $wacFixtureState.HostMessages
}
$json = $result | ConvertTo-Json -Depth 5 -Compress
$encodedOutput = ($outputDirectory | ConvertTo-Json -Compress).Trim('"')
$encodedScratch = ($scratch | ConvertTo-Json -Compress).Trim('"')
$json = $json.Replace($encodedOutput, 'C:\\WAC synthetic output').Replace($encodedScratch, 'C:\\WAC synthetic input')
[Console]::WriteLine($json)
