# Portable tool-only package

Extract the complete ZIP into a user-writable folder. Spaces and Unicode in
the folder name are supported. Keep the eight PowerShell files and
`WinAudioClean.bat` together. No installer, administrator rights, repository,
Git, Python or test modules are required to run the extracted application.

The application version comes from `scriptVersion` in `WinAudioClean.ps1`.
`PACKAGE-MANIFEST.json` records that version, the exact source commit/tree and
each packaged source file's byte count and SHA256. The ZIP filename also
identifies the source revision. This is a local build artifact; creating it
does not publish a release.

## Verify and supply dependencies

Compare `Get-FileHash -Algorithm SHA256 -LiteralPath '<package.zip>'` with the
matching `.sha256` file obtained through a trusted channel. A checksum detects
changed bytes against that expected value; it is not a digital signature.
The adjacent `.provenance.json` records the ZIP checksum and payload manifest.
Do not edit files while checking their manifest hashes.

FFmpeg and ffprobe are not included or downloaded. Supply an already installed
Windows build with both executables and the required filters. You can place
them beside the extracted scripts, keep their `bin` directory on `PATH`, or
use the explicit PowerShell paths below. An invalid supplied path fails rather
than selecting another installation. See [dependency notices](../THIRD_PARTY_NOTICES.md)
and the [main README](../README.md) for supported media and dependency lookup.

## Run from PowerShell

From the extracted folder, use the built-in Windows PowerShell host:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WinAudioClean.ps1 -inputPath 'C:\Audio\recording.wav' -Mode Zoom -OutputDirectory 'C:\Audio\Cleaned' -FfmpegPath 'C:\Tools\ffmpeg\bin\ffmpeg.exe' -FfprobePath 'C:\Tools\ffmpeg\bin\ffprobe.exe' -IgnoreSavedSettings -NonInteractive
```

If PowerShell 7 is installed, `pwsh.exe` accepts the same arguments. Execution
policy is selected only for this invocation; no global policy change is needed.
`-IgnoreSavedSettings` selects built-in defaults plus these explicit choices.
The source remains intact and a new WAV and reports are written to the chosen
destination. Read the reports and listen to the output before using it.

## Run the BAT launcher

For interactive use, drag a file onto `WinAudioClean.bat` and select Raw or
Zoom/Teams. For an unattended check, supply literal paths from PowerShell:

```powershell
$env:WAC_LAUNCH_INPUT = 'C:\Audio\recording.wav'
$env:WAC_LAUNCH_OUTPUT_DIRECTORY = 'C:\Audio\Cleaned'
$env:WAC_LAUNCH_IGNORE_SAVED_SETTINGS = '1'
& .\WinAudioClean.bat /unattended Zoom
```

The BAT finds sibling FFmpeg/ffprobe or the existing `PATH`. It starts built-in
PowerShell 5.1 by default. To select an installed PowerShell 7 executable, set
`WAC_LAUNCH_POWERSHELL` to its absolute path before invoking the BAT. These
environment values apply to the caller and its children; remove them when done.
Use the manifest or direct PowerShell route for paths CMD cannot transport.
See the README for exit codes, batch selection, reports and saved preferences.

## Rebuild locally

Development builds require Git and PowerShell 5.1 or 7, but no Python or test
module. From an unchanged clean checkout, choose its complete commit SHA:

```powershell
.\scripts\Build-Release.ps1 -Revision '<full-lowercase-40-hex-commit>' -OutputDirectory '.\dist\build-one'
.\scripts\Build-Release.ps1 -Revision '<same-commit>' -OutputDirectory '.\dist\build-two'
```

The builder requires the explicit current clean revision, reads a fixed list
of committed blobs and creates new files without replacing existing outputs.
It preserves their bytes, uses ordinal entry order, a fixed ZIP timestamp and
uncompressed entries. Only runtime files, their selected docs/icon, MIT notice
and generated manifest enter the archive. Development tools, tests, handoff
records, settings, logs, recordings and dependency binaries are excluded.
Compare the actual ZIP hashes before claiming reproducibility; cross-host
equality is evidence only for the versions and builds actually checked.
