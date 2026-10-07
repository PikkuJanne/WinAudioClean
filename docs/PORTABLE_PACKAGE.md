# Portable tool-only package

Verify the ZIP, then extract the complete payload into a short user-writable folder.
Spaces and Unicode in that folder are supported. Keep all eight PowerShell
files and `WinAudioClean.bat` together. No installer, administrator rights,
repository, Git, Python or test modules are needed to run the application.
The [first-run guide](../README.md) covers dependency placement and tested
platform scope; [security guidance](SECURITY.md) explains execution restrictions.

Application version comes from `scriptVersion` in `WinAudioClean.ps1`.
`PACKAGE-MANIFEST.json` records it, the exact source commit/tree, and each
packaged file's byte count/SHA256. The ZIP name includes its source revision.
A locally built candidate is not a published release or a download promise.

The first public application version is **1.0.0**. Use the
[v1.0.0 release page](https://github.com/PikkuJanne/WinAudioClean/releases/tag/v1.0.0)
to check availability of the tool-only ZIP and matching checksum/provenance files. The filename
and manifest identify the exact tagged source. Previous internal `2.3` candidates
below are retained historical checkpoints. Public numbering does not change
Original `1.0.0`, Gentle `0.1.0`, saved-settings/report schema `1`, or default sound.

## Verify a download before extraction

Place exactly one `WinAudioClean-*-tool-only.zip` and its matching `.sha256`
file in the current folder. Obtain the expected checksum through a trusted
channel; a checksum is an integrity comparison, not a digital signature.
The matching `.provenance.json` additionally records source/payload identity.

<!-- example: verify-zip -->
```powershell
$zip = @(Get-ChildItem -LiteralPath '.' -File -Filter 'WinAudioClean-*-tool-only.zip')
if ($zip.Count -ne 1) { throw 'Keep exactly one candidate ZIP in this folder.' }
$checksum = [IO.File]::ReadAllText([IO.Path]::ChangeExtension($zip[0].FullName, '.sha256')).Trim()
$actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip[0].FullName).Hash.ToLowerInvariant()
if ($checksum -cne ($actual + '  ' + $zip[0].Name)) { throw 'ZIP checksum mismatch.' }
$actual
```

Extract only after that comparison succeeds. Choose a new folder; retain every
packaged runtime/doc/license/icon file. Keep the extraction and output paths short:
generated names and job folders can exceed host-specific native path limits. See
[destination troubleshooting](SUPPORT.md). Do not edit payload files while checking
manifest hashes. For an altered or unexpected download, obtain a trusted copy.

## Supply FFmpeg and run

FFmpeg/ffprobe are not included or downloaded. Supply a trusted Windows build
with both executables and the required filters. The official
[FFmpeg download page](https://ffmpeg.org/download.html) links Windows builds;
verify the chosen provider's exact build/integrity/license information. See
[dependency notices](../THIRD_PARTY_NOTICES.md). A version banner or capability
check does not authenticate a binary.

Place both tools beside the extracted scripts for the README examples. You can
instead bind explicit `-FfmpegPath` / `-FfprobePath` or configure PATH. A bad
explicit or present sibling tool fails without fallback. FFprobe also checks
beside the resolved FFmpeg. No numeric minimum replaces capability checks.

Open PowerShell in the extracted folder, supply your input, and follow the
[exact README commands](../README.md). The first command chooses execution
policy for that child process only; it does not change a machine-wide policy
or override an enforced restriction. See Microsoft's
[execution-policy documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies).
If blocked, follow the normal trusted policy/admin process. Global security
changes and elevation are not installation steps.

The BAT's default inner host is built-in PowerShell 5.1; an explicitly supplied
installed PowerShell host can be selected through `WAC_LAUNCH_POWERSHELL`.
The README shows an unattended environment-data route and cleanup. Review
reports and listen before using output. [Troubleshooting](SUPPORT.md) covers
failures, warnings and private support exports.

## Rebuild a candidate locally (development only)

Development builds need Git and PS5.1/PS7. In an unchanged clean checkout,
`git rev-parse HEAD` gives the full lowercase forty-character revision to pass
to `scripts/Build-Release.ps1 -Revision <revision> -OutputDirectory <new-folder>`.
Build twice to different new folders from that exact HEAD and compare ZIP hashes.
The explicit revision must equal clean HEAD; an existing output is never replaced.

The fixed allowlist has eight PS components, BAT, icon, MIT license, README,
portable/support/security docs, dependency notices and the linked report-format
doc: **17 committed payload files plus the generated manifest**. Tests, build
scripts, handoff records, preferences, logs, recordings and third-party binaries
are excluded. Committed bytes are preserved, ZIP order/timestamps/attributes
are fixed and entries are uncompressed. Actual equality is evidence only for
the source and host versions checked; compare your own outputs before making
a reproducibility claim.

## Return to a prior source candidate safely

The recorded earlier candidate is application **2.3**, source commit
`1f10940ee970ebe719c21ba0e7290830beeb7123`, archive
`WinAudioClean-2.3-1f10940ee970-tool-only.zip`, **438904 bytes**, SHA256
`d543ab046e9b1c5330552038f4eaa9eea794b2392ced079e620ed2f65cf04bf7`.
This identifies a reviewed source checkpoint and locally tested candidate;
it is not a published release or tag. A different source commit has a different
package identity even when its application version is also 2.3.

1. Let active jobs finish or cancel them through the application before switching
   tools. Retain the current tool directory, original recordings, preferences,
   reports and exports. Returning to older code does not require removing any of
   them or resetting preferences.
2. Obtain the complete earlier package from your retained verified local copy,
   or reconstruct that exact source as described below. Apply the checksum
   verification above and compare its manifest's version/source commit with the
   reference here. Stop if bytes, checksum or identity differ.
3. Extract into a **new**, short, user-writable folder such as
   `WinAudioClean-prior`. Keep all package components together; do not overwrite
   the current installation or mix individual scripts from different revisions.
   Supply the same deliberately selected, trusted FFmpeg/ffprobe dependencies.
4. For the first check, supply a recording explicitly, use a separate output
   folder and an isolated settings path. Older code may not accept newer saved
   preferences. `-IgnoreSavedSettings` bypasses preferences without changing
   their bytes; do not use `-SaveSettings` or `-ResetSettings` against your normal
   settings as a rollback step. Read the result and listen before choosing which
   complete tool directory to use.

For this example, run from the parent of `WinAudioClean-prior`, supply your own
`Inputs\recording.wav`, and create a new writable `RollbackCheck` directory.
`RollbackCheck\isolated-settings.json` may remain absent. The command chooses a
distinct output directory; it never replaces the source or prior exports:

```powershell
& '.\WinAudioClean-prior\WinAudioClean.ps1' -inputPath '.\Inputs\recording.wav' -Mode Zoom -OutputDirectory '.\RollbackExports' -SettingsPath '.\RollbackCheck\isolated-settings.json' -IgnoreSavedSettings -NonInteractive
```

The existing BAT route can likewise use explicit `WAC_LAUNCH_SETTINGS_PATH`,
input and output environment values as documented in the README. Switch back
by invoking the retained current tool directory with those deliberate paths.
Keep source recordings and preferences outside tool directories; no automatic
delete, reset, cleanup sweep or folder reuse is part of this procedure.

For a development reconstruction, use Git and PowerShell in a **new** checkout:

```powershell
git clone --no-checkout https://github.com/PikkuJanne/WinAudioClean.git '.\WinAudioClean-prior-source'
git -C '.\WinAudioClean-prior-source' switch --detach '1f10940ee970ebe719c21ba0e7290830beeb7123'
git -C '.\WinAudioClean-prior-source' rev-parse HEAD
git -C '.\WinAudioClean-prior-source' status --short
& '.\WinAudioClean-prior-source\scripts\Build-Release.ps1' -Revision '1f10940ee970ebe719c21ba0e7290830beeb7123' -OutputDirectory '.\WinAudioClean-prior-build'
```

Before building, require the displayed HEAD to match the exact reference and
`status --short` to be empty. Each command must succeed; stop on a nonzero exit
instead of resetting or cleaning an existing checkout. Choose new clone/build
directories, repeat the build to another new destination as described above,
and verify the resulting archive against the recorded identity and checksum.
These are local development actions and do not create a release or enable a
website download.
