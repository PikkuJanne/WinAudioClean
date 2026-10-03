# Dedicated test-only fixture; uses the already installed .NET Framework compiler.
function New-WacTestProgressExecutable {
    param([Parameter(Mandatory = $true)][string]$OutputPath)

    if (-not [IO.Path]::IsPathRooted($OutputPath)) { throw 'Fixture output path must be absolute.' }
    if (Test-Path -LiteralPath $OutputPath) { throw 'Fixture output already exists; use a fresh test path.' }
    $compiler = @(
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $compiler) { throw 'The installed Windows .NET Framework C# compiler is required for progress tests.' }
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($OutputPath))
    $compileOutput = & $compiler '/nologo' '/target:exe' ('/out:' + $OutputPath) (Join-Path $PSScriptRoot 'ProgressProcessFixture.cs') 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        throw ('Progress fixture compilation failed: ' + ($compileOutput -join [Environment]::NewLine))
    }
    $OutputPath
}
