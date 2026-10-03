BeforeDiscovery {
    $shellCases = @()
    foreach ($shellName in @('powershell.exe', 'pwsh.exe')) {
        $command = Get-Command -Name $shellName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $shellCases += @{ ShellName = $shellName; ShellPath = $command.Source; Unavailable = ($null -eq $command) }
    }
    $controlledCases = foreach ($shell in $shellCases) {
        foreach ($mode in @('1', '2')) {
            foreach ($exitCode in @(0, 7)) {
              foreach ($blockLog in @($false, $true)) {
                @{
                    ShellName = $shell.ShellName; ShellPath = $shell.ShellPath
                    Unavailable = $shell.Unavailable; Mode = $mode; ProcessExitCode = $exitCode; BlockLog = $blockLog
                }
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
    $dependencyCases = foreach ($shell in $shellCases) {
        foreach ($brokenExecutable in @($false, $true)) {
            @{
                ShellName = $shell.ShellName; ShellPath = $shell.ShellPath; Unavailable = $shell.Unavailable
                BrokenExecutable = $brokenExecutable
            }
        }
    }
    $directPathCases = foreach ($shell in $shellCases) {
        foreach ($fileName in @(
            'spaces here.wav', '[square brackets].wav', "speaker's recording.wav",
            ('Unicode ' + [char]0x00e4 + [char]0x00f6 + [char]0x00c5 + '.wav'), 'ampersand & here.wav', '%PATH% literal.wav',
            '!PATH! literal.wav', '(parentheses).wav', 'name & echo WAC_UNEXPECTED_COMMAND.wav'
        )) {
            @{
                ShellName = $shell.ShellName; ShellPath = $shell.ShellPath; Unavailable = $shell.Unavailable
                FileName = $fileName
            }
        }
    }
    $publicationFailureCases = foreach ($shell in $shellCases) {
        foreach ($scenario in @('empty', 'header', 'truncated', 'short', 'malformed output probe', 'failed output probe', 'missing input duration', 'input aliases log')) {
            @{
                ShellName = $shell.ShellName; ShellPath = $shell.ShellPath; Unavailable = $shell.Unavailable
                Scenario = $scenario
            }
        }
    }
}

Describe 'AC-023/AC-024: invalid output is never published and reporting preserves source bytes' -Tag 'OutputSafety', 'Runtime', 'Native' {
    It 'handles <Scenario> in the actual application in <ShellName>' -ForEach $publicationFailureCases {
        if ($Unavailable) {
            Set-ItResult -Skipped -Because "$ShellName is unavailable on this machine; this shell was not tested."
            return
        }
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $outputDirectory = Join-Path $scratch 'output'
        $null = [IO.Directory]::CreateDirectory($outputDirectory)
        $app = Join-Path $scratch 'WinAudioClean.ps1'
        Copy-Item -LiteralPath $scriptPath -Destination $app
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'WinAudioClean.IO.ps1') -Destination $scratch
        Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $scratch 'ffmpeg.exe')
        Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $scratch 'ffprobe.exe')
        $inputFile = Join-Path $scratch 'recording.wav'
        if ($Scenario -eq 'input aliases log') { $inputFile = Join-Path $outputDirectory 'WinAudioClean_Log.txt' }
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(11, 22, 33, 44))
        $priorExport = Join-Path $outputDirectory 'prior.wav'
        [IO.File]::WriteAllBytes($priorExport, [byte[]]@(55, 66, 77))
        $argvPath = Join-Path $scratch 'render-argv.json'
        $childEnvironment = @{
            WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_ARGV_PATH = $argvPath
            WAC_TEST_EXIT_CODE = '0'
        }
        $expectedExit = 5
        switch ($Scenario) {
            { $_ -in @('empty', 'header', 'truncated', 'short') } { $childEnvironment.WAC_TEST_OUTPUT_MODE = $Scenario }
            'malformed output probe' { $childEnvironment.WAC_TEST_OUTPUT_PROBE_STDOUT = '{bad json' }
            'failed output probe' { $childEnvironment.WAC_TEST_OUTPUT_PROBE_EXIT_CODE = '9' }
            'missing input duration' {
                $childEnvironment.WAC_TEST_PROBE_STDOUT = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"pcm_s16le","channels":1,"sample_rate":"48000"}]}'
                $expectedExit = 4
            }
            'input aliases log' { $expectedExit = 7 }
        }
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -inputPath {1} -OutputDirectory {2} -Mode Zoom -NonInteractive' -f
            (ConvertTo-WacTestQuotedArgument $app), (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument $outputDirectory)
        $result = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $scratch -EnvironmentVariables $childEnvironment
        $result.ExitCode | Should -Be $expectedExit -Because ("stdout: {0}; stderr: {1}" -f $result.StandardOutput, $result.StandardError)
        $result.StandardOutput | Should -Not -Match 'DONE: SUCCESS'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputFile)) | Should -BeExactly 'CxYhLA=='
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($priorExport)) | Should -BeExactly 'N0JN'
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter '*.partial' -Force).Count | Should -Be 0
        $published = @(Get-ChildItem -LiteralPath $outputDirectory -Filter '*.wav' | Where-Object { $_.FullName -ne $priorExport })
        if ($Scenario -eq 'input aliases log') {
            $published.Count | Should -Be 1
            $published[0].Length | Should -Be 288044
            $result.StandardOutput | Should -Match 'DONE: WARNING'
        } else {
            $published.Count | Should -Be 0
        }
        if ($Scenario -eq 'missing input duration') {
            Test-Path -LiteralPath $argvPath | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $outputDirectory 'WinAudioClean_Log.txt') | Should -BeFalse
        } else {
            Test-Path -LiteralPath $argvPath | Should -BeTrue
        }
    }
}

BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $scriptPath = Join-Path $repositoryRoot 'WinAudioClean.ps1'
    $launcherPath = Join-Path $repositoryRoot 'WinAudioClean.bat'
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
    $nativeFixture = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'native fixture.exe')
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

Describe 'AC-017: actual native execution reports success, failure and reporting warnings' -Tag 'Runtime', 'Native' {
    It 'AC-016: preserves <FileName> through direct <ShellName> -File and the native child' -ForEach $directPathCases {
        if ($Unavailable) {
            Set-ItResult -Skipped -Because "$ShellName is unavailable on this machine; this shell was not tested."
            return
        }
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = [IO.Directory]::CreateDirectory($scratch)
        $app = Join-Path $scratch 'WinAudioClean.ps1'
        Copy-Item -LiteralPath $scriptPath -Destination $app
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'WinAudioClean.IO.ps1') -Destination $scratch
        Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $scratch 'ffmpeg.exe')
        Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $scratch 'ffprobe.exe')
        $inputFile = Join-Path $scratch $FileName
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $outputDirectory = Join-Path $scratch 'output [1] & %PATH% !'
        $argvPath = Join-Path $scratch 'argv.json'
        $probeArgvPath = Join-Path $scratch 'probe-argv.json'
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -inputPath {1} -OutputDirectory {2} -Mode Zoom -NonInteractive' -f
            (ConvertTo-WacTestQuotedArgument $app), (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument ($outputDirectory + '\'))
        $result = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $scratch -EnvironmentVariables @{
            WAC_TEST_ARGV_PATH = $argvPath; WAC_TEST_EXIT_CODE = '0'; WAC_TEST_FFMPEG_OUTPUT = '1'
            WAC_TEST_PROBE_ARGV_PATH = $probeArgvPath
        }
        $result.ExitCode | Should -Be 0 -Because ("stdout: {0}; stderr: {1}" -f $result.StandardOutput, $result.StandardError)
        $received = Get-Content -Raw -LiteralPath $argvPath -Encoding UTF8 | ConvertFrom-Json
        $probeArguments = Get-Content -Raw -LiteralPath $probeArgvPath -Encoding UTF8 | ConvertFrom-Json
        $probeArguments | Should -BeExactly @('-v', 'error', '-protocol_whitelist', 'file', '-format_whitelist',
            'wav,mp3,flac,ogg,mov,matroska,webm,aac,aiff,asf,avi', '-show_entries',
            'stream=index,codec_type,codec_name,channels,channel_layout,sample_rate,duration,start_time:stream_tags=language,title,DURATION',
            '-of', 'json', '-i', $inputFile)
        $inputIndex = [Array]::IndexOf($received, '-i')
        $inputIndex | Should -BeGreaterOrEqual 0
        $received[$inputIndex + 1] | Should -BeExactly $inputFile
        $outputFile = $received[[Array]::IndexOf($received, '-y') - 1]
        # The final file remains inside the literal destination, regardless of
        # trailing separators; its actual native argv is what is checked here.
        [IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($outputFile)).TrimEnd('\') | Should -BeExactly $outputDirectory
        [IO.Path]::GetFileName($outputFile) | Should -Match '^\.wac-[a-f0-9]{32}\.partial$'
        Test-Path -LiteralPath $outputFile | Should -BeFalse
        $published = @(Get-ChildItem -LiteralPath $outputDirectory -Filter '*.wav')
        $published.Count | Should -Be 1
        $published[0].Name | Should -Match ('^' + [regex]::Escape([IO.Path]::GetFileNameWithoutExtension($FileName)) + '_Cleaned_[0-9]{8}-[0-9]{9}_[a-f0-9]{32}\.wav$')
        $published[0].Length | Should -Be 288044
        [IO.File]::ReadAllBytes($inputFile).Count | Should -Be 3
        $result.StandardOutput | Should -Match 'DONE: SUCCESS'
    }

    It 'returns dependency failure for invalid executable <BrokenExecutable> in <ShellName>' -ForEach $dependencyCases {
        if ($Unavailable) {
            Set-ItResult -Skipped -Because "$ShellName is unavailable on this machine; this shell was not tested."
            return
        }
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = [IO.Directory]::CreateDirectory($scratch)
        $app = Join-Path $scratch 'WinAudioClean.ps1'
        Copy-Item -LiteralPath $scriptPath -Destination $app
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'WinAudioClean.IO.ps1') -Destination $scratch
        $inputFile = Join-Path $scratch 'input.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $outputDirectory = Join-Path $scratch 'output'
        if ($BrokenExecutable) { [IO.File]::WriteAllText((Join-Path $scratch 'ffmpeg.exe'), 'invalid executable') }
        Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $scratch 'ffprobe.exe')
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -inputPath {1} -OutputDirectory {2} -Mode Zoom -NonInteractive' -f
            (ConvertTo-WacTestQuotedArgument $app), (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument $outputDirectory)
        $result = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $scratch -EnvironmentVariables @{ PATH = '' }
        $result.ExitCode | Should -Be 3
        $result.StandardError | Should -Not -BeNullOrEmpty
        $result.StandardOutput | Should -Not -Match 'DONE: SUCCESS|Enter selection'
        # Inspection now rejects the dependency before the rendering/reporting
        # stage, so no render report should suggest that cleaning was attempted.
        $result.StandardOutput | Should -Not -Match 'Running WinAudioClean|DONE:'
        Test-Path -LiteralPath (Join-Path $outputDirectory 'WinAudioClean_Log.txt') | Should -BeFalse
        if (-not $BrokenExecutable) { $result.StandardError | Should -Match 'ffmpeg.exe.*not found|not found.*ffmpeg.exe' }
        @(Get-ChildItem -LiteralPath $outputDirectory -Filter '*.wav').Count | Should -Be 0
    }

    It 'uses mode <Mode>, native exit <ProcessExitCode>, blocked log <BlockLog> in <ShellName>' -ForEach $controlledCases {
        if ($Unavailable) {
            Set-ItResult -Skipped -Because "$ShellName is unavailable on this machine; this shell was not tested."
            return
        }
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $scratch
        $app = Join-Path $scratch 'WinAudioClean.ps1'
        Copy-Item -LiteralPath $scriptPath -Destination $app
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'WinAudioClean.IO.ps1') -Destination $scratch
        Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $scratch 'ffmpeg.exe')
        Copy-Item -LiteralPath $nativeFixture -Destination (Join-Path $scratch 'ffprobe.exe')
        $inputFile = Join-Path $scratch 'meeting [draft].wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $outputDirectory = Join-Path $scratch 'output [literal]'
        $argvPath = Join-Path $scratch 'argv.json'
        $modeValue = if ($Mode -eq '1') { 'Raw' } else { 'Zoom' }
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -inputPath {1} -OutputDirectory {2} -Mode {3} -NonInteractive' -f
            (ConvertTo-WacTestQuotedArgument $app), (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument $outputDirectory), $modeValue
        $childEnvironment = @{
            WAC_TEST_ARGV_PATH = $argvPath; WAC_TEST_EXIT_CODE = [string]$ProcessExitCode
            WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_BLOCK_LOG = [string][int]$BlockLog
            WAC_TEST_STDOUT = "out_time_us=1500000`nprogress=continue`nout_time_us=3000000`nprogress=end`n"
            WAC_TEST_STDERR = 'Native stderr retained'
        }
        $result = Invoke-WacTestProcess -FilePath $ShellPath -Arguments $arguments -WorkingDirectory $scratch -EnvironmentVariables $childEnvironment
        $expectedExit = if ($ProcessExitCode -ne 0) { 4 } elseif ($BlockLog) { 7 } else { 0 }
        $result.ExitCode | Should -Be $expectedExit -Because ("stdout: {0}; stderr: {1}" -f $result.StandardOutput, $result.StandardError)
        $result.StandardError | Should -BeNullOrEmpty
        $result.StandardOutput | Should -Not -Match '(?m)^out_time_us=|^progress=(continue|end)'
        $result.StandardOutput | Should -Match 'Native stderr retained'
        $argv = Get-Content -Raw -LiteralPath $argvPath | ConvertFrom-Json
        $filters = 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
        $modeName = 'ZOOM (Level Only)'
        if ($Mode -eq '1') {
            $filters = 'adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056,' + $filters
            $modeName = 'RAW (Clean+Level)'
        }
        $argv.Count | Should -Be 36
        $argv[0] | Should -BeExactly '-progress'
        $argv[1] | Should -BeExactly 'pipe:1'
        $argv[2] | Should -BeExactly '-nostdin'
        $argv | Should -Contain '-nostats'
        $argv | Should -Not -Contain '-stats'
        $argv[[Array]::IndexOf($argv, '-protocol_whitelist') + 1] | Should -BeExactly 'file'
        $argv[[Array]::IndexOf($argv, '-format_whitelist') + 1] | Should -BeExactly 'wav,mp3,flac,ogg,mov,matroska,webm,aac,aiff,asf,avi'
        $argv[[Array]::IndexOf($argv, '-i') + 1] | Should -BeExactly $inputFile
        $argv[[Array]::IndexOf($argv, '-map') + 1] | Should -BeExactly '0:0'
        $argv[[Array]::IndexOf($argv, '-af') + 1] | Should -BeExactly $filters
        $argv[[Array]::IndexOf($argv, '-f') + 1] | Should -BeExactly 'wav'
        foreach ($pair in @(@('-ar', '48000'), @('-c:a', 'pcm_s16le'), @('-ac', '1'), @('-channel_layout', 'mono'), @('-rf64', 'never'), @('-map_metadata', '-1'), @('-map_chapters', '-1'))) {
            $argv[[Array]::IndexOf($argv, $pair[0]) + 1] | Should -BeExactly $pair[1]
        }
        $outputFile = $argv[[Array]::IndexOf($argv, '-y') - 1]
        [IO.Path]::GetDirectoryName($outputFile) | Should -BeExactly $outputDirectory
        $status = if ($expectedExit -eq 0) { 'SUCCESS' } elseif ($expectedExit -eq 7) { 'WARNING' } else { 'FAILED' }
        $result.StandardOutput | Should -Match "DONE: $status"
        if ($expectedExit -ne 0) { $result.StandardOutput | Should -Not -Match 'DONE: SUCCESS' }
        if ($BlockLog) { $result.StandardOutput | Should -Match 'Report could not be written' }
        else {
            $log = Get-Content -Raw -LiteralPath (Join-Path $outputDirectory 'WinAudioClean_Log.txt')
            $log | Should -Match ('MODE\s+: ' + [regex]::Escape($modeName))
            $log | Should -Match ('ACTIVE FILTERS : ' + [regex]::Escape($filters))
            $log | Should -Match "Native Exit Code: $ProcessExitCode; Application Exit Code: $expectedExit"
            $log | Should -Not -Match '(?m)^out_time_us=|^progress=(continue|end)'
            $log | Should -Match 'Native stderr retained'
            $log | Should -Match ('EXECUTABLE\s+: ' + [regex]::Escape((Join-Path $scratch 'ffmpeg.exe')))
            $log | Should -Match ('FFPROBE\s+: ' + [regex]::Escape((Join-Path $scratch 'ffprobe.exe')))
            $log | Should -Match 'FFMPEG VERSION\s+: ffmpeg version 9\.0\.2-wac-fixture'
            $log | Should -Match 'FFPROBE VERSION\s*: ffprobe version 9\.0\.2-wac-fixture'
            $log | Should -Match 'AUDIO STREAM\s+: 0 \(absolute index; map 0:0\)'
        }
        $jsonFiles = @(Get-ChildItem -LiteralPath $outputDirectory -Filter 'WinAudioClean_*.json')
        $jsonFiles.Count | Should -Be 1
        $report = Get-Content -Raw -LiteralPath $jsonFiles[0].FullName | ConvertFrom-Json
        $report.diagnostics.standardOutput | Should -BeNullOrEmpty
        $report.diagnostics.standardError | Should -BeExactly 'Native stderr retained'
        $rendering = @($report.progress.stages | Where-Object { $_.stage -eq 'Rendering' })
        $rendering.Count | Should -Be 1
        $rendering[0].snapshot.Blocks | Should -Be 2
        $rendering[0].snapshot.OutTimeMicroseconds | Should -Be 3000000
        $rendering[0].structuredEnd | Should -BeTrue
        $rendering[0].percent | Should -BeGreaterOrEqual 0
        $rendering[0].percent | Should -BeLessOrEqual 90
        $report.progress.completed | Should -Be ($ProcessExitCode -eq 0)
        if ($ProcessExitCode -ne 0) { @($report.progress.stages | Where-Object { $_.percent -eq 100 }).Count | Should -Be 0 }
        Test-Path -LiteralPath $outputFile | Should -BeFalse
        $published = @(Get-ChildItem -LiteralPath $outputDirectory -Filter '*.wav')
        if ($ProcessExitCode -eq 0) {
            $published.Count | Should -Be 1
            $published[0].Length | Should -Be 288044
            $published[0].Name | Should -Match '_Cleaned_[0-9]{8}-[0-9]{9}_[a-f0-9]{32}\.wav$'
        } else { $published.Count | Should -Be 0 }
        [IO.File]::ReadAllBytes($inputFile).Count | Should -Be 3
    }
}
