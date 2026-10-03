param([switch]$Worker)

# The batch file supplies numbered environment values, never a path-bearing
# PowerShell command. Importing this sibling defines transport helpers only.
function Resolve-WacLauncherFileSystemPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '^[\\/]{2}' -or
        $Path -match '^[a-zA-Z][a-zA-Z0-9+.-]*://' -or $Path.Contains('::')) {
        throw 'Launcher paths must be ordinary local filesystem paths.'
    }
    $provider = $null; $drive = $null
    try { $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive) }
    catch { throw 'Cannot resolve the launcher filesystem path.' }
    if ($provider.Name -ne 'FileSystem' -or $resolved -notmatch '^[a-zA-Z]:[\\/]' -or
        $resolved.Substring(2) -match '[:*?"<>|\x00-\x1f]') {
        throw 'Launcher paths must use an ordinary Windows drive path.'
    }
    $resolved
}

function ConvertFrom-WacLauncherCommandTokens {
    param([Parameter(Mandatory = $true)][string]$Text)
    $tokens = [Collections.Generic.List[string]]::new()
    $position = 0
    while ($position -lt $Text.Length) {
        while ($position -lt $Text.Length -and $Text[$position] -in @(' ', "`t")) { $position++ }
        if ($position -eq $Text.Length) { break }
        if ($Text[$position] -eq '"') {
            $position++; $start = $position
            while ($position -lt $Text.Length -and $Text[$position] -ne '"') { $position++ }
            if ($position -eq $Text.Length) { throw 'Unbalanced launcher command quotes. Use the manifest/environment route.' }
            $token = $Text.Substring($start, $position - $start); $position++
            if ($position -lt $Text.Length -and $Text[$position] -notin @(' ', "`t")) {
                throw 'Ambiguous launcher command quoting. Use the manifest/environment route.'
            }
        } else {
            $start = $position
            while ($position -lt $Text.Length -and $Text[$position] -notin @(' ', "`t")) { $position++ }
            $token = $Text.Substring($start, $position - $start)
            if ($token -match '["&|<>^();,=\x00-\x1f]') {
                throw 'Quote launcher paths containing shell punctuation, or use the manifest/environment route.'
            }
        }
        if ($token -match '["\x00-\x1f]') { throw 'Unsupported characters in the launcher command.' }
        $tokens.Add($token)
    }
    # A single returned array remains an array on Windows PowerShell 5.1.
    ,$tokens.ToArray()
}

