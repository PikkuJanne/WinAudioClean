param([string]$inputPath)

# A managed application double verifies the default launcher handoff and pause.
# The separate unattended suite uses the full, unchanged application copy.
$env:WAC_TEST_FFMPEG_OUTPUT = ''
& (Join-Path $PSScriptRoot 'ffmpeg.exe') '-i' $inputPath '-inner-shell' ([string]$PSVersionTable.PSVersion.Major)
exit $LASTEXITCODE
