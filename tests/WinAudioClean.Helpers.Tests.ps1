BeforeAll {
    $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'WinAudioClean.ps1'
    . $scriptPath
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    # Independent literal expectations protect the reviewed filter sound. Do not
    # build these from production constants or from the helper under test.
    $rawFilters = 'adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
    $zoomFilters = 'dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5'
}

Describe 'Processing profiles preserve the reviewed baseline sound' -Tag 'Unit' {
    It 'selects the exact original Raw mode and filters for choice 1' {
        $processingProfile = Get-WacProcessingProfile -Choice '1'
        $processingProfile.ModeName | Should -BeExactly 'RAW (Clean+Level)'
        $processingProfile.FilterChain | Should -BeExactly $rawFilters
    }

    It 'selects the exact original Zoom mode and filters for choice 2' {
        $processingProfile = Get-WacProcessingProfile -Choice '2'
        $processingProfile.ModeName | Should -BeExactly 'ZOOM (Level Only)'
        $processingProfile.FilterChain | Should -BeExactly $zoomFilters
    }

    It 'characterizes the legacy invalid-choice fallback to Zoom (<Choice>)' -ForEach @(
        @{ Choice = '' }, @{ Choice = 'invalid' }, @{ Choice = '3' }
    ) {
        # Known validation defect, scheduled for WAC-M1-01. This freezes the
        # extraction baseline only; accepting invalid input is not a goal.
        $processingProfile = Get-WacProcessingProfile -Choice $Choice
        $processingProfile.ModeName | Should -BeExactly 'ZOOM (Level Only)'
        $processingProfile.FilterChain | Should -BeExactly $zoomFilters
    }
}

Describe 'Output naming and command construction preserve extraction behavior' -Tag 'Unit' {
    It 'keeps spaces, brackets and extra dots in the stem while replacing its extension' {
        Get-WacOutputPath -InputPath 'C:\WAC input\Meeting [draft].v2.m4a' -OutputFolder 'C:\WAC output' -Timestamp '20261002-1200' |
            Should -BeExactly 'C:\WAC output\Meeting [draft].v2_Cleaned_20261002-1200.wav'
    }

    It 'accepts an input stem without an extension' {
        Get-WacOutputPath -InputPath 'C:\WAC input\meeting' -OutputFolder 'C:\WAC output' -Timestamp '20261002-1200' |
            Should -BeExactly 'C:\WAC output\meeting_Cleaned_20261002-1200.wav'
    }

    It 'characterizes the legacy minute-timestamp collision' {
        # Known collision risk, scheduled for WAC-M1-04. No files are created.
        $first = Get-WacOutputPath -InputPath 'C:\WAC input\same.wav' -OutputFolder 'C:\WAC output' -Timestamp '20261002-1200'
        $second = Get-WacOutputPath -InputPath 'C:\WAC input\same.mp3' -OutputFolder 'C:\WAC output' -Timestamp '20261002-1200'
        $first | Should -BeExactly 'C:\WAC output\same_Cleaned_20261002-1200.wav'
        $second | Should -BeExactly $first
    }

    It 'quotes paths and the filter string in the original FFmpeg argument order' {
        $arguments = Get-WacFfmpegArguments -InputPath 'C:\WAC input\speaker [1].wav' -FilterChain $rawFilters -OutputFile 'C:\WAC output\speaker [1]_Cleaned.wav'
        $expected = '-i "C:\WAC input\speaker [1].wav" -vn -af "adeclip,highpass=f=80,adeclick,afftdn=nf=-25,agate=range=0.056:threshold=0.0056,dynaudnorm=f=200:g=11:p=0.85:m=20:s=12,loudnorm=I=-12:TP=-1.5" "C:\WAC output\speaker [1]_Cleaned.wav" -y -hide_banner -loglevel error -stats'
        $arguments | Should -BeOfType [string]
        $arguments | Should -BeExactly $expected
    }

    It 'characterizes the legacy overwrite flag pending transactional output work' {
        # WAC-M1-04 will replace this unsafe baseline. This does not authorize
        # overwriting recordings or prior exports, and no process runs here.
        Get-WacFfmpegArguments -InputPath 'input.wav' -FilterChain $zoomFilters -OutputFile 'output.wav' |
            Should -Match '"output\.wav" -y -hide_banner -loglevel error -stats$'
    }
}

Describe 'AC-005: importing helpers is unattended and has no side effects' -Tag 'Import' {
    It 'imports silently in a fresh current-shell host without prompts, processes, writes or exit' {
        $scratch = Join-Path $TestDrive 'import working directory'
        $null = New-Item -ItemType Directory -Path $scratch
        $currentShell = (Get-Process -Id $PID).Path
        $fixture = Join-Path $PSScriptRoot 'fixtures\Import-Safety.ps1'
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -ScriptPath {1}' -f
            (ConvertTo-WacTestQuotedArgument $fixture), (ConvertTo-WacTestQuotedArgument $scriptPath)
        $result = Invoke-WacTestProcess -FilePath $currentShell -Arguments $arguments -WorkingDirectory $scratch
        $result.ExitCode | Should -Be 0
        $result.StandardOutput.Trim() | Should -BeExactly 'WAC_IMPORT_COMPLETED'
        $result.StandardError | Should -BeNullOrEmpty
        @(Get-ChildItem -LiteralPath $scratch -Force -Recurse).Count | Should -Be 0
    }
}
