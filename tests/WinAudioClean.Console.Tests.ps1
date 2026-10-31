BeforeAll {
    $consoleRepo = Split-Path $PSScriptRoot -Parent
    . (Join-Path $consoleRepo 'WinAudioClean.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    $consoleShell = (Get-Process -Id $PID).Path
}

Describe 'Signal console uses real state and readable host rendering' -Tag 'Console', 'Unit' {
    BeforeEach {
        $script:consoleCapture = New-Object 'System.Collections.Generic.List[string]'
        Mock Write-Host { param($Object) $script:consoleCapture.Add([string]$Object) }
        $script:WacConsoleDesignEnabled = $false
    }

    AfterEach { $script:WacConsoleDesignEnabled = $false }

    It 'captures the menu at width <Width> without claiming capabilities are ready' -ForEach @(
        @{ Width = 79 }, @{ Width = 31 }
    ) {
        Write-WacConsoleHeader -Version '1.0.1' -InputPath 'C:\Inputs\interview.wav' -Width $Width
        Write-WacConsoleMenu -Preset Original -Width $Width
        $captured = $script:consoleCapture -join "`n"
        $captured | Should -Match 'WINAUDIOCLEAN'
        $captured | Should -Match 'SIGNAL\s+CONTROL'
        $captured | Should -Match 'v1\.0\.1'
        $captured | Should -Match 'INPUT   interview\.wav'
        $captured | Should -Match 'ENGINE  FOUND'
        $captured | Should -Match '\[1\] Raw recording'
        $captured | Should -Match '\[2\] Zoom / Teams'
        $captured | Should -Match '\[Q\] Cancel'
        $captured | Should -Not -Match '\bREADY\b|\x1b|[^\x00-\x7f]'
        foreach ($line in $script:consoleCapture) { $line.Length | Should -BeLessOrEqual $Width }
    }

    It 'retains a complete long output location and puts it directly after <Status> at width <Width>' -ForEach @(
        @{ Width = 79; Status = 'SUCCESS' }, @{ Width = 31; Status = 'SUCCESS' },
        @{ Width = 79; Status = 'WARNING' }, @{ Width = 31; Status = 'WARNING' }
    ) {
        $output = 'C:\Exports\a long folder [literal]\interview-processed.wav'
        Write-WacConsoleOutcome -Status $Status -OutputPath $output -Detail 'Validated audio. Details follow.' -Width $Width
        $captured = $script:consoleCapture -join "`n"
        $captured | Should -Match ('DONE: ' + $Status + '\nOUTPUT')
        ($captured -replace '\s', '') | Should -Match ([regex]::Escape((('OUTPUT' + $output) -replace '\s', '')))
        $captured | Should -Not -Match '\x1b|[^\x00-\x7f]'
        foreach ($line in $script:consoleCapture) { $line.Length | Should -BeLessOrEqual $Width }
    }

    It 'shows dependency reasons and a next step without a stack at width <Width>' -ForEach @(
        @{ Width = 79 }, @{ Width = 31 }
    ) {
        Write-WacDependencyFailure -Reason 'ffmpeg.exe not found.' -Interactive $true -Width $Width
        $captured = $script:consoleCapture -join "`n"
        $captured | Should -Match '^Dependency failed: ffmpeg.exe'
        $captured | Should -Match 'Next step:'
        $captured | Should -Not -Match 'READY|CategoryInfo|FullyQualifiedErrorId|\.ps1:\d|\x1b'
        foreach ($line in $script:consoleCapture) { $line.Length | Should -BeLessOrEqual $Width }
    }

    It 'captures real stage transitions without inventing percent or progress' {
        $script:WacConsoleDesignEnabled = $true
        $script:WacProgressStages = $null
        $script:WacRunContext = $null
        Mock Write-Progress {}
        $state = Add-WacProgressStage -Stage 'Rendering' -DurationSeconds 8
        $state.Percent | Should -Be 0
        $script:consoleCapture -join "`n" | Should -BeExactly 'STATUS  RENDERING'
        $null = Update-WacProgress -State $state
        $script:consoleCapture.Count | Should -Be 1
        $null = Add-WacProgressStage -Stage 'Validating'
        $script:consoleCapture -join "`n" | Should -BeExactly "STATUS  RENDERING`nSTATUS  VALIDATING"
    }

    It 'leaves ordinary progress output free of the new console status lines' {
        $script:WacProgressStages = $null
        $script:WacRunContext = $null
        Mock Write-Progress {}
        $null = Add-WacProgressStage -Stage 'Rendering' -DurationSeconds 8
        $script:consoleCapture.Count | Should -Be 0
    }

    It 'retains mode keys 1, 2 and Q' {
        Mock Read-WacHostSelection { '1' }
        Read-WacMode | Should -BeExactly Raw
        Mock Read-WacHostSelection { '2' }
        Read-WacMode | Should -BeExactly Zoom
        Mock Read-WacHostSelection { 'Q' }
        Read-WacMode | Should -BeNullOrEmpty
    }

    It 'falls back to plain host text if a host rejects foreground colors' {
        $script:rejectedColor = $false
        Mock Write-Host {
            param($Object, $ForegroundColor)
            if ($ForegroundColor) { $script:rejectedColor = $true; throw 'Host color unavailable.' }
            $script:consoleCapture.Add([string]$Object)
        }
        Write-WacConsoleText -Text 'ENGINE READY' -Tone Success
        $script:rejectedColor | Should -BeTrue
        $script:consoleCapture -join "`n" | Should -BeExactly 'ENGINE READY'
    }
}

Describe 'Expected dependency failures remain plain in redirected processes' -Tag 'Console', 'Runtime' {
    It 'returns dependency exit 3 without console decoration, a pause, stack trace or completed WAV' {
        $scratch = Join-Path $TestDrive 'redirected failure'
        $null = [IO.Directory]::CreateDirectory($scratch)
        $inputFile = Join-Path $scratch 'generated.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        $missing = Join-Path $scratch 'missing.exe'
        $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File {0} -inputPath {1} -Mode Zoom -OutputDirectory {2} -FfmpegPath {3} -IgnoreSavedSettings -NonInteractive' -f
            (ConvertTo-WacTestQuotedArgument (Join-Path $consoleRepo 'WinAudioClean.ps1')),
            (ConvertTo-WacTestQuotedArgument $inputFile), (ConvertTo-WacTestQuotedArgument $scratch),
            (ConvertTo-WacTestQuotedArgument $missing)
        $result = Invoke-WacTestProcess -FilePath $consoleShell -Arguments $arguments -WorkingDirectory $scratch
        $result.ExitCode | Should -Be 3
        $result.StandardError | Should -Match '^Dependency failed:'
        $result.StandardError | Should -Match 'Next step:'
        ($result.StandardOutput + $result.StandardError) | Should -Not -Match 'SIGNAL CONTROL|ENGINE  READY|Enter selection|Press any key|CategoryInfo|FullyQualifiedErrorId|\x1b|DONE: SUCCESS'
        @(Get-ChildItem -LiteralPath $scratch -Filter '*.wav').Count | Should -Be 1
    }
}

Describe 'Signal console snapshots through a private Windows console' -Tag 'Console', 'Runtime', 'Native' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
        $consoleNative = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'console-native.exe')
    }

    It 'captures actual <Status> rendering at native buffer width <Width>' -ForEach @(
        @{ Width = 80; Status = 'SUCCESS' }, @{ Width = 32; Status = 'SUCCESS' },
        @{ Width = 80; Status = 'WARNING' }, @{ Width = 32; Status = 'WARNING' },
        @{ Width = 80; Status = 'DEPENDENCY' }, @{ Width = 32; Status = 'DEPENDENCY' },
        @{ Width = 80; Status = 'PAN_DEPENDENCY' }, @{ Width = 32; Status = 'PAN_DEPENDENCY' }
    ) {
        $scratch = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($scratch)
        foreach ($component in @(Get-ChildItem -LiteralPath $consoleRepo -Filter 'WinAudioClean*.ps1')) {
            Copy-Item -LiteralPath $component.FullName -Destination $scratch
        }
        foreach ($tool in @('ffmpeg.exe', 'ffprobe.exe')) {
            Copy-Item -LiteralPath $consoleNative -Destination (Join-Path $scratch $tool)
        }
        $inputFile = Join-Path $scratch 'generated.wav'
        $channels = if ($Status -eq 'PAN_DEPENDENCY') { 2 } else { 1 }
        $dataBytes = 288000 * $channels
        $writer = [IO.BinaryWriter]::new([IO.File]::Create($inputFile))
        try {
            $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $writer.Write([int](36 + $dataBytes))
            $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $writer.Write([int]16)
            $writer.Write([int16]1); $writer.Write([int16]$channels); $writer.Write([int]48000); $writer.Write([int](96000 * $channels))
            $writer.Write([int16](2 * $channels)); $writer.Write([int16]16)
            $writer.Write([Text.Encoding]::ASCII.GetBytes('data')); $writer.Write([int]$dataBytes)
            $writer.Write((New-Object byte[] $dataBytes))
        } finally { $writer.Dispose() }
        $sourceHash = (Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash
        $casePath = Join-Path $scratch 'case.json'
        $resultPath = Join-Path $scratch 'snapshot.json'
        $caseData = @{ root = $scratch; input = $inputFile; output = (Join-Path $scratch 'exports')
            width = $Width; status = $Status; result = $resultPath }
        [IO.File]::WriteAllText($casePath, ($caseData | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
        $fixturePath = Join-Path $PSScriptRoot 'fixtures\Invoke-SignalConsoleCase.ps1'
        $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File {0} -CasePath {1}' -f
            (ConvertTo-WacTestQuotedArgument $fixturePath), (ConvertTo-WacTestQuotedArgument $casePath)
        $process = Start-Process -FilePath $consoleShell -ArgumentList $arguments -WindowStyle Hidden -PassThru
        try {
            if (-not $process.WaitForExit(30000)) {
                & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $process.Id /T /F | Out-Null
                throw 'Private console snapshot exceeded its 30-second deadline.'
            }
        } finally { $process.Dispose() }
        Test-Path -LiteralPath $resultPath | Should -BeTrue
        $result = [IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
        $result.error | Should -BeNullOrEmpty
        $result.width | Should -Be $Width
        (Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash | Should -BeExactly $sourceHash
        $snapshot = $result.completed -replace '\s', ' '
        $snapshot | Should -Not -Match 'CategoryInfo|FullyQualifiedErrorId|\x1b'
        if ($Status -in @('DEPENDENCY', 'PAN_DEPENDENCY')) {
            $result.exitCode | Should -Be 3
            $result.inputInjected | Should -Be ($Status -eq 'PAN_DEPENDENCY')
            $snapshot | Should -Match 'Dependency failed:'
            $snapshot | Should -Match 'Next step:'
            $snapshot | Should -Not -Match 'DONE: SUCCESS|\bREADY\b'
            if ($Status -eq 'PAN_DEPENDENCY') { $snapshot | Should -Match 'pan' }
            @(Get-ChildItem -LiteralPath $caseData.output -Filter '*.wav').Count | Should -Be 0
        } else {
            $expectedExit = if ($Status -eq 'SUCCESS') { 0 } else { 7 }
            $result.exitCode | Should -Be $expectedExit
            $result.inputInjected | Should -BeTrue
            $result.menu | Should -Match 'WINAUDIOCLEAN'
            $result.menu | Should -Match '\[1\] Raw recording'
            $result.menu | Should -Match '\[2\] Zoom / Teams'
            $result.menu | Should -Match '\[Q\] Cancel'
            $result.menu | Should -Not -Match '\bREADY\b'
            $snapshot | Should -Match 'ENGINE\s+READY'
            $snapshot | Should -Match 'STATUS\s+RENDERING'
            $snapshot | Should -Match 'STATUS\s+VALIDATING'
            $snapshot | Should -Match ('DONE:\s+' + $Status)
            $snapshot | Should -Match 'OUTPUT'
            @(Get-ChildItem -LiteralPath $caseData.output -Filter '*.wav').Count | Should -Be 1
        }
    }
}
