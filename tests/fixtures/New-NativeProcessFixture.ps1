# Test-only compiler helper; uses the Windows-installed .NET Framework compiler.
# Each caller supplies a fresh test-owned executable path. No binary is committed.
function New-WacTestNativeExecutable {
    param([Parameter(Mandatory = $true)][string]$OutputPath)

    if (-not [IO.Path]::IsPathRooted($OutputPath)) { throw 'Fixture output path must be absolute.' }
    if (Test-Path -LiteralPath $OutputPath) { throw 'Fixture output already exists; use a fresh test path.' }
    $compiler = @(
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $compiler) { throw 'The installed Windows .NET Framework C# compiler is required for native fixture tests.' }

    $sourcePath = Join-Path $PSScriptRoot 'NativeProcessFixture.cs'
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($OutputPath))
    $compilerOutput = & $compiler '/nologo' '/target:exe' ('/out:' + $OutputPath) $sourcePath 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        throw ('Native fixture compilation failed: ' + ($compilerOutput -join [Environment]::NewLine))
    }
    $OutputPath
}