function Assert-WacLauncherCommandFrame {
    param([string[]]$Arguments, [string]$CommandLine, [string]$LauncherPath)
    if ([string]::IsNullOrWhiteSpace($CommandLine) -or $CommandLine -eq '__WAC_CAPTURE_FAILED__') {
        throw 'The original CMD invocation could not be captured. Use the manifest/environment route.'
    }
    if ($CommandLine.Length -ge 7600) {
        throw 'Launcher command exceeds the safe 7600-character budget. Use a short manifest path through WAC_LAUNCH_INPUT_LIST_PATH.'
    }
    if ($CommandLine.IndexOfAny([char[]]@(37, 33)) -ge 0 -or
        @($Arguments | Where-Object { $_ -and $_.IndexOfAny([char[]]@(37, 33)) -ge 0 }).Count -gt 0) {
        throw 'CMD can change percent or exclamation characters before the launcher runs. Use the literal environment/manifest route or direct PowerShell.'
    }
    # CMD parsing is not CommandLineToArgvW/CRT parsing. Accept only the narrow
    # fresh /c framing whose original tokens agree with every captured argument.
    $header = [regex]::Match($CommandLine, '^\s*(?:"([^"]+)"|([^\s"]+))\s+')
    if (-not $header.Success) { throw 'Cannot verify the CMD invocation. Use the manifest/environment route.' }
    $program = if ($header.Groups[1].Success) { $header.Groups[1].Value } else { $header.Groups[2].Value }
    if ([IO.Path]::GetFileName($program) -ine 'cmd.exe') { throw 'Cannot verify the CMD invocation. Use the manifest/environment route.' }
    $remaining = $CommandLine.Substring($header.Length).TrimStart()
    $command = $null
    while ($remaining) {
        $option = [regex]::Match($remaining, '^(/[^\s]+)(?:\s+|$)')
        if (-not $option.Success) { break }
        $name = $option.Groups[1].Value.ToLowerInvariant()
        $remaining = $remaining.Substring($option.Length).TrimStart()
        if ($name -eq '/c') { $command = $remaining; break }
        if ($name -notin @('/d', '/s', '/q', '/a', '/u', '/v:on', '/v:off', '/e:on', '/e:off')) { break }
    }
    if ([string]::IsNullOrWhiteSpace($command)) {
        throw 'An existing or nested CMD session cannot verify dropped arguments. Use the manifest/environment route or direct PowerShell.'
    }
    $command = $command.Trim()
    if ($command.StartsWith('""') -and $command.EndsWith('"')) { $command = $command.Substring(1, $command.Length - 2) }
    $tokens = ConvertFrom-WacLauncherCommandTokens -Text $command
    if ($tokens.Count -ne $Arguments.Count + 1) { throw 'Launcher argument count changed at the CMD boundary. Use the manifest/environment route.' }
    $expected = Resolve-WacLauncherFileSystemPath -Path $LauncherPath
    $actual = Resolve-WacLauncherFileSystemPath -Path $tokens[0]
    if ($actual -ine $expected) { throw 'The original command does not identify this launcher. Use the manifest/environment route.' }
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        if ($tokens[$index + 1] -cne $Arguments[$index]) {
            throw 'Launcher arguments changed at the CMD boundary. Use the manifest/environment route.'
        }
    }
}

