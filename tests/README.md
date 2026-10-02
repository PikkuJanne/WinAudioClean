# Local development checks

The application still needs only PowerShell and FFmpeg. These checks also need
Python 3.10 or newer (standard library only), Pester and PSScriptAnalyzer. Native
fixture tests additionally use the installed Windows .NET Framework C# compiler
(`csc.exe`). These are development dependencies; the application and test runner
do not install or download them.

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
design advice is advisory: the original
console interface intentionally uses `Write-Host`, and test setup assigns values
that Pester consumes in later scopes. This does not certify all analyzer advice
as resolved. New warnings should be inspected rather than hidden in a baseline.

## What the tests establish

The small helpers lock the original Raw/Zoom filter text and command construction.
Characterization cases label known defects, such as timestamp collisions and
overwrite arguments, with the future task that
will change the expectation. They do not endorse those behaviors as requirements.

Import checks run in fresh shell processes. Entry point checks run the actual
`.ps1 -inputPath` with disposable filesystem inputs and a compiled native argument
recorder in place of FFmpeg. Launcher checks cross the actual `.bat` boundary;
their scope is described below. These establish process and argument behavior,
not audio quality or actual encoding. Missing shells must be reported as skipped,
never passed. Listening, real FFmpeg output and large-file behavior remain separate
acceptance work. Tests use temporary synthetic artifacts; private recordings are
unnecessary.

## Input and menu regression checks (WAC-M1-01)

```powershell
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Targeted -Tag Preflight
```

The helper suite checks the literal filename matrix and destination handling,
including an exclusively locked input and a disposable directory whose ACL denies
file creation. The test restores that directory's ACL in `finally` and verifies
that it can write again. Read-Host doubles exercise menu retry, selection, cancel,
EOF and read failure. A host-argument seam checks abbreviated noninteractive
switches without redirecting stdin and masking that branch.

Actual bounded child processes in PS5.1 and PS7 reject invalid inputs, destinations
and missing/invalid modes without showing a menu or processing. Explicit valid
modes now run through the script with the compiled native fixture to check
filter/report wiring. Real console empty/invalid/cancel checks and their exact
M1-01 setup are recorded in the
[M1-01 evidence](../docs/codex/winaudioclean/evidence/WAC-M1-01.md).

## Native process and launcher checks (WAC-M1-02)

```powershell
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Native.Tests.ps1
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Launcher.Tests.ps1
pwsh -NoProfile -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Reporting.Tests.ps1
```

[New-NativeProcessFixture.ps1](fixtures/New-NativeProcessFixture.ps1) compiles
[NativeProcessFixture.cs](fixtures/NativeProcessFixture.cs) into a fresh,
test-owned executable with the installed Framework `csc.exe`. Generated binaries
are temporary and are not committed. The helper refuses to replace an existing
executable and downloads nothing. Its [fixture contract](fixtures/NativeProcessFixture.md)
describes the environment controls for actual argv recording, stdout/stderr,
native exits, stdin and reporting failures. Synthetic output bytes are not audio.

The recorder writes a UTF-8 JSON string array without a BOM. Tests read it with
`Get-Content -Raw -Encoding UTF8 | ConvertFrom-Json` directly into a variable.
Explicit UTF-8 preserves Unicode on PS5.1; omitting an outer `@(...)` avoids
nesting the returned array on that host.

The unattended launcher matrix runs copied application source through outer
PS5.1 and PS7, CMD, inner Windows PowerShell 5.1, and the native argv recorder.
It covers spaces, brackets, apostrophes, Unicode, ampersands, percent signs,
exclamation marks, parentheses, command-looking filenames, a trailing destination
backslash and a 240-character input path. Exit cases check native success,
native failure, startup failure and reporting failure without a pause.

Set unattended paths from PowerShell so CMD never parses them as arguments:

```powershell
$env:WAC_LAUNCH_INPUT = 'C:\Audio\meeting %complete%!.wav'
$env:WAC_LAUNCH_OUTPUT_DIRECTORY = 'C:\Audio\Cleaned'
& .\WinAudioClean.bat /unattended Zoom
$LASTEXITCODE
```

Default single-file handoff tests use [LauncherApplicationStub.ps1](fixtures/LauncherApplicationStub.ps1)
followed by the actual native recorder. They check literal handoff, inner PS5.1,
and exit preservation through `pause`; they do not render audio or exercise the
interactive application menu. The launcher rejects visible percent/exclamation
characters in positional input or CMD's original command line. An already-running
CMD can expand text before the launcher sees it, so that route cannot guarantee
those characters. A defined-percent-token decoy case checks rejection before
processing. Use the environment route above or direct `.ps1 -inputPath` from
PowerShell for these paths.

Windows application-control policy can reject the unsigned compiled fixture even
when compilation succeeds. This blocked the initial M1-02 validation. The owner
later reported Smart App Control Off and authorized a rerun; both Full gates
then passed on unchanged source (227 Pester and 61 Python cases, one Python
symlink-privilege skip per shell). See the [resumption evidence](../docs/codex/winaudioclean/evidence/WAC-M1-02-resume.md).
The runner never changes machine security settings. Preserve child diagnostics
and CodeIntegrity event evidence; a rejected native start must remain a failed
check. Do not retry
or alter fixtures, trust or security settings to bypass a rejection. Real FFmpeg
checks provide separate evidence and do not replace blocked fixture cases. See
the fixture contract for the recorded event details and task governance for the
current acceptance status.

## Dependencies, stream mapping and local media (WAC-M1-03)

The Media suite covers dependency precedence, version/filter failures, strict
JSON validation, selection/reprompt/cancel behavior and exact absolute mapping.
It also invokes the real native fixture for malformed/nonzero probe output,
version/filter/probe deadlines and child reaping. Actual PATH lookup and a copied
application verify that ffprobe is found next to explicitly selected FFmpeg.
The existing direct/batch matrices now verify both inspection and render argv.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Media.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Media.Tests.ps1
```

The final targeted suite passed 99 tests in each shell. Fixture inspection has
separate `WAC_TEST_VERSION_*`, `WAC_TEST_FILTERS_*` and `WAC_TEST_PROBE_*`
controls; these test-only variables do not change production behavior. Tests
preserve absent versus empty environment variables explicitly across PS5.1/PS7.

Run the optional standard-library harness with an existing local FFmpeg pair:

```powershell
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-MediaPreflight.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
```

It creates a fresh ignored run folder and a three-second Matroska file with video
index 0, mono 440 Hz audio index 1 and stereo 880 Hz audio index 2. Both shells
render each track in Raw/Zoom. Independent sample measurements verify selected
frequency and channel count. Negative cases cover unattended ambiguity,
non-audio/missing indexes, video-only input and ordinary/renamed HLS/concat lists.
A loopback HTTP listener has a positive control and counts attempted media
requests; direct render-helper checks exercise policy even though application
probing rejects these files earlier. All 32 cases passed with zero media requests.

Python is development tooling only. Generated media and raw local logs remain
under `.wac-local`; only sanitized evidence is committed. This is no speech
listening, channel-isolation or decoder-sandbox certification. Output encoding
and legacy collision behavior remain unchanged in this task. See the
[M1-03 evidence](../docs/codex/winaudioclean/evidence/WAC-M1-03.md).

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
