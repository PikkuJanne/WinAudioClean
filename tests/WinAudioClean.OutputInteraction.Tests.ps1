BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $mainPath = Join-Path $repositoryRoot 'WinAudioClean.ps1'
    . $mainPath
    $actualDestinationOpener = (Get-Command Open-WacDestinationFolder).ScriptBlock
    . (Join-Path $repositoryRoot 'WinAudioClean.Settings.ps1')
    . (Join-Path $repositoryRoot 'WinAudioClean.Queue.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
    $currentShell = (Get-Process -Id $PID).Path
    $nativeFixture = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'output interaction native.exe')

    function New-WacInteractionSandbox {
        # Leave room for legacy Win32 output names below the job/media hierarchy.
        $root = Join-Path $TestDrive ('i' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        if ([IO.Directory]::Exists($root)) { throw 'The private sandbox identifier collided.' }
        $working = Join-Path $root 'working directory'
        $null = [IO.Directory]::CreateDirectory($working)
        $app = Join-Path $root 'WinAudioClean.ps1'
        $source = [IO.File]::ReadAllText($mainPath)
        $marker = "if (`$MyInvocation.InvocationName -eq '.') { return }"
        if (-not $source.Contains($marker)) { throw 'The isolated host seam insertion point is missing.' }
        # These are controlled UI/default-path boundaries in this disposable copy.
        # Native probing, rendering, publication, reports and exit handling remain real.
        $seams = @'
function Get-WacDefaultOutputDirectory { $env:WAC_INTERACTION_MUSIC }
function Test-WacInteractive {
    param([switch]$NonInteractive)
    -not $NonInteractive -and $env:WAC_INTERACTION_INTERACTIVE -eq '1'
}
function Clear-Host { }
function Show-WacFilePicker {
    [IO.File]::WriteAllText($env:WAC_INTERACTION_PICKER_RECORD, 'called', [Text.UTF8Encoding]::new($false))
    if ($env:WAC_INTERACTION_PICKER_THROW -eq '1') { throw 'WAC_PICKER_UNAVAILABLE_TEST' }
    if ($env:WAC_INTERACTION_PICKER_CANCEL -eq '1') { return $null }
    $env:WAC_INTERACTION_PICKER_SELECTION
}
function Open-WacDestinationFolder {
    param([Alias('Path')][string]$Directory, [string]$ExpectedDirectoryIdentity)
    [IO.File]::AppendAllText($env:WAC_INTERACTION_OPEN_RECORD,
        (([ordered]@{ directory = $Directory; expectedIdentity = $ExpectedDirectoryIdentity } | ConvertTo-Json -Compress) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    if ($env:WAC_INTERACTION_OPEN_THROW -eq '1') { throw 'WAC_OPEN_UNAVAILABLE_TEST' }
}
'@
        [IO.File]::WriteAllText($app, $source.Replace($marker, ($marker + "`r`n" + $seams)), [Text.UTF8Encoding]::new($false))
        foreach ($name in @('WinAudioClean.IO.ps1', 'WinAudioClean.Settings.ps1', 'WinAudioClean.Batch.ps1',
                'WinAudioClean.Queue.ps1', 'WinAudioClean.Preview.ps1', 'WinAudioClean.Output.ps1')) {
            $path = Join-Path $repositoryRoot $name
            if ([IO.File]::Exists($path)) { Copy-Item -LiteralPath $path -Destination $root }
        }
        foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
            Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $root $name)
        }
        $inputFile = Join-Path $root 'source.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(11, 22, 33, 44))
        $sentinel = Join-Path $working 'foreign sentinel.txt'
        [IO.File]::WriteAllBytes($sentinel, [byte[]]@(9, 8, 7))
        [pscustomobject]@{
            Root = $root; Working = $working; App = $app; Input = $inputFile; Sentinel = $sentinel
            Music = Join-Path $root 'Music [literal] & %PATH% !'; Output = Join-Path $root 'out [1] & %PATH% !'
            Settings = Join-Path $root 'isolated missing settings.json'
            PickerRecord = Join-Path $root 'picker-called.txt'; OpenRecord = Join-Path $root 'opened-directories.jsonl'
            RenderArgv = Join-Path $root 'render-argv.json'; NativePid = Join-Path $root 'native-started.txt'
            VersionPid = Join-Path $root 'version-started.txt'; ProbePid = Join-Path $root 'probe-started.txt'
            FilterPid = Join-Path $root 'filters-started.txt'
        }
    }

    function Invoke-WacInteractionCase {
        param($Sandbox, [string]$Options = '', [switch]$NoInput, [switch]$Interactive,
            [switch]$DefaultOutput, [switch]$NoMode, [switch]$UseSavedSettings,
            [switch]$LegacyHelperless, [switch]$FalseActions, [hashtable]$Environment = @{})
        $environmentValues = @{
            WAC_INTERACTION_MUSIC = $Sandbox.Music; WAC_INTERACTION_INTERACTIVE = $(if ($Interactive) { '1' } else { '0' })
            WAC_INTERACTION_PICKER_RECORD = $Sandbox.PickerRecord; WAC_INTERACTION_OPEN_RECORD = $Sandbox.OpenRecord
            WAC_INTERACTION_PICKER_SELECTION = $Sandbox.Input
            WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_ARGV_PATH = $Sandbox.RenderArgv; WAC_TEST_PID_PATH = $Sandbox.NativePid
            WAC_TEST_VERSION_PID_PATH = $Sandbox.VersionPid; WAC_TEST_PROBE_PID_PATH = $Sandbox.ProbePid
            WAC_TEST_FILTERS_PID_PATH = $Sandbox.FilterPid
            WAC_TEST_STDOUT = "out_time_us=1500000`nprogress=continue`nout_time_us=3000000`nprogress=end`n"
            WAC_TEST_STDERR = 'WAC_OUTPUT_INTERACTION_NATIVE_DIAGNOSTIC'; WAC_TEST_EXIT_CODE = '0'
        }
        foreach ($name in $Environment.Keys) { $environmentValues[$name] = $Environment[$name] }
        $arguments = '-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File {0}' -f (ConvertTo-WacTestQuotedArgument $Sandbox.App)
        if (-not $LegacyHelperless) { $arguments += ' -SettingsPath ' + (ConvertTo-WacTestQuotedArgument $Sandbox.Settings) }
        if (-not $UseSavedSettings) { $arguments += ' -IgnoreSavedSettings' }
        if (-not $NoInput) { $arguments += ' -inputPath ' + (ConvertTo-WacTestQuotedArgument $Sandbox.Input) }
        if (-not $DefaultOutput) { $arguments += ' -OutputDirectory ' + (ConvertTo-WacTestQuotedArgument $Sandbox.Output) }
        if (-not $NoMode) { $arguments += ' -Mode Zoom' }
        if (-not $Interactive) { $arguments += ' -NonInteractive' }
        if ($Options) { $arguments += ' ' + $Options }
        if ($FalseActions) {
            $driver = Join-Path $Sandbox.Root 'typed-false-actions.ps1'
            $code = @'
param([string]$WacApp, [string]$WacInput, [string]$WacOutput)
& $WacApp -inputPath $WacInput -OutputDirectory $WacOutput -Mode Zoom -NonInteractive -IgnoreSavedSettings -JobFolder:$false -PickFile:$false -OpenOutputFolder:$false
exit $LASTEXITCODE
'@
            [IO.File]::WriteAllText($driver, $code, [Text.UTF8Encoding]::new($false))
            $arguments = '-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File {0} -WacApp {1} -WacInput {2} -WacOutput {3}' -f
                (ConvertTo-WacTestQuotedArgument $driver), (ConvertTo-WacTestQuotedArgument $Sandbox.App),
                (ConvertTo-WacTestQuotedArgument $Sandbox.Input), (ConvertTo-WacTestQuotedArgument $Sandbox.Output)
        }
        Invoke-WacTestProcess -FilePath $currentShell -Arguments $arguments -WorkingDirectory $Sandbox.Working -EnvironmentVariables $environmentValues -TimeoutMilliseconds 30000
    }

    function Assert-WacInteractionSourceAndWorkingDirectory {
        param($Sandbox)
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($Sandbox.Input)) | Should -BeExactly 'CxYhLA=='
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($Sandbox.Sentinel)) | Should -BeExactly 'CQgH'
        @(Get-ChildItem -LiteralPath $Sandbox.Working -Force).Count | Should -Be 1
        Test-Path -LiteralPath $Sandbox.Settings | Should -BeFalse
    }

    function Assert-WacInteractionNoNative {
        param($Sandbox)
        foreach ($path in @($Sandbox.NativePid, $Sandbox.VersionPid, $Sandbox.ProbePid, $Sandbox.FilterPid, $Sandbox.RenderArgv)) {
            Test-Path -LiteralPath $path | Should -BeFalse
        }
    }

    function Assert-WacInteractionOpenedIdentity {
        param($Record, [string]$Directory)
        $Record.directory | Should -BeExactly $Directory
        $Record.expectedIdentity | Should -Not -BeNullOrEmpty
        Initialize-WacNativeFileIO
        $handle = [WinAudioClean.NativeFileIO]::OpenDirectory($Directory)
        try { [WinAudioClean.NativeFileIO]::Identity($handle) | Should -BeExactly $Record.expectedIdentity }
        finally { $handle.Dispose() }
    }

    function Invoke-WacPickerBodyCase {
        param([string]$Case)
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($root)
        $driver = Join-Path $root 'picker-body.ps1'
        $code = @'
param([string]$WacMain, [string]$WacCase)
$WacMainToImport = $WacMain
. $WacMainToImport
$script:WacPickerCase = $WacCase
$script:WacAssemblyCalls = 0
$script:WacDialogCalls = 0
$script:WacDialog = [pscustomobject]@{
    Title = ''; Filter = ''; Multiselect = $true; CheckFileExists = $false
    CheckPathExists = $false; RestoreDirectory = $false
    FileName = 'C:\WAC synthetic\selected.wav'; Disposed = $false
}
$script:WacDialog | Add-Member -MemberType ScriptMethod -Name ShowDialog -Value {
    if ($script:WacPickerCase -eq 'throw') { throw 'WAC_DIALOG_SHOW_FAILURE' }
    if ($script:WacPickerCase -eq 'cancel') { return 'Cancel' }
    'OK'
}
$script:WacDialog | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.Disposed = $true }
function Test-WacInteractive { $true }
function Add-Type {
    param([string]$AssemblyName)
    if ($AssemblyName -ne 'System.Windows.Forms') { throw 'Unexpected assembly request.' }
    $script:WacAssemblyCalls++
}
function New-Object {
    param([string]$TypeName)
    if ($TypeName -ne 'System.Windows.Forms.OpenFileDialog') { throw 'Unexpected dialog type request.' }
    $script:WacDialogCalls++
    $script:WacDialog
}
$selected = $null; $failure = $null
try { $selected = Show-WacFilePicker } catch { $failure = $_.Exception.Message }
[ordered]@{
    selected = $selected; error = $failure; disposed = $script:WacDialog.Disposed
    title = $script:WacDialog.Title; filter = $script:WacDialog.Filter
    multiselect = $script:WacDialog.Multiselect; checkFileExists = $script:WacDialog.CheckFileExists
    checkPathExists = $script:WacDialog.CheckPathExists; restoreDirectory = $script:WacDialog.RestoreDirectory
    assemblyCalls = $script:WacAssemblyCalls; dialogCalls = $script:WacDialogCalls
    formsLoaded = @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'System.Windows.Forms' }).Count -gt 0
} | ConvertTo-Json -Compress
'@
        [IO.File]::WriteAllText($driver, $code, [Text.UTF8Encoding]::new($false))
        $arguments = '-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File {0} -WacMain {1} -WacCase {2}' -f
            (ConvertTo-WacTestQuotedArgument $driver), (ConvertTo-WacTestQuotedArgument $mainPath), (ConvertTo-WacTestQuotedArgument $Case)
        Invoke-WacTestProcess -FilePath $currentShell -Arguments $arguments -WorkingDirectory $root
    }
}

