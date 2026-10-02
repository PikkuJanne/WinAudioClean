BeforeDiscovery {
    $literalCases = @(
        @{ FileName = 'meeting with spaces.wav' }
        @{ FileName = 'meeting [draft].wav' }
        @{ FileName = "speaker's recording.wav" }
        @{ FileName = 'meeting äöÅ.wav' }
        @{ FileName = 'speaker & guest.wav' }
        @{ FileName = 'meeting %completed%.wav' }
        @{ FileName = 'meeting !important!.wav' }
        @{ FileName = 'meeting (take 1).wav' }
    )
    $unsupportedCases = @(
        @{ PathValue = ''; Description = 'empty path' }
        @{ PathValue = '   '; Description = 'blank path' }
        @{ PathValue = 'https://example.invalid/recording.wav'; Description = 'HTTPS URL' }
        @{ PathValue = 'file:///C:/recording.wav'; Description = 'file URL' }
        @{ PathValue = 'Env:PATH'; Description = 'environment provider' }
        @{ PathValue = 'HKCU:\Software'; Description = 'registry provider' }
        @{ PathValue = '\\server\share\recording.wav'; Description = 'UNC path' }
        @{ PathValue = '//server/share/recording.wav'; Description = 'forward-slash UNC path' }
        @{ PathValue = '\\?\C:\recording.wav'; Description = 'extended device path' }
        @{ PathValue = '\\.\pipe\recording'; Description = 'device namespace' }
        @{ PathValue = 'C:\recording.wav:alternate'; Description = 'alternate data stream' }
    )
}

BeforeAll {
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'WinAudioClean.ps1')
}

Describe 'AC-013: preflight treats filenames as literal data' -Tag 'Preflight', 'Unit' {
    It 'resolves and reads exactly <FileName>' -ForEach $literalCases {
        $filePath = Join-Path $TestDrive $FileName
        [IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3, 4))

        Resolve-WacFileSystemPath -Path $filePath | Should -BeExactly $filePath
        $inputFile = Get-WacInputFile -Path $filePath
        $inputFile | Should -BeOfType [IO.FileInfo]
        $inputFile.FullName | Should -BeExactly $filePath
        $inputFile.Length | Should -Be 4
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePath)) | Should -BeExactly 'AQIDBA=='
    }

    It 'does not expand brackets to a different existing filename' {
        $literalFile = Join-Path $TestDrive 'speaker [1].wav'
        $decoyFile = Join-Path $TestDrive 'speaker 1.wav'
        [IO.File]::WriteAllBytes($literalFile, [byte[]](1, 2, 3))
        [IO.File]::WriteAllBytes($decoyFile, [byte[]](9))

        (Get-WacInputFile -Path $literalFile).FullName | Should -BeExactly $literalFile
        (Get-WacInputFile -Path $literalFile).Length | Should -Be 3
        [IO.File]::Delete($literalFile)
        { Get-WacInputFile -Path $literalFile } | Should -Throw
        [IO.File]::ReadAllBytes($decoyFile)[0] | Should -Be 9
    }

    It 'normalizes a relative path against the PowerShell working directory' {
        $folder = Join-Path $TestDrive 'relative input'
        $null = [IO.Directory]::CreateDirectory($folder)
        $filePath = Join-Path $folder 'speaker [1].wav'
        [IO.File]::WriteAllBytes($filePath, [byte[]](1))
        Push-Location -LiteralPath $TestDrive
        try {
            Resolve-WacFileSystemPath -Path '.\relative input\..\relative input\speaker [1].wav' |
                Should -BeExactly $filePath
            (Get-WacInputFile -Path '.\relative input\speaker [1].wav').FullName |
                Should -BeExactly $filePath
        } finally {
            Pop-Location
        }
    }

    It 'rejects provider-qualified syntax even when the underlying file exists' {
        $filePath = Join-Path $TestDrive 'provider input.wav'
        [IO.File]::WriteAllBytes($filePath, [byte[]](1))
        { Get-WacInputFile -Path ('FileSystem::' + $filePath) } | Should -Throw '*provider-qualified*'
        { Get-WacOutputDirectory -Path ('FileSystem::' + $TestDrive) } | Should -Throw '*provider-qualified*'
    }
}

