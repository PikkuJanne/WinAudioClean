BeforeDiscovery {
    $launcherShellCases = foreach ($shellName in @('powershell.exe', 'pwsh.exe')) {
        $shellCommand = Get-Command $shellName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        @{ ShellName = $shellName; ShellPath = $shellCommand.Source; Unavailable = ($null -eq $shellCommand) }
    }
    $launcherPathCases = foreach ($shell in $launcherShellCases) {
        foreach ($fileName in @(
            'meeting with spaces.wav', 'meeting [draft].wav', "speaker's recording.wav",
            'meeting äöÅ.wav', 'speaker & guest.wav', 'meeting %WAC_LAUNCH_PERCENT_TOKEN%.wav',
            'meeting !important!.wav', 'meeting (take 1).wav', 'name & echo WAC_UNEXPECTED_COMMAND.wav'
        )) {
            @{
                ShellName = $shell.ShellName; ShellPath = $shell.ShellPath; Unavailable = $shell.Unavailable
                FileName = $fileName
            }
        }
    }
    $launcherExitCases = foreach ($shell in $launcherShellCases) {
        foreach ($case in @(
            @{ Scenario = 'successful child'; NativeExitCode = 0; BlockLog = $false; ExpectedExit = 0; Dependency = 'fixture' },
            @{ Scenario = 'nonzero child'; NativeExitCode = 9; BlockLog = $false; ExpectedExit = 4; Dependency = 'fixture' },
            @{ Scenario = 'failed report after native success'; NativeExitCode = 0; BlockLog = $true; ExpectedExit = 7; Dependency = 'fixture' },
            @{ Scenario = 'invalid executable'; NativeExitCode = 0; BlockLog = $false; ExpectedExit = 3; Dependency = 'invalid' }
        )) {
            @{
                ShellName = $shell.ShellName; ShellPath = $shell.ShellPath; Unavailable = $shell.Unavailable
                Scenario = $case.Scenario; NativeExitCode = $case.NativeExitCode; BlockLog = $case.BlockLog
                ExpectedExit = $case.ExpectedExit; Dependency = $case.Dependency
            }
        }
    }
    $defaultLauncherPathCases = @($launcherPathCases | Where-Object { $_.FileName -notmatch '[%!]' })
    $launcherInvalidCases = foreach ($shell in $launcherShellCases) {
        foreach ($route in @('InvalidMode', 'MissingEnvironment', 'ExtraArgument', 'ExtraFile')) {
            @{
                ShellName = $shell.ShellName; ShellPath = $shell.ShellPath; Unavailable = $shell.Unavailable
                Route = $route
            }
        }
    }
}

BeforeAll {
    $launcherRepositoryRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $PSScriptRoot 'fixtures/TestProcess.ps1')
    . (Join-Path $PSScriptRoot 'fixtures/New-NativeProcessFixture.ps1')
    $launcherFixtureExecutable = Join-Path $TestDrive 'native-launcher-fixture.exe'
    New-WacTestNativeExecutable -OutputPath $launcherFixtureExecutable

    function New-WacLauncherTestFolder {
        $folder = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8) + ' [app]')
        $null = [IO.Directory]::CreateDirectory($folder)
        foreach ($fileName in @('WinAudioClean.ps1', 'WinAudioClean.IO.ps1', 'WinAudioClean.bat')) {
            [IO.File]::Copy((Join-Path $launcherRepositoryRoot $fileName), (Join-Path $folder $fileName))
        }
        [IO.File]::Copy($launcherFixtureExecutable, (Join-Path $folder 'ffmpeg.exe'))
        [IO.File]::Copy($launcherFixtureExecutable, (Join-Path $folder 'ffprobe.exe'))
        $folder
    }

    function Invoke-WacLauncherTestCase {
        param(
            [string]$ShellPath, [string]$Folder, [string]$InputFile, [string]$OutputFolder,
            [string]$Route = 'Unattended', [int]$NativeExitCode = 0, [switch]$BlockLog,
            [switch]$DefinePercentToken, [switch]$TrailingOutputSeparator
        )
        $fixture = Join-Path $PSScriptRoot 'fixtures/Invoke-LauncherCase.ps1'
        $recordFile = Join-Path $Folder 'recorded-argv.json'
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -LauncherPath {1} -InputPath {2} -OutputDirectory {3} -RecordPath {4} -Route {5} -NativeExitCode {6}' -f
            (ConvertTo-WacTestQuotedArgument $fixture), (ConvertTo-WacTestQuotedArgument (Join-Path $Folder 'WinAudioClean.bat')),
            (ConvertTo-WacTestQuotedArgument $InputFile), (ConvertTo-WacTestQuotedArgument $OutputFolder),
            (ConvertTo-WacTestQuotedArgument $recordFile), $Route, $NativeExitCode
        if ($BlockLog) { $arguments += ' -BlockLog' }
        if ($DefinePercentToken) { $arguments += ' -DefinePercentToken' }
        if ($TrailingOutputSeparator) { $arguments += ' -TrailingOutputSeparator' }
        $childResult = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $Folder -StandardInput "`r`n"
        $childResult | Add-Member -NotePropertyName Diagnostic -NotePropertyValue ("Launcher stderr:`n" + $childResult.StandardError + "`nLauncher stdout:`n" + $childResult.StandardOutput)
        $childResult
    }
}

