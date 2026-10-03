BeforeDiscovery {
    $transportHosts = foreach ($name in @('powershell.exe', 'pwsh.exe')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        @{ Name = $name; HostPath = $command.Source; Major = $(if ($name -eq 'powershell.exe') { 5 } else { 7 }); Unavailable = $null -eq $command }
    }
}

BeforeAll {
    $transportRepository = Split-Path $PSScriptRoot -Parent
    . (Join-Path $transportRepository 'WinAudioClean.Launcher.ps1')
    . (Join-Path $PSScriptRoot 'fixtures/TestProcess.ps1')
    $transportUtf8 = New-Object Text.UTF8Encoding($false)
    $transportUnicode = ([string][char]0x00E4) + [char]0x00F6 + [char]0x00C5
    function New-WacTransportFolder {
        $path = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($path)
        $path
    }
    function Get-WacTransportFrame {
        param([string]$LauncherPath, [string[]]$Arguments = @())
        $tokens = @('"' + $LauncherPath + '"') + @($Arguments | ForEach-Object { '"' + $_ + '"' })
        'cmd.exe /d /s /c "' + ($tokens -join ' ') + '"'
    }
    function New-WacTransportSandbox {
        $path = New-WacTransportFolder
        foreach ($name in @('WinAudioClean.bat', 'WinAudioClean.Launcher.ps1')) {
            [IO.File]::Copy((Join-Path $transportRepository $name), (Join-Path $path $name))
        }
        [IO.File]::Copy((Join-Path $PSScriptRoot 'fixtures/LauncherMatrixApplicationStub.ps1'), (Join-Path $path 'WinAudioClean.ps1'))
        [pscustomobject]@{ Root = $path; Launcher = Join-Path $path 'WinAudioClean.bat'
            Manifest = Join-Path $path 'list %WAC_TRANSPORT_PERCENT%!literal!.json'
            Record = Join-Path $path 'received parameters.json'; Config = Join-Path $path 'isolated settings.json'
            Output = Join-Path $path 'output [draft] %literal%!'; Sentinel = Join-Path $path 'shell sentinel.txt' }
    }
    function Invoke-WacTransportCmd {
        param($Sandbox, [string[]]$Arguments = @(), [string]$InnerHost, [hashtable]$ExtraEnvironment = @{}, [int]$ApplicationExit = 0)
        $tokens = @('"' + $Sandbox.Launcher + '"') + @($Arguments | ForEach-Object { '"' + $_ + '"' })
        $command = '/d /s /c "' + ($tokens -join ' ') + '"'
        $environment = @{ WAC_TRANSPORT_RECORD_PATH = $Sandbox.Record; WAC_TRANSPORT_APP_EXIT = [string]$ApplicationExit
            WAC_LAUNCH_SETTINGS_PATH = $Sandbox.Config; WAC_LAUNCH_IGNORE_SAVED_SETTINGS = '1'
            WAC_LAUNCH_POWERSHELL = $InnerHost; WAC_LAUNCH_INPUT = $null; WAC_LAUNCH_INPUT_LIST_PATH = $null
            WAC_LAUNCH_OUTPUT_DIRECTORY = $null; WAC_TRANSPORT_PERCENT = 'expanded-decoy'; PSModulePath = $null }
        foreach ($name in $ExtraEnvironment.Keys) { $environment[$name] = $ExtraEnvironment[$name] }
        Invoke-WacTestProcess -FilePath (Join-Path $env:SystemRoot 'System32/cmd.exe') -Arguments $command -WorkingDirectory $Sandbox.Root -EnvironmentVariables $environment -StandardInput "`r`n" -TimeoutMilliseconds 30000
    }
}

