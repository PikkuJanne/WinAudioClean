BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $scriptPath = Join-Path $repositoryRoot 'WinAudioClean.ps1'
    . $scriptPath
    . (Join-Path $PSScriptRoot 'fixtures\TestProcess.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\New-NativeProcessFixture.ps1')
    $presetShell = (Get-Process -Id $PID).Path
    $presetNativeFixture = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'preset fixture.exe')
    $baseline = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs\codex\winaudioclean\BASELINE.json') | ConvertFrom-Json

    function New-WacPresetSandbox {
        param([switch]$Menu)

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($root)
        $app = Join-Path $root 'WinAudioClean.ps1'
        $source = [IO.File]::ReadAllText($scriptPath)
        if ($Menu) {
            # Override only the host boundary in this disposable script copy.
            # Read-WacMode, profile selection, rendering and reporting stay real.
            # This is bounded menu integration, not Explorer/keyboard validation.
            $injection = @'
function Test-WacInteractive { param([switch]$NonInteractive) $true }
function Clear-Host {}
function Read-Host {
    param([string]$Prompt)
    if ($script:WacPresetPrompted) { throw 'Unexpected extra menu prompt.' }
    $script:WacPresetPrompted = $true
    Write-Host ('PRESET_TEST_PROMPT: ' + $Prompt)
    $env:WAC_PRESET_TEST_CHOICE
}
'@
            $marker = '# Explicit local support export bypasses media/dependency initialization.'
            if (-not $source.Contains($marker)) { throw 'Cannot locate the test-only host boundary.' }
            $source = $source.Replace($marker, ($injection + "`n" + $marker))
        }
        [IO.File]::WriteAllText($app, $source, [Text.UTF8Encoding]::new($true))
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'WinAudioClean.IO.ps1') -Destination $root
        foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
            Copy-Item -LiteralPath $presetNativeFixture -Destination (Join-Path $root $name)
        }
        $inputFile = Join-Path $root 'synthetic input.wav'
        [IO.File]::WriteAllBytes($inputFile, [byte[]]@(1, 2, 3))
        [pscustomobject]@{
            Root = $root; App = $app; Input = $inputFile
            Output = Join-Path $root 'output'; Argv = Join-Path $root 'argv.json'
        }
    }
}

Describe 'AC-035/036: Original identity belongs to each unchanged processing profile' -Tag 'Preset', 'Unit' {
    It 'names and versions the Original <Mode> profile separately from its mode' -ForEach @(
        @{ Choice = '1'; Mode = 'Raw'; ModeName = 'RAW (Clean+Level)' }
        @{ Choice = '2'; Mode = 'Zoom'; ModeName = 'ZOOM (Level Only)' }
    ) {
        $presetProfile = Get-WacProcessingProfile -Choice $Choice
        $presetProfile.PresetId | Should -BeExactly 'original'
        $presetProfile.PresetName | Should -BeExactly 'Original'
        $presetProfile.PresetVersion | Should -BeExactly '1.0.0'
        $presetProfile.ModeName | Should -BeExactly $ModeName
        $expectedFilters = $baseline.filters.level
        if ($Mode -eq 'Raw') { $expectedFilters = $baseline.filters.raw_clean + ',' + $expectedFilters }
        $presetProfile.FilterChain | Should -BeExactly $expectedFilters
    }
}

