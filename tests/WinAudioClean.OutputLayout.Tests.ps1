BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    . (Join-Path $repositoryRoot 'WinAudioClean.ps1')
    . (Join-Path $repositoryRoot 'WinAudioClean.Output.ps1')
    if (-not ('WinAudioClean.Tests.OutputLayoutWrite' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace WinAudioClean.Tests {
    public static class OutputLayoutWrite {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(string path, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);
        public static bool CanOpenDirectoryForWrite(string path) {
            using (SafeFileHandle handle = CreateFileW(path, 0x40000000, 7, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero))
                return !handle.IsInvalid;
        }
    }
}
'@ -ErrorAction Stop
    }
}

Describe 'Optional held output layout' -Tag Unit, OutputLayout {
    It 'allows media publication and separate held report writing while denying directory replacement' {
        $base = Join-Path $TestDrive 'owned base'
        $null = [IO.Directory]::CreateDirectory($base)
        [WinAudioClean.Tests.OutputLayoutWrite]::CanOpenDirectoryForWrite($base) | Should -BeTrue
        $source = Join-Path $TestDrive 'source.wav'
        [IO.File]::WriteAllBytes($source, [byte[]](1, 2, 3))
        $layout = $null; $transaction = $null; $writer = $null
        try {
            $layout = New-WacOutputLayout -BaseDirectory $base
            Assert-WacOutputLayout -Layout $layout
            foreach ($path in @($layout.BaseDirectory, $layout.RootDirectory, $layout.ReportDirectory)) {
                [WinAudioClean.Tests.OutputLayoutWrite]::CanOpenDirectoryForWrite($path) | Should -BeFalse
            }
            [WinAudioClean.Tests.OutputLayoutWrite]::CanOpenDirectoryForWrite($layout.MediaDirectory) | Should -BeTrue
            foreach ($path in @($layout.RootDirectory, $layout.MediaDirectory, $layout.ReportDirectory)) {
                { [IO.Directory]::Move($path, ($path + '-foreign')) } | Should -Throw
                { [IO.Directory]::Delete($path, $false) } | Should -Throw
            }
            $transaction = New-WacOutputTransaction -InputPath $source -OutputFolder $layout.MediaDirectory
            $transaction.TempHandle.Write([byte[]](4, 5, 6), 0, 3)
            $transaction.TempHandle.Flush($true)
            $null = Freeze-WacOutputTransaction -Transaction $transaction
            Publish-WacOutputTransaction -Transaction $transaction
            $writer = Open-WacReportWriter -Path (Join-Path $layout.ReportDirectory 'owned.txt') -CreateNew
            Set-WacOwnedReportContent -Writer $writer -Content 'owned report'
            @(Complete-WacOutputTransaction -Transaction $transaction).Count | Should -Be 0
            Close-WacReportWriter -Writer $writer
            [BitConverter]::ToString([IO.File]::ReadAllBytes($transaction.FinalPath)) | Should -BeExactly '04-05-06'
            [IO.File]::ReadAllText($writer.Path) | Should -BeExactly 'owned report'
            Assert-WacOutputLayout -Layout $layout
        } finally {
            if ($writer) { Close-WacReportWriter -Writer $writer }
            if ($transaction) { Close-WacOutputTransaction -Transaction $transaction }
            if ($layout) { Close-WacOutputLayout -Layout $layout }
        }
        $layout.Closed | Should -BeTrue
        [WinAudioClean.Tests.OutputLayoutWrite]::CanOpenDirectoryForWrite($layout.ReportDirectory) | Should -BeTrue
        { Assert-WacOutputLayout -Layout $layout } | Should -Throw '*closed*'
        [IO.Directory]::Move($layout.RootDirectory, ($layout.RootDirectory + '-after-close'))
    }

    It 'does not reuse a prior job directory or alter its foreign contents' {
        $base = Join-Path $TestDrive 'collision ordinary'
        $jobId = '00112233445566778899aabbccddeeff'
        $root = Join-Path $base ('WinAudioClean_Job_' + $jobId)
        $null = [IO.Directory]::CreateDirectory($root)
        $foreign = Join-Path $root 'foreign.txt'
        [IO.File]::WriteAllText($foreign, 'keep exact bytes')
        { New-WacOutputLayout -BaseDirectory $base -JobId $jobId } | Should -Throw '*exclusively create*'
        [IO.File]::ReadAllText($foreign) | Should -BeExactly 'keep exact bytes'
        @(Get-ChildItem -LiteralPath $root -Force).Count | Should -Be 1
        [IO.Directory]::Move($base, ($base + '-released'))
    }

    It 'preserves a file occupying the generated job directory name' {
        $base = Join-Path $TestDrive 'collision file'
        $null = [IO.Directory]::CreateDirectory($base)
        $jobId = '10112233445566778899aabbccddeeff'
        $root = Join-Path $base ('WinAudioClean_Job_' + $jobId)
        [IO.File]::WriteAllText($root, 'foreign file')
        { New-WacOutputLayout -BaseDirectory $base -JobId $jobId } | Should -Throw '*exclusively create*'
        [IO.File]::ReadAllText($root) | Should -BeExactly 'foreign file'
        [IO.File]::Move($root, ($root + '-released'))
    }

    It 'resolves a supported existing base junction and rejects a generated child junction collision' {
        $target = Join-Path $TestDrive 'junction target'
        $base = Join-Path $TestDrive 'junction base'
        $null = [IO.Directory]::CreateDirectory($target)
        $null = New-Item -ItemType Junction -Path $base -Target $target -ErrorAction Stop
        $layout = $null
        try {
            $layout = New-WacOutputLayout -BaseDirectory $base
            $layout.BaseDirectory | Should -BeExactly $target
            [IO.Path]::GetDirectoryName($layout.RootDirectory) | Should -BeExactly $target
            Assert-WacOutputLayout -Layout $layout
        } finally {
            if ($layout) { Close-WacOutputLayout -Layout $layout }
            [IO.Directory]::Delete($base, $false)
        }
        $jobId = '20112233445566778899aabbccddeeff'
        $collision = Join-Path $target ('WinAudioClean_Job_' + $jobId)
        $foreignTarget = Join-Path $TestDrive 'foreign junction target'
        $null = [IO.Directory]::CreateDirectory($foreignTarget)
        $foreign = Join-Path $foreignTarget 'foreign.txt'
        [IO.File]::WriteAllText($foreign, 'foreign target remains')
        $null = New-Item -ItemType Junction -Path $collision -Target $foreignTarget -ErrorAction Stop
        try {
            { New-WacOutputLayout -BaseDirectory $target -JobId $jobId } | Should -Throw '*exclusively create*'
            [IO.File]::ReadAllText($foreign) | Should -BeExactly 'foreign target remains'
            @(Get-ChildItem -LiteralPath $foreignTarget -Force).Count | Should -Be 1
        } finally { [IO.Directory]::Delete($collision, $false) }
    }

    It 'rejects paths changed in a borrowed layout while preserving the original held hierarchy' {
        $base = Join-Path $TestDrive 'borrowed paths'
        $null = [IO.Directory]::CreateDirectory($base)
        $layout = New-WacOutputLayout -BaseDirectory $base
        $original = $layout.ReportDirectory
        try {
            $layout.ReportDirectory = Join-Path $TestDrive 'foreign reports'
            { Assert-WacOutputLayout -Layout $layout } | Should -Throw '*hierarchy*'
            $layout.ReportDirectory = $original
            Assert-WacOutputLayout -Layout $layout
        } finally { Close-WacOutputLayout -Layout $layout }
    }

    It 'rejects a closed directory lease before further use' {
        $base = Join-Path $TestDrive 'closed child'
        $null = [IO.Directory]::CreateDirectory($base)
        $layout = New-WacOutputLayout -BaseDirectory $base
        try {
            $layout.Handles.Reports.Dispose()
            { Assert-WacOutputLayout -Layout $layout } | Should -Throw '*unavailable*'
        } finally { Close-WacOutputLayout -Layout $layout }
    }

    It 'releases every directory after an allocation assertion fails and retains empty directories' {
        $base = Join-Path $TestDrive 'allocation failure'
        $null = [IO.Directory]::CreateDirectory($base)
        $jobId = '30112233445566778899aabbccddeeff'
        Mock Assert-WacOutputLayout { throw 'injected allocation assertion' }
        { New-WacOutputLayout -BaseDirectory $base -JobId $jobId } | Should -Throw '*injected allocation assertion*'
        $root = Join-Path $base ('WinAudioClean_Job_' + $jobId)
        @(Get-ChildItem -LiteralPath $root -Directory).Count | Should -Be 2
        @(Get-ChildItem -LiteralPath $root -Recurse -File).Count | Should -Be 0
        [IO.Directory]::Move($root, ($root + '-released'))
        [IO.Directory]::Move($base, ($base + '-released'))
    }

    It 'continues releasing handles after a disposal failure and closes idempotently' {
        $first = [pscustomobject]@{ Released = $false }
        $first | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.Released = $true }
        $fault = [pscustomobject]@{}
        $fault | Add-Member -MemberType ScriptMethod -Name Dispose -Value { throw 'injected dispose failure' }
        $layout = [pscustomobject]@{ Handles = [ordered]@{ First = $first; Fault = $fault }; Closed = $false }
        $diagnostics = @(Close-WacOutputLayout -Layout $layout)
        $diagnostics.Count | Should -Be 1
        $diagnostics[0] | Should -BeLike '*injected dispose failure*'
        $first.Released | Should -BeTrue
        $layout.Closed | Should -BeTrue
        @(Close-WacOutputLayout -Layout $layout).Count | Should -Be 0
    }

    It 'does not create a missing base or fall back to the current directory' {
        $missing = Join-Path $TestDrive 'missing output base'
        { New-WacOutputLayout -BaseDirectory $missing } | Should -Throw
        Test-Path -LiteralPath $missing | Should -BeFalse
        { New-WacOutputLayout -BaseDirectory 'https://invalid.example/output' } | Should -Throw '*filesystem*'
        { New-WacOutputLayout -BaseDirectory '\\invalid\share' } | Should -Throw '*UNC*'
        { New-WacOutputLayout -BaseDirectory $TestDrive -JobId '../escape' } | Should -Throw
    }

    It 'rejects an existing regular file used as the base without modifying it' {
        $base = Join-Path $TestDrive 'base is a file'
        [IO.File]::WriteAllText($base, 'original base file')
        { New-WacOutputLayout -BaseDirectory $base } | Should -Throw
        [IO.File]::ReadAllText($base) | Should -BeExactly 'original base file'
        [IO.File]::Move($base, ($base + '-released'))
    }
}
