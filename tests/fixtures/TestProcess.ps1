# Shared test-only process harness. Every child has redirected input and a deadline.
function ConvertTo-WacTestQuotedArgument {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value.Contains('"') -or $Value.Contains("`r") -or $Value.Contains("`n")) {
        throw 'The test harness accepts only single-line paths without quotation marks.'
    }
    '"{0}"' -f $Value
}

function Invoke-WacTestProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [string]$StandardInput = '',
        [int]$TimeoutMilliseconds = 20000
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = $Arguments
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Write($StandardInput)
        $process.StandardInput.Close()
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            # Only this test's process tree is terminated, never processes by name.
            $killInfo = New-Object System.Diagnostics.ProcessStartInfo
            $killInfo.FileName = Join-Path $env:SystemRoot 'System32\taskkill.exe'
            $killInfo.Arguments = '/PID {0} /T /F' -f $process.Id
            $killInfo.UseShellExecute = $false
            $killInfo.CreateNoWindow = $true
            $killInfo.RedirectStandardOutput = $true
            $killInfo.RedirectStandardError = $true
            $killer = [System.Diagnostics.Process]::Start($killInfo)
            try {
                if (-not $killer.WaitForExit(5000)) { $killer.Kill() }
            } finally {
                $killer.Dispose()
            }
            if (-not $process.HasExited) { $process.Kill() }
            throw "Test child exceeded its $TimeoutMilliseconds ms deadline."
        }
        if (-not $stdout.Wait(5000) -or -not $stderr.Wait(5000)) {
            throw 'Test child output streams did not close within 5000 ms.'
        }
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            StandardOutput = $stdout.Result
            StandardError = $stderr.Result
        }
    } finally {
        $process.Dispose()
    }
}
