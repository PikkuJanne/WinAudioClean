BeforeDiscovery {
    $folderArtifactCases = @(
        @{ Name = 'voice_Cleaned_20261003-1234_0123456789abcdef0123456789abcdef.wav' }
        @{ Name = 'voice_Cleaned_20261003-123456_0123456789abcdef0123456789abcdef.wav' }
        @{ Name = 'voice_Cleaned_20261003-123456789_0123456789abcdef0123456789abcdef.wav' }
        @{ Name = 'voice_Preview_0123456789abcdef0123456789abcdef_Original.wav' }
        @{ Name = 'voice_Preview_0123456789abcdef0123456789abcdef_Processed.wav' }
        @{ Name = 'voice_Preview_0123456789abcdef0123456789abcdef_CompareOriginal.wav' }
        @{ Name = 'voice_Preview_0123456789abcdef0123456789abcdef_CompareProcessed.wav' }
        @{ Name = '.wac-0123456789abcdef0123456789abcdef.partial' }
        @{ Name = '.wac-write-check-0123456789abcdef0123456789abcdef.tmp' }
        @{ Name = '.wac-settings-0123456789abcdef0123456789abcdef.tmp' }
        @{ Name = 'WinAudioClean_0123456789abcdef0123456789abcdef.json' }
        @{ Name = 'WinAudioClean_0123456789abcdef0123456789abcdef.txt' }
        @{ Name = 'WinAudioClean_Preview_0123456789abcdef0123456789abcdef.json' }
        @{ Name = 'WinAudioClean_Batch_0123456789abcdef0123456789abcdef.jsonl' }
        @{ Name = 'WinAudioClean_Log.txt' }
    )
    $folderChangedCases = @(@{ Change = 'replacement' }, @{ Change = 'length' }, @{ Change = 'timestamp' }, @{ Change = 'removal' })
}

BeforeAll {
    $folderRepository = Split-Path $PSScriptRoot -Parent
    . (Join-Path $folderRepository 'WinAudioClean.ps1')
    . (Join-Path $folderRepository 'WinAudioClean.Settings.ps1')
    . (Join-Path $folderRepository 'WinAudioClean.Batch.ps1')
    . (Join-Path $folderRepository 'WinAudioClean.Queue.ps1')
    . (Join-Path $PSScriptRoot 'fixtures/TestProcess.ps1')
    $folderUtf8 = New-Object Text.UTF8Encoding($false, $true)
    $folderUnicode = ([string][char]0x00E4) + [char]0x00F6 + [char]0x00C5
    $folderExtensions = @('.aac', '.aif', '.aiff', '.avi', '.flac', '.m4a', '.mkv', '.mov', '.mp3', '.mp4', '.ogg', '.opus', '.wav', '.webm', '.wma')
    function New-WacFolderTestRoot {
        $path = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($path)
        $path
    }
    function New-WacFolderTestInput {
        param([string]$Root, [string]$Name = 'source.wav', [byte[]]$Bytes = [byte[]](1, 2, 3, 4))
        $path = Join-Path $Root $Name
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
        [IO.File]::WriteAllBytes($path, $Bytes)
        $path
    }
    function New-WacFolderTestLink {
        param([string]$Kind, [string]$Path, [string]$Target)
        $linkTarget = if ($PSVersionTable.PSVersion.Major -le 5) { [WildcardPattern]::Escape($Target) } else { $Target }
        New-Item -ItemType $Kind -Path $Path -Target $linkTarget -ErrorAction Stop
    }
    function Read-WacFolderTestJournal {
        param([string]$Path)
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader = New-Object IO.StreamReader($stream, $folderUtf8)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose(); $stream.Dispose() }
        foreach ($line in @($text -split '\r?\n' | Where-Object { $_.Length -gt 0 })) { $line | ConvertFrom-Json }
    }
    function Get-WacFolderTestBytes {
        param([string]$Path)
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
    }
    function Invoke-WacFolderTestBatch {
        param($Queue, [hashtable]$Parameters, $Resolved, [string]$ApplicationPath = 'unused.ps1')
        Invoke-WacBatch -Inputs @($Queue.Entries | ForEach-Object { $_.InputPath }) -FolderQueue $Queue -Parameters $Parameters -ResolvedSettings $Resolved -ApplicationPath $ApplicationPath
    }
}

