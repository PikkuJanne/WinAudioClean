param(
    [Parameter(Mandatory = $true)][string]$LauncherPath,
    [Parameter(Mandatory = $true)][string]$InputPath
)

# Exercise the real .bat through the selected outer PowerShell process. The
# unchanged launcher itself explicitly starts Windows PowerShell, even on PS7.
& $LauncherPath $InputPath
exit $LASTEXITCODE
