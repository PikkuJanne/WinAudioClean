param([string]$ApplicationPath, [string]$SettingsPath, [string]$SelectionPath,
    [string]$OutputDirectory, [string]$ResultPath, [string]$Case)

# The selection document is test-only typed data, never an evaluated command.
$document = Get-Content -LiteralPath $SelectionPath -Raw -Encoding UTF8 | ConvertFrom-Json
$options = @{ InputDirectories = [string[]]$document.directories; SettingsPath = $SettingsPath
    OutputDirectory = $OutputDirectory; BatchResultPath = $ResultPath; NonInteractive = $true }
if ($Case -ne 'no mode') { $options.Mode = 'Zoom' }
if ($Case -eq 'recursive') { $options.Recurse = $true }
if ($Case -eq 'single conflict') { $options.inputPath = 'extra.wav' }
if ($Case -eq 'explicit list conflict') { $options.InputPaths = @('extra.wav') }
if ($Case -eq 'manifest conflict') { $options.InputListPath = 'missing.json' }
if ($Case -eq 'recursion without folder false') {
    $options.Remove('InputDirectories'); $options.inputPath = 'missing.wav'; $options.Recurse = $false
}
if ($Case -eq 'preview conflict') { $options.Preview = $true }
if ($Case -eq 'range conflict') { $options.PreviewDurationSeconds = '1' }
if ($Case -eq 'show settings conflict') { $options.ShowSettings = $true }
if ($Case -eq 'import only') {
    . $ApplicationPath @options
    Write-Output ('ImportOnly:Queue=' + [bool](Get-Command New-WacFolderQueue -ErrorAction SilentlyContinue) +
        ';Batch=' + [bool](Get-Command Invoke-WacBatch -ErrorAction SilentlyContinue) +
        ';Settings=' + [bool](Get-Command Read-WacSettings -ErrorAction SilentlyContinue))
    exit 0
}
& $ApplicationPath @options
exit $LASTEXITCODE
