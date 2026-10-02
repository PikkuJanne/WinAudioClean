param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][ValidateSet('1', '2')][string]$Choice,
    [int]$ProcessExitCode = 0
)

# Test doubles exercise script execution while preventing native processing and
# file writes. The synthetic input never has to exist; no recording is needed.
$ErrorActionPreference = 'Stop'
$wacFixtureState = [pscustomobject]@{
    Choice = $Choice
    ProcessExitCode = $ProcessExitCode
    ProcessCalls = @()
    LogCalls = @()
    HostMessages = @()
}
function Clear-Host { }
function Read-Host { param($Prompt) $wacFixtureState.Choice }
function Write-Host {
    param($Object, $ForegroundColor, [switch]$NoNewline)
    $wacFixtureState.HostMessages += [string]$Object
}
function Test-Path { param($Path) $true }
function Get-Item { param($Path) [pscustomobject]@{ Length = 2097152 } }
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
    param($Path, $Value)
    $wacFixtureState.LogCalls += [pscustomobject]@{
        FileName = [System.IO.Path]::GetFileName($Path)
        Value = $Value
    }
}
function Set-Content { throw 'Unexpected file write in controlled execution.' }
function Out-File { throw 'Unexpected file write in controlled execution.' }
function New-Item { throw 'Unexpected file write in controlled execution.' }
function Remove-Item { throw 'Unexpected file removal in controlled execution.' }
function ffmpeg { throw 'Unexpected direct FFmpeg invocation.' }
function ffmpeg.exe { throw 'Unexpected direct FFmpeg invocation.' }

& $ScriptPath -inputPath 'C:\WAC synthetic input\meeting sample.wav'

# Redact the real Music directory before any child output or test diagnostics.
$musicFolder = [Environment]::GetFolderPath('MyMusic')
$result = [pscustomobject]@{
    Processes = $wacFixtureState.ProcessCalls
    Logs = $wacFixtureState.LogCalls
    HostMessages = $wacFixtureState.HostMessages
}
$json = $result | ConvertTo-Json -Depth 5 -Compress
if ($musicFolder) {
    # JSON escaping doubles backslashes; redact after serialization as well.
    $encodedMusic = ($musicFolder | ConvertTo-Json -Compress).Trim('"')
    $json = $json.Replace($encodedMusic, 'C:\\WAC synthetic output')
}
[Console]::WriteLine($json)