function Get-WacLauncherRequest {
    param([string[]]$Arguments = @(), [string]$CommandLine, [string]$LauncherPath,
        [string]$InputListPath, [string]$InputPath, [string]$OutputDirectory, [string]$SettingsPath,
        [bool]$IgnoreSavedSettings = $false, [bool]$CaptureOverflow = $false)
    if ($null -eq $Arguments -or $CaptureOverflow -or $Arguments.Count -gt 1024) {
        throw 'Launcher accepts at most 1024 inputs. Use an explicit bounded input manifest.'
    }
    $unattended = $Arguments.Count -gt 0 -and $Arguments[0] -ieq '/unattended'
    $manifest = $Arguments.Count -gt 0 -and $Arguments[0] -ieq '/manifest'
    # Environment routes have no input paths in CMD text and work from an
    # existing shell too. Strict control tokens never repair expanded data.
    if ($unattended) {
        if ($Arguments.Count -ne 2 -or $Arguments[1] -notin @('Raw', 'Zoom') -or
            [string]::IsNullOrWhiteSpace($OutputDirectory)) {
            throw 'Usage: set WAC_LAUNCH_INPUT or WAC_LAUNCH_INPUT_LIST_PATH and WAC_LAUNCH_OUTPUT_DIRECTORY from PowerShell, then run WinAudioClean.bat /unattended Raw or Zoom.'
        }
        $hasInput = -not [string]::IsNullOrWhiteSpace($InputPath)
        $hasList = -not [string]::IsNullOrWhiteSpace($InputListPath)
        if ($hasInput -eq $hasList) { throw 'Unattended launch requires exactly one of WAC_LAUNCH_INPUT and WAC_LAUNCH_INPUT_LIST_PATH.' }
    } elseif ($manifest) {
        if ($Arguments.Count -ne 1 -or [string]::IsNullOrWhiteSpace($InputListPath) -or
            -not [string]::IsNullOrWhiteSpace($InputPath)) {
            throw 'Usage: set only WAC_LAUNCH_INPUT_LIST_PATH from PowerShell, then run WinAudioClean.bat /manifest.'
        }
    } else {
        Assert-WacLauncherCommandFrame -Arguments $Arguments -CommandLine $CommandLine -LauncherPath $LauncherPath
        if ($Arguments.Count -eq 0) {
            throw 'Drop one or more audio files onto WinAudioClean.bat. For many/long/special paths, set WAC_LAUNCH_INPUT_LIST_PATH from PowerShell and use /manifest.'
        }
        foreach ($argument in $Arguments) {
            if ([string]::IsNullOrWhiteSpace($argument) -or $argument -match '["\x00-\x1f]') {
                throw 'Launcher inputs must be nonempty literal file paths.'
            }
        }
    }
    $mode = if ($unattended) { if ($Arguments[1] -ieq 'Raw') { 'Raw' } else { 'Zoom' } } else { $null }
    $inputs = [string[]]@(
        if ($unattended -and -not [string]::IsNullOrWhiteSpace($InputPath)) { $InputPath }
        elseif (-not $unattended -and -not $manifest) { $Arguments }
    )
    $list = if (($unattended -or $manifest) -and -not [string]::IsNullOrWhiteSpace($InputListPath)) { $InputListPath } else { $null }
    [pscustomobject]@{
        Route = $(if ($unattended) { 'Unattended' } elseif ($manifest) { 'Manifest' } else { 'Positional' })
        InputPaths = $inputs; InputListPath = $list; Mode = $mode
        OutputDirectory = $(if (($unattended -or $manifest) -and -not [string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory } else { $null })
        SettingsPath = $(if (-not [string]::IsNullOrWhiteSpace($SettingsPath)) { $SettingsPath } else { $null })
        IgnoreSavedSettings = $IgnoreSavedSettings; NonInteractive = $unattended; Pause = (-not $unattended)
        Transport = $(if ($list) { 'manifest_environment' } elseif ($unattended) { 'single_environment' } else { 'positional_environment' })
    }
}

function Get-WacLauncherPowerShellPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = [IO.Path]::Combine($env:SystemRoot, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe') }
    if ($Path -notmatch '^[a-zA-Z]:[\\/]') { throw 'WAC_LAUNCH_POWERSHELL must be an absolute local executable path.' }
    $resolved = Resolve-WacLauncherFileSystemPath -Path $Path
    if ([IO.Path]::GetExtension($resolved) -ine '.exe' -or -not [IO.File]::Exists($resolved)) {
        throw 'WAC_LAUNCH_POWERSHELL must identify an existing local PowerShell executable.'
    }
    $resolved
}

function Invoke-WacLauncherApplication {
    param([Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][hashtable]$Parameters)
    # Application stdout remains console output rather than part of the result.
    & $ScriptPath @Parameters | Out-Host
    [int]$LASTEXITCODE
}

function Invoke-WacLauncherRequest {
    param([Parameter(Mandatory = $true)]$Request, [Parameter(Mandatory = $true)][string]$ScriptPath)
    $parameters = @{}
    if ($Request.InputListPath) { $parameters.InputListPath = $Request.InputListPath }
    elseif ($Request.InputPaths.Count -eq 1) { $parameters.inputPath = $Request.InputPaths[0] }
    else { $parameters.InputPaths = [string[]]$Request.InputPaths }
    if ($Request.Mode) { $parameters.Mode = $Request.Mode }
    if ($Request.OutputDirectory) { $parameters.OutputDirectory = $Request.OutputDirectory }
    if ($Request.SettingsPath) { $parameters.SettingsPath = $Request.SettingsPath }
    if ($Request.IgnoreSavedSettings) { $parameters.IgnoreSavedSettings = $true }
    if ($Request.NonInteractive) { $parameters.NonInteractive = $true }
    Invoke-WacLauncherApplication -ScriptPath $ScriptPath -Parameters $parameters
}

function Invoke-WacLauncherWorker {
    param([Parameter(Mandatory = $true)][string]$PowerShellPath)
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $PowerShellPath
    # This command is fixed; every path and list remains inherited environment data.
    $code = "& `$env:WAC_LAUNCH_HELPER -Worker; exit `$LASTEXITCODE"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    $info.Arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -EncodedCommand ' + $encoded
    $info.UseShellExecute = $false
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $info
    try {
        try { $started = $process.Start() } catch { throw 'Selected PowerShell worker could not start.' }
        if (-not $started) { throw 'Selected PowerShell worker could not start.' }
        $process.WaitForExit()
        [int]$process.ExitCode
    } finally { $process.Dispose() }
}

if ($MyInvocation.InvocationName -eq '.') { return }
$ErrorActionPreference = 'Stop'
$launcherExit = 2; $pauseAfter = $true
try {
    $count = 0
    if ($env:WAC_LAUNCH_COUNT -notmatch '^[0-9]+$' -or
        -not [int]::TryParse($env:WAC_LAUNCH_COUNT, [ref]$count) -or $count -gt 1024) {
        throw 'Launcher argument capture failed or exceeded 1024 inputs. Use a short manifest/environment route.'
    }
    $captured = [string[]]@()
    for ($index = 1; $index -le $count; $index++) {
        $captured += [Environment]::GetEnvironmentVariable(('WAC_LAUNCH_ITEM_' + $index), 'Process')
    }
    $pauseAfter = -not ($captured.Count -gt 0 -and $captured[0] -ieq '/unattended')
    if ([string]::IsNullOrWhiteSpace($env:WAC_LAUNCH_COMMAND_LINE) -or
        $env:WAC_LAUNCH_COMMAND_LINE -eq '__WAC_CAPTURE_FAILED__' -or $env:WAC_LAUNCH_COMMAND_LINE.Length -ge 7600) {
        throw 'Original CMD capture failed or exceeded the safe 7600-character budget. Use a short manifest/environment route.'
    }
    if ($env:WAC_LAUNCH_IGNORE_SAVED_SETTINGS -and $env:WAC_LAUNCH_IGNORE_SAVED_SETTINGS -ne '1') {
        throw 'WAC_LAUNCH_IGNORE_SAVED_SETTINGS must be unset or 1.'
    }
    $request = Get-WacLauncherRequest -Arguments $captured -CommandLine $env:WAC_LAUNCH_COMMAND_LINE -LauncherPath $env:WAC_LAUNCH_BAT `
        -InputListPath $env:WAC_LAUNCH_INPUT_LIST_PATH -InputPath $env:WAC_LAUNCH_INPUT -OutputDirectory $env:WAC_LAUNCH_OUTPUT_DIRECTORY `
        -SettingsPath $env:WAC_LAUNCH_SETTINGS_PATH -IgnoreSavedSettings ($env:WAC_LAUNCH_IGNORE_SAVED_SETTINGS -eq '1')
    $pauseAfter = $request.Pause
    $shellPath = Get-WacLauncherPowerShellPath -Path $env:WAC_LAUNCH_POWERSHELL
    $currentProcess = [Diagnostics.Process]::GetCurrentProcess()
    try { $currentPath = $currentProcess.MainModule.FileName } finally { $currentProcess.Dispose() }
    if (-not $Worker -and $shellPath -ine $currentPath) {
        try {
            $launcherExit = Invoke-WacLauncherWorker -PowerShellPath $shellPath
            # The started worker owns any interactive pause; a start failure does not.
            $pauseAfter = $false
        }
        catch { Write-Error -Message $_.Exception.Message -ErrorAction Continue; $launcherExit = 3 }
    } else { $launcherExit = Invoke-WacLauncherRequest -Request $request -ScriptPath $env:WAC_LAUNCH_SCRIPT }
} catch { Write-Error -Message $_.Exception.Message -ErrorAction Continue; $launcherExit = 2 }
if ($pauseAfter) {
    & ([IO.Path]::Combine($env:SystemRoot, 'System32', 'cmd.exe')) /d /c pause | Out-Host
}
exit $launcherExit