Describe 'AC-061: default Music is explicit and never falls back to the current directory' -Tag 'OutputInteraction', 'Unit' {
    It 'reads the existing Music registration without writing to it' {
        Get-WacDefaultOutputDirectory | Should -BeExactly ([Environment]::GetFolderPath('MyMusic'))
    }

    It 'rejects unavailable or unsupported default Music <Case>' -ForEach @(
        @{ Case = 'empty'; Path = '' }; @{ Case = 'relative'; Path = 'relative music' }
        @{ Case = 'UNC'; Path = '\\server\share\Music' }; @{ Case = 'provider'; Path = 'Env:PATH' }
    ) {
        { Get-WacOutputDirectory -Path $Path -DefaultMusic:$true } | Should -Throw '*OutputDirectory*'
    }

    It 'preserves explicit relative output resolution instead of applying the default Music guard' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($root)
        Push-Location $root
        try {
            Get-WacOutputDirectory -Path 'explicit output' -DefaultMusic:$false | Should -BeExactly (Join-Path $root 'explicit output')
        } finally { Pop-Location }
    }

    It 'keeps action switches outside the saved preference schema' {
        $resolved = Resolve-WacSettings -Explicit @{
            Mode = 'Zoom'; OutputDirectory = $TestDrive; JobFolder = $true; PickFile = $true; OpenOutputFolder = $true
        }
        $document = ConvertTo-WacSettingsJson -Values $resolved.Values | ConvertFrom-Json
        $keys = @($document.settings.PSObject.Properties.Name)
        $keys | Should -Not -Contain 'jobFolder'
        $keys | Should -Not -Contain 'pickFile'
        $keys | Should -Not -Contain 'openOutputFolder'
        $document.settings.outputDirectory | Should -BeExactly $TestDrive
    }

    It 'skips an exact prior job directory without traversing renamed media while traversing a near miss' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $destination = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $oldGroup = Join-Path $root 'WinAudioClean_Job_0123456789abcdef0123456789abcdef'
        $nearGroup = Join-Path $root 'WinAudioClean_Job_0123456789abcdef0123456789abcdefx'
        foreach ($directory in @($oldGroup, $nearGroup, $destination)) { $null = [IO.Directory]::CreateDirectory($directory) }
        $oldMedia = Join-Path $oldGroup 'renamed.wav'
        $nearMedia = Join-Path $nearGroup 'renamed.wav'
        [IO.File]::WriteAllBytes($oldMedia, [byte[]]@(1, 2, 3))
        [IO.File]::WriteAllBytes($nearMedia, [byte[]]@(4, 5, 6))
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $destination -Recurse
        $queue.Entries.Count | Should -Be 2
        $excluded = @($queue.Entries | Where-Object { $_.InputPath -eq $oldGroup })
        $excluded.Count | Should -Be 1
        $excluded[0].Status | Should -BeExactly 'SKIPPED'
        $excluded[0].ReasonCode | Should -BeExactly 'generated_artifact'
        @($queue.Entries | Where-Object { $_.InputPath -eq $oldMedia }).Count | Should -Be 0
        $selected = @($queue.Entries | Where-Object { $_.InputPath -eq $nearMedia })
        $selected.Count | Should -Be 1
        $selected[0].Status | Should -BeExactly 'PENDING'
    }
}

