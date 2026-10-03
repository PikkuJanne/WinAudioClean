# Test-only private-console fixture. It uses synthetic media and an isolated copy.
param(
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$CaseDirectory,
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$FfmpegPath,
    [Parameter(Mandatory = $true)][string]$FfprobePath,
    [ValidateSet('Receiver', 'Survivor')][string]$Role = 'Receiver',
    [ValidateSet('Fast', 'Accurate')][string]$LoudnessMode = 'Fast',
    [ValidateSet('Analysis', 'Rendering', 'Verification')][string]$SignalStage = 'Rendering',
    [ValidateRange(5, 120)][int]$RestorationTimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
$repositoryPath = [IO.Path]::GetFullPath($Repository)
$casePath = [IO.Path]::GetFullPath($CaseDirectory)
if (-not [IO.Directory]::Exists($casePath)) { throw 'Caller must provide a new owned case directory.' }
$applicationDirectory = [IO.Path]::Combine($casePath, 'app')
if ([IO.Directory]::Exists($applicationDirectory)) { throw 'Application fixture directory already exists.' }
$null = [IO.Directory]::CreateDirectory($applicationDirectory)
$utf8 = [Text.UTF8Encoding]::new($false)
$resultPath = [IO.Path]::Combine($casePath, 'fixture-result.json')
$context = $null; $fixtureError = $null; $applicationCode = $null
$observerInstalled = $false; $registeredBefore = $false; $registeredAfter = $null
$requestedAfter = $null; $cancellationStage = $null; $observedBefore = $null
$fixtureCode = 1
# Dot-sourcing the entry point binds its own identically named parameters.
# Preserve fixture inputs first so importing helpers cannot reset them.
$fixtureOptions = @{ InputPath = $InputPath; FfmpegPath = $FfmpegPath; FfprobePath = $FfprobePath
    LoudnessMode = $LoudnessMode; SignalStage = $SignalStage; Role = $Role }

function Write-WacConsoleFixtureRecord {
    param([string]$Name, $Record)
    [IO.File]::WriteAllText([IO.Path]::Combine($casePath, $Name),
        (($Record | ConvertTo-Json -Depth 10 -Compress) + "`r`n"), $utf8)
}

try {
    foreach ($name in @('WinAudioClean.IO.ps1', 'WinAudioClean.Settings.ps1', 'WinAudioClean.Preview.ps1',
        'WinAudioClean.Batch.ps1', 'WinAudioClean.Queue.ps1')) {
        [IO.File]::Copy([IO.Path]::Combine($repositoryPath, $name), [IO.Path]::Combine($applicationDirectory, $name), $false)
    }
    $mainPath = [IO.Path]::Combine($repositoryPath, 'WinAudioClean.ps1')
    . $mainPath
    Add-Type -TypeDefinition @'
using System;
using System.Threading;
using System.Runtime.InteropServices;
namespace WinAudioCleanConsoleFixture {
    public static class Observer {
        private delegate bool Handler(uint signal);
        private static Handler handler;
        private static int count;
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern bool SetConsoleCtrlHandler(Handler callback, bool add);
        public static int Count { get { return Interlocked.CompareExchange(ref count,0,0); } }
        public static void Install() {
            // Establish a known signal-enabled private test console. This does
            // not alter another process's handler list or the product's context.
            if (!SetConsoleCtrlHandler(null,false)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            handler = delegate(uint signal) {
                if (signal > 1) return false;
                Interlocked.Increment(ref count); return true;
            };
            if (!SetConsoleCtrlHandler(handler,true)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
        public static void Remove() {
            if (!SetConsoleCtrlHandler(handler,false)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            GC.KeepAlive(handler);
        }
    }
}
'@
    [WinAudioCleanConsoleFixture.Observer]::Install(); $observerInstalled = $true
    $context = New-WacRunContext -CaptureConsole
    $registeredBefore = $context.ConsoleHandlerRegistered
    if (-not $registeredBefore) { throw 'Private test console did not register the product control handler.' }

    # Hook only an isolated source copy, after the ordinary dot-source return.
    # Native execution delegates to the unchanged helper; only input pacing and
    # observation differ. Environment values carry all case paths as data.
    $hook = @'
$script:ConsoleFixtureDirectory = [Environment]::GetEnvironmentVariable('WAC_CONSOLE_FIXTURE_DIRECTORY')
$script:ConsoleFixtureStage = [Environment]::GetEnvironmentVariable('WAC_CONSOLE_FIXTURE_STAGE')
$script:ConsoleFixtureReady = $false
Set-Item -Path Function:Invoke-ConsoleFixtureNativeCore -Value (Get-Item Function:Invoke-WacNativeProcess).ScriptBlock
Set-Item -Path Function:Write-ConsoleFixtureProgressCore -Value (Get-Item Function:Write-WacProgress).ScriptBlock
Set-Item -Path Function:Publish-ConsoleFixtureCore -Value (Get-Item Function:Publish-WacOutputTransaction).ScriptBlock
function Write-ConsoleFixtureTrace {
    param($Record)
    [IO.File]::AppendAllText([IO.Path]::Combine($script:ConsoleFixtureDirectory, 'events.jsonl'),
        (($Record | ConvertTo-Json -Depth 8 -Compress) + "`r`n"), [Text.UTF8Encoding]::new($false))
}
function Invoke-WacNativeProcess {
    param([string]$FilePath, [AllowEmptyCollection()][string[]]$ArgumentList = @(),
        [int]$TimeoutMilliseconds = 0, [int]$StreamCloseTimeoutMilliseconds = 5000,
        [IO.Stream]$StandardInputStream, $RunContext = $script:WacRunContext, $ProgressState)
    $forward = @{}
    foreach ($name in $PSBoundParameters.Keys) { $forward[$name] = $PSBoundParameters[$name] }
    $forward.RunContext = $RunContext
    if ($null -ne $ProgressState) {
        $inputIndex = [array]::IndexOf($ArgumentList, '-i')
        if ($inputIndex -lt 0) { throw 'Console fixture cannot pace a native stage without an input.' }
        $arguments = New-Object 'System.Collections.Generic.List[string]'
        for ($argumentIndex = 0; $argumentIndex -lt $ArgumentList.Count; $argumentIndex++) {
            if ($argumentIndex -eq $inputIndex) { $arguments.Add('-readrate'); $arguments.Add('1') }
            $arguments.Add($ArgumentList[$argumentIndex])
        }
        $forward.ArgumentList = $arguments.ToArray()
    }
    Write-ConsoleFixtureTrace -Record ([ordered]@{ kind = 'native_start'; executable = $FilePath
        arguments = @($forward.ArgumentList); originalArguments = @($ArgumentList)
        stage = $(if ($null -ne $ProgressState) { $ProgressState.Stage } else { $null }) })
    $result = Invoke-ConsoleFixtureNativeCore @forward
    Write-ConsoleFixtureTrace -Record ([ordered]@{ kind = 'native_result'; cancelled = $result.Cancelled
        ownedProcessId = $result.OwnedProcessId; exitCode = $result.ExitCode; error = $result.Error
        cleanupError = $result.CleanupError; stage = $(if ($null -ne $ProgressState) { $ProgressState.Stage } else { $null }) })
    $result
}
function Publish-WacOutputTransaction {
    param($Transaction)
    Publish-ConsoleFixtureCore -Transaction $Transaction
    Write-ConsoleFixtureTrace -Record ([ordered]@{ kind = 'published'; published = $Transaction.Published })
}
function Write-WacProgress {
    param($State, [switch]$Completed)
    $record = [ordered]@{ stage = $State.Stage; percent = $State.Percent; processedSeconds = $State.ProcessedSeconds
        processId = $State.ProcessId; completedDisplay = [bool]$Completed; requested = $State.RunContext.IsCancellationRequested }
    [IO.File]::AppendAllText([IO.Path]::Combine($script:ConsoleFixtureDirectory, 'progress.jsonl'),
        (($record | ConvertTo-Json -Compress) + "`r`n"), [Text.UTF8Encoding]::new($false))
    Write-ConsoleFixtureTrace -Record ([ordered]@{ kind = 'progress'; stage = $State.Stage; percent = $State.Percent })
    if (-not $script:ConsoleFixtureReady -and $State.Stage -eq $script:ConsoleFixtureStage -and
        $null -ne $State.ProcessId -and $State.ProcessedSeconds -gt 0) {
        $owned = [Diagnostics.Process]::GetProcessById($State.ProcessId)
        try { $alive = -not $owned.HasExited } finally { $owned.Dispose() }
        if ($alive) {
            $ready = [ordered]@{ shellProcessId = $PID; nativeProcessId = $State.ProcessId; stage = $State.Stage
                processedSeconds = $State.ProcessedSeconds; handlerRegistered = $State.RunContext.ConsoleHandlerRegistered }
            [IO.File]::WriteAllText([IO.Path]::Combine($script:ConsoleFixtureDirectory, 'ready.json'),
                (($ready | ConvertTo-Json -Compress) + "`r`n"), [Text.UTF8Encoding]::new($false))
            $script:ConsoleFixtureReady = $true
        }
    }
    Write-ConsoleFixtureProgressCore -State $State -Completed:$Completed
}
'@
    $source = [IO.File]::ReadAllText($mainPath)
    $marker = "if (`$MyInvocation.InvocationName -eq '.') { return }"
    if ($source.IndexOf($marker, [StringComparison]::Ordinal) -lt 0 -or
        $source.LastIndexOf($marker, [StringComparison]::Ordinal) -ne $source.IndexOf($marker, [StringComparison]::Ordinal)) {
        throw 'Expected exactly one main import boundary.'
    }
    $copiedMain = [IO.Path]::Combine($applicationDirectory, 'WinAudioClean.ps1')
    [IO.File]::WriteAllText($copiedMain, $source.Replace($marker, ($marker + "`r`n" + $hook + "`r`n")), [Text.UTF8Encoding]::new($true))
    [Environment]::SetEnvironmentVariable('WAC_CONSOLE_FIXTURE_DIRECTORY', $casePath)
    [Environment]::SetEnvironmentVariable('WAC_CONSOLE_FIXTURE_STAGE', $fixtureOptions.SignalStage)
    $arguments = @{ inputPath = $fixtureOptions.InputPath; Mode = 'Raw'; LoudnessMode = $fixtureOptions.LoudnessMode
        OutputDirectory = [IO.Path]::Combine($casePath, 'output'); SettingsPath = [IO.Path]::Combine($casePath, 'isolated-settings.json')
        NonInteractive = $true; FfmpegPath = $fixtureOptions.FfmpegPath; FfprobePath = $fixtureOptions.FfprobePath; WacRunContext = $context }
    & $copiedMain @arguments
    $applicationCode = $LASTEXITCODE
    $requestedAfter = $context.IsCancellationRequested; $cancellationStage = $context.CancellationStage
    $observedBefore = [WinAudioCleanConsoleFixture.Observer]::Count
    $context.Dispose(); $registeredAfter = $context.ConsoleHandlerRegistered
    Write-WacConsoleFixtureRecord -Name 'restoration-ready.json' -Record @{ shellProcessId = $PID
        applicationExitCode = $applicationCode; requested = $requestedAfter; cancellationStage = $cancellationStage
        registeredAfterDispose = $registeredAfter; lowerObserverCount = $observedBefore; role = $Role }
    $restorationWatch = [Diagnostics.Stopwatch]::StartNew()
    while ([WinAudioCleanConsoleFixture.Observer]::Count -eq 0 -and $restorationWatch.Elapsed.TotalSeconds -lt $RestorationTimeoutSeconds) {
        [Threading.Thread]::Sleep(100)
    }
    if ([WinAudioCleanConsoleFixture.Observer]::Count -ne 1) { throw 'Expected exactly one signal to the restored lower-priority observer.' }
    if ($observedBefore -ne 0) { throw 'Product handler failed to prevent the lower-priority observer from seeing the first signal.' }
    if ($registeredAfter) { throw 'Product console handler remained registered after disposal.' }
    if ($Role -eq 'Receiver' -and ($applicationCode -ne 130 -or -not $requestedAfter)) { throw 'Actual console cancellation did not retain script execution and exit 130.' }
    if ($Role -eq 'Survivor' -and ($applicationCode -ne 0 -or $requestedAfter)) { throw 'Independent survivor did not complete without cancellation.' }
    $fixtureCode = 0
} catch {
    $fixtureError = $_.Exception.GetBaseException().Message
} finally {
    if ($null -ne $context -and $context.ConsoleHandlerRegistered) {
        try { $context.Dispose() } catch { $fixtureCode = 1; $fixtureError = 'Product handler cleanup failed: ' + $_.Exception.Message }
    }
    if ($observerInstalled) {
        try { [WinAudioCleanConsoleFixture.Observer]::Remove() } catch { $fixtureCode = 1; $fixtureError = 'Fixture handler cleanup failed: ' + $_.Exception.Message }
    }
    Write-WacConsoleFixtureRecord -Name 'fixture-result.json' -Record ([ordered]@{ shellVersion = $PSVersionTable.PSVersion.ToString()
        shellProcessId = $PID; role = $Role; fixtureExitCode = $fixtureCode; applicationExitCode = $applicationCode
        requested = $requestedAfter; cancellationStage = $cancellationStage; registeredBefore = $registeredBefore
        registeredAfterDispose = $registeredAfter; lowerObserverBeforeDispose = $observedBefore
        lowerObserverAfterDispose = $(if ($observerInstalled) { [WinAudioCleanConsoleFixture.Observer]::Count } else { $null })
        error = $fixtureError })
}
exit $fixtureCode
