# Portable tool-only package

Verify the ZIP, then extract the complete payload into a user-writable folder.
Spaces and Unicode in that folder are supported. Keep all eight PowerShell
files and `WinAudioClean.bat` together. No installer, administrator rights,
repository, Git, Python or test modules are needed to run the application.
The [first-run guide](../README.md) covers dependency placement and tested
platform scope; [security guidance](SECURITY.md) explains execution restrictions.

Application version comes from `scriptVersion` in `WinAudioClean.ps1`.
`PACKAGE-MANIFEST.json` records it, the exact source commit/tree, and each
packaged file's byte count/SHA256. The ZIP name includes its source revision.
A locally built candidate is not a published release or a download promise.

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
packaged runtime/doc/license/icon file. Do not edit payload files while checking
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
