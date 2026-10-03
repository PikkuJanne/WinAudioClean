BeforeAll {
    $previewReportRepository = Split-Path $PSScriptRoot -Parent
    . (Join-Path $previewReportRepository 'WinAudioClean.ps1')
    . (Join-Path $previewReportRepository 'WinAudioClean.Preview.ps1')
    . (Join-Path $PSScriptRoot 'fixtures\ReportCloseFault.ps1')
    $realPreviewReportOpen = ${function:Open-WacReportWriter}
    $realPreviewReportSet = ${function:Set-WacOwnedReportContent}
}

Describe 'AC-030/045/068: Preview report close faults retain flushed outcomes and primary errors' -Tag 'Preview', 'Unit', 'Report', 'ReportCloseFault', 'FaultInjection' {
    BeforeEach {
        $previewReportFolder = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($previewReportFolder)
        $previewReport = [ordered]@{
            jobId = 'owned-close-case'; status = 'SUCCESS'; applicationExitCode = 0
            reporting = [ordered]@{ complete = $true; paths = $null; errors = @() }
            assets = [ordered]@{}; range = [ordered]@{ startSeconds = 0; durationSeconds = 3 }
            input = [ordered]@{ streamIndex = 0 }; timeline = [ordered]@{}
            settings = [ordered]@{ mode = 'Zoom'; loudnessMode = 'Fast' }
            alignment = [ordered]@{}; matching = [ordered]@{}
        }
        $script:previewReportWriters = New-Object 'System.Collections.Generic.List[object]'
        $script:previewReportStreams = New-Object 'System.Collections.Generic.List[object]'
        $script:previewReportFaultKinds = $CloseKinds
        $script:previewReportPrimaryWriteFault = $false
        $script:previewReportWarnings = @()
        Mock Open-WacReportWriter {
            param([string]$Path, [switch]$CreateNew)
            $writer = & $realPreviewReportOpen -Path $Path -CreateNew:$CreateNew -TimeoutMilliseconds 0
            $kind = [IO.Path]::GetExtension($Path).TrimStart('.')
            if ($script:previewReportFaultKinds -contains $kind) {
                $writer.Stream = New-WacReportCloseFaultStream -RealStream $writer.Stream -Label $kind
                $script:previewReportStreams.Add($writer.Stream)
            }
            $script:previewReportWriters.Add($writer)
            $writer
        }
        Mock Set-WacOwnedReportContent {
            param($Writer, [string]$Content)
            if ($script:previewReportPrimaryWriteFault -and [IO.Path]::GetExtension($Writer.Path) -eq '.txt') {
                throw 'Injected primary text report write failure.'
            }
            & $realPreviewReportSet -Writer $Writer -Content $Content
        }
    }
    AfterEach {
        # Cleanup is limited to the real streams opened by this test, even if
        # an old implementation skips a close after the injected diagnostic.
        foreach ($stream in $script:previewReportStreams) { $stream.ThrowOnDispose = $false; $stream.Dispose() }
        foreach ($writer in $script:previewReportWriters) {
            if ($writer.Stream -is [IO.Stream]) { $writer.Stream.Dispose() }
        }
    }

    It 'closes every writer after a post-dispose fault in <Case>' -ForEach @(
        @{ Case = 'the first JSON writer'; CloseKinds = @('json'); WarningCount = 1 }
        @{ Case = 'the second text writer'; CloseKinds = @('txt'); WarningCount = 1 }
        @{ Case = 'both writers'; CloseKinds = @('json', 'txt'); WarningCount = 2 }
    ) {
        $paths = Write-WacPreviewReports -Report $previewReport -OutputFolder $previewReportFolder -WarningVariable +script:previewReportWarnings
        @($paths).Count | Should -Be 1
        $script:previewReportWriters.Count | Should -Be 2
        foreach ($writer in $script:previewReportWriters) {
            $writer.Closed | Should -BeTrue
            $writer.Stream | Should -BeNullOrEmpty
        }
        foreach ($stream in $script:previewReportStreams) {
            $stream.DisposeCalls | Should -Be 1
            $stream.Real.CanWrite | Should -BeFalse
        }
        $json = Get-Content -Raw -LiteralPath $paths.JsonPath | ConvertFrom-Json
        $json.status | Should -BeExactly 'SUCCESS'
        $json.applicationExitCode | Should -Be 0
        $json.reporting.complete | Should -BeTrue
        (Get-Content -Raw -LiteralPath $paths.TextPath) | Should -Match '^WinAudioClean PREVIEW: SUCCESS / exit 0'
        $script:previewReportWarnings.Count | Should -Be $WarningCount
        foreach ($warning in $script:previewReportWarnings) { $warning | Should -BeLike 'Preview report handle release failed:*' }
    }

    It 'keeps release advisories nonterminating when the caller stops on warnings' {
        $script:previewReportFaultKinds = @('json', 'txt')
        $priorWarningPreference = $WarningPreference
        try {
            $WarningPreference = 'Stop'
            $paths = Write-WacPreviewReports -Report $previewReport -OutputFolder $previewReportFolder -WarningVariable +script:previewReportWarnings
            Test-Path -LiteralPath $paths.JsonPath | Should -BeTrue
            Test-Path -LiteralPath $paths.TextPath | Should -BeTrue
            $script:previewReportWriters.Count | Should -Be 2
            foreach ($writer in $script:previewReportWriters) { $writer.Closed | Should -BeTrue }
            $script:previewReportWarnings.Count | Should -Be 2
            foreach ($warning in $script:previewReportWarnings) { $warning | Should -BeLike 'Preview report handle release failed:*' }
        } finally { $WarningPreference = $priorWarningPreference }
    }

    It 'retains the primary write exception and rolls back both owned reports despite both close faults' {
        $script:previewReportFaultKinds = @('json', 'txt')
        $script:previewReportPrimaryWriteFault = $true
        { Write-WacPreviewReports -Report $previewReport -OutputFolder $previewReportFolder -WarningVariable +script:previewReportWarnings } | Should -Throw '*Injected primary text report write failure*'
        $script:previewReportWriters.Count | Should -Be 2
        foreach ($writer in $script:previewReportWriters) {
            $writer.Closed | Should -BeTrue
            $writer.Stream | Should -BeNullOrEmpty
        }
        foreach ($stream in $script:previewReportStreams) {
            $stream.DisposeCalls | Should -Be 1
            $stream.Real.CanWrite | Should -BeFalse
        }
        @(Get-ChildItem -LiteralPath $previewReportFolder -File).Count | Should -Be 0
        $script:previewReportWarnings.Count | Should -Be 2
        foreach ($warning in $script:previewReportWarnings) { $warning | Should -BeLike 'Preview report handle release failed:*' }
    }

    It 'retains a second-writer collision and foreign bytes when the first writer close faults' {
        $script:previewReportFaultKinds = @('json')
        $foreignText = Join-Path $previewReportFolder ('WinAudioClean_Preview_' + $previewReport.jobId + '.txt')
        [IO.File]::WriteAllText($foreignText, 'FOREIGN_REPORT_MUST_SURVIVE')
        { Write-WacPreviewReports -Report $previewReport -OutputFolder $previewReportFolder -WarningVariable +script:previewReportWarnings } | Should -Throw
        $script:previewReportWriters.Count | Should -Be 1
        $script:previewReportWriters[0].Closed | Should -BeTrue
        $script:previewReportStreams[0].DisposeCalls | Should -Be 1
        $script:previewReportStreams[0].Real.CanWrite | Should -BeFalse
        [IO.File]::ReadAllText($foreignText) | Should -BeExactly 'FOREIGN_REPORT_MUST_SURVIVE'
        @(Get-ChildItem -LiteralPath $previewReportFolder -Filter '*.json').Count | Should -Be 0
        $script:previewReportWarnings.Count | Should -Be 1
        $script:previewReportWarnings[0] | Should -BeLike 'Preview report handle release failed:*'
    }
}