Describe 'AC-036: menu choices and direct invocations persist the effective Original preset' -Tag 'Preset', 'Runtime', 'Native' {
    It 'records the Original <Mode> preset through <Invocation>' -ForEach @(
        @{ Mode = 'Raw'; Choice = '1'; Invocation = 'menu'; Menu = $true }
        @{ Mode = 'Zoom'; Choice = '2'; Invocation = 'menu'; Menu = $true }
        @{ Mode = 'Raw'; Choice = '1'; Invocation = 'direct -Mode'; Menu = $false }
        @{ Mode = 'Zoom'; Choice = '2'; Invocation = 'direct -Mode'; Menu = $false }
    ) {
        $sandbox = New-WacPresetSandbox -Menu:$Menu
        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -inputPath {1} -OutputDirectory {2}' -f
            (ConvertTo-WacTestQuotedArgument $sandbox.App), (ConvertTo-WacTestQuotedArgument $sandbox.Input),
            (ConvertTo-WacTestQuotedArgument $sandbox.Output)
        if (-not $Menu) { $arguments += ' -Mode ' + $Mode + ' -NonInteractive' }
        $result = Invoke-WacTestProcess -FilePath $presetShell -Arguments $arguments -WorkingDirectory $sandbox.Root -EnvironmentVariables @{
            WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_EXIT_CODE = '0'; WAC_TEST_ARGV_PATH = $sandbox.Argv
            WAC_PRESET_TEST_CHOICE = $Choice; PSMODULEPATH = $null
        } -TimeoutMilliseconds 40000
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput | Should -Match 'DONE: SUCCESS'
        if ($Menu) {
            $result.StandardOutput | Should -Match 'Select Processing Mode \(Original preset\)'
            ([regex]::Matches($result.StandardOutput, 'PRESET_TEST_PROMPT:')).Count | Should -Be 1
            $result.StandardOutput | Should -Match 'Enter selection'
        } else {
            $result.StandardOutput | Should -Not -Match 'Select Processing Mode|PRESET_TEST_PROMPT:|Enter selection'
        }
        $jsonFiles = @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json')
        $jsonFiles.Count | Should -Be 1
        $jsonText = Get-Content -Raw -LiteralPath $jsonFiles[0].FullName
        $report = $jsonText | ConvertFrom-Json
        $report.presetId | Should -BeExactly 'original'
        $report.presetName | Should -BeExactly 'Original'
        $report.presetVersion | Should -BeExactly '1.0.0'
        $jsonText | Should -Match '"presetVersionReason"\s*:\s*null'
        $report.toolVersion | Should -BeExactly '2.3'
        $report.toolVersion | Should -Not -Be $report.presetVersion
        $report.settings.mode | Should -BeExactly $Mode
        $report.status | Should -BeExactly 'SUCCESS'
        $expectedFilters = $baseline.filters.level
        if ($Mode -eq 'Raw') { $expectedFilters = $baseline.filters.raw_clean + ',' + $expectedFilters }
        $report.settings.exactFilters | Should -BeExactly $expectedFilters
        $argv = Get-Content -Raw -LiteralPath $sandbox.Argv | ConvertFrom-Json
        $argv[[Array]::IndexOf($argv, '-af') + 1] | Should -BeExactly $expectedFilters
        $text = Get-Content -Raw -LiteralPath ([IO.Path]::ChangeExtension($jsonFiles[0].FullName, '.txt'))
        $summary = Get-Content -Raw -LiteralPath (Join-Path $sandbox.Output 'WinAudioClean_Log.txt')
        foreach ($human in @($text, $summary)) {
            $human | Should -Match '(?m)^PRESET\s+: Original \(ID: original; version: 1\.0\.0\)\r?$'
            $human | Should -Match '(?m)^TOOL VERSION\s+: 2\.3;'
            $human | Should -Not -Match 'preset not_versioned'
            $human | Should -Match ([regex]::Escape($report.jobId))
        }
    }
}

Describe 'AC-029/036: support export does not invent or disclose preset versions' -Tag 'Preset', 'RunReports', 'Unit' {
    It 'keeps <Case> identity and version fields out of the redacted projection' -ForEach @(
        @{ Case = 'legacy unversioned'; PresetId = $null; PresetName = $null; PresetVersion = $null; Reason = 'not_versioned'; ToolVersion = '2.3' }
        @{ Case = 'current Original'; PresetId = 'original'; PresetName = 'Original'; PresetVersion = '1.0.0'; Reason = $null; ToolVersion = '2.3' }
        @{ Case = 'unknown private'; PresetId = 'PRIVATE_ID'; PresetName = 'PRIVATE_NAME'; PresetVersion = 'PRIVATE_VERSION'; Reason = 'PRIVATE_REASON'; ToolVersion = 'PRIVATE_TOOL' }
    ) {
        $report = [pscustomobject]@{
            schemaVersion = 1; status = 'SUCCESS'; processingStatus = 'SUCCESS'
            presetId = $PresetId; presetName = $PresetName; presetVersion = $PresetVersion
            presetVersionReason = $Reason; toolVersion = $ToolVersion
            settings = [pscustomobject]@{ mode = 'Raw' }
        }
        $safe = ConvertTo-WacRedactedReport -Report $report
        $safe.settings.mode | Should -BeExactly 'Raw'
        foreach ($field in @('presetId', 'presetName', 'presetVersion', 'presetVersionReason', 'toolVersion')) {
            $safe.Keys | Should -Not -Contain $field
        }
        ($safe | ConvertTo-Json -Depth 20) | Should -Not -Match 'PRIVATE_|1\.0\.0|not_versioned'
    }
}