Describe 'AC-052/054: launcher request parsing accepts narrow verified CMD frames' -Tag 'Launcher', 'Batch', 'Unit' {
    It 'retains every quoted safe character-rich path in order and maps multiple inputs as typed data' {
        $launcher = Join-Path (New-WacTransportFolder) 'WinAudioClean.bat'
        $arguments = @('C:\audio\spaces [draft].wav', "C:\audio\speaker's $transportUnicode (take 1) & guest.wav", 'C:\audio\name & echo WAC_LAUNCH_SHELL_SENTINEL.wav')
        $request = Get-WacLauncherRequest -Arguments $arguments -LauncherPath $launcher -CommandLine (Get-WacTransportFrame -LauncherPath $launcher -Arguments $arguments)
        $request.InputPaths.Count | Should -Be 3
        for ($index = 0; $index -lt $arguments.Count; $index++) { $request.InputPaths[$index] | Should -BeExactly $arguments[$index] }
        $request.Pause | Should -BeTrue
        $request.NonInteractive | Should -BeFalse
    }

    It 'rejects <Case> before application invocation' -ForEach @(
        @{ Case = 'percent token'; Argument = 'C:\audio\%TOKEN%.wav'; Frame = $null }
        @{ Case = 'exclamation token'; Argument = 'C:\audio\!TOKEN!.wav'; Frame = $null }
        @{ Case = 'different original token'; Argument = 'C:\audio\a.wav'; Frame = 'cmd.exe /c "C:\different.bat" "C:\audio\a.wav"' }
        @{ Case = 'existing CMD session'; Argument = 'C:\audio\a.wav'; Frame = 'cmd.exe' }
        @{ Case = 'unquoted operator'; Argument = 'C:\audio\a.wav'; Frame = 'cmd.exe /c C:\launcher.bat C:\audio\a.wav & echo WAC_LAUNCH_SHELL_SENTINEL' }
        @{ Case = 'unbalanced quote'; Argument = 'C:\audio\a.wav'; Frame = 'cmd.exe /c "C:\launcher.bat' }
        @{ Case = 'capture unavailable'; Argument = 'C:\audio\a.wav'; Frame = '__WAC_CAPTURE_FAILED__' }
    ) {
        $launcher = 'C:\launcher.bat'
        $line = if ($Frame) { $Frame } else { Get-WacTransportFrame -LauncherPath $launcher -Arguments @($Argument) }
        { Get-WacLauncherRequest -Arguments @($Argument) -LauncherPath $launcher -CommandLine $line } | Should -Throw
    }

    It 'accepts a 7599-character original frame and rejects 7600 with manifest guidance' {
        $launcher = 'C:\launcher.bat'
        $arguments = @('C:\audio\a.wav')
        $line = Get-WacTransportFrame -LauncherPath $launcher -Arguments $arguments
        $line = $line + (' ' * (7599 - $line.Length))
        (Get-WacLauncherRequest -Arguments $arguments -LauncherPath $launcher -CommandLine $line).InputPaths.Count | Should -Be 1
        { Get-WacLauncherRequest -Arguments $arguments -LauncherPath $launcher -CommandLine ($line + ' ') } | Should -Throw '*manifest*'
    }

    It 'accepts 1024 captured arguments and rejects excess or an explicit capture-overflow marker' {
        $launcher = 'C:\launcher.bat'
        $arguments = @('a') * 1024
        $line = Get-WacTransportFrame -LauncherPath $launcher -Arguments $arguments
        (Get-WacLauncherRequest -Arguments $arguments -LauncherPath $launcher -CommandLine $line).InputPaths.Count | Should -Be 1024
        { Get-WacLauncherRequest -Arguments ($arguments + 'b') -LauncherPath $launcher -CommandLine $line } | Should -Throw '*1024*'
        { Get-WacLauncherRequest -Arguments @('a') -LauncherPath $launcher -CommandLine $line -CaptureOverflow $true } | Should -Throw '*1024*'
    }

    It 'keeps special-character manifest and single-environment paths literal without CMD evaluation' {
        $path = "C:\audio\spaces %TOKEN%! $transportUnicode & speaker's (take).json"
        $manifest = Get-WacLauncherRequest -Arguments @('/manifest') -InputListPath $path -CommandLine 'cmd.exe' -SettingsPath 'C:\isolated settings.json' -IgnoreSavedSettings $true
        $manifest.InputListPath | Should -BeExactly $path
        $manifest.Pause | Should -BeTrue
        $manifest.IgnoreSavedSettings | Should -BeTrue
        $single = Get-WacLauncherRequest -Arguments @('/unattended', 'Zoom') -InputPath $path -OutputDirectory 'C:\output [draft] %literal%!' -CommandLine 'cmd.exe'
        $single.InputPaths[0] | Should -BeExactly $path
        $single.NonInteractive | Should -BeTrue
        $single.Pause | Should -BeFalse
    }

    It 'rejects the <Case> control route' -ForEach @(
        @{ Case = 'manifest and single input'; Arguments = @('/manifest'); InputValue = 'a.wav'; List = 'list.json'; Output = '' }
        @{ Case = 'extra manifest argument'; Arguments = @('/manifest', 'extra'); InputValue = ''; List = 'list.json'; Output = '' }
        @{ Case = 'missing manifest'; Arguments = @('/manifest'); InputValue = ''; List = ''; Output = '' }
        @{ Case = 'two unattended sources'; Arguments = @('/unattended', 'Zoom'); InputValue = 'a.wav'; List = 'list.json'; Output = 'C:\output' }
        @{ Case = 'no unattended source'; Arguments = @('/unattended', 'Zoom'); InputValue = ''; List = ''; Output = 'C:\output' }
        @{ Case = 'invalid mode'; Arguments = @('/unattended', 'invalid'); InputValue = 'a.wav'; List = ''; Output = 'C:\output' }
        @{ Case = 'extra unattended argument'; Arguments = @('/unattended', 'Zoom', 'extra'); InputValue = 'a.wav'; List = ''; Output = 'C:\output' }
    ) {
        { Get-WacLauncherRequest -Arguments $Arguments -InputPath $InputValue -InputListPath $List -OutputDirectory $Output } | Should -Throw
    }

    It 'forwards exactly one legacy string or one typed array and preserves status' -ForEach @(@{ Count = 1 }, @{ Count = 3 }) {
        $arguments = @('C:\audio\a.wav') * $Count
        $launcher = 'C:\launcher.bat'
        $request = Get-WacLauncherRequest -Arguments $arguments -LauncherPath $launcher -CommandLine (Get-WacTransportFrame -LauncherPath $launcher -Arguments $arguments)
        Mock Invoke-WacLauncherApplication {
            param($ScriptPath, $Parameters)
            if ($Count -eq 1) {
                $Parameters.inputPath | Should -BeExactly 'C:\audio\a.wav'
                $Parameters.ContainsKey('InputPaths') | Should -BeFalse
            } else { $Parameters.InputPaths -is [string[]] | Should -BeTrue; $Parameters.InputPaths.Count | Should -Be 3 }
            7
        }
        $result = @(Invoke-WacLauncherRequest -Request $request -ScriptPath 'unused.ps1')
        $result.Count | Should -Be 1
        $result[0] | Should -Be 7
        Should -Invoke Invoke-WacLauncherApplication -Times 1 -Exactly
    }
}