Describe 'AC-014: input preflight rejects unsupported or unreadable input' -Tag 'Preflight', 'Unit' {
    It 'rejects <Description> for both input and destination' -ForEach $unsupportedCases {
        { Resolve-WacFileSystemPath -Path $PathValue } | Should -Throw
        { Get-WacInputFile -Path $PathValue } | Should -Throw
        { Get-WacOutputDirectory -Path $PathValue } | Should -Throw
    }

    It 'rejects a missing file without creating it' {
        $filePath = Join-Path $TestDrive 'missing.wav'
        { Get-WacInputFile -Path $filePath } | Should -Throw '*does not exist*'
        Test-Path -LiteralPath $filePath | Should -BeFalse
    }

    It 'rejects an existing directory' {
        $folder = Join-Path $TestDrive 'input directory.wav'
        $null = [IO.Directory]::CreateDirectory($folder)
        { Get-WacInputFile -Path $folder } | Should -Throw '*directory*'
    }

    It 'rejects a zero-byte file and leaves it unchanged' {
        $filePath = Join-Path $TestDrive 'empty.wav'
        [IO.File]::WriteAllBytes($filePath, [byte[]]@())
        { Get-WacInputFile -Path $filePath } | Should -Throw '*zero bytes*'
        (Get-Item -LiteralPath $filePath).Length | Should -Be 0
    }

    It 'rejects a file that cannot be opened for reading' {
        $filePath = Join-Path $TestDrive 'locked.wav'
        [IO.File]::WriteAllBytes($filePath, [byte[]](1, 2, 3))
        $exclusiveHandle = [IO.File]::Open($filePath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try {
            { Get-WacInputFile -Path $filePath } | Should -Throw '*readable*'
        } finally {
            $exclusiveHandle.Dispose()
        }
        # The failure must release every handle so a later valid attempt works.
        (Get-WacInputFile -Path $filePath).Length | Should -Be 3
    }
}

Describe 'AC-013/AC-014: destination preflight creates and verifies literal directories' -Tag 'Preflight', 'Unit' {
    It 'creates a literal destination containing <FileName> without leaving probe files' -ForEach $literalCases {
        $folder = Join-Path $TestDrive ('output ' + $FileName)
        $result = Get-WacOutputDirectory -Path $folder
        $result | Should -BeExactly $folder
        Test-Path -LiteralPath $folder -PathType Container | Should -BeTrue
        @(Get-ChildItem -LiteralPath $folder -Force).Count | Should -Be 0
    }

    It 'normalizes and creates a nested relative destination' {
        Push-Location -LiteralPath $TestDrive
        try {
            $folder = Join-Path $TestDrive 'nested\output [1]'
            Get-WacOutputDirectory -Path '.\nested\unused\..\output [1]' | Should -BeExactly $folder
            Test-Path -LiteralPath $folder -PathType Container | Should -BeTrue
            @(Get-ChildItem -LiteralPath $folder -Force).Count | Should -Be 0
        } finally {
            Pop-Location
        }
    }

    It 'preserves existing files and removes only its own write probe' {
        $folder = Join-Path $TestDrive 'existing destination'
        $null = [IO.Directory]::CreateDirectory($folder)
        $existingFile = Join-Path $folder '.wac-write-probe-existing.tmp'
        [IO.File]::WriteAllBytes($existingFile, [byte[]](4, 5, 6))

        Get-WacOutputDirectory -Path $folder | Should -BeExactly $folder
        @(Get-ChildItem -LiteralPath $folder -Force).Count | Should -Be 1
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($existingFile)) | Should -BeExactly 'BAUG'
    }

    It 'rejects a destination occupied by a file and preserves that file' {
        $filePath = Join-Path $TestDrive 'output collision'
        [IO.File]::WriteAllBytes($filePath, [byte[]](4, 5, 6))
        { Get-WacOutputDirectory -Path $filePath } | Should -Throw '*cannot be created or written*'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePath)) | Should -BeExactly 'BAUG'
    }

    It 'rejects a directory whose ACL denies creating files' {
        # Change only this test-owned directory. Deny CreateFiles without
        # inheritance; retain permission to restore the original ACL in finally.
        $folder = Join-Path $TestDrive ('denied-output-' + [guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($folder)
        $originalAcl = Get-Acl -LiteralPath $folder
        $deniedAcl = Get-Acl -LiteralPath $folder
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $rule = New-Object Security.AccessControl.FileSystemAccessRule -ArgumentList @(
            $identity,
            [Security.AccessControl.FileSystemRights]::CreateFiles,
            [Security.AccessControl.AccessControlType]::Deny
        )
        $deniedAcl.AddAccessRule($rule)
        $aclChanged = $false
        try {
            try {
                Set-Acl -LiteralPath $folder -AclObject $deniedAcl -ErrorAction Stop
                $aclChanged = $true
            } catch {
                Set-ItResult -Skipped -Because 'This environment cannot apply an ACL to a test-owned directory.'
                return
            }

            # Confirm the OS actually enforces the fixture before trusting it.
            $controlProbe = Join-Path $folder 'fixture-permission-check.tmp'
            $denied = $false
            try {
                $handle = [IO.File]::Open($controlProbe, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                $handle.Dispose()
            } catch [UnauthorizedAccessException] {
                $denied = $true
            }
            if (-not $denied) {
                [IO.File]::Delete($controlProbe)
                Set-ItResult -Skipped -Because 'This environment does not enforce the test directory write-denial ACL.'
                return
            }

            { Get-WacOutputDirectory -Path $folder } | Should -Throw '*cannot be created or written*'
            @(Get-ChildItem -LiteralPath $folder -Force).Count | Should -Be 0
        } finally {
            if ($aclChanged) { Set-Acl -LiteralPath $folder -AclObject $originalAcl -ErrorAction Stop }
        }
        # Restoration is part of the test contract, not just best-effort cleanup.
        Get-WacOutputDirectory -Path $folder | Should -BeExactly $folder
        @(Get-ChildItem -LiteralPath $folder -Force).Count | Should -Be 0
    }
}

Describe 'AC-015: the menu retries invalid answers and permits cancellation' -Tag 'Preflight', 'Unit' {
    BeforeEach {
        $script:wacModeAnswers = New-Object 'System.Collections.Generic.Queue[string]'
        Mock Write-Host { }
        Mock Read-Host {
            if ($script:wacModeAnswers.Count -eq 0) { throw 'Unexpected extra menu prompt.' }
            $script:wacModeAnswers.Dequeue()
        }
    }

    It 'selects <ExpectedMode> for <Answer>' -ForEach @(
        @{ Answer = '1'; ExpectedMode = 'Raw' }
        @{ Answer = '2'; ExpectedMode = 'Zoom' }
    ) {
        $script:wacModeAnswers.Enqueue($Answer)
        Read-WacMode | Should -BeExactly $ExpectedMode
        Should -Invoke Read-Host -Times 1 -Exactly
    }

    It 'retries empty and invalid answers before accepting a valid choice' {
        foreach ($answer in @('', 'invalid', '3', '1')) { $script:wacModeAnswers.Enqueue($answer) }
        Read-WacMode | Should -BeExactly 'Raw'
        Should -Invoke Read-Host -Times 4 -Exactly
    }

    It 'returns no mode for cancellation <Answer>' -ForEach @(
        @{ Answer = 'q' }
        @{ Answer = 'cancel' }
    ) {
        $script:wacModeAnswers.Enqueue($Answer)
        Read-WacMode | Should -BeNullOrEmpty
        Should -Invoke Read-Host -Times 1 -Exactly
    }

    It 'returns no mode when the host reports end of input' {
        Mock Read-Host { return $null }
        Read-WacMode | Should -BeNullOrEmpty
        Should -Invoke Read-Host -Times 1 -Exactly
    }

    It 'reports a clear unattended-use route when Read-Host fails' {
        Mock Read-Host { throw 'The host cannot read input.' }
        { Read-WacMode } | Should -Throw '*Cannot read a mode*Supply -Mode Raw or -Mode Zoom with -NonInteractive*'
        Should -Invoke Read-Host -Times 1 -Exactly
    }
}

Describe 'AC-015: prompt eligibility follows host and script invocation boundaries' -Tag 'Preflight', 'Unit' {
    It 'allows an interactive host with ordinary startup switches' {
        Test-WacInteractive -HostArguments @('powershell.exe', '-NoLogo', '-NoProfile') -InputRedirected $false -UserInteractive $true |
            Should -BeTrue
    }

    It 'prevents prompting for <Description>' -ForEach @(
        @{ Description = 'the explicit application switch'; ExplicitNonInteractive = $true; Redirected = $false; Interactive = $true }
        @{ Description = 'redirected standard input'; ExplicitNonInteractive = $false; Redirected = $true; Interactive = $true }
        @{ Description = 'a noninteractive operating system session'; ExplicitNonInteractive = $false; Redirected = $false; Interactive = $false }
    ) {
        Test-WacInteractive -HostArguments @('powershell.exe') -NonInteractive:$ExplicitNonInteractive -InputRedirected $Redirected -UserInteractive $Interactive |
            Should -BeFalse
    }

    It 'recognizes host switch <HostSwitch> before script arguments' -ForEach @(
        @{ HostSwitch = '-NonInteractive' }
        @{ HostSwitch = '-noni' }
        @{ HostSwitch = '-nonin' }
        @{ HostSwitch = '-noninter' }
        @{ HostSwitch = '-NoNiNtErAcTiVe' }
    ) {
        Test-WacInteractive -HostArguments @('powershell.exe', '-NoProfile', $HostSwitch, '-File', 'WinAudioClean.ps1') -InputRedirected $false -UserInteractive $true |
            Should -BeFalse
    }

    It 'does not interpret application arguments after <Boundary> as host switches' -ForEach @(
        @{ Boundary = '-File' }
        @{ Boundary = '-fi' }
        @{ Boundary = '-Command' }
        @{ Boundary = '-co' }
        @{ Boundary = '-EncodedCommand' }
        @{ Boundary = '-ec' }
    ) {
        Test-WacInteractive -HostArguments @('powershell.exe', '-NoProfile', $Boundary, 'script-or-command', '-NonInteractive') -InputRedirected $false -UserInteractive $true |
            Should -BeTrue
    }

    It 'does not confuse a longer lookalike argument with a supported host switch' {
        Test-WacInteractive -HostArguments @('powershell.exe', '-NonInteractiveSuffix') -InputRedirected $false -UserInteractive $true |
            Should -BeTrue
    }
}