Describe 'AC-055: folder discovery is bounded deterministic local data' -Tag 'FolderQueue', 'Unit' {
    It 'selects every allowlisted extension case-insensitively and explains unsupported files' {
        $root = New-WacFolderTestRoot
        foreach ($extension in $folderExtensions) { $null = New-WacFolderTestInput -Root $root -Name ('source' + $extension.ToUpperInvariant()) }
        foreach ($name in @('readme.txt', 'playlist.m3u', 'payload.ps1', 'unknown.bin')) { $null = New-WacFolderTestInput -Root $root -Name $name }
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root
        @($queue.Entries | Where-Object Status -eq 'PENDING').Count | Should -Be 15
        @($queue.Entries | Where-Object ReasonCode -eq 'unsupported_extension').Count | Should -Be 4
        @($queue.Extensions).Count | Should -Be 15
        foreach ($extension in $folderExtensions) { $queue.Extensions | Should -Contain $extension }
        foreach ($entry in @($queue.Entries | Where-Object Status -eq 'SKIPPED')) { $entry.Diagnostics.Count | Should -BeGreaterThan 0 }
        $queue.Recurse | Should -BeFalse
        $queue.CapturedAt | Should -Not -BeNullOrEmpty
    }

    It 'leaves recursion off and records the omitted ordinary subdirectory' {
        $root = New-WacFolderTestRoot
        $top = New-WacFolderTestInput -Root $root -Name 'top.wav'
        $null = New-WacFolderTestInput -Root $root -Name 'nested/child.wav'
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root
        @($queue.Entries | Where-Object Status -eq 'PENDING').Count | Should -Be 1
        @($queue.Entries | Where-Object Status -eq 'PENDING')[0].InputPath | Should -BeExactly $top
        @($queue.Entries | Where-Object ReasonCode -eq 'recursion_disabled').Count | Should -Be 1
    }

    It 'uses root order and breadth-first traversal with ordinal entry ordering' {
        $first = New-WacFolderTestRoot
        $second = New-WacFolderTestRoot
        $rootFile = New-WacFolderTestInput -Root $first -Name 'root.wav'
        $upper = New-WacFolderTestInput -Root $first -Name 'a child/Z-upper.wav'
        $lower = New-WacFolderTestInput -Root $first -Name 'a child/b-lower.wav'
        $otherChild = New-WacFolderTestInput -Root $first -Name 'b child/other.wav'
        $grandchild = New-WacFolderTestInput -Root $first -Name 'a child/nested/deep.wav'
        $secondFile = New-WacFolderTestInput -Root $second -Name 'second.wav'
        $destination = New-WacFolderTestRoot
        $queue = New-WacFolderQueue -Directories @($first, $second) -OutputDirectory $destination -Recurse
        $actual = @($queue.Entries | Where-Object Status -eq 'PENDING' | ForEach-Object { $_.InputPath })
        $expected = @($rootFile, $secondFile, $upper, $lower, $otherChild, $grandchild)
        $actual.Count | Should -Be $expected.Count
        for ($index = 0; $index -lt $actual.Count; $index++) { $actual[$index] | Should -BeExactly $expected[$index] }
        $queue.Recurse | Should -BeTrue
    }

    It 'skips the generated artifact <Name> using the actual naming contract' -ForEach $folderArtifactCases {
        $root = New-WacFolderTestRoot
        $path = New-WacFolderTestInput -Root $root -Name $Name
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root
        $queue.Entries.Count | Should -Be 1
        $queue.Entries[0].InputPath | Should -BeExactly $path
        $queue.Entries[0].Status | Should -BeExactly 'SKIPPED'
        $queue.Entries[0].ReasonCode | Should -BeExactly 'generated_artifact'
    }

    It 'keeps legitimate sources that merely resemble generated filenames' {
        $root = New-WacFolderTestRoot
        $names = @('voice_Cleaned_take.wav', 'voice_Cleaned_20261003-123456_not-a-job.wav',
            'voice_Cleaned_20261003-1234567890_0123456789abcdef0123456789abcdef.wav',
            'voice_Preview_0123456789abcdef0123456789abcdef_Custom.wav', 'WinAudioClean_notes.wav')
        foreach ($name in $names) { $null = New-WacFolderTestInput -Root $root -Name $name }
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root
        @($queue.Entries | Where-Object Status -eq 'PENDING').Count | Should -Be $names.Count
    }

    It 'excludes the nested destination subtree while keeping a similarly prefixed sibling' {
        $root = New-WacFolderTestRoot
        $destination = Join-Path $root 'output'
        $null = New-WacFolderTestInput -Root $root -Name 'output/prior.wav'
        $source = New-WacFolderTestInput -Root $root -Name 'output-other/source.wav'
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $destination -Recurse
        @($queue.Entries | Where-Object ReasonCode -eq 'output_directory').Count | Should -Be 1
        @($queue.Entries | Where-Object Status -eq 'PENDING').Count | Should -Be 1
        @($queue.Entries | Where-Object Status -eq 'PENDING')[0].InputPath | Should -BeExactly $source
    }

    It 'allows source root equal to the destination without selecting existing generated audio' {
        $root = New-WacFolderTestRoot
        $source = New-WacFolderTestInput -Root $root
        $null = New-WacFolderTestInput -Root $root -Name 'source_Cleaned_20261003-1234_0123456789abcdef0123456789abcdef.wav'
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root -Recurse
        @($queue.Entries | Where-Object Status -eq 'PENDING').Count | Should -Be 1
        @($queue.Entries | Where-Object Status -eq 'PENDING')[0].InputPath | Should -BeExactly $source
        @($queue.Entries | Where-Object ReasonCode -eq 'generated_artifact').Count | Should -Be 1
    }

    It 'accepts the64-root limit before deduplication and rejects65' {
        $root = New-WacFolderTestRoot
        { New-WacFolderQueue -Directories (@($root) * 64) -OutputDirectory $root } | Should -Not -Throw
        { New-WacFolderQueue -Directories (@($root) * 65) -OutputDirectory $root } | Should -Throw
    }

    It 'accepts1024 materialized entries including skipped files and rejects the next entry' {
        $root = New-WacFolderTestRoot
        foreach ($index in 1..1024) { $null = New-WacFolderTestInput -Root $root -Name ('unsupported{0:D4}.txt' -f $index) }
        (New-WacFolderQueue -Directories @($root) -OutputDirectory $root).Entries.Count | Should -Be 1024
        $null = New-WacFolderTestInput -Root $root -Name 'unsupported1025.txt'
        { New-WacFolderQueue -Directories @($root) -OutputDirectory $root } | Should -Throw
    }

    It 'rejects more than1024 recursively visited directories even when they contain no files' {
        $root = New-WacFolderTestRoot
        foreach ($index in 1..1024) { $null = [IO.Directory]::CreateDirectory((Join-Path $root ('d{0:D4}' -f $index))) }
        { New-WacFolderQueue -Directories @($root) -OutputDirectory $root -Recurse } | Should -Throw
    }

    It 'rejects a <Case> root as a global selection failure' -ForEach @(
        @{ Case = 'missing'; RootKind = 'missing' }; @{ Case = 'file'; RootKind = 'file' }
        @{ Case = 'UNC'; RootKind = '\\server\share' }; @{ Case = 'URL'; RootKind = 'https://invalid.example/audio' }
        @{ Case = 'provider'; RootKind = 'FileSystem::C:\audio' }; @{ Case = 'empty'; RootKind = '' }
    ) {
        $root = New-WacFolderTestRoot
        $selected = switch ($RootKind) { 'missing' { Join-Path $root 'missing' }; 'file' { New-WacFolderTestInput -Root $root }; default { $RootKind } }
        { New-WacFolderQueue -Directories @($selected) -OutputDirectory $root } | Should -Throw
    }

    It 'rejects invalid folder-source combinations including an explicitly false recursion flag' -ForEach @(
        @{ Parameters = @{} }; @{ Parameters = @{ InputDirectories = @() } }
        @{ Parameters = @{ InputDirectories = @('folder'); inputPath = 'source.wav' } }
        @{ Parameters = @{ InputDirectories = @('folder'); InputPaths = @('source.wav') } }
        @{ Parameters = @{ InputDirectories = @('folder'); InputListPath = 'inputs.json' } }
        @{ Parameters = @{ inputPath = 'source.wav'; Recurse = $false } }
        @{ Parameters = @{ InputPaths = @('source.wav'); Recurse = $true } }
        @{ Parameters = @{ InputListPath = 'inputs.json'; Recurse = $false } }
    ) {
        { Resolve-WacFolderSelection -Parameters $Parameters } | Should -Throw
    }

    It 'accepts actual bound folder parameters without ambiguous dictionary methods' {
        function Invoke-WacFolderBoundSelection {
            [CmdletBinding()]
            param([string[]]$InputDirectories, [switch]$Recurse)
            Resolve-WacFolderSelection -Parameters $PSBoundParameters
        }
        $root = New-WacFolderTestRoot
        { Invoke-WacFolderBoundSelection -InputDirectories @($root) -Recurse:$false } | Should -Not -Throw
    }
}

