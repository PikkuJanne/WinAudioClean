# Run only in a fresh test-owned CreateNoWindow process, never the caller's console.
param(
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$NativeFixturePath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('Utf8Empty', 'Utf8Binary', 'Utf8LeadingBomData', 'Utf8NoBomControl', 'OemControl', 'StartupFailure')]
    [string]$Case
)
$ErrorActionPreference = 'Stop'
. (Join-Path $Repository 'WinAudioClean.ps1')
foreach ($name in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
    if ([string]$name -like 'WAC_TEST_*' -or [string]$name -in @('GH_TOKEN', 'GITHUB_TOKEN')) {
        [Environment]::SetEnvironmentVariable([string]$name, $null, 'Process')
    }
}
$originalConsoleInput = [Console]::InputEncoding
$stream = $null
try {
    if ($Case -eq 'OemControl') { [Console]::InputEncoding = [Text.Encoding]::GetEncoding(437) }
    elseif ($Case -eq 'Utf8NoBomControl') { [Console]::InputEncoding = [Text.UTF8Encoding]::new($false) }
    else { [Console]::InputEncoding = [Text.Encoding]::UTF8 }
    $selectedInput = [Console]::InputEncoding
    $selectedReader = [Console]::In
    $payload = [byte[]]@()
    if ($Case -eq 'Utf8LeadingBomData') { $payload = [byte[]]@(239, 187, 191, 0, 255, 83) }
    elseif ($Case -ne 'Utf8Empty' -and $Case -ne 'StartupFailure') {
        $payload = [byte[]]@(0, 1, 2, 3, 255, 128, 0, 239, 187, 191, 83)
    }
    if ($payload.Length -gt 0) { $stream = [IO.MemoryStream]::new($payload) }
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $expectedDigest = [BitConverter]::ToString($hash.ComputeHash($payload)).Replace('-', '') }
    finally { $hash.Dispose() }
    $env:WAC_TEST_READ_STDIN_BYTES = '1'
    $target = $NativeFixturePath
    if ($Case -eq 'StartupFailure') { $target = $NativeFixturePath + '.missing.exe' }
    $result = Invoke-WacNativeProcess -FilePath $target -StandardInputStream $stream -TimeoutMilliseconds 5000
    $afterInput = [Console]::InputEncoding
    $observedLength = $null
    $observedDigest = $null
    if ($result.StandardOutput -match '^STDIN_BYTES:([0-9]+):([A-F0-9]{64})$') {
        $observedLength = [int]$Matches[1]
        $observedDigest = $Matches[2]
    }
    [pscustomobject]@{
        case = $Case
        started = $result.Started
        exit_code = $result.ExitCode
        has_error = [bool]$result.Error
        has_cleanup_error = [bool]$result.CleanupError
        timed_out = $result.TimedOut
        expected_length = $payload.Length
        observed_length = $observedLength
        expected_sha256 = $expectedDigest
        observed_sha256 = $observedDigest
        caller_readable = ($null -eq $stream -or $stream.CanRead)
        input_encoding_equal = $selectedInput.Equals($afterInput)
        input_encoding_type_equal = ($selectedInput.GetType() -eq $afterInput.GetType())
        before_code_page = $selectedInput.CodePage
        after_code_page = $afterInput.CodePage
        before_preamble_hex = [BitConverter]::ToString($selectedInput.GetPreamble()).Replace('-', '')
        after_preamble_hex = [BitConverter]::ToString($afterInput.GetPreamble()).Replace('-', '')
        console_reader_unchanged = [object]::ReferenceEquals($selectedReader, [Console]::In)
    } | ConvertTo-Json -Compress
} finally {
    if ($stream) { $stream.Dispose() }
    [Console]::InputEncoding = $originalConsoleInput
    [Environment]::SetEnvironmentVariable('WAC_TEST_READ_STDIN_BYTES', $null, 'Process')
}
