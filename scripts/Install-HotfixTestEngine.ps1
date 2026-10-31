#requires -Version 5.1
<#
.SYNOPSIS
Downloads the pinned trusted FFmpeg pair for explicit development/CI testing.
.DESCRIPTION
Never invoked by the application. Verifies the manifest's SHA256 before
extracting; does not change PATH, user/machine settings, or installed software.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$lock = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'CIDependencies.json') | ConvertFrom-Json
$tool = $lock.ffmpeg
if ($tool.uri -cne 'https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-9.0.2-essentials_build.zip' -or
    $tool.sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid trusted hotfix engine manifest.' }
$stage = Join-Path $repoRoot ('.wac-local/hotfix-engine-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $stage -ErrorAction Stop
$archive = Join-Path $stage 'engine.zip'
$previousProtocol = [Net.ServicePointManager]::SecurityProtocol
try {
    [Net.ServicePointManager]::SecurityProtocol = $previousProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $tool.uri -OutFile $archive -ErrorAction Stop
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $tool.sha256) { throw 'Trusted hotfix engine checksum mismatch; nothing was extracted or executed.' }
    Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $stage 'engine') -ErrorAction Stop
    $bin = Join-Path $stage 'engine/ffmpeg-9.0.2-essentials_build/bin'
    $ffmpeg = Join-Path $bin 'ffmpeg.exe'
    $ffprobe = Join-Path $bin 'ffprobe.exe'
    if (-not [IO.File]::Exists($ffmpeg) -or -not [IO.File]::Exists($ffprobe)) { throw 'Trusted archive has no expected engine pair.' }
    [pscustomobject]@{ Ffmpeg = $ffmpeg; Ffprobe = $ffprobe }
} finally { [Net.ServicePointManager]::SecurityProtocol = $previousProtocol }