Describe 'AC-055/056: real filesystem identities and links cannot expand the queue' -Tag 'FolderQueue', 'Unit', 'OutputSafety' {
    It 'deduplicates repeated roots and overlapping ordinary directories' {
        $root = New-WacFolderTestRoot
        $source = New-WacFolderTestInput -Root $root -Name 'nested/source.wav'
        $destination = New-WacFolderTestRoot
        $queue = New-WacFolderQueue -Directories @($root, $root, (Join-Path $root 'nested')) -OutputDirectory $destination -Recurse
        @($queue.Entries | Where-Object Status -eq 'PENDING').Count | Should -Be 1
        @($queue.Entries | Where-Object Status -eq 'PENDING')[0].InputPath | Should -BeExactly $source
        @($queue.Entries | Where-Object ReasonCode -eq 'duplicate_directory').Count | Should -Be 2
    }

    It 'deduplicates real hardlink aliases using the volume and file identity' {
        $root = New-WacFolderTestRoot
        $source = New-WacFolderTestInput -Root $root -Name 'a original.wav'
        $alias = Join-Path $root 'b alias.wav'
        $null = New-WacFolderTestLink -Kind HardLink -Path $alias -Target $source
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root
        @($queue.Entries | Where-Object Status -eq 'PENDING').Count | Should -Be 1
        @($queue.Entries | Where-Object ReasonCode -eq 'duplicate_file').Count | Should -Be 1
        @($queue.Entries | Where-Object Status -eq 'PENDING')[0].Identity | Should -Match '^[0-9A-F]{48}$'
        Get-WacFolderTestBytes -Path $source | Should -BeExactly 'AQIDBA=='
        Get-WacFolderTestBytes -Path $alias | Should -BeExactly 'AQIDBA=='
    }

    It 'records a junction loop and outside junction without visiting either target' {
        $root = New-WacFolderTestRoot
        $outside = New-WacFolderTestRoot
        $null = New-WacFolderTestInput -Root $root
        $outsideSource = New-WacFolderTestInput -Root $outside -Name 'outside.wav'
        $loop = Join-Path $root 'loop'
        $redirect = Join-Path $root 'outside'
        $null = New-WacFolderTestLink -Kind Junction -Path $loop -Target $root
        $null = New-WacFolderTestLink -Kind Junction -Path $redirect -Target $outside
        try {
            $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root -Recurse
            $queue.Entries.Count | Should -Be 3
            @($queue.Entries | Where-Object ReasonCode -eq 'reparse_point').Count | Should -Be 2
            @($queue.Entries | Where-Object Status -eq 'PENDING').Count | Should -Be 1
            Get-WacFolderTestBytes -Path $outsideSource | Should -BeExactly 'AQIDBA=='
        } finally { [IO.Directory]::Delete($loop); [IO.Directory]::Delete($redirect) }
        Get-WacFolderTestBytes -Path $outsideSource | Should -BeExactly 'AQIDBA=='
    }

    It 'rejects an explicitly selected reparse <Part> before traversal' -ForEach @(@{ Part = 'root' }, @{ Part = 'ancestor' }) {
        $base = New-WacFolderTestRoot
        $target = New-WacFolderTestRoot
        $null = New-WacFolderTestInput -Root $target -Name 'child/source.wav'
        $junction = Join-Path $base 'redirected'
        $null = New-WacFolderTestLink -Kind Junction -Path $junction -Target $target
        try {
            $selected = if ($Part -eq 'root') { $junction } else { Join-Path $junction 'child' }
            { New-WacFolderQueue -Directories @($selected) -OutputDirectory $base -Recurse } | Should -Throw
        } finally { [IO.Directory]::Delete($junction) }
    }

    It 'never follows a file symlink when the local token permits creating it' {
        $root = New-WacFolderTestRoot
        $outside = New-WacFolderTestRoot
        $target = New-WacFolderTestInput -Root $outside
        $link = Join-Path $root 'link.wav'
        try { $null = New-WacFolderTestLink -Kind SymbolicLink -Path $link -Target $target }
        catch {
            if ($_.Exception.Message -match 'privilege|1314|not held|administrator') { Set-ItResult -Skipped -Because 'This local token cannot create a symbolic link; junction coverage runs separately.'; return }
            throw
        }
        try {
            $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root -Recurse
            $queue.Entries.Count | Should -Be 1
            $queue.Entries[0].ReasonCode | Should -BeExactly 'reparse_point'
            Get-WacFolderTestBytes -Path $target | Should -BeExactly 'AQIDBA=='
        } finally { [IO.File]::Delete($link) }
    }

    It 'retains captured identity length and timestamp in each pending entry' {
        $root = New-WacFolderTestRoot
        $source = New-WacFolderTestInput -Root $root
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root
        $entry = $queue.Entries[0]
        $entry.Identity | Should -Match '^[0-9A-F]{48}$'
        $entry.Length | Should -Be 4
        ([datetime]$entry.LastWriteTimeUtc).ToUniversalTime().Ticks | Should -Be ([IO.File]::GetLastWriteTimeUtc($source).Ticks)
        $entry.Status | Should -BeExactly 'PENDING'
    }

    It 'holds the exact input and ordinary ancestors against foreign write rename and deletion until close' {
        $root = New-WacFolderTestRoot
        $source = New-WacFolderTestInput -Root $root
        $entry = (New-WacFolderQueue -Directories @($root) -OutputDirectory $root).Entries[0]
        $lease = Open-WacQueuedInput -Entry $entry
        try {
            $lease.Stream | Should -BeOfType [IO.FileStream]
            [WinAudioClean.NativeFileIO]::Identity($lease.Stream.SafeFileHandle) | Should -BeExactly $entry.Identity
            $lease.DirectoryHandles.Count | Should -BeGreaterThan 0
            { [IO.File]::WriteAllBytes($source, [byte[]](9)) } | Should -Throw
            { [IO.File]::Delete($source) } | Should -Throw
            { [IO.File]::Move($source, ($source + '.foreign')) } | Should -Throw
            { [IO.Directory]::Move($root, ($root + '-foreign')) } | Should -Throw
            Get-WacFolderTestBytes -Path $source | Should -BeExactly 'AQIDBA=='
        } finally { Close-WacQueuedInput -Lease $lease }
        [IO.File]::WriteAllBytes($source, [byte[]](8, 7))
        Get-WacFolderTestBytes -Path $source | Should -BeExactly 'CAc='
        [IO.Directory]::Move($root, ($root + '-released'))
    }

    It 'rejects a captured source after <Change> without returning a usable lease' -ForEach $folderChangedCases {
        $root = New-WacFolderTestRoot
        $source = New-WacFolderTestInput -Root $root
        $entry = (New-WacFolderQueue -Directories @($root) -OutputDirectory $root).Entries[0]
        switch ($Change) {
            'replacement' { [IO.File]::Move($source, ($source + '.prior')); [IO.File]::WriteAllBytes($source, [byte[]](1, 2, 3, 4)); [IO.File]::SetLastWriteTimeUtc($source, [datetime]$entry.LastWriteTimeUtc) }
            'length' { [IO.File]::WriteAllBytes($source, [byte[]](1)) }
            'timestamp' { [IO.File]::SetLastWriteTimeUtc($source, ([IO.File]::GetLastWriteTimeUtc($source).AddSeconds(10))) }
            'removal' { [IO.File]::Delete($source) }
        }
        $lease = $null; $failure = $null
        try { $lease = Open-WacQueuedInput -Entry $entry } catch { $failure = $_ }
        finally { if ($null -ne $lease) { Close-WacQueuedInput -Lease $lease } }
        $failure | Should -Not -BeNullOrEmpty
    }

    It 'records a supported file that cannot be opened as a failed source rather than a global root error' {
        $root = New-WacFolderTestRoot
        $source = New-WacFolderTestInput -Root $root
        $blocked = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try {
            $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root
            $queue.Entries.Count | Should -Be 1
            $queue.Entries[0].Status | Should -BeExactly 'FAILED'
            $queue.Entries[0].ReasonCode | Should -BeExactly 'source_unavailable'
            $queue.Entries[0].Diagnostics.Count | Should -BeGreaterThan 0
        } finally { $blocked.Dispose() }
    }

    It 'excludes a renamed hardlink alias of a generated audio identity even when the alias sorts first' {
        $root = New-WacFolderTestRoot
        $generated = New-WacFolderTestInput -Root $root -Name 'z_Cleaned_20261003-123456_0123456789abcdef0123456789abcdef.wav'
        $alias = Join-Path $root 'a renamed source.wav'
        $null = New-WacFolderTestLink -Kind HardLink -Path $alias -Target $generated
        $queue = New-WacFolderQueue -Directories @($root) -OutputDirectory $root
        @($queue.Entries | Where-Object Status -eq 'PENDING').Count | Should -Be 0
        @($queue.Entries | Where-Object ReasonCode -eq 'generated_artifact').Count | Should -Be 2
        Get-WacFolderTestBytes -Path $alias | Should -BeExactly 'AQIDBA=='
    }

    It 'rejects a captured ordinary ancestor that was replaced with a junction before a child starts' {
        $root = New-WacFolderTestRoot
        $alternate = New-WacFolderTestRoot
        $null = New-WacFolderTestInput -Root $root
        $alternateSource = New-WacFolderTestInput -Root $alternate -Bytes ([byte[]](9, 9))
        $entry = (New-WacFolderQueue -Directories @($root) -OutputDirectory $root).Entries[0]
        $priorRoot = $root + '-prior'
        [IO.Directory]::Move($root, $priorRoot)
        $null = New-WacFolderTestLink -Kind Junction -Path $root -Target $alternate
        try {
            $lease = $null; $failure = $null
            try { $lease = Open-WacQueuedInput -Entry $entry } catch { $failure = $_ }
            finally { if ($null -ne $lease) { Close-WacQueuedInput -Lease $lease } }
            $failure | Should -Not -BeNullOrEmpty
            Get-WacFolderTestBytes -Path $alternateSource | Should -BeExactly 'CQk='
            Get-WacFolderTestBytes -Path (Join-Path $priorRoot 'source.wav') | Should -BeExactly 'AQIDBA=='
        } finally { [IO.Directory]::Delete($root) }
    }
}