Describe 'AC-063: follow-up action requires explicit interactive published success' -Tag 'OutputInteraction', 'Unit' {
    BeforeEach { Mock Open-WacDestinationFolder { } }

    It 'does not open for <Case>' -ForEach @(
        @{ Case = 'not requested'; Requested = $false; Interactive = $true; Code = 0; Published = $true }
        @{ Case = 'not interactive'; Requested = $true; Interactive = $false; Code = 0; Published = $true }
        @{ Case = 'not published'; Requested = $true; Interactive = $true; Code = 0; Published = $false }
        @{ Case = 'unpublished warning'; Requested = $true; Interactive = $true; Code = 7; Published = $false }
        @{ Case = 'preflight failure'; Requested = $true; Interactive = $true; Code = 2; Published = $false }
        @{ Case = 'dependency failure'; Requested = $true; Interactive = $true; Code = 3; Published = $false }
        @{ Case = 'processing failure'; Requested = $true; Interactive = $true; Code = 4; Published = $false }
        @{ Case = 'storage failure'; Requested = $true; Interactive = $true; Code = 5; Published = $false }
        @{ Case = 'mixed batch failure'; Requested = $true; Interactive = $true; Code = 6; Published = $true }
        @{ Case = 'cancellation'; Requested = $true; Interactive = $true; Code = 130; Published = $true }
    ) {
        $null = Invoke-WacOutputFollowUp -Requested $Requested -Interactive $Interactive -ExitCode $Code -Published $Published -Directory $TestDrive
        Should -Invoke Open-WacDestinationFolder -Times 0 -Exactly
    }

    It 'opens the selected directory once for published exit <Code>' -ForEach @(@{ Code = 0 }, @{ Code = 7 }) {
        $null = Invoke-WacOutputFollowUp -Requested $true -Interactive $true -ExitCode $Code -Published $true -Directory $TestDrive
        Should -Invoke Open-WacDestinationFolder -Times 1 -Exactly -ParameterFilter { $Directory -eq $TestDrive }
    }

    It 'contains an explicit folder-open failure as an advisory' {
        Mock Open-WacDestinationFolder { throw 'WAC_OPEN_UNAVAILABLE_TEST' }
        { Invoke-WacOutputFollowUp -Requested $true -Interactive $true -ExitCode 7 -Published $true -Directory $TestDrive 3>$null } | Should -Not -Throw
        Should -Invoke Open-WacDestinationFolder -Times 1 -Exactly
    }

    It 'refuses an existing directory whose identity differs before launching the shell' {
        $directory = Join-Path $TestDrive ('wrong-identity-' + [guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($directory)
        # The body captured before Pester mocking exercises the actual guard.
        { & $actualDestinationOpener -Directory $directory -ExpectedDirectoryIdentity 'WAC_WRONG_DIRECTORY_IDENTITY' } | Should -Throw '*changed*'
        @(Get-ChildItem -LiteralPath $directory -Force).Count | Should -Be 0
    }
}

Describe 'AC-062/063: actual picker body with isolated STA dialog doubles' -Tag 'OutputInteraction', 'Unit' {
    It 'configures and disposes the optional picker for <Case> without loading a GUI assembly' -ForEach @(
        @{ Case = 'OK' }; @{ Case = 'cancel' }; @{ Case = 'throw' }
    ) {
        $result = Invoke-WacPickerBodyCase -Case $Case
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $snapshot = $result.StandardOutput | ConvertFrom-Json
        $snapshot.disposed | Should -BeTrue
        $snapshot.multiselect | Should -BeFalse
        $snapshot.checkFileExists | Should -BeTrue
        $snapshot.checkPathExists | Should -BeTrue
        $snapshot.restoreDirectory | Should -BeTrue
        $snapshot.title | Should -Not -BeNullOrEmpty
        $snapshot.filter | Should -Match '\*\.wav'
        $snapshot.assemblyCalls | Should -Be 1
        $snapshot.dialogCalls | Should -Be 1
        $snapshot.formsLoaded | Should -BeFalse
        if ($Case -eq 'OK') {
            $snapshot.selected | Should -BeExactly 'C:\WAC synthetic\selected.wav'
            $snapshot.error | Should -BeNullOrEmpty
        } elseif ($Case -eq 'cancel') {
            $snapshot.selected | Should -BeNullOrEmpty
            $snapshot.error | Should -BeNullOrEmpty
        } else {
            $snapshot.selected | Should -BeNullOrEmpty
            $snapshot.error | Should -Match 'WAC_DIALOG_SHOW_FAILURE'
            $snapshot.error | Should -Match 'inputPath'
        }
    }
}

Describe 'AC-061/062: actual isolated destination and no-GUI entry points' -Tag 'OutputInteraction', 'Runtime', 'Native' {
    It 'keeps default Music or chosen output flat (<DefaultOutput>) without a picker or Explorer' -ForEach @(
        @{ DefaultOutput = $true }; @{ DefaultOutput = $false }
    ) {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -DefaultOutput:$DefaultOutput
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $destination = if ($DefaultOutput) { $sandbox.Music } else { $sandbox.Output }
        @(Get-ChildItem -LiteralPath $destination -Filter '*.wav').Count | Should -Be 1
        @(Get-ChildItem -LiteralPath $destination -Filter 'WinAudioClean_*.json').Count | Should -Be 1
        $flat = Get-Content -LiteralPath @(Get-ChildItem -LiteralPath $destination -Filter 'WinAudioClean_*.json')[0].FullName -Raw | ConvertFrom-Json
        @($flat.output.PSObject.Properties.Name) | Should -Not -Contain 'organization'
        Test-Path -LiteralPath (Join-Path $destination 'WinAudioClean_Log.txt') | Should -BeTrue
        @(Get-ChildItem -LiteralPath $destination -Directory).Count | Should -Be 0
        Test-Path -LiteralPath $sandbox.PickerRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'uses explicit output successfully when default Music is unavailable' {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Environment @{ WAC_INTERACTION_MUSIC = '' }
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav').Count | Should -Be 1
        Test-Path -LiteralPath $sandbox.Music | Should -BeFalse
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'uses saved custom output even when default Music is unavailable without rewriting preferences' {
        $sandbox = New-WacInteractionSandbox
        $json = @{ schemaVersion = 1; settings = @{ mode = 'Zoom'; outputDirectory = $sandbox.Output } } | ConvertTo-Json -Compress
        [IO.File]::WriteAllText($sandbox.Settings, $json, [Text.UTF8Encoding]::new($false))
        $before = (Get-FileHash -LiteralPath $sandbox.Settings -Algorithm SHA256).Hash
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -UseSavedSettings -DefaultOutput -NoMode -Environment @{ WAC_INTERACTION_MUSIC = '' }
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav').Count | Should -Be 1
        (Get-FileHash -LiteralPath $sandbox.Settings -Algorithm SHA256).Hash | Should -BeExactly $before
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($sandbox.Input)) | Should -BeExactly 'CxYhLA=='
        @(Get-ChildItem -LiteralPath $sandbox.Working -Force).Count | Should -Be 1
        Test-Path -LiteralPath $sandbox.Music | Should -BeFalse
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
    }

    It 'keeps normal helper-less installs flat with explicitly false new action switches' {
        $sandbox = New-WacInteractionSandbox
        foreach ($name in @('WinAudioClean.Settings.ps1', 'WinAudioClean.Batch.ps1', 'WinAudioClean.Queue.ps1', 'WinAudioClean.Preview.ps1', 'WinAudioClean.Output.ps1')) {
            $path = Join-Path $sandbox.Root $name
            if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
        }
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -LegacyHelperless -FalseActions
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav').Count | Should -Be 1
        @(Get-ChildItem -LiteralPath $sandbox.Output -Directory).Count | Should -Be 0
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.PickerRecord | Should -BeFalse
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'rejects unavailable default Music before native work and cwd output (<Case>)' -ForEach @(
        @{ Case = 'empty'; Music = '' }; @{ Case = 'relative'; Music = 'relative music' }
        @{ Case = 'UNC'; Music = '\\server\share\Music' }
    ) {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -DefaultOutput -Environment @{ WAC_INTERACTION_MUSIC = $Music }
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        ($result.StandardOutput + $result.StandardError) | Should -Match 'OutputDirectory'
        Assert-WacInteractionNoNative -Sandbox $sandbox
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'shows no-input usage without a desktop dependency, prompt or destination creation' {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -NoInput -NoMode -DefaultOutput
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        ($result.StandardOutput + $result.StandardError) | Should -Match 'No input file supplied'
        $result.StandardOutput | Should -Not -Match 'Enter selection|Running WinAudioClean|DONE: SUCCESS'
        Assert-WacInteractionNoNative -Sandbox $sandbox
        Test-Path -LiteralPath $sandbox.Music | Should -BeFalse
        Test-Path -LiteralPath $sandbox.PickerRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'creates one job group with separate media and detailed reports' {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Options '-JobFolder'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $groups = @(Get-ChildItem -LiteralPath $sandbox.Output -Directory)
        $groups.Count | Should -Be 1
        $groups[0].Name | Should -Match '^WinAudioClean_Job_[a-f0-9]{32}$'
        $media = Join-Path $groups[0].FullName 'media'
        $reports = Join-Path $groups[0].FullName 'reports'
        @(Get-ChildItem -LiteralPath $media -Filter '*.wav').Count | Should -Be 1
        @(Get-ChildItem -LiteralPath $media -File -Force).Count | Should -Be 1
        $json = @(Get-ChildItem -LiteralPath $reports -Filter 'WinAudioClean_*.json')
        $json.Count | Should -Be 1
        $report = Get-Content -LiteralPath $json[0].FullName -Raw | ConvertFrom-Json
        $report.output.published | Should -BeTrue
        $report.output.organization.rootDirectory | Should -BeExactly $groups[0].FullName
        $report.output.organization.mediaDirectory | Should -BeExactly $media
        $report.output.organization.reportDirectory | Should -BeExactly $reports
        $report.output.organization.jobId | Should -BeExactly $groups[0].Name.Substring('WinAudioClean_Job_'.Length)
        $report.jobId | Should -Not -BeExactly $report.output.organization.jobId
        $report.diagnostics.jsonPath | Should -BeExactly $json[0].FullName
        [IO.Path]::GetDirectoryName($report.diagnostics.textPath) | Should -BeExactly $reports
        Test-Path -LiteralPath (Join-Path $reports 'WinAudioClean_Log.txt') | Should -BeTrue
        @(Get-ChildItem -LiteralPath $sandbox.Output -File -Force).Count | Should -Be 0
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'shares one job group across explicit list children and opens it once at the parent' {
        $sandbox = New-WacInteractionSandbox
        $second = Join-Path $sandbox.Root 'second synthetic source.wav'
        [IO.File]::WriteAllBytes($second, [byte[]]@(55, 66, 77, 88))
        $manifest = Join-Path $sandbox.Root 'inputs.json'
        [IO.File]::WriteAllText($manifest, (@{ schemaVersion = 1; inputs = @($sandbox.Input, $second) } | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
        $options = '-JobFolder -OpenOutputFolder -InputListPath ' + (ConvertTo-WacTestQuotedArgument $manifest)
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Options $options -NoInput -Interactive
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $groups = @(Get-ChildItem -LiteralPath $sandbox.Output -Directory)
        $groups.Count | Should -Be 1
        @(Get-ChildItem -LiteralPath (Join-Path $groups[0].FullName 'media') -Filter '*.wav').Count | Should -Be 2
        $reports = Join-Path $groups[0].FullName 'reports'
        @(Get-ChildItem -LiteralPath $reports -Filter 'WinAudioClean_*.json').Count | Should -Be 2
        $journals = @(Get-ChildItem -LiteralPath $reports -Filter '*.jsonl')
        $journals.Count | Should -Be 1
        $records = @(Get-Content -LiteralPath $journals[0].FullName | ForEach-Object { $_ | ConvertFrom-Json })
        $records[0].inputCount | Should -Be 2
        $records[0].outputOrganization.rootDirectory | Should -BeExactly $groups[0].FullName
        $records[0].outputOrganization.reportDirectory | Should -BeExactly $reports
        $records[0].outputOrganization.jobId | Should -BeExactly $groups[0].Name.Substring('WinAudioClean_Job_'.Length)
        $childReports = @(Get-ChildItem -LiteralPath $reports -Filter 'WinAudioClean_*.json' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
        @($childReports.jobId | Sort-Object -Unique).Count | Should -Be 2
        @($childReports.output.organization.jobId | Sort-Object -Unique).Count | Should -Be 1
        $childReports[0].output.organization.jobId | Should -BeExactly $records[0].outputOrganization.jobId
        $records[-1].counts.success | Should -Be 2
        $records[-1].exitCode | Should -Be 0
        $opened = @(Get-Content -LiteralPath $sandbox.OpenRecord | ForEach-Object { $_ | ConvertFrom-Json })
        $opened.Count | Should -Be 1
        Assert-WacInteractionOpenedIdentity -Record $opened[0] -Directory $groups[0].FullName
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($second)) | Should -BeExactly 'N0JNWA=='
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }
}

Describe 'AC-062/063: requested UI boundaries in actual isolated hosts' -Tag 'OutputInteraction', 'Runtime', 'Native' {
    It 'rejects persisting processing action <Option> without input, native work or config changes' -ForEach @(
        @{ Option = '-JobFolder' }; @{ Option = '-PickFile' }; @{ Option = '-OpenOutputFolder' }
    ) {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -NoInput -Options ('-SaveSettings ' + $Option)
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        Assert-WacInteractionNoNative -Sandbox $sandbox
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        Test-Path -LiteralPath $sandbox.PickerRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'rejects unattended <Option> before picker, Explorer or native work' -ForEach @(
        @{ Option = '-PickFile'; NoInput = $true }; @{ Option = '-OpenOutputFolder'; NoInput = $false }
    ) {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Options $Option -NoInput:$NoInput
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        Assert-WacInteractionNoNative -Sandbox $sandbox
        Test-Path -LiteralPath $sandbox.PickerRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'returns 130 on picker cancellation without creating output or starting native tools' {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Options '-PickFile' -NoInput -Interactive -Environment @{ WAC_INTERACTION_PICKER_CANCEL = '1' }
        $result.ExitCode | Should -Be 130 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.PickerRecord | Should -BeTrue
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        Assert-WacInteractionNoNative -Sandbox $sandbox
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'rejects PickFile combined with an explicit input before picker or native work' {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Options '-PickFile' -Interactive
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.PickerRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        Assert-WacInteractionNoNative -Sandbox $sandbox
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'uses a picked file through normal validation and native rendering' {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Options '-PickFile' -NoInput -Interactive
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.PickerRecord | Should -BeTrue
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        $argv = Get-Content -LiteralPath $sandbox.RenderArgv -Raw | ConvertFrom-Json
        $argv[[Array]::IndexOf($argv, '-i') + 1] | Should -BeExactly $sandbox.Input
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'rejects an unavailable picker without native work or a false completed result' {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Options '-PickFile' -NoInput -Interactive -Environment @{ WAC_INTERACTION_PICKER_THROW = '1' }
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.PickerRecord | Should -BeTrue
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
        $result.StandardOutput | Should -Not -Match 'DONE: SUCCESS|File saved to:'
        Assert-WacInteractionNoNative -Sandbox $sandbox
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'opens only a published successful group and preserves success when opening fails' -ForEach @(
        @{ ThrowOpen = $false }; @{ ThrowOpen = $true }
    ) {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Options '-JobFolder -OpenOutputFolder' -Interactive -Environment @{
            WAC_INTERACTION_OPEN_THROW = $(if ($ThrowOpen) { '1' } else { '0' })
        }
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $groups = @(Get-ChildItem -LiteralPath $sandbox.Output -Directory)
        $opened = @(Get-Content -LiteralPath $sandbox.OpenRecord | ForEach-Object { $_ | ConvertFrom-Json })
        $opened.Count | Should -Be 1
        Assert-WacInteractionOpenedIdentity -Record $opened[0] -Directory $groups[0].FullName
        @(Get-ChildItem -LiteralPath (Join-Path $groups[0].FullName 'media') -Filter '*.wav').Count | Should -Be 1
        if ($ThrowOpen) { ($result.StandardOutput + $result.StandardError) | Should -Match 'WAC_OPEN_UNAVAILABLE_TEST' }
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }

    It 'never offers or opens a completed destination after native failure' {
        $sandbox = New-WacInteractionSandbox
        $result = Invoke-WacInteractionCase -Sandbox $sandbox -Options '-JobFolder -OpenOutputFolder' -Interactive -Environment @{ WAC_TEST_EXIT_CODE = '19' }
        $result.ExitCode | Should -Be 4 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.OpenRecord | Should -BeFalse
        $result.StandardOutput | Should -Not -Match 'DONE: SUCCESS|File saved to:'
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav' -Recurse).Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.partial' -Recurse -Force).Count | Should -Be 0
        Assert-WacInteractionSourceAndWorkingDirectory -Sandbox $sandbox
    }
}