Describe 'AC-016: actual launcher keeps environment paths literal through both Windows shells' -Tag 'Launcher', 'NativeProcess' {
    It 'passes <FileName> exactly from <ShellName> through inner PS5.1 to the native child' -ForEach $launcherPathCases {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$ShellName is unavailable."; return }
        $folder = New-WacLauncherTestFolder
        $inputFile = Join-Path $folder $FileName
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $outputFolder = Join-Path $folder 'out [1] & %WAC_LAUNCH_PERCENT_TOKEN% !'
        $result = Invoke-WacLauncherTestCase -ShellPath $ShellPath -Folder $folder -InputFile $inputFile -OutputFolder $outputFolder -DefinePercentToken
        $result.ExitCode | Should -Be 0 -Because $result.Diagnostic
        $result.StandardOutput | Should -Not -Match 'Select Processing Mode|Press any key|(?m)^WAC_UNEXPECTED_COMMAND(?:\.wav)?\s*$'
        $recordFile = Join-Path $folder 'recorded-argv.json'
        Test-Path -LiteralPath $recordFile | Should -BeTrue
        $nativeArguments = Get-Content -LiteralPath $recordFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $inputIndex = [Array]::IndexOf($nativeArguments, '-i')
        $inputIndex | Should -BeGreaterOrEqual 0
        $nativeArguments[$inputIndex + 1] | Should -BeExactly $inputFile
        $nativeArguments | Should -Contain '-nostdin'
        $outputArgument = @($nativeArguments | Where-Object { $_ -like '*.partial' })
        $outputArgument.Count | Should -Be 1
        [IO.Path]::GetDirectoryName($outputArgument[0]) | Should -BeExactly $outputFolder
        Test-Path -LiteralPath $outputArgument[0] | Should -BeFalse
        $published = @(Get-ChildItem -LiteralPath $outputFolder -Filter '*.wav')
        $published.Count | Should -Be 1
        $published[0].Name | Should -Match '_Cleaned_[0-9]{8}-[0-9]{9}_[a-f0-9]{32}\.wav$'
        [IO.File]::ReadAllBytes($inputFile).Length | Should -Be 3
    }

    It 'preserves the default single-file handoff for <FileName> from <ShellName>' -ForEach $defaultLauncherPathCases {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$ShellName is unavailable."; return }
        $folder = New-WacLauncherTestFolder
        [IO.File]::Copy((Join-Path $PSScriptRoot 'fixtures/LauncherApplicationStub.ps1'), (Join-Path $folder 'WinAudioClean.ps1'), $true)
        $inputFile = Join-Path $folder $FileName
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $result = Invoke-WacLauncherTestCase -ShellPath $ShellPath -Folder $folder -InputFile $inputFile -OutputFolder (Join-Path $folder 'out') -Route Positional
        $result.ExitCode | Should -Be 0 -Because $result.Diagnostic
        $nativeArguments = Get-Content -LiteralPath (Join-Path $folder 'recorded-argv.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $nativeArguments[0] | Should -BeExactly '-i'
        $nativeArguments[1] | Should -BeExactly $inputFile
        $nativeArguments[3] | Should -BeExactly '5'
        $result.StandardOutput | Should -Not -Match '(?m)^WAC_UNEXPECTED_COMMAND(?:\.wav)?\s*$'
    }

    It 'accepts an environment destination with a trailing backslash from <ShellName>' -ForEach $launcherShellCases {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$ShellName is unavailable."; return }
        $folder = New-WacLauncherTestFolder
        $inputFile = Join-Path $folder 'input.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $outputFolder = Join-Path $folder 'out [1]'
        $result = Invoke-WacLauncherTestCase -ShellPath $ShellPath -Folder $folder -InputFile $inputFile -OutputFolder $outputFolder -TrailingOutputSeparator
        $result.ExitCode | Should -Be 0 -Because $result.Diagnostic
        $nativeArguments = Get-Content -LiteralPath (Join-Path $folder 'recorded-argv.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $outputArgument = @($nativeArguments | Where-Object { $_ -like '*.partial' })
        $outputArgument.Count | Should -Be 1
        [IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($outputArgument[0])).TrimEnd('\') | Should -BeExactly $outputFolder
        Test-Path -LiteralPath $outputArgument[0] | Should -BeFalse
        @(Get-ChildItem -LiteralPath $outputFolder -Filter '*.wav').Count | Should -Be 1
    }

    It 'passes a 240-character input path exactly from <ShellName>' -ForEach $launcherShellCases {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$ShellName is unavailable."; return }
        $folder = New-WacLauncherTestFolder
        $paddingLength = 240 - $folder.Length - 2 - 'input.wav'.Length
        $paddingLength | Should -BeGreaterThan 0
        $inputParent = Join-Path $folder ('p' * $paddingLength)
        $null = [IO.Directory]::CreateDirectory($inputParent)
        $inputFile = Join-Path $inputParent 'input.wav'
        $inputFile.Length | Should -Be 240
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $result = Invoke-WacLauncherTestCase -ShellPath $ShellPath -Folder $folder -InputFile $inputFile -OutputFolder (Join-Path $folder 'out')
        $result.ExitCode | Should -Be 0 -Because $result.Diagnostic
        $nativeArguments = Get-Content -LiteralPath (Join-Path $folder 'recorded-argv.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $inputIndex = [Array]::IndexOf($nativeArguments, '-i')
        $nativeArguments[$inputIndex + 1] | Should -BeExactly $inputFile
    }

    It 'rejects positional percent expansion before a defined-token decoy can be processed in <ShellName>' -ForEach $launcherShellCases {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$ShellName is unavailable."; return }
        $folder = New-WacLauncherTestFolder
        $inputFile = Join-Path $folder 'meeting %WAC_LAUNCH_PERCENT_TOKEN%.wav'
        $decoyFile = Join-Path $folder 'meeting expanded-decoy.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        [IO.File]::WriteAllBytes($decoyFile, [byte[]]@(9, 9))
        $result = Invoke-WacLauncherTestCase -ShellPath $ShellPath -Folder $folder -InputFile $inputFile -OutputFolder (Join-Path $folder 'output') -Route Positional -DefinePercentToken
        $result.ExitCode | Should -Be 2 -Because $result.Diagnostic
        $result.StandardError | Should -Match 'CMD can change percent or exclamation'
        Test-Path -LiteralPath (Join-Path $folder 'recorded-argv.json') | Should -BeFalse
        [IO.File]::ReadAllBytes($decoyFile).Length | Should -Be 2
    }
}

Describe 'AC-017: launcher preserves application status and has a bounded unattended route' -Tag 'Launcher', 'NativeProcess' {
    It 'preserves status for <Scenario> from <ShellName>' -ForEach $launcherExitCases {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$ShellName is unavailable."; return }
        $folder = New-WacLauncherTestFolder
        $inputFile = Join-Path $folder 'input.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        if ($Dependency -eq 'invalid') { [IO.File]::WriteAllBytes((Join-Path $folder 'ffmpeg.exe'), [byte[]]@(1)) }
        $result = Invoke-WacLauncherTestCase -ShellPath $ShellPath -Folder $folder -InputFile $inputFile -OutputFolder (Join-Path $folder 'output') -NativeExitCode $NativeExitCode -BlockLog:$BlockLog
        $result.ExitCode | Should -Be $ExpectedExit -Because $result.Diagnostic
        $result.StandardOutput | Should -Not -Match 'Press any key|Select Processing Mode'
        if ($ExpectedExit -ne 0) { $result.StandardOutput | Should -Not -Match 'DONE: SUCCESS' }
    }

    It 'rejects <Route> without starting native processing from <ShellName>' -ForEach $launcherInvalidCases {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$ShellName is unavailable."; return }
        $folder = New-WacLauncherTestFolder
        $inputFile = Join-Path $folder 'input.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $result = Invoke-WacLauncherTestCase -ShellPath $ShellPath -Folder $folder -InputFile $inputFile -OutputFolder (Join-Path $folder 'output') -Route $Route
        $result.ExitCode | Should -Be 2 -Because $result.Diagnostic
        Test-Path -LiteralPath (Join-Path $folder 'recorded-argv.json') | Should -BeFalse
        $result.StandardOutput | Should -Not -Match 'Running WinAudioClean|DONE: SUCCESS'
    }

    It 'preserves missing-input failure after the default pause in <ShellName>' -ForEach $launcherShellCases {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$ShellName is unavailable."; return }
        $folder = New-WacLauncherTestFolder
        $result = Invoke-WacLauncherTestCase -ShellPath $ShellPath -Folder $folder -InputFile (Join-Path $folder 'missing.wav') -OutputFolder (Join-Path $folder 'output') -Route Positional
        $result.ExitCode | Should -Be 2 -Because $result.Diagnostic
        $result.StandardError | Should -Match 'Input file does not exist'
        Test-Path -LiteralPath (Join-Path $folder 'recorded-argv.json') | Should -BeFalse
    }

    It 'preserves a controlled application cancellation status after pause in <ShellName>' -ForEach $launcherShellCases {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$ShellName is unavailable."; return }
        $folder = New-WacLauncherTestFolder
        [IO.File]::Copy((Join-Path $PSScriptRoot 'fixtures/LauncherApplicationStub.ps1'), (Join-Path $folder 'WinAudioClean.ps1'), $true)
        $inputFile = Join-Path $folder 'input.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $result = Invoke-WacLauncherTestCase -ShellPath $ShellPath -Folder $folder -InputFile $inputFile -OutputFolder (Join-Path $folder 'out') -Route Positional -NativeExitCode 130
        $result.ExitCode | Should -Be 130 -Because $result.Diagnostic
    }
}
