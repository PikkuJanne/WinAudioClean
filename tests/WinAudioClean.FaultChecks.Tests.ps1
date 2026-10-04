BeforeAll {
    if (-not ('WinAudioClean.Tests.FaultCheckScratch' -as [type])) {
        Add-Type -Path (Join-Path $PSScriptRoot 'fixtures/FaultCheckScratch.cs') -ErrorAction Stop
    }
}

Describe 'AC-068: fault-check fixture ownership and cleanup containment' -Tag 'FaultChecks', 'Unit' {
    BeforeEach {
        $repository = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($repository)
        $owner = [WinAudioClean.Tests.FaultCheckScratch]::Create($repository)
    }
    AfterEach {
        try { $owner.RemoveTree() }
        finally { $owner.Dispose() }
    }

    It 'deletes only its newly allocated tree and leaves preexisting sibling files intact' {
        $foreign = Join-Path $owner.LocalRoot 'user-owned.txt'
        [IO.File]::WriteAllText($foreign, 'keep these foreign bytes')
        $child = Join-Path $owner.Root 'nested/fixture.txt'
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($child))
        [IO.File]::WriteAllText($child, 'owned synthetic fixture')
        $owner.RemoveTree()
        Test-Path -LiteralPath $owner.Root | Should -BeFalse
        [IO.File]::ReadAllText($foreign) | Should -BeExactly 'keep these foreign bytes'
        $owner.RemoveTree()
    }

    It 'pins the root and ordinary ancestors against path replacement until release' {
        { [IO.Directory]::Move($owner.Root, ($owner.Root + '-foreign')) } | Should -Throw
        { [IO.Directory]::Move($owner.LocalRoot, ($owner.LocalRoot + '-foreign')) } | Should -Throw
        { [IO.Directory]::Move($repository, ($repository + '-foreign')) } | Should -Throw
        Test-Path -LiteralPath $owner.Root | Should -BeTrue
    }

    It 'refuses an escaping junction before deleting any item and retains the outside sentinel' {
        $foreign = Join-Path $TestDrive ('foreign-' + [guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($foreign)
        $sentinel = Join-Path $foreign 'user-owned.txt'
        [IO.File]::WriteAllText($sentinel, 'keep these foreign bytes')
        $sibling = Join-Path $owner.Root 'owned.txt'
        [IO.File]::WriteAllText($sibling, 'owned fixture retained on refusal')
        $link = Join-Path $owner.Root 'escape'
        $null = New-Item -ItemType Junction -Path $link -Target $foreign -ErrorAction Stop
        try {
            { $owner.RemoveTree() } | Should -Throw '*reparse point*'
            [IO.File]::ReadAllText($sentinel) | Should -BeExactly 'keep these foreign bytes'
            [IO.File]::ReadAllText($sibling) | Should -BeExactly 'owned fixture retained on refusal'
        }
        finally { [IO.Directory]::Delete($link) }
    }

    It 'rejects a junction scratch parent without touching the external target' {
        $otherRepo = Join-Path $TestDrive ('other-' + [guid]::NewGuid().ToString('N'))
        $foreign = Join-Path $TestDrive ('external-' + [guid]::NewGuid().ToString('N'))
        $null = [IO.Directory]::CreateDirectory($otherRepo)
        $null = [IO.Directory]::CreateDirectory($foreign)
        $sentinel = Join-Path $foreign 'user-owned.txt'
        [IO.File]::WriteAllText($sentinel, 'keep these foreign bytes')
        $link = Join-Path $otherRepo '.wac-local'
        $null = New-Item -ItemType Junction -Path $link -Target $foreign -ErrorAction Stop
        try {
            { [WinAudioClean.Tests.FaultCheckScratch]::Create($otherRepo) } | Should -Throw '*reparse point*'
            [IO.File]::ReadAllText($sentinel) | Should -BeExactly 'keep these foreign bytes'
            @(Get-ChildItem -LiteralPath $foreign -Force).Count | Should -Be 1
        }
        finally { [IO.Directory]::Delete($link) }
    }

    It 'retains a released tree instead of falling back to recursive path deletion' {
        $retainedRoot = $owner.Root
        $owner.Dispose()
        { $owner.RemoveTree() } | Should -Throw '*owner has been released*'
        Test-Path -LiteralPath $retainedRoot | Should -BeTrue
        # This case knows it allocated an empty directory; no recursive fallback.
        [IO.Directory]::Delete($retainedRoot)
        $owner = [WinAudioClean.Tests.FaultCheckScratch]::Create($repository)
    }
}
