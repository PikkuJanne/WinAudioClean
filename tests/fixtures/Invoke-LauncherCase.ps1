param(
    [Parameter(Mandatory = $true)][string]$LauncherPath,
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [Parameter(Mandatory = $true)][string]$RecordPath,
    [ValidateSet('Unattended', 'Positional', 'InvalidMode', 'MissingEnvironment', 'ExtraArgument', 'ExtraFile')]
    [string]$Route = 'Unattended',
    [int]$NativeExitCode = 0,
    [switch]$BlockLog,
    [switch]$DefinePercentToken,
    [switch]$TrailingOutputSeparator
)

# Runs in an owned child shell. Its environment never escapes into the test host.
$env:WAC_TEST_ARGV_PATH = $RecordPath
$env:WAC_TEST_EXIT_CODE = [string]$NativeExitCode
$env:WAC_TEST_STDOUT = 'WAC launcher fixture stdout'
$env:WAC_TEST_STDERR = 'WAC launcher fixture stderr'
$env:WAC_TEST_FFMPEG_OUTPUT = '1'
$env:WAC_TEST_BLOCK_LOG = if ($BlockLog) { '1' } else { '' }
$env:WAC_TEST_OUTPUT_PATH = ''
$env:WAC_LAUNCH_INPUT = $InputPath
$env:WAC_LAUNCH_OUTPUT_DIRECTORY = $OutputDirectory
if ($TrailingOutputSeparator) { $env:WAC_LAUNCH_OUTPUT_DIRECTORY += '\' }
if ($DefinePercentToken) { $env:WAC_LAUNCH_PERCENT_TOKEN = 'expanded-decoy' }
switch ($Route) {
    'Unattended' { & $LauncherPath /unattended Raw }
    'Positional' { & $LauncherPath $InputPath }
    'InvalidMode' { & $LauncherPath /unattended invalid }
    'MissingEnvironment' {
        $env:WAC_LAUNCH_INPUT = ''
        & $LauncherPath /unattended Raw
    }
    'ExtraArgument' { & $LauncherPath /unattended Raw unexpected }
    'ExtraFile' { & $LauncherPath $InputPath $InputPath }
}
exit $LASTEXITCODE
