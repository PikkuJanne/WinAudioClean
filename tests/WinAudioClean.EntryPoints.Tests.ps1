BeforeDiscovery {
    $shellCases = @()
    foreach ($shellName in @('powershell.exe', 'pwsh.exe')) {
        $command = Get-Command -Name $shellName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $shellCases += @{ ShellName = $shellName; ShellPath = $command.Source; Unavailable = ($null -eq $command) }
    }
    $controlledCases = foreach ($shell in $shellCases) {
        foreach ($mode in @('1', '2')) {
            foreach ($exitCode in @(0, 7)) {
                @{
                    ShellName = $shell.ShellName; ShellPath = $shell.ShellPath
                    Unavailable = $shell.Unavailable; Mode = $mode; ProcessExitCode = $exitCode
                }
            }
        }
    }
    $preflightCases = foreach ($shell in $shellCases) {
        foreach ($case in @(
            @{ Scenario = 'no input'; Diagnostic = 'No input file supplied' },
            @{ Scenario = 'directory'; Diagnostic = 'Input must be a file' },
            @{ Scenario = 'URL'; Diagnostic = 'Only filesystem paths' },
            @{ Scenario = 'zero bytes'; Diagnostic = 'zero bytes' },
            @{ Scenario = 'destination file'; Diagnostic = 'Output directory cannot be created' },
            @{ Scenario = 'empty destination'; Diagnostic = 'filesystem path is required' },
            @{ Scenario = 'invalid mode'; Diagnostic = 'Invalid mode' },
            @{ Scenario = 'empty mode'; Diagnostic = 'Invalid mode' },
            @{ Scenario = 'missing mode'; Diagnostic = 'mode is required for unattended use' },
            @{ Scenario = 'redirected input'; Diagnostic = 'mode is required for unattended use' },
            @{ Scenario = 'host noninteractive'; Diagnostic = 'mode is required for unattended use' }
        )) {
            @{
                ShellName = $shell.ShellName; ShellPath = $shell.ShellPath; Unavailable = $shell.Unavailable
                Scenario = $case.Scenario; Diagnostic = $case.Diagnostic
            }
        }
    }
}

BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $scriptPath = Join-Path $repositoryRoot 'WinAudioClean.ps1'
    $launcherPath = Join-Path $repositoryRoot 'WinAudioClean.bat'
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
}

Describe 'AC-004: actual entry points with bounded, controlled input' -Tag 'EntryPoint' {
    It 'AC-014: rejects missing -File -inputPath before prompting in <ShellName>' -ForEach $shellCases {
        if ($Unavailable) {
            Set-ItResult -Skipped -Because "$ShellName is unavailable on this machine; this shell was not tested."
            return
        }
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $scratch
        $missingInput = Join-Path $scratch 'missing recording with spaces.wav'
        $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File {0} -inputPath {1}' -f
            (ConvertTo-WacTestQuotedArgument $scriptPath), (ConvertTo-WacTestQuotedArgument $missingInput)
        $result = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $scratch
        $result.ExitCode | Should -Be 2
        $result.StandardOutput | Should -Not -Match 'Select Processing Mode|Enter selection'
        $result.StandardError | Should -Match 'Input file does not exist'
        $result.StandardOutput | Should -Not -Match 'Running WinAudioClean|DONE: SUCCESS'
        @(Get-ChildItem -LiteralPath $scratch -Force -Recurse).Count | Should -Be 0
    }

    It 'AC-014: rejects a missing dropped file via outer <ShellName> before the menu (inner Windows PowerShell)' -ForEach $shellCases {
        if ($Unavailable) {
            Set-ItResult -Skipped -Because "$ShellName is unavailable on this machine; this outer shell was not tested."
            return
        }
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $scratch
        $missingInput = Join-Path $scratch 'missing dropped recording.wav'
        $fixture = Join-Path $PSScriptRoot 'fixtures\Invoke-Launcher.ps1'
        $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File {0} -LauncherPath {1} -InputPath {2}' -f
            (ConvertTo-WacTestQuotedArgument $fixture), (ConvertTo-WacTestQuotedArgument $launcherPath), (ConvertTo-WacTestQuotedArgument $missingInput)
        $result = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $scratch -StandardInput "`r`n"
        $result.StandardOutput | Should -Not -Match 'Select Processing Mode|Enter selection'
        $result.StandardError | Should -Match 'Input file does not exist'
        $result.StandardOutput | Should -Not -Match 'Running WinAudioClean|DONE: SUCCESS'
        @(Get-ChildItem -LiteralPath $scratch -Force -Recurse).Count | Should -Be 0
        # The existing launcher pause and exit propagation belong to M1-02.
    }
}

