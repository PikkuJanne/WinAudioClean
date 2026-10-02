# Local development checks

The application still needs only PowerShell and FFmpeg. These checks also need
Python 3.10 or newer (standard library only), Pester and PSScriptAnalyzer. None is installed
by the application or test runner.

## Explicit setup

From the repository root, use Windows PowerShell 5.1 or PowerShell 7:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Install-DevDependencies.ps1
# Or: pwsh -NoProfile -File scripts/Install-DevDependencies.ps1
```

Setup downloads **Pester 5.7.1** and **PSScriptAnalyzer 1.24.0** from the official
PowerShell Gallery into `.wac-local/Modules`, already ignored by Git. It verifies
the package SHA512 digests in `scripts/DevDependencies.psd1` before extraction.
It changes no global/user module installation, profile, repository trust,
execution policy, or persistent environment setting. Existing matching module
folders are reused; setup does not repair or overwrite them automatically.

These are deliberately fixed versions, not a claim of the newest release. The
official [Pester package](https://www.powershellgallery.com/packages/Pester/5.7.1)
supports Desktop/Core with minimum PowerShell 3.0, and the
[analyzer package](https://www.powershellgallery.com/packages/PSScriptAnalyzer/1.24.0)
requires PowerShell 5.1. Both have no package dependencies. Versions and Base64
SHA512 `PackageHash` values were checked on 2026-10-02 using the Gallery OData
`Packages(Id='NAME',Version='VERSION')` metadata. Package checksums pin the exact
download; they do not independently authenticate the publisher.

## Run the checks

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Targeted -Tag EntryPoint
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Helpers.Tests.ps1
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Full
```

The Windows PowerShell examples use a process-only execution policy because the
active machine's default policy blocks local scripts. This does not change any
persistent execution policy. Use `-PythonPath` for a particular Python executable. For an isolated worktree,
`-ModuleRoot` can reuse the original checkout's `.wac-local/Modules` directory.
Start a fresh shell if another Pester/analyzer version is loaded. A missing module,
invalid filter, empty test selection, parser/static error, or failing test produces
a nonzero process exit. A run with only skipped/inconclusive tests also fails.

| Level | Checks |
| --- | --- |
| Quick | Parse maintained PowerShell files; analyzer gate; governance plan validation; Pester `Quick`, `Unit`, or `Import` tags. |
| Targeted | Same parser/static/plan checks; Pester tests selected by explicit `-Path` and/or `-Tag`. |
| Full | Same parser/static/plan checks; every Pester test, including entry points; complete Python governance helper suite. |

Paths are literal and resolve relative to the repository root. Pester tags can
use Pester's filtering syntax; multiple tags select their union. When both paths
and tags are supplied, tags restrict tests found under those paths. Quick and
Full reject filters so their scopes cannot silently shrink.

## Static analysis scope

All default analyzer rules run on the root PowerShell source, `scripts/` and
`tests/`. The configured `PSUseCompatibleSyntax` rule additionally checks syntax
for PowerShell 5.1 and 7.0. The gate fails on every Error finding and these safety
rules at any severity:

- `PSAvoidUsingInvokeExpression`
- `PSUseCompatibleSyntax`
- `PSAvoidUsingEmptyCatchBlock`
- `PSAvoidUsingPlainTextForPassword`
- `PSAvoidUsingConvertToSecureStringWithPlainText`
- `PSAvoidUsingUsernameAndPasswordParams`
- `PSAvoidUsingBrokenHashAlgorithms`

Other default findings are counted on every run. Inspect them with:

```powershell
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Quick -AnalyzerWarnings
```

There are no suppressed rules or suppression attributes. Non-error style and
design advice is advisory in this first characterization task: the original
console interface intentionally uses `Write-Host`, and test setup assigns values
that Pester consumes in later scopes. This does not certify all analyzer advice
as resolved. New warnings should be inspected rather than hidden in a baseline.

## What the tests establish

The small helpers lock the original Raw/Zoom filter text and command construction.
Characterization cases label known defects, such as invalid selections choosing
Zoom, timestamp collisions and overwrite arguments, with the future task that
will change the expectation. They do not endorse those behaviors as requirements.

Import checks run in fresh shell processes. Entry point checks run a controlled
missing-input path through the original `.ps1 -inputPath` and `.bat` boundaries,
stopping at preflight. A separate script-invocation fixture exercises the runtime
with process/filesystem doubles. They verify launch/argument behavior, not audio
quality or actual encoding. Missing shells must be reported as skipped, never passed.
Listening, real FFmpeg output and large-file behavior remain separate acceptance
work. Tests use temporary synthetic artifacts; private recordings are unnecessary.

## Synthetic audio characterization (WAC-M0-03)

Provide an existing local FFmpeg/ffprobe pair explicitly. This script never
downloads tools or changes PATH. The recorded Windows baseline uses the
checksum-verified portable Gyan 9.0.2 essentials build under ignored
`.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin`.
Gyan is linked from the [FFmpeg download page](https://ffmpeg.org/download.html).
The exact archive/binary hashes and full build configuration are in the
[task evidence](../docs/codex/winaudioclean/evidence/WAC-M0-03.md).

From the repository root, using new output directory names for each run:

```powershell
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 docs/codex/winaudioclean/tools/characterize_filters.py --output .wac-local/WAC-M0-03/run-1 --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
python -X utf8 docs/codex/winaudioclean/tools/characterize_filters.py --output .wac-local/WAC-M0-03/run-2 --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
Get-FileHash .wac-local/WAC-M0-03/run-1/characterization.json,.wac-local/WAC-M0-03/run-2/characterization.json -Algorithm SHA256
```

Each run creates all [five fixtures](fixtures/README.md), then renders both
legacy chains with unspecified WAV encoding and, separately, explicit
`-ar 48000 -c:a pcm_s16le`. That makes 20 output files per run. This encoding
comparison changes no application settings. The script refuses existing output
directories and uses bounded, noninteractive FFmpeg processes with `-n`.

Schema-v2 reports record tool/build hashes, fixture hashes, complete argument
arrays and exits, final WAV hashes/formats/durations, and final-file metrics.
Independent astats and loudnorm analysis passes discard their renders. The
reported loudness values use loudnorm's **input** measurements of the final WAV.
Nonfinite metrics are null with reasons; missing or malformed metrics fail the
run. Equal report hashes show exact repeatability on the recorded build;
investigate differing reports rather than adjusting tolerances or hiding them.
This is direct FFmpeg characterization, not a launcher or speech-quality test.

The new metric-parser tests are included in Full and can run alone:

```powershell
python -X utf8 -m unittest discover -s docs/codex/winaudioclean/tests -p test_characterize_filters.py -v
```

Keep WAVs, portable binaries and raw local logs ignored. Commit only sanitized
reports and metadata. Use the [listening checklist](../docs/codex/winaudioclean/evidence/WAC-M0-03-listening.md)
when owner-supplied, permission-cleared speech is available; listening remains
pending until that review actually occurs.
