param([string]$inputPath, [string[]]$InputPaths, [string]$InputListPath,
    [string]$Mode, [string]$OutputDirectory, [string]$SettingsPath,
    [switch]$IgnoreSavedSettings, [switch]$NonInteractive)

# Typed app boundary recorder; the Batch suite separately runs actual audio jobs.
$inputs = @()
if ($InputListPath) {
    $document = Get-Content -LiteralPath $InputListPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $inputs = @($document.inputs)
} elseif ($InputPaths) { $inputs = @($InputPaths) }
elseif ($inputPath) { $inputs = @($inputPath) }
$record = [ordered]@{ shellMajor = $PSVersionTable.PSVersion.Major; inputs = $inputs
    inputPath = $inputPath; InputPaths = @($InputPaths); InputListPath = $InputListPath
    Mode = $Mode; OutputDirectory = $OutputDirectory; SettingsPath = $SettingsPath
    IgnoreSavedSettings = [bool]$IgnoreSavedSettings; NonInteractive = [bool]$NonInteractive }
[IO.File]::WriteAllText($env:WAC_TRANSPORT_RECORD_PATH, ($record | ConvertTo-Json -Depth 5 -Compress), [Text.UTF8Encoding]::new($false))
Write-Output 'WAC typed application output'
exit ([int]$env:WAC_TRANSPORT_APP_EXIT)