Describe 'AC-056/057: folder journals summarize the frozen queue and stop safely' -Tag 'FolderQueue', 'Unit', 'OutputSafety' {
    BeforeEach {
        $folderRunRoot = New-WacFolderTestRoot
        $folderRunOutput = New-WacFolderTestRoot
        $folderRunResult = Join-Path $folderRunOutput 'results.jsonl'
        $folderRunParameters = @{ BatchResultPath = $folderRunResult; NonInteractive = $true }
        $folderRunResolved = Resolve-WacSettings -Explicit @{ Mode = 'Zoom'; OutputDirectory = $folderRunOutput }
        $script:folderCalls = New-Object 'System.Collections.Generic.List[object]'
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:folderCalls.Add($Arguments)
            [pscustomobject]@{ ExitCode = 0; Diagnostics = @() }
        }
    }

    It 'writes schema2 folder selection and skipped counts while keeping per-source identities' {
        $source = New-WacFolderTestInput -Root $folderRunRoot
        $null = New-WacFolderTestInput -Root $folderRunRoot -Name 'notes.txt'
        $queue = New-WacFolderQueue -Directories @($folderRunRoot) -OutputDirectory $folderRunOutput
        $result = Invoke-WacFolderTestBatch -Queue $queue -Parameters $folderRunParameters -Resolved $folderRunResolved
        $result.ExitCode | Should -Be 0
        $result.ReportingComplete | Should -BeTrue
        $records = @(Read-WacFolderTestJournal -Path $folderRunResult)
        $records.Count | Should -Be 4
        $records[0].schemaVersion | Should -Be 2
        $records[0].selection.kind | Should -BeExactly 'folders'
        $records[0].selection.directories[0] | Should -BeExactly $folderRunRoot
        $records[0].selection.recurse | Should -BeFalse
        $records[0].selection.extensions.Count | Should -Be 15
        # Newer ConvertFrom-Json converts ISO timestamps to DateTime; compare
        # the same UTC value without changing the report's string wire format.
        $parsedCapturedAt = if ($records[0].selection.capturedAt -is [datetime]) {
            $records[0].selection.capturedAt.ToUniversalTime().ToString('o')
        } else { [string]$records[0].selection.capturedAt }
        $parsedCapturedAt | Should -BeExactly $queue.CapturedAt
        $success = @($records | Where-Object status -eq 'SUCCESS' | Where-Object type -eq 'item')[0]
        $success.inputPath | Should -BeExactly $source
        $success.sourceIdentity | Should -BeExactly @($queue.Entries | Where-Object Status -eq 'PENDING')[0].Identity
        $success.sourceLength | Should -Be 4
        $success.sourceLastWriteTimeUtc | Should -Not -BeNullOrEmpty
        $records[3].counts.success | Should -Be 1
        $records[3].counts.skipped | Should -Be 1
        $script:folderCalls.Count | Should -Be 1
        $script:folderCalls[0].IgnoreSavedSettings | Should -BeTrue
        $script:folderCalls[0].ContainsKey('InputDirectories') | Should -BeFalse
        $script:folderCalls[0].ContainsKey('Recurse') | Should -BeFalse
        $script:folderCalls[0].ContainsKey('SettingsPath') | Should -BeFalse
    }

    It 'does not request mode or start children for <Case> selections' -ForEach @(@{ Case = 'empty' }, @{ Case = 'all skipped' }) {
        if ($Case -eq 'all skipped') { $null = New-WacFolderTestInput -Root $folderRunRoot -Name 'notes.txt' }
        $queue = New-WacFolderQueue -Directories @($folderRunRoot) -OutputDirectory $folderRunOutput
        $folderRunResolved.Values.Mode = $null
        Mock Test-WacInteractive { $true }
        Mock Read-WacMode { throw 'The empty/skipped folder must not request a mode.' }
        $result = Invoke-WacFolderTestBatch -Queue $queue -Parameters $folderRunParameters -Resolved $folderRunResolved
        $result.ExitCode | Should -Be 0
        $result.ReportingComplete | Should -BeTrue
        Should -Invoke Read-WacMode -Times 0 -Exactly
        Should -Invoke Invoke-WacBatchItem -Times 0 -Exactly
        $records = @(Read-WacFolderTestJournal -Path $folderRunResult)
        $records[-1].counts.success | Should -Be 0
        $records[-1].counts.skipped | Should -Be $(if ($Case -eq 'empty') { 0 } else { 1 })
        $records[-1].exitCode | Should -Be 0
    }

    It 'treats a one-file folder failure as aggregate6 while preserving the ordinary failed-item code' {
        $null = New-WacFolderTestInput -Root $folderRunRoot
        $queue = New-WacFolderQueue -Directories @($folderRunRoot) -OutputDirectory $folderRunOutput
        Mock Invoke-WacBatchItem { [pscustomobject]@{ ExitCode = 4; Diagnostics = @('controlled processing failure') } }
        $result = Invoke-WacFolderTestBatch -Queue $queue -Parameters $folderRunParameters -Resolved $folderRunResolved
        $result.ExitCode | Should -Be 6
        $records = @(Read-WacFolderTestJournal -Path $folderRunResult)
        $records[1].exitCode | Should -Be 4
        $records[2].counts.failed | Should -Be 1
        $records[2].exitCode | Should -Be 6
    }

    It 'continues a middle failure and retains success/failure/skipped records and exports' {
        foreach ($name in @('a.wav', 'b.wav', 'c.wav', 'notes.txt')) { $null = New-WacFolderTestInput -Root $folderRunRoot -Name $name }
        $queue = New-WacFolderQueue -Directories @($folderRunRoot) -OutputDirectory $folderRunOutput
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:folderCalls.Add($Arguments)
            $code = if ([IO.Path]::GetFileName($Arguments.inputPath) -eq 'b.wav') { 4 } else { 0 }
            if ($code -eq 0) { [IO.File]::WriteAllBytes((Join-Path $folderRunOutput ([IO.Path]::GetFileName($Arguments.inputPath) + '.export')), [byte[]](8)) }
            [pscustomobject]@{ ExitCode = $code; Diagnostics = @('controlled per-item result') }
        }
        $result = Invoke-WacFolderTestBatch -Queue $queue -Parameters $folderRunParameters -Resolved $folderRunResolved
        $result.ExitCode | Should -Be 6
        $script:folderCalls.Count | Should -Be 3
        $records = @(Read-WacFolderTestJournal -Path $folderRunResult)
        @($records[1..4] | ForEach-Object { $_.status }) -join ',' | Should -BeExactly 'SUCCESS,FAILED,SUCCESS,SKIPPED'
        $records[-1].counts.success | Should -Be 2
        $records[-1].counts.failed | Should -Be 1
        $records[-1].counts.skipped | Should -Be 1
        @(Get-ChildItem -LiteralPath $folderRunOutput -Filter '*.export').Count | Should -Be 2
    }

    It 'keeps a warning-only folder at7 and counts static skips separately' {
        $null = New-WacFolderTestInput -Root $folderRunRoot
        $null = New-WacFolderTestInput -Root $folderRunRoot -Name 'notes.txt'
        $queue = New-WacFolderQueue -Directories @($folderRunRoot) -OutputDirectory $folderRunOutput
        Mock Invoke-WacBatchItem { [pscustomobject]@{ ExitCode = 7; Diagnostics = @('controlled warning') } }
        $result = Invoke-WacFolderTestBatch -Queue $queue -Parameters $folderRunParameters -Resolved $folderRunResolved
        $result.ExitCode | Should -Be 7
        $records = @(Read-WacFolderTestJournal -Path $folderRunResult)
        $records[-1].counts.warning | Should -Be 1
        $records[-1].counts.skipped | Should -Be 1
    }

    It 'does not add ordinary late arrivals or newly generated outputs to the materialized queue' {
        foreach ($name in @('a.wav', 'b.wav')) { $null = New-WacFolderTestInput -Root $folderRunRoot -Name $name }
        $queue = New-WacFolderQueue -Directories @($folderRunRoot) -OutputDirectory $folderRunRoot
        $folderRunResolved.Values.OutputDirectory = $folderRunRoot
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:folderCalls.Add($Arguments)
            if ($script:folderCalls.Count -eq 1) {
                $null = New-WacFolderTestInput -Root $folderRunRoot -Name 'late.wav'
                $null = New-WacFolderTestInput -Root $folderRunRoot -Name 'a_Cleaned_20261003-123456_0123456789abcdef0123456789abcdef.wav'
            }
            [pscustomobject]@{ ExitCode = 0; Diagnostics = @() }
        }
        $result = Invoke-WacFolderTestBatch -Queue $queue -Parameters $folderRunParameters -Resolved $folderRunResolved
        $result.ExitCode | Should -Be 0
        $script:folderCalls.Count | Should -Be 2
        $queue.Entries.Count | Should -Be 2
        $records = @(Read-WacFolderTestJournal -Path $folderRunResult)
        $records.Count | Should -Be 4
        $records[0].inputCount | Should -Be 2
        @($records | Where-Object inputPath -match 'late|_Cleaned_').Count | Should -Be 0
    }

    It 'fails a later replaced identity before invoking it and continues to the final original' {
        foreach ($name in @('a.wav', 'b.wav', 'c.wav')) { $null = New-WacFolderTestInput -Root $folderRunRoot -Name $name }
        $queue = New-WacFolderQueue -Directories @($folderRunRoot) -OutputDirectory $folderRunOutput
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:folderCalls.Add($Arguments)
            if ($script:folderCalls.Count -eq 1) {
                $later = Join-Path $folderRunRoot 'b.wav'
                [IO.File]::Move($later, ($later + '.prior'))
                [IO.File]::WriteAllBytes($later, [byte[]](9, 9, 9, 9))
                [IO.File]::SetLastWriteTimeUtc($later, [datetime]$queue.Entries[1].LastWriteTimeUtc)
            }
            [pscustomobject]@{ ExitCode = 0; Diagnostics = @() }
        }
        $result = Invoke-WacFolderTestBatch -Queue $queue -Parameters $folderRunParameters -Resolved $folderRunResolved
        $result.ExitCode | Should -Be 6
        $script:folderCalls.Count | Should -Be 2
        $records = @(Read-WacFolderTestJournal -Path $folderRunResult)
        @($records[1..3] | ForEach-Object { $_.status }) -join ',' | Should -BeExactly 'SUCCESS,FAILED,SUCCESS'
        $records[2].reasonCode | Should -BeExactly 'source_changed'
        $records[2].exitCode | Should -Be 2
        Get-WacFolderTestBytes -Path (Join-Path $folderRunRoot 'b.wav') | Should -BeExactly 'CQkJCQ=='
        Get-WacFolderTestBytes -Path (Join-Path $folderRunRoot 'b.wav.prior') | Should -BeExactly 'AQIDBA=='
    }

    It 'preserves static skips/failures after cancellation while pending entries become not started' {
        foreach ($name in @('a.wav', 'b.txt', 'c.wav', 'd.wav')) { $null = New-WacFolderTestInput -Root $folderRunRoot -Name $name }
        $blockedPath = Join-Path $folderRunRoot 'c.wav'
        $blocked = [IO.File]::Open($blockedPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try { $queue = New-WacFolderQueue -Directories @($folderRunRoot) -OutputDirectory $folderRunOutput }
        finally { $blocked.Dispose() }
        Mock Invoke-WacBatchItem { [pscustomobject]@{ ExitCode = 130; Diagnostics = @('controlled cancellation') } }
        $result = Invoke-WacFolderTestBatch -Queue $queue -Parameters $folderRunParameters -Resolved $folderRunResolved
        $result.ExitCode | Should -Be 130
        Should -Invoke Invoke-WacBatchItem -Times 1 -Exactly
        $records = @(Read-WacFolderTestJournal -Path $folderRunResult)
        @($records[1..4] | ForEach-Object { $_.status }) -join ',' | Should -BeExactly 'CANCELLED,SKIPPED,FAILED,NOT_STARTED'
        $records[3].reasonCode | Should -BeExactly 'source_unavailable'
        $records[3].exitCode | Should -Be 2
        $records[4].exitCode | Should -BeNullOrEmpty
        $records[-1].counts.cancelled | Should -Be 1
        $records[-1].counts.skipped | Should -Be 1
        $records[-1].counts.failed | Should -Be 1
        $records[-1].counts.notStarted | Should -Be 1
        [IO.File]::WriteAllBytes((Join-Path $folderRunRoot 'a.wav'), [byte[]](7))
    }

    It 'closes source leases when <Stage> journal persistence fails and retains completed exports' -ForEach @(
        @{ Stage = 'item'; FailedType = 'item'; ExpectedJobs = 1; ExpectedRecords = 1 }
        @{ Stage = 'summary'; FailedType = 'summary'; ExpectedJobs = 2; ExpectedRecords = 3 }
    ) {
        foreach ($name in @('a.wav', 'b.wav')) { $null = New-WacFolderTestInput -Root $folderRunRoot -Name $name }
        $queue = New-WacFolderQueue -Directories @($folderRunRoot) -OutputDirectory $folderRunOutput
        $originalAppender = (Get-Command Add-WacBatchRecord).ScriptBlock
        Mock Invoke-WacBatchItem {
            param($ApplicationPath, $Arguments)
            $script:folderCalls.Add($Arguments)
            { [IO.File]::WriteAllBytes($Arguments.inputPath, [byte[]](9)) } | Should -Throw
            [IO.File]::WriteAllBytes((Join-Path $folderRunOutput ([IO.Path]::GetFileName($Arguments.inputPath) + '.export')), [byte[]](8))
            [pscustomobject]@{ ExitCode = 0; Diagnostics = @() }
        }
        Mock Add-WacBatchRecord {
            param($Writer, $Record)
            if ($Record.type -eq $FailedType) { throw 'controlled folder journal persistence failure' }
            & $originalAppender -Writer $Writer -Record $Record
        }
        $result = Invoke-WacFolderTestBatch -Queue $queue -Parameters $folderRunParameters -Resolved $folderRunResolved
        $result.ExitCode | Should -Be 5
        $result.ReportingComplete | Should -BeFalse
        $script:folderCalls.Count | Should -Be $ExpectedJobs
        @(Read-WacFolderTestJournal -Path $folderRunResult).Count | Should -Be $ExpectedRecords
        @(Get-ChildItem -LiteralPath $folderRunOutput -Filter '*.export').Count | Should -Be $ExpectedJobs
        foreach ($name in @('a.wav', 'b.wav')) { [IO.File]::WriteAllBytes((Join-Path $folderRunRoot $name), [byte[]](7)) }
        [IO.Directory]::Move($folderRunRoot, ($folderRunRoot + '-released'))
    }
}