Describe 'AC-014/015: actual script preflight is bounded and unattended on invalid requests' -Tag 'EntryPoint', 'Preflight' {
    It 'rejects <Scenario> without a menu or processing in <ShellName>' -ForEach $preflightCases {
        if ($Unavailable) {
            Set-ItResult -Skipped -Because "$ShellName is unavailable on this machine; this shell was not tested."
            return
        }
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $scratch
        $inputFile = Join-Path $scratch 'synthetic [input].wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $outputDirectory = Join-Path $scratch 'destination [literal]'
        $hostSwitch = ''
        $scriptSwitch = '-NonInteractive'
        $modeSwitch = ''
        switch ($Scenario) {
            'no input' { $inputFile = '' }
            'directory' { $inputFile = $scratch }
            'URL' { $inputFile = 'https://example.invalid/recording.wav' }
            'zero bytes' { [IO.File]::WriteAllBytes($inputFile, [byte[]]@()) }
            'destination file' { [IO.File]::WriteAllText($outputDirectory, 'keep this file') }
            'empty destination' { $outputDirectory = '' }
            'invalid mode' { $modeSwitch = '-Mode invalid' }
            'empty mode' { $modeSwitch = '-Mode ""' }
            'redirected input' { $scriptSwitch = '' }
            'host noninteractive' { $scriptSwitch = ''; $hostSwitch = '-NonInteractive' }
        }
        $inputArgument = if ($inputFile) { '-inputPath ' + (ConvertTo-WacTestQuotedArgument $inputFile) } else { '' }
        $outputArgument = if ($outputDirectory) { ConvertTo-WacTestQuotedArgument $outputDirectory } else { '""' }
        $arguments = '-NoLogo -NoProfile {0} -ExecutionPolicy Bypass -File {1} {2} -OutputDirectory {3} {4} {5}' -f
            $hostSwitch, (ConvertTo-WacTestQuotedArgument $scriptPath), $inputArgument, $outputArgument, $scriptSwitch, $modeSwitch
        $result = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $scratch
        $result.ExitCode | Should -Be 2
        $result.StandardError | Should -Match ([regex]::Escape($Diagnostic))
        $result.StandardOutput | Should -Not -Match 'Select Processing Mode|Enter selection|Running WinAudioClean|DONE: SUCCESS'
        @(Get-ChildItem -LiteralPath $scratch -Recurse -Force -Filter '*.tmp').Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $scratch -Recurse -Filter 'WinAudioClean_Log.txt').Count | Should -Be 0
        if ($Scenario -eq 'destination file') { [IO.File]::ReadAllText($outputDirectory) | Should -BeExactly 'keep this file' }
    }
}

Describe 'Controlled runtime execution preserves mode, process and report wiring' -Tag 'Runtime' {
    It 'uses choice <Mode> and reports process exit <ProcessExitCode> in <ShellName>' -ForEach $controlledCases {
        if ($Unavailable) {
            Set-ItResult -Skipped -Because "$ShellName is unavailable on this machine; this shell was not tested."
            return
        }
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $scratch
        $fixture = Join-Path $PSScriptRoot 'fixtures\Invoke-ControlledApplication.ps1'
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -ScriptPath {1} -Choice {2} -ProcessExitCode {3}' -f
            (ConvertTo-WacTestQuotedArgument $fixture), (ConvertTo-WacTestQuotedArgument $scriptPath), $Mode, $ProcessExitCode
        $result = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $scratch
        $result.ExitCode | Should -Be 0
        $result.StandardError | Should -BeNullOrEmpty
        $run = $result.StandardOutput | ConvertFrom-Json
        @($run.Processes).Count | Should -Be 1
        @($run.Logs).Count | Should -Be 1
        $run.Processes[0].FileName | Should -BeExactly 'ffmpeg.exe'
        $run.Processes[0].Wait | Should -BeTrue
        $run.Processes[0].NoNewWindow | Should -BeTrue
        $run.Processes[0].PassThru | Should -BeTrue
        $filters = 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
        $modeName = 'ZOOM (Level Only)'
        if ($Mode -eq '1') {
            $filters = 'adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056,' + $filters
            $modeName = 'RAW (Clean+Level)'
        }
        $expectedArguments = '-i "C:\WAC synthetic input\meeting sample.wav" -vn -af "{0}" "C:\WAC synthetic output\meeting sample_Cleaned_20261002-1200.wav" -y -hide_banner -loglevel error -stats' -f $filters
        $run.Processes[0].Arguments | Should -BeExactly $expectedArguments
        $run.Logs[0].FileName | Should -BeExactly 'WinAudioClean_Log.txt'
        $run.Logs[0].Value | Should -Match ('MODE\s+: ' + [regex]::Escape($modeName))
        $run.Logs[0].Value | Should -Match ('ACTIVE FILTERS : ' + [regex]::Escape($filters))
        $run.Logs[0].Value | Should -Match 'LOG DATE\s+: 2026-10-02 12:00:00'
        $status = if ($ProcessExitCode -eq 0) { 'SUCCESS' } else { 'FAILED' }
        $run.Logs[0].Value | Should -Match ('STATUS\s+: ' + $status + ' \(Exit Code: ' + $ProcessExitCode + '\)')
        ($run.HostMessages -join "`n") | Should -Match "DONE: $status"
        @(Get-ChildItem -LiteralPath $scratch -Force -Recurse).Count | Should -Be 0
    }
}