Describe 'AC-052/054: real CMD and the actual BAT forward to both inner PowerShell hosts' -Tag 'Launcher', 'Batch', 'EntryPoint' {
    It 'passes the safe single and ordered multiple-file matrix exactly to <Name>' -ForEach $transportHosts {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$Name is unavailable."; return }
        $sandbox = New-WacTransportSandbox
        $inputs = @('space [draft].wav', "speaker's $transportUnicode (take) & guest.wav", 'name & echo WAC_LAUNCH_SHELL_SENTINEL.wav') | ForEach-Object { Join-Path $sandbox.Root $_ }
        foreach ($path in $inputs) { [IO.File]::WriteAllBytes($path, [byte[]](1, 2, 3)) }
        foreach ($requested in @(@($inputs[0]), @($inputs))) {
            if (Test-Path -LiteralPath $sandbox.Record) { [IO.File]::Delete($sandbox.Record) }
            $result = Invoke-WacTransportCmd -Sandbox $sandbox -Arguments $requested -InnerHost $HostPath
            $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
            $received = Get-Content -Encoding UTF8 -Raw -LiteralPath $sandbox.Record | ConvertFrom-Json
            $received.shellMajor | Should -Be $Major
            $received.inputs.Count | Should -Be $requested.Count
            for ($index = 0; $index -lt $requested.Count; $index++) { $received.inputs[$index] | Should -BeExactly $requested[$index] }
            $received.SettingsPath | Should -BeExactly $sandbox.Config
            $received.IgnoreSavedSettings | Should -BeTrue
            $result.StandardOutput | Should -Not -Match '(?m)^WAC_LAUNCH_SHELL_SENTINEL(?:\.wav)?\s*$'
            Test-Path -LiteralPath $sandbox.Sentinel | Should -BeFalse
        }
    }

    It 'passes all special names and >8191 manifest payload literally to <Name>' -ForEach $transportHosts {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$Name is unavailable."; return }
        $sandbox = New-WacTransportSandbox
        $inputs = @(1..120 | ForEach-Object { Join-Path $sandbox.Root ("recording {0:D3} %WAC_TRANSPORT_PERCENT%! $transportUnicode [draft] & speaker's (take).wav" -f $_) })
        [IO.File]::WriteAllText($sandbox.Manifest, (([ordered]@{ schemaVersion = 1; inputs = $inputs }) | ConvertTo-Json -Compress), $transportUtf8)
        (Get-Item -LiteralPath $sandbox.Manifest).Length | Should -BeGreaterThan 8191
        $result = Invoke-WacTransportCmd -Sandbox $sandbox -Arguments @('/unattended', 'Zoom') -InnerHost $HostPath -ExtraEnvironment @{ WAC_LAUNCH_INPUT_LIST_PATH = $sandbox.Manifest; WAC_LAUNCH_OUTPUT_DIRECTORY = $sandbox.Output }
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $received = Get-Content -Encoding UTF8 -Raw -LiteralPath $sandbox.Record | ConvertFrom-Json
        $received.shellMajor | Should -Be $Major
        $received.inputs.Count | Should -Be 120
        for ($index = 0; $index -lt $inputs.Count; $index++) { $received.inputs[$index] | Should -BeExactly $inputs[$index] }
        $received.InputListPath | Should -BeExactly $sandbox.Manifest
        $received.OutputDirectory | Should -BeExactly $sandbox.Output
        $received.NonInteractive | Should -BeTrue
        $result.StandardOutput | Should -Not -Match 'Press any key'
    }

    It 'rejects defined percent-token expansion before processing a decoy through <Name>' -ForEach $transportHosts {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$Name is unavailable."; return }
        $sandbox = New-WacTransportSandbox
        $raw = Join-Path $sandbox.Root 'recording %WAC_TRANSPORT_PERCENT%.wav'
        $decoy = Join-Path $sandbox.Root 'recording expanded-decoy.wav'
        [IO.File]::WriteAllBytes($raw, [byte[]](1, 2, 3))
        [IO.File]::WriteAllBytes($decoy, [byte[]](9, 9))
        $result = Invoke-WacTransportCmd -Sandbox $sandbox -Arguments @($raw) -InnerHost $HostPath
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.Record | Should -BeFalse
        [IO.File]::ReadAllBytes($decoy).Length | Should -Be 2
    }

    It 'forwards 30 long paths without loss and rejects 32 before work through <Name>' -ForEach $transportHosts {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$Name is unavailable."; return }
        $sandbox = New-WacTransportSandbox
        $padding = 240 - $sandbox.Root.Length - 2 - 'input001.wav'.Length
        $padding | Should -BeGreaterThan 0
        $parent = Join-Path $sandbox.Root ('p' * $padding)
        $null = [IO.Directory]::CreateDirectory($parent)
        $inputs = @(1..32 | ForEach-Object { Join-Path $parent ('input{0:D3}.wav' -f $_) })
        foreach ($inputFile in $inputs) { $inputFile.Length | Should -Be 240; [IO.File]::WriteAllBytes($inputFile, [byte[]](1, 2, 3)) }
        $result = Invoke-WacTransportCmd -Sandbox $sandbox -Arguments $inputs[0..29] -InnerHost $HostPath
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $received = Get-Content -Encoding UTF8 -Raw -LiteralPath $sandbox.Record | ConvertFrom-Json
        $received.inputs.Count | Should -Be 30
        for ($index = 0; $index -lt 30; $index++) { $received.inputs[$index] | Should -BeExactly $inputs[$index] }
        [IO.File]::Delete($sandbox.Record)
        $result = Invoke-WacTransportCmd -Sandbox $sandbox -Arguments $inputs -InnerHost $HostPath
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardError | Should -Match '7600|manifest'
        Test-Path -LiteralPath $sandbox.Record | Should -BeFalse
    }

    It 'shows no-input guidance and starts no app through <Name>' -ForEach $transportHosts {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$Name is unavailable."; return }
        $sandbox = New-WacTransportSandbox
        $result = Invoke-WacTransportCmd -Sandbox $sandbox -InnerHost $HostPath
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardError | Should -Match 'Drop one or more|manifest'
        Test-Path -LiteralPath $sandbox.Record | Should -BeFalse
    }

    It 'preserves cancellation130 after the interactive-route pause through <Name>' -ForEach $transportHosts {
        if ($Unavailable) { Set-ItResult -Skipped -Because "$Name is unavailable."; return }
        $sandbox = New-WacTransportSandbox
        $result = Invoke-WacTransportCmd -Sandbox $sandbox -Arguments @((Join-Path $sandbox.Root 'input.wav')) -InnerHost $HostPath -ApplicationExit 130
        $result.ExitCode | Should -Be 130 -Because ($result.StandardOutput + $result.StandardError)
    }

    It 'preserves selected-worker startup failure3 through one parent pause without starting the application' {
        $sandbox = New-WacTransportSandbox
        $invalidImage = Join-Path $sandbox.Root 'invalid worker.exe'
        [IO.File]::WriteAllBytes($invalidImage, [byte[]](1, 2, 3))
        $result = Invoke-WacTransportCmd -Sandbox $sandbox -Arguments @((Join-Path $sandbox.Root 'input.wav')) -InnerHost $invalidImage
        $result.ExitCode | Should -Be 3 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardError | Should -Match 'PowerShell worker could not start'
        @([regex]::Matches($result.StandardOutput, 'Press any key')).Count | Should -Be 1
        Test-Path -LiteralPath $sandbox.Record | Should -BeFalse
    }
}
