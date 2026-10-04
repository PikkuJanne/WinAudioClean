BeforeAll {
    . (Join-Path $PSScriptRoot '../scripts/Install-CIDependencies.ps1')
}

Describe 'AC-071: explicit CI tool download integrity' -Tag 'CI', 'Unit' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $root
        $payload = Join-Path $root 'payload'
        $null = New-Item -ItemType Directory -Path $payload
        [IO.File]::WriteAllText((Join-Path $payload 'python.exe'), 'synthetic archive member; never executed')
        $fixture = Join-Path $root 'fixture.zip'
        Compress-Archive -LiteralPath (Join-Path $payload 'python.exe') -DestinationPath $fixture
        $tool = [pscustomobject]@{
            uri = 'https://www.python.org/ftp/python/pinned-fixture.zip'
            sha256 = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash.ToLowerInvariant()
            executable = 'python.exe'
        }
        Mock Invoke-WebRequest { Copy-Item -LiteralPath $fixture -Destination $OutFile }
        $toolRoot = Join-Path $root 'tools'
        $null = New-Item -ItemType Directory -Path $toolRoot
    }

    It 'verifies downloaded bytes before extraction and uses a fresh contained directory' {
        $result = Install-WacCITool -Tool $tool -ToolRoot $toolRoot
        [IO.File]::ReadAllText($result) | Should -BeExactly 'synthetic archive member; never executed'
        $result.StartsWith($toolRoot + [IO.Path]::DirectorySeparatorChar) | Should -BeTrue
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
        $again = Install-WacCITool -Tool $tool -ToolRoot $toolRoot
        $again | Should -Not -Be $result
        Test-Path -LiteralPath $result | Should -BeTrue
    }

    It 'rejects a mismatching trusted digest before extraction or execution' {
        $tool.sha256 = '0' * 64
        Mock Expand-Archive { throw 'Extraction must not run after mismatch' }
        { Install-WacCITool -Tool $tool -ToolRoot $toolRoot } | Should -Throw '*SHA256 mismatch*'
        Should -Invoke Expand-Archive -Times 0 -Exactly
        @(Get-ChildItem -LiteralPath $toolRoot -Recurse -Filter python.exe).Count | Should -Be 0
    }

    It 'refuses an untrusted download host before a request' {
        $tool.uri = 'https://example.invalid/tool.zip'
        { Install-WacCITool -Tool $tool -ToolRoot $toolRoot } | Should -Throw '*official HTTPS*'
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
    }

    It 'refuses an invalid manifest before creating a download' {
        $tool.sha256 = 'not-a-checksum'
        { Install-WacCITool -Tool $tool -ToolRoot $toolRoot } | Should -Throw '*manifest*'
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly
        @(Get-ChildItem -LiteralPath $toolRoot).Count | Should -Be 0
    }

    It 'restores the caller TLS setting when the request fails' {
        $previous = [Net.ServicePointManager]::SecurityProtocol
        Mock Invoke-WebRequest { throw 'controlled download failure' }
        { Install-WacCITool -Tool $tool -ToolRoot $toolRoot } | Should -Throw '*controlled download failure*'
        [Net.ServicePointManager]::SecurityProtocol | Should -Be $previous
    }
}