Describe 'AC-055/056: isolated folder CLI preserves single-file publication and preference isolation' -Tag 'FolderQueue', 'EntryPoint', 'Runtime' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'fixtures/New-NativeProcessFixture.ps1')
        $folderNative = New-WacTestNativeExecutable -OutputPath (Join-Path $TestDrive 'folder native fixture.exe')
        $folderShell = (Get-Process -Id $PID).Path
        function New-WacFolderSandbox {
            $root = New-WacFolderTestRoot
            foreach ($name in @('WinAudioClean.ps1', 'WinAudioClean.IO.ps1', 'WinAudioClean.Settings.ps1', 'WinAudioClean.Batch.ps1', 'WinAudioClean.Queue.ps1')) {
                [IO.File]::Copy((Join-Path $folderRepository $name), (Join-Path $root $name))
            }
            foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) { [IO.File]::Copy($folderNative, (Join-Path $root $name)) }
            $inputRoot = Join-Path $root 'input [draft]'
            $otherRoot = Join-Path $root 'second input'
            $cwd = Join-Path $root 'different cwd'
            foreach ($path in @($inputRoot, $otherRoot, $cwd)) { $null = [IO.Directory]::CreateDirectory($path) }
            [pscustomobject]@{ Root = $root; App = Join-Path $root 'WinAudioClean.ps1'; InputRoot = $inputRoot; OtherRoot = $otherRoot
                Selection = Join-Path $root 'folder selection.json'; Config = Join-Path $root 'isolated settings.json'
                Output = Join-Path $inputRoot 'nested destination'; Result = Join-Path $root 'results.jsonl'; Cwd = $cwd
                RenderArgv = Join-Path $root 'last render.json'; NativePid = Join-Path $root 'native.pid' }
        }
        function Write-WacFolderSandboxSelection {
            param($Sandbox, [string[]]$Directories)
            [IO.File]::WriteAllText($Sandbox.Selection, (([ordered]@{ directories = $Directories }) | ConvertTo-Json -Compress), $folderUtf8)
        }
        function Invoke-WacFolderSandbox {
            param($Sandbox, [string]$Case = 'normal')
            $driver = Join-Path $PSScriptRoot 'fixtures/Invoke-FolderQueueCase.ps1'
            $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {0} -ApplicationPath {1} -SettingsPath {2} -SelectionPath {3} -OutputDirectory {4} -ResultPath {5} -Case {6}' -f
                (ConvertTo-WacTestQuotedArgument $driver), (ConvertTo-WacTestQuotedArgument $Sandbox.App),
                (ConvertTo-WacTestQuotedArgument $Sandbox.Config), (ConvertTo-WacTestQuotedArgument $Sandbox.Selection),
                (ConvertTo-WacTestQuotedArgument $Sandbox.Output), (ConvertTo-WacTestQuotedArgument $Sandbox.Result), (ConvertTo-WacTestQuotedArgument $Case)
            $environment = @{ WAC_TEST_FFMPEG_OUTPUT = '1'; WAC_TEST_ARGV_PATH = $Sandbox.RenderArgv
                WAC_TEST_VERSION_PID_PATH = $Sandbox.NativePid; WAC_TEST_FILTERS_PID_PATH = $Sandbox.NativePid
                WAC_TEST_PROBE_PID_PATH = $Sandbox.NativePid; PSModulePath = $null }
            Invoke-WacTestProcess -FilePath $folderShell -Arguments $arguments -WorkingDirectory $Sandbox.Cwd -EnvironmentVariables $environment -TimeoutMilliseconds 60000
        }
    }

    It 'defaults to top-level selection and explains unsupported nested and generated exclusions' {
        $sandbox = New-WacFolderSandbox
        $source = New-WacFolderTestInput -Root $sandbox.InputRoot -Name ("speaker's $folderUnicode %literal%! & guest.wav")
        $null = New-WacFolderTestInput -Root $sandbox.InputRoot -Name 'notes.txt'
        $null = New-WacFolderTestInput -Root $sandbox.InputRoot -Name 'ordinary nested/child.wav'
        $prior = New-WacFolderTestInput -Root $sandbox.InputRoot -Name 'old_Cleaned_20261003-1234_0123456789abcdef0123456789abcdef.wav' -Bytes ([byte[]](9, 8))
        Write-WacFolderSandboxSelection -Sandbox $sandbox -Directories @($sandbox.InputRoot)
        $result = Invoke-WacFolderSandbox -Sandbox $sandbox
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $records = @(Read-WacFolderTestJournal -Path $sandbox.Result)
        $records[0].schemaVersion | Should -Be 2
        $records[0].selection.recurse | Should -BeFalse
        $records[-1].counts.success | Should -Be 1
        $records[-1].counts.skipped | Should -Be 4
        foreach ($reason in @('unsupported_extension', 'recursion_disabled', 'generated_artifact', 'output_directory')) {
            @($records | Where-Object reasonCode -eq $reason).Count | Should -Be 1
        }
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav').Count | Should -Be 1
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json').Count | Should -Be 1
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.partial' -Force).Count | Should -Be 0
        Get-WacFolderTestBytes -Path $source | Should -BeExactly 'AQIDBA=='
        Get-WacFolderTestBytes -Path $prior | Should -BeExactly 'CQg='
        Test-Path -LiteralPath $sandbox.Config | Should -BeFalse
        $result.StandardOutput | Should -Match 'Folder summary:'
        $result.StandardOutput | Should -Not -Match 'Enter selection|Press any key'
    }

    It 'publishes identical stems from different folders to unique names without overwriting a prior export or requeuing the destination' {
        $sandbox = New-WacFolderSandbox
        $first = New-WacFolderTestInput -Root $sandbox.InputRoot -Name 'ordinary nested/same.wav'
        $second = New-WacFolderTestInput -Root $sandbox.OtherRoot -Name 'same.wav'
        $prior = New-WacFolderTestInput -Root $sandbox.Output -Name 'same_Cleaned_20261003-123456_0123456789abcdef0123456789abcdef.wav' -Bytes ([byte[]](9, 8))
        Write-WacFolderSandboxSelection -Sandbox $sandbox -Directories @($sandbox.InputRoot, $sandbox.OtherRoot)
        $result = Invoke-WacFolderSandbox -Sandbox $sandbox -Case 'recursive'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $records = @(Read-WacFolderTestJournal -Path $sandbox.Result)
        $records[0].selection.recurse | Should -BeTrue
        $records[-1].counts.success | Should -Be 2
        $records[-1].counts.skipped | Should -Be 1
        @($records | Where-Object reasonCode -eq 'output_directory').Count | Should -Be 1
        $exports = @(Get-ChildItem -LiteralPath $sandbox.Output -Filter '*.wav' | Where-Object FullName -ne $prior)
        $exports.Count | Should -Be 2
        $exports[0].Name | Should -Not -BeExactly $exports[1].Name
        foreach ($export in $exports) { $export.Name | Should -Match '^same_Cleaned_[0-9]{8}-[0-9]{9}_[0-9a-f]{32}\.wav$' }
        @(Get-ChildItem -LiteralPath $sandbox.Output -Filter 'WinAudioClean_*.json').Count | Should -Be 2
        Get-WacFolderTestBytes -Path $prior | Should -BeExactly 'CQg='
        Get-WacFolderTestBytes -Path $first | Should -BeExactly 'AQIDBA=='
        Get-WacFolderTestBytes -Path $second | Should -BeExactly 'AQIDBA=='
        Test-Path -LiteralPath $sandbox.Config | Should -BeFalse
    }

    It 'does not require mode or media tools for a CLI <Case> selection' -ForEach @(@{ Case = 'empty' }, @{ Case = 'all skipped' }) {
        $sandbox = New-WacFolderSandbox
        if ($Case -eq 'all skipped') { $null = New-WacFolderTestInput -Root $sandbox.InputRoot -Name 'notes.txt' }
        Write-WacFolderSandboxSelection -Sandbox $sandbox -Directories @($sandbox.InputRoot)
        foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) { [IO.File]::Delete((Join-Path $sandbox.Root $name)) }
        $result = Invoke-WacFolderSandbox -Sandbox $sandbox -Case 'no mode'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
        Test-Path -LiteralPath $sandbox.RenderArgv | Should -BeFalse
        $records = @(Read-WacFolderTestJournal -Path $sandbox.Result)
        $records[-1].counts.success | Should -Be 0
        $records[-1].counts.skipped | Should -Be $(if ($Case -eq 'empty') { 1 } else { 2 })
        $records[-1].exitCode | Should -Be 0
        $result.StandardOutput | Should -Not -Match 'Enter selection|Select one processing mode|Press any key'
    }

    It 'rejects CLI <Case> before native invocation or result allocation' -ForEach @(
        @{ Case = 'single conflict' }; @{ Case = 'explicit list conflict' }; @{ Case = 'manifest conflict' }
        @{ Case = 'recursion without folder false' }; @{ Case = 'preview conflict' }; @{ Case = 'range conflict' }
        @{ Case = 'show settings conflict' }; @{ Case = 'missing root' }; @{ Case = 'corrupt saved' }; @{ Case = 'missing helper' }
    ) {
        $sandbox = New-WacFolderSandbox
        $selected = if ($Case -eq 'missing root') { Join-Path $sandbox.Root 'does not exist' } else { $sandbox.InputRoot }
        Write-WacFolderSandboxSelection -Sandbox $sandbox -Directories @($selected)
        if ($Case -eq 'corrupt saved') { [IO.File]::WriteAllText($sandbox.Config, '{"schemaVersion":1,"settings":{"preset":"invalid"}}', $folderUtf8) }
        if ($Case -eq 'missing helper') { [IO.File]::Delete((Join-Path $sandbox.Root 'WinAudioClean.Queue.ps1')) }
        $result = Invoke-WacFolderSandbox -Sandbox $sandbox -Case $Case
        $result.ExitCode | Should -Be 2 -Because ($result.StandardOutput + $result.StandardError)
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
        Test-Path -LiteralPath $sandbox.RenderArgv | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Result | Should -BeFalse
        $result.StandardOutput | Should -Not -Match 'Processing input|Enter selection|Press any key'
    }

    It 'keeps main imports IO-only even when folder parameters are present and optional siblings are absent' {
        $sandbox = New-WacFolderSandbox
        Write-WacFolderSandboxSelection -Sandbox $sandbox -Directories @($sandbox.InputRoot)
        foreach ($name in @('WinAudioClean.Queue.ps1', 'WinAudioClean.Batch.ps1', 'WinAudioClean.Settings.ps1')) { [IO.File]::Delete((Join-Path $sandbox.Root $name)) }
        $result = Invoke-WacFolderSandbox -Sandbox $sandbox -Case 'import only'
        $result.ExitCode | Should -Be 0 -Because ($result.StandardOutput + $result.StandardError)
        $result.StandardOutput | Should -Match 'ImportOnly:Queue=False;Batch=False;Settings=False'
        Test-Path -LiteralPath $sandbox.NativePid | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Result | Should -BeFalse
        Test-Path -LiteralPath $sandbox.Output | Should -BeFalse
    }
}
