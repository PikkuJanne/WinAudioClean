param([string]$ApplicationPath, [string]$SettingsPath, [string]$ManifestPath,
    [string]$OutputDirectory, [string]$ResultPath, [string]$Case)

# All paths/preferences belong to the enclosing test's isolated sandbox.
$options = @{ SettingsPath = $SettingsPath; NonInteractive = $true }
if ($Case -notin @('saved choices', 'explicit overrides', 'corrupt saved')) {
    $options.Mode = 'Zoom'; $options.OutputDirectory = $OutputDirectory
}
if ($Case -eq 'direct list') {
    $document = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json
    $options.InputPaths = [string[]]$document.inputs
} elseif ($Case -ne 'result without list') { $options.InputListPath = $ManifestPath }
if ($Case -eq 'both lists') { $options.InputPaths = @('extra input.wav') }
if ($Case -eq 'legacy conflict') { $options.inputPath = 'extra input.wav' }
if ($Case -eq 'preview conflict') { $options.Preview = $true }
if ($Case -eq 'range conflict') { $options.PreviewDurationSeconds = '5' }
if ($Case -eq 'explicit overrides') {
    $options.Mode = 'Raw'; $options.Preset = 'Gentle'; $options.OutputDirectory = $OutputDirectory
    $options.CleaningOptions = @{}; $options.Mono = $false; $options.Rf64 = $false
}
if ($Case -eq 'corrupt saved') { $options.Mode = 'Zoom'; $options.OutputDirectory = $OutputDirectory }
if ($ResultPath) { $options.BatchResultPath = $ResultPath }
& $ApplicationPath @options
exit $LASTEXITCODE
