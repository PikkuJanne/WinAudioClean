BeforeAll {
    $script:releaseRepo = Split-Path -Parent $PSScriptRoot
    $script:releasePayload = @(
        'LICENSE', 'README.md', 'THIRD_PARTY_NOTICES.md', 'WinAudioClean.Batch.ps1',
        'WinAudioClean.IO.ps1', 'WinAudioClean.Launcher.ps1', 'WinAudioClean.Output.ps1',
        'WinAudioClean.Preview.ps1', 'WinAudioClean.Queue.ps1', 'WinAudioClean.Settings.ps1',
        'WinAudioClean.bat', 'WinAudioClean.ico', 'WinAudioClean.ps1',
        'docs/PORTABLE_PACKAGE.md', 'docs/codex/winaudioclean/DATA_FORMATS.md'
    )
    [Array]::Sort($script:releasePayload, [StringComparer]::Ordinal)
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    function Invoke-ReleaseFixtureGit {
        param([string]$Root, [string[]]$Arguments)
        $value = & git -C $Root @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Fixture Git failed: $($Arguments[0])" }
        return $value
    }

    function New-ReleaseFixture {
        param([string]$VersionSource = '$scriptVersion = "2.3"', [string]$Missing)
        $root = Join-Path $TestDrive ('source ' + [char]0xE4 + ' ' + [guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory((Join-Path $root 'scripts'))
        Copy-Item -LiteralPath (Join-Path $script:releaseRepo 'scripts/Build-Release.ps1') -Destination (Join-Path $root 'scripts/Build-Release.ps1')
        foreach ($path in $script:releasePayload) {
            if ($path -ceq $Missing) { continue }
            $target = Join-Path $root $path
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
            if ($path -ceq 'WinAudioClean.ps1') {
                [IO.File]::WriteAllText($target, $VersionSource + "`r`n", [Text.UTF8Encoding]::new($true))
            } elseif ($path -ceq 'WinAudioClean.ico') {
                [IO.File]::WriteAllBytes($target, [byte[]]@(0, 1, 255, 128, 13, 10))
            } elseif ($path -ceq 'LICENSE') {
                Copy-Item -LiteralPath (Join-Path $script:releaseRepo 'LICENSE') -Destination $target
            } else {
                [IO.File]::WriteAllText($target, 'Synthetic payload: ' + $path + "`r`n", [Text.UTF8Encoding]::new($false))
            }
        }
        [IO.File]::WriteAllText((Join-Path $root '.gitignore'), "/dist/`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $root 'private-development-sentinel.txt'), 'synthetic excluded marker')
        $null = Invoke-ReleaseFixtureGit $root @('init', '--quiet')
        $null = Invoke-ReleaseFixtureGit $root @('config', 'user.name', 'Package test')
        $null = Invoke-ReleaseFixtureGit $root @('config', 'user.email', 'package-test@example.invalid')
        $null = Invoke-ReleaseFixtureGit $root @('config', 'core.autocrlf', 'false')
        $null = Invoke-ReleaseFixtureGit $root @('add', '--all')
        $null = Invoke-ReleaseFixtureGit $root @('commit', '--quiet', '-m', 'Synthetic package fixture')
        return [pscustomobject]@{
            Root = $root
            Builder = Join-Path $root 'scripts/Build-Release.ps1'
            Commit = [string](Invoke-ReleaseFixtureGit $root @('rev-parse', 'HEAD'))
            Tree = [string](Invoke-ReleaseFixtureGit $root @('rev-parse', 'HEAD^{tree}'))
        }
    }

    function Get-ReleaseFixtureHash {
        param([byte[]]$Bytes)
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
    }

    function Read-ReleaseFixtureZip {
        param([string]$Path)
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            $entries = @()
            foreach ($entry in $archive.Entries) {
                $stream = $entry.Open()
                $bytes = [IO.MemoryStream]::new()
                try { $stream.CopyTo($bytes); $content = $bytes.ToArray() }
                finally { $stream.Dispose(); $bytes.Dispose() }
                $entries += [pscustomobject]@{
                    Path = $entry.FullName; Bytes = $content
                    Time = $entry.LastWriteTime; Attributes = $entry.ExternalAttributes
                }
            }
            return ,$entries
        } finally { $archive.Dispose() }
    }
}

Describe 'Committed tool-only release packaging' -Tag 'Release', 'Packaging' {
    It 'builds identical bytes twice and preserves every allowed payload byte with consistent integrity metadata' {
        $fixture = New-ReleaseFixture
        $one = Join-Path $fixture.Root 'dist/one'
        $two = Join-Path $fixture.Root 'dist/two'
        $first = & $fixture.Builder -Revision $fixture.Commit -OutputDirectory $one
        $second = & $fixture.Builder -Revision $fixture.Commit -OutputDirectory $two
        $first.version | Should -BeExactly '2.3'
        $first.source_commit | Should -BeExactly $fixture.Commit
        $first.source_tree | Should -BeExactly $fixture.Tree
        $first.zip | Should -BeExactly ('WinAudioClean-2.3-' + $fixture.Commit.Substring(0, 12) + '-tool-only.zip')
        foreach ($name in @($first.zip, $first.checksum, $first.provenance)) {
            [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $one $name))) |
                Should -BeExactly ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $two $name))))
        }
        $first.zip_sha256 | Should -BeExactly $second.zip_sha256
        $zipBytes = [IO.File]::ReadAllBytes((Join-Path $one $first.zip))
        $first.zip_sha256 | Should -BeExactly (Get-ReleaseFixtureHash $zipBytes)
        [IO.File]::ReadAllText((Join-Path $one $first.checksum)) |
            Should -BeExactly ($first.zip_sha256 + '  ' + $first.zip + "`n")
        $entries = Read-ReleaseFixtureZip (Join-Path $one $first.zip)
        [string[]]$expected = @($script:releasePayload) + 'PACKAGE-MANIFEST.json'
        [Array]::Sort($expected, [StringComparer]::Ordinal)
        ($entries.Path -join '|') | Should -BeExactly ($expected -join '|')
        $entries.Count | Should -Be 16
        foreach ($entry in $entries) {
            $entry.Time.Year | Should -Be 1980
            $entry.Time.Month | Should -Be 1
            $entry.Time.Day | Should -Be 1
            $entry.Time.TimeOfDay.Ticks | Should -Be 0
            $entry.Attributes | Should -Be 0
            if ($entry.Path -cne 'PACKAGE-MANIFEST.json') {
                [Convert]::ToBase64String($entry.Bytes) |
                    Should -BeExactly ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $fixture.Root $entry.Path))))
            }
        }
        $manifest = [Text.Encoding]::UTF8.GetString(($entries | Where-Object Path -CEQ 'PACKAGE-MANIFEST.json').Bytes) | ConvertFrom-Json
        $manifest.schema_version | Should -Be 1
        $manifest.version | Should -BeExactly '2.3'
        $manifest.source_commit | Should -BeExactly $fixture.Commit
        $manifest.source_tree | Should -BeExactly $fixture.Tree
        $manifest.payload.Count | Should -Be 15
        ($manifest.payload.path -join '|') | Should -BeExactly ($script:releasePayload -join '|')
        foreach ($item in $manifest.payload) {
            $entry = $entries | Where-Object Path -CEQ $item.path
            $item.bytes | Should -Be $entry.Bytes.Length
            $item.sha256 | Should -BeExactly (Get-ReleaseFixtureHash $entry.Bytes)
        }
        $provenance = [IO.File]::ReadAllText((Join-Path $one $first.provenance)) | ConvertFrom-Json
        $provenance.zip_sha256 | Should -BeExactly $first.zip_sha256
        $provenance.version | Should -BeExactly $manifest.version
        $provenance.source_commit | Should -BeExactly $manifest.source_commit
        ($provenance.payload | ConvertTo-Json -Compress) | Should -BeExactly ($manifest.payload | ConvertTo-Json -Compress)
        [string](Invoke-ReleaseFixtureGit $fixture.Root @('status', '--porcelain')) | Should -BeNullOrEmpty
    }

    It 'rejects a tracked edit before creating outputs' {
        $fixture = New-ReleaseFixture
        [IO.File]::AppendAllText((Join-Path $fixture.Root 'README.md'), 'dirty')
        { & $fixture.Builder -Revision $fixture.Commit -OutputDirectory (Join-Path $fixture.Root 'dist/rejected') } | Should -Throw '*clean checkout*'
        Test-Path -LiteralPath (Join-Path $fixture.Root 'dist/rejected') | Should -BeFalse
    }

    It 'rejects a nonignored untracked file before creating outputs' {
        $fixture = New-ReleaseFixture
        [IO.File]::WriteAllText((Join-Path $fixture.Root 'untracked.txt'), 'synthetic')
        { & $fixture.Builder -Revision $fixture.Commit -OutputDirectory (Join-Path $fixture.Root 'dist/rejected') } | Should -Throw '*clean checkout*'
        Test-Path -LiteralPath (Join-Path $fixture.Root 'dist/rejected') | Should -BeFalse
    }

    It 'rejects a different explicit revision' {
        $fixture = New-ReleaseFixture
        { & $fixture.Builder -Revision ('a' * 40) -OutputDirectory (Join-Path $fixture.Root 'dist/rejected') } | Should -Throw '*current clean HEAD*'
    }

    It 'rejects a missing allowlisted blob instead of emitting an incomplete package' {
        $fixture = New-ReleaseFixture -Missing 'WinAudioClean.Settings.ps1'
        { & $fixture.Builder -Revision $fixture.Commit -OutputDirectory (Join-Path $fixture.Root 'dist/rejected') } | Should -Throw '*committed ordinary Git blob*'
        Test-Path -LiteralPath (Join-Path $fixture.Root 'dist/rejected') | Should -BeFalse
    }

    It 'rejects a Git symlink entry even when the Windows checkout represents it as an ordinary file' {
        $fixture = New-ReleaseFixture
        $null = Invoke-ReleaseFixtureGit $fixture.Root @('config', 'core.symlinks', 'false')
        [IO.File]::WriteAllText((Join-Path $fixture.Root 'WinAudioClean.ico'), 'README.md', [Text.UTF8Encoding]::new($false))
        $blob = [string](Invoke-ReleaseFixtureGit $fixture.Root @('hash-object', '-w', 'WinAudioClean.ico'))
        $null = Invoke-ReleaseFixtureGit $fixture.Root @('update-index', '--cacheinfo', ('120000,' + $blob + ',WinAudioClean.ico'))
        $null = Invoke-ReleaseFixtureGit $fixture.Root @('commit', '--quiet', '-m', 'Synthetic Git symlink fixture')
        $revision = [string](Invoke-ReleaseFixtureGit $fixture.Root @('rev-parse', 'HEAD'))
        [string](Invoke-ReleaseFixtureGit $fixture.Root @('status', '--porcelain')) | Should -BeNullOrEmpty
        { & $fixture.Builder -Revision $revision -OutputDirectory (Join-Path $fixture.Root 'dist/rejected') } | Should -Throw '*committed ordinary Git blob*'
        Test-Path -LiteralPath (Join-Path $fixture.Root 'dist/rejected') | Should -BeFalse
    }

    It 'rejects ambiguous, computed or unsafe authoritative versions: <Label>' -TestCases @(
        @{ Label = 'duplicate'; Source = '$scriptVersion = "2.3"; $scriptVersion = "2.4"' },
        @{ Label = 'computed'; Source = '$scriptVersion = ("2." + "3")' },
        @{ Label = 'unsafe'; Source = '$scriptVersion = "../2.3"' },
        @{ Label = 'nested'; Source = 'function Uncalled { $scriptVersion = "2.3" }' },
        @{ Label = 'environment'; Source = '$env:scriptVersion = "2.3"' }
    ) {
        param($Label, $Source)
        $fixture = New-ReleaseFixture -VersionSource $Source
        { & $fixture.Builder -Revision $fixture.Commit -OutputDirectory (Join-Path $fixture.Root 'dist/rejected') } | Should -Throw
        Test-Path -LiteralPath (Join-Path $fixture.Root 'dist/rejected') | Should -BeFalse
    }

    It 'preserves any preexisting output and creates no sibling artifacts: <Extension>' -TestCases @(
        @{ Extension = '.zip' }, @{ Extension = '.sha256' }, @{ Extension = '.provenance.json' }
    ) {
        param($Extension)
        $fixture = New-ReleaseFixture
        $output = Join-Path $fixture.Root 'dist/existing'
        [void][IO.Directory]::CreateDirectory($output)
        $name = 'WinAudioClean-2.3-' + $fixture.Commit.Substring(0, 12) + '-tool-only' + $Extension
        [IO.File]::WriteAllText((Join-Path $output $name), 'existing marker')
        { & $fixture.Builder -Revision $fixture.Commit -OutputDirectory $output } | Should -Throw '*already exists*'
        [IO.File]::ReadAllText((Join-Path $output $name)) | Should -BeExactly 'existing marker'
        @(Get-ChildItem -LiteralPath $output -Force).Count | Should -Be 1
    }

    It 'rejects a nonignored destination within the source tree before writing an artifact' {
        $fixture = New-ReleaseFixture
        $output = Join-Path $fixture.Root 'not-ignored'
        { & $fixture.Builder -Revision $fixture.Commit -OutputDirectory $output } | Should -Throw
        @(Get-ChildItem -LiteralPath $output -File).Count | Should -Be 0
        [string](Invoke-ReleaseFixtureGit $fixture.Root @('status', '--porcelain')) | Should -BeNullOrEmpty
    }

    It 'rejects a junction destination without writing into its target' {
        $fixture = New-ReleaseFixture
        $target = Join-Path $TestDrive ('ordinary-' + [guid]::NewGuid().ToString('N'))
        $alias = Join-Path $fixture.Root 'dist/junction'
        [void][IO.Directory]::CreateDirectory($target)
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($alias))
        $null = New-Item -ItemType Junction -Path $alias -Target $target
        try {
            { & $fixture.Builder -Revision $fixture.Commit -OutputDirectory $alias } | Should -Throw '*without reparse points*'
            @(Get-ChildItem -LiteralPath $target -Force).Count | Should -Be 0
        } finally {
            # Remove only this owned junction, never recursively traverse its target.
            [IO.Directory]::Delete($alias)
        }
    }
}
