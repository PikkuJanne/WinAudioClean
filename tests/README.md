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
Output regressions now require unique job IDs, owned partials, independent WAV
validation and no-replacement publication. The exact Raw/Zoom filter strings
remain baseline assertions.

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

## Owned output, validation and publication (WAC-M1-04)

`WinAudioClean.Transaction.Tests.ps1` exercises Windows handles, unique jobs,
exclusive reservations, hardlink aliases, a retargeted directory junction,
replacement races, held-object publication, cleanup and guarded reporting.
`WinAudioClean.Validation.Tests.ps1` checks actual RIFF/sample bytes and selected
track timing, including repaired headers hiding a shortened render. Entry tests
inject zero-exit empty/header/truncated/short outputs and probe failures; reporting
tests retain native failures and published audio.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Transaction.Tests.ps1
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-OutputTransactions.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
```

The development harness runs both shells against existing real FFmpeg. It tests
rapid repeats, same-stem inputs, concurrent jobs, MP3/AAC inputs, empty/invalid/
truncated output, encoder/disk-full simulations, a final-name race, an abrupt
pre-rename exit and the next run's preservation of that leftover. Faults use
explicitly recorded overrides only in disposable app copies; production has no
fault environment controls. The disk-full case is simulated, not a filled disk.
Source, prior-export and runtime hashes are checked; independent PCM duration,
frequency and channels are recorded. A changed runtime makes the harness fail.

Both runtime files must be copied together when testing or installing the app.
Keep generated audio and raw logs ignored. Evidence and remaining limits are in
[M1-04 evidence](../docs/codex/winaudioclean/evidence/WAC-M1-04.md).

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

## Explicit output encoding (WAC-M1-05)

Run `tests/WinAudioClean.Encoding.Tests.ps1` for export/channel policy, RIFF
boundaries, headroom, pinned destination capacity and injected early failures.
`tests/WinAudioClean.Validation.Tests.ps1` checks requested PCM format/layout and
small RF64 ds64 fixtures, including malformed sizes/tables/sample counts.

The real audio matrix is optional development tooling using installed tools:

```powershell
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-OutputEncoding.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
```

It generates synthetic 44.1/48 kHz mono/stereo signals, runs both original modes
and PCM16/24 in PS5.1/7, then inspects final format, channel content, timing and
source hashes. Extra cases exercise explicit mono and small RF64 output. An
independently encoded frozen legacy chain establishes existing filter delay;
the harness rejects unexplained residual shifts and altered sample data. Raw's
existing approximately 25 ms marker delay is recorded, not silently corrected.
These checks do not certify speech quality, full >4 GB output or real disk
exhaustion. Keep generated media and raw logs under `.wac-local`.

## M1 reliability gate (WAC-M1-07)

Run Quick, then the focused safety/launcher/reporting group, then one Full gate
in each available supported Windows shell. Full includes all M0/M1 Pester
suites and the Python governance tests; it cannot be reduced by path/tag flags.
Use a fresh process for each command. When launching PS5.1 from a PS7/Python
host, omit inherited `PSModulePath` in the child environment so Windows
PowerShell initializes its own module defaults.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/Invoke-Tests.ps1 -Level Targeted -Tag @('Transaction','RunReports','OutputSafety','Launcher')"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/Invoke-Tests.ps1 -Level Targeted -Tag @('Transaction','RunReports','OutputSafety','Launcher')"
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full -AnalyzerWarnings
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

The focused group checks ownership/cleanup, report writes/rollback, malformed
outputs and batch forwarding. Full also covers preflight, native-process,
dependency/media, encoding and PCM/RF64 validation. A default single-file batch
handoff uses a controlled application stub; do not label it an Explorer
interactive drag/drop render.

For additional real encoder and report checks, use existing local binaries and
fresh output directories under `.wac-local`:

```powershell
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-OutputTransactions.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M1-07/real-transactions
python -X utf8 scripts/Test-RunReports.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M1-07/real-reports
```

These harnesses retain their originating task labels (M1-04 and M1-06) in the
JSON; M1-07 records the fresh invocation, source hashes and case results without
rewriting that provenance. Faults use isolated application copies and synthetic
media. Disk-full and report-permission injection do not prove real volume
exhaustion or hardware-failure recovery. Do not commit raw audio or reports.

[Gate evidence](../docs/codex/winaudioclean/evidence/WAC-M1-07.md) records exact
commands, environment, source identities and limits. The
[file-safety review](../docs/codex/winaudioclean/evidence/WAC-M1-07-review.md)
maps runtime writes and cleanup to the relevant tests.

## Original preset identity and compatibility (WAC-M2-01)

`WinAudioClean.Preset.Tests.ps1` checks the unchanged Original profiles and
preset/report identity through Raw/Zoom menu and direct invocation paths. Its
isolated menu copies override only host-interactivity detection and Read-Host;
profile selection, native command construction and persisted reporting run
normally. Legacy, current and arbitrary identity strings stay omitted from
redacted diagnostic exports. This does not simulate Explorer drag-and-drop.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Preset.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Preset.Tests.ps1
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-OriginalPreset.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe"
```

The optional comparison harness uses existing local tools and deterministic
synthetic fixtures. It compares both modes in both shells against direct FFmpeg
references built from `BASELINE.json`: 48 kHz PCM16 stereo, 44.1 kHz mono input,
short input, silence, and stereo PCM24. Outputs must match decoded PCM bytes
at zero lag with identical encoding settings and the same FFmpeg build. This
establishes preservation of tested filter behavior, not speech quality or
identical files across FFmpeg builds or the historical implicit encoder.
Generated media/reports remain under ignored `.wac-local`; only sanitized
summary evidence belongs in Git.

When Python starts child shells on Windows, remove inherited module-path keys
case-insensitively (`key.upper() != 'PSMODULEPATH'`); `os.environ.copy()` uses
uppercase keys. This avoids PS7 module paths breaking PS5.1 cmdlet discovery.
See [M2-01 evidence](../docs/codex/winaudioclean/evidence/WAC-M2-01.md) for actual
checks and the preserved initial environment failure.

## Measured loudness and held-stream input (WAC-M2-02)

Three new suites cover the opt-in Accurate path:

- `WinAudioClean.Loudness.Tests.ps1`: identical Raw/Zoom prechains, selected
  streams and mono policy; invariant measured arguments; strict JSON parsing;
  short/silent/out-of-range fallback; final input metrics and peak precedence;
  warning/report status and redacted fields.
- `WinAudioClean.LoudnessRuntime.Tests.ps1`: isolated application copies inject
  native-stage faults while the real runtime controls ordering, publication and
  persisted reports. It checks fatal first-pass failures, render/final diagnostic
  warnings, dynamic fallback and successful completion.
- `WinAudioClean.NativeInput.Tests.ps1`: input larger than a pipe buffer, EOF,
  both diagnostic streams, unreadable/failing input, early zero-exit children,
  blocked-input timeout and preservation of an unrelated process. The caller
  stream remains open and the wrapper returns one result in PS5.1 and PS7.

Run focused suites first in each supported shell; for example:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Loudness.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.LoudnessRuntime.Tests.ps1
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.NativeInput.Tests.ps1
```

Repeat those commands with `powershell.exe` for PS5.1. After focused checks
stabilize, run one cumulative `-Level Full` per shell using the commands above.
Full includes these suites; the real-FFmpeg harness remains a separate check.

Use existing local FFmpeg/ffprobe binaries for the complete measured matrix:

```powershell
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-MeasuredLoudness.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M2-02/measured-full-1
python -X utf8 scripts/Test-OriginalPreset.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M2-02/fast-baseline-1
```

Choose fresh output directories. The measured harness defaults to all **16
cases**: eight configurations in PS5.1/en-US and PS7/de-DE. Synthetic fixtures
cover a selected second stream, Raw/Zoom, mono/stereo, explicit downmix, PCM16/24,
high LRA, restricted peak headroom, silence and subsecond audio. It inspects
encoded PCM and independently measures the published WAV, verifies all three
stage commands/measurements, checks the documented compliance/fallback outcomes
and compares decoded samples across shells/locales. Eligible cases must meet
the declared integrated/peak tolerances. Source and fixture hashes must remain
unchanged during the run. Missing shells or failed checks make the run fail.

`--case <case-id>` (repeatable) and `--shell ps51|ps7` limit investigative runs.
Their recorded `scope.full_matrix` is false; a passing scoped run is not full
AC-037/038/039 acceptance. Keep preliminary runs and their exact scope separate
from the final unfiltered 16-case matrix. The Original comparison harness also
requires Fast to remain unmeasured with null Accurate stages and no loudness
warning, alongside its existing exact-PCM comparison against Original.

The native wrapper uses binary stdin only for the held final WAV, retains caller
ownership and closes child stdin at EOF. Accurate stage deadlines are duration
based with a two-minute minimum; Fast retains its unlimited total render time.
The development harness has its own bounded child-process timeout and kills
only the owned harness process tree if it expires. Fixture tests and generated
audio establish mechanics, not listening approval, long-file/memory stress or
full >4 GB output. Keep media, raw local reports and private paths out of Git;
only reviewed, sanitized evidence belongs in the task record.

## Optional Gentle cleaning and validated controls (WAC-M2-03)

`WinAudioClean.Cleaning.Tests.ps1` covers finite typed options, both numeric
bounds, injected/unknown settings, stage toggles, locale serialization and
exact Original defaults. It checks the versioned effective settings, Accurate
profile reconstruction, candidate/customization reports and diagnostic redaction.
Entry checks reject invalid cleaning configuration before native execution or
destination creation. Run this suite in both supported shells before Full:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Cleaning.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Cleaning.Tests.ps1
```

Use fresh ignored directories for the real FFmpeg harnesses:

```powershell
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-GentleCleaning.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M2-03/gentle-final
python -X utf8 scripts/Test-OriginalPreset.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M2-03/original-final
```

The Gentle matrix uses deterministic synthetic input in PS5.1/en-US and
PS7/de-DE. It checks selected streams, mono conversion, Fast/Accurate processing,
custom stage toggles and boundary/fractional options. An isolated app copy
records native arguments through a reviewed wrapper that delegates to the
unchanged runtime. Accurate repeats the validated prechain and meters the held
encoded output. Independent published-file checks verify reports; Fast cases
also compare decoded PCM with direct filter references. The separate Original
matrix verifies unchanged default PCM against the frozen baseline.

These checks establish processing mechanics on the recorded build. Speech
listening remains unperformed without cleared material; use the
[candidate record](../docs/codex/winaudioclean/evidence/WAC-M2-03-listening.md)
for the pending review. Neither synthetic exports nor the Gentle name approve
voice quality or a default sound change.

## Bounded preview and separate comparison (WAC-M2-04)

`WinAudioClean.Preview.Tests.ps1` tests invariant range validation, sample
rounding, bounded context, selected-track timestamps, fractional attenuation
and exact output frames. Fault cases use real owned file transactions with
controlled native results: cancellation, failed renders/meters, a short output,
an excessive comparison peak, a publication collision and a report failure.
They check source/settings preservation, foreign-file retention, owned rollback
and completed assets retained on a reporting warning. Run both shells:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Preview.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Preview.Tests.ps1
```

Run the real FFmpeg matrix separately, using a fresh ignored output directory:

```powershell
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-Preview.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M2-04/preview-final
```

The matrix covers start/middle/end, default/fractional intervals, short/silent
input, a shifted selected track, Original/Gentle/custom cleaning, Fast/Accurate,
channel conversion and encoding including small RF64. Original PCM must match
an independently decoded source-frame slice exactly at zero offset for WAV;
container cases record any exact sample offset within the declared timestamp
precision. Processed PCM matches the bounded filter reference exactly, and
comparison PCM matches gain-only references. Published-file meters check
the reported comparison target, matching tolerance and true-peak ceiling.
Native argument capture proves the application bounds the source input and
meters held streams; intentional full decoding occurs only in the evidence
harness. Locale pairs must produce identical PCM and all tested sources and
fixtures must remain unchanged. `--case` and `--shell` select investigative
runs; their partial scope cannot establish the complete acceptance matrix.

Five-second context and preserved graph delay can differ from a full render.
These synthetic checks do not establish listening quality, full-recording
loudness, running-render Ctrl+C behavior or independent meter calibration.
Playback is explicit. Keep generated audio and raw local reports out of Git.
The inherited loudness parser rejects integrated values above 0 LUFS. The
preliminary hot square exposed that limit; the final lower-amplitude peak-guard
case does not establish support for positive integrated source loudness.

## M2 objective gate and report reproduction (WAC-M2-05)

Run the Preset, Loudness, LoudnessRuntime, NativeInput, Cleaning, Preview and
Encoding suites in both shells before the unfiltered Full gate. The Loudness
suite also checks that positive input/output integrated values and positive
thresholds remain explicit parser failures, including on short input; they
must not be relabeled as silence or unavailable measurements.

Run all five real-media matrices separately: `Test-OriginalPreset.py`,
`Test-MeasuredLoudness.py`, `Test-GentleCleaning.py`, `Test-Preview.py` and
`Test-OutputEncoding.py`. Use fresh ignored output directories and the same
pinned FFmpeg/ffprobe. Omit investigative case/shell/prepare-only filters.
Passing mechanics does not mean every export reaches the loudness targets:
Fast is NOT_MEASURED, and Accurate fallback, target misses and undefined
metrics retain their documented warnings and reasons.

`Test-AudioReproduction.py` is a development-only check of reproduction from
local reports, using deterministic synthetic inputs and the installed build:

```powershell
$bin = '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
python -X utf8 scripts/Test-AudioReproduction.py --ffmpeg "$bin/ffmpeg.exe" --ffprobe "$bin/ffprobe.exe" --output .wac-local/WAC-M2-05/reproduction-final
```

It checks preset identity/effective settings, processing graphs, stream/channel
selection, encoding, Accurate measurements and preview range/gains against
the report before direct same-build replay. Decode and compare the reproduced
PCM and frame counts; retain input, report, source and tool hashes.
The matrix covers its selected configurations; reconstructed literals and
graphs must agree exactly before replay. It does not promise formatter parity
for every highly precise custom value or independently revalidate every
preview range-policy field; those policy checks remain in the preview suite.
Ordinary reports do not embed a source revision or input/executable hashes, so the
evidence harness supplies that provenance separately. Reproduction depends
on the same retained input and build; it does not certify different builds,
speech quality, playback or default promotion. Keep audio and raw reports
ignored. Record listening status separately from objective acceptance.

## Local JSON settings and unattended precedence (WAC-M3-01)

`WinAudioClean.Settings.Tests.ps1` covers the optional settings helper,
schema-1 JSON types and keys, complete saved-file validation, explicit
CLI > saved > built-in precedence, and settings management without audio or
native execution. It checks actual bound-key presence for explicit false
switches and empty cleaning dictionaries, saved mode/stream selection,
malformed/unknown-version recovery, locale-independent numbers, atomic writes
and preservation of the prior valid file on injected save failures.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Settings.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Settings.Tests.ps1
```

Keep input/import, preset/cleaning and entry-point regressions in the focused
compatibility group, then run the unfiltered Full gate in both supported shells.
Importing the main script remains IO-only. A missing settings sibling is
compatible when the default file is absent and no explicit SettingsPath or
settings action requires it. Unattended input
still fails promptly when neither CLI nor saved choices resolve a required
mode or an ambiguous audio stream; it must never fall back to Read-Host.

Settings tests use isolated JSON paths and temporary outputs. The task's real
FFmpeg matrix uses synthetic fixtures under ignored `.wac-local/WAC-M3-01`
and an explicit isolated `-SettingsPath` for every run. It compares saved
preferences with equivalent explicit CLI renders on the same pinned build,
including PCM16/24, mono false overriding saved true, RF64 selection, a saved
second-stream index, whole-dictionary cleaning replacement and `@{}` clearing.
German/Finnish decimal-culture cases use actual JSON numbers with decimal dots.
Malformed settings fail with code 2 even if a CLI override names the invalid
field; Ignore and Reset exercise the documented recovery routes. Management
cases verify no audio publication, while source/settings hashes and exact
decoded PCM/frame checks establish preservation and precedence. A direct
Original reference checks the unchanged built-in graph separately.

Record the actual matrix command, cases, exits, source/tool/configuration hashes
and sanitized results with the task evidence. Counts describe completed runs,
not planned coverage. Keep generated audio, full local reports and raw logs
ignored; do not read or overwrite the user's own preferences. These checks do
not approve speech quality, retune Original or certify cross-build PCM.

## Ordered launcher lists and persistent item results (WAC-M3-02)

Test the actual CMD launcher transport independently from audio processing.
Check one/many ordered paths, spaces/Unicode/brackets/ampersands/apostrophes/
parentheses, literal percent/exclamation limitations, malformed and oversized
handoffs, no-input guidance and preserving status across pause. Use explicit
manifest fallback where CMD cannot preserve a name or list; never replace an
unrun Explorer drop with a claim that it was tested.

The accepted positional transport is a fresh CMD `/c` frame whose original
tokens exactly match the numbered environment captures, below 7,600 characters
and at most 1,024 inputs. Existing/nested CMD frames and observable `%`/`!`
positional text fail closed. `/manifest` reads only the literal
`WAC_LAUNCH_INPUT_LIST_PATH` environment value; `/unattended Raw|Zoom` requires
that value or `WAC_LAUNCH_INPUT`, exclusively, plus a destination. Exercise both
default PS5.1 and explicitly selected PS7 inner hosts, isolated settings,
interactive one-pause and unattended no-pause behavior. Keep transport probes
distinct from full application/FFmpeg integration results.

Batch tests cover mutually exclusive legacy input/typed `InputPaths`/
`InputListPath`, schema-1 UTF-8 manifest bounds and relative paths, retained
explicit repeats, frozen shared settings, one mode selection, and rejection of
preview/settings/support actions. A held CreateNew JSONL writer records header,
ordered per-item results and aggregate summary; injected persistence failures
stop later work. One-item lists preserve the item code; multiple failed items
produce code 6, warning-only results 7, cancellation 130, and successful lists 0.
Cancellation marks remaining inputs NOT_STARTED. Explicit-list checks retain
repeats; folder discovery and deduplication have separate coverage below.
The M3-02 checks did not establish active-render cancellation; the M3-04 scope
below tests that behavior separately.

The ignored `.wac-local/WAC-M3-02` real-media matrix uses synthetic inputs and
isolated saved settings in both PS5.1/PS7. It compares ordered batch items with
equivalent single-file renders using exact decoded PCM, frames, format, graph,
stream and effective report settings. Valid/invalid continuation, warning
retention, literal-name manifests, saved choices and controlled cancellation
are separate outcomes. Capture hashes, actual commands/exits, JSONL records and
sanitized evidence; a simulated cancellation seam is labeled explicitly and
does not certify active Ctrl+C. Preserve failed preliminary runs. No user
preferences/audio, listening approval, retuning or cross-build claim is involved.

## Sequential folder discovery and source snapshots (WAC-M3-03)

Run the folder suite in both supported shells:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.FolderQueue.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.FolderQueue.Tests.ps1
```

Test the direct PowerShell `InputDirectories` route separately from explicit
lists and the BAT. Recursion defaults off; `Recurse` requires folder input.
Folders are mutually exclusive with other input routes and preview/settings/
diagnostic actions. Importing the main script and running ordinary single-file
or explicit-list requests must retain their optional-component contracts.

Queue coverage must establish complete materialization before child jobs,
supplied-root order, breadth-first traversal with ordinal entry ordering,
identity deduplication and unchanged explicit-list repeats. Use mixed folders
with supported candidate extensions, unsupported files, duplicate/overlapping
roots, hardlink aliases, identical stems, generated exports/previews/reports/
journals/partials, nested directories and reparse entries. Verify a generated
name discovered later also excludes its earlier identity alias; arbitrary
renamed outputs without a marker alias remain a documented limitation.

Reject reparse roots/ancestors without following them; encountered reparse
entries are skipped. Keep junction/symlink fixtures owned and clean up only the
link entry. If privileges prevent a fixture, record the actual skip and reason.
Test destination containment by path components, a proper descendant output
subtree, destination equal to a selected root, and a nearby sibling whose name
shares a prefix. New outputs or children created after materialization must
never enter the running queue.

Check root/entry/directory/ancestor/path-byte bounds and enumeration failures
before any child call. The limits are 64 roots, 1,024 recorded entries including
skips/failures, 1,024 visited directories, 2,048 pinned ancestors and 1 MiB of
UTF-8 paths for recorded entries. Source snapshots include stable identity,
length and last-write time; mutation/replacement before dispatch produces a
failed entry with code 2,
while the current source stays held through its child invocation. Test denial
of source replacement/write during that held interval and safe release after
success, failure and cancellation.

Folder-only schema-2 journals must record selection provenance, fixed selection/
source reasons, source snapshots and skipped counts. Intentional skips are
not successful renders. Empty/all-skipped selections need no mode prompt or
FFmpeg/ffprobe call and return 0. A middle failure continues later jobs and gives aggregate 6;
warnings alone give 7. Controlled child cancellation gives 130, stops new jobs,
preserves known skips/failures and marks pending entries NOT_STARTED. Persistence
failures stop later work with 5, preserving completed audio and flushed records.
Keep explicit-list schema 1, its one-item exit behavior and repeat semantics
unchanged. A simulated cancellation seam does not establish active Ctrl+C.

Use synthetic media and isolated settings for real folder integration in both
PS5.1 and PS7. Compare queued exports with equivalent single-file renders on
the same pinned FFmpeg build, including exact decoded PCM/frame counts and
effective report settings. Record actual cases, commands, exits and source/
tool/journal hashes; preserve failed preliminary captures. Keep audio/raw
reports and fixture trees ignored, publish only sanitized evidence, and do not
infer listening approval or default promotion from objective checks. Run the
smallest relevant suites before the required unfiltered Full gate in both
supported shells; count only completed coverage.

## Structured progress and owned cancellation (WAC-M3-04)

Run the focused suite in both supported shells before cumulative gates:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Progress.Tests.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Path tests/WinAudioClean.Progress.Tests.ps1
```

The native fixture emits valid, malformed, oversized, truncated and flooding
stdout blocks plus independent stderr. Verify the 4,096-character line and
64-field block limits, recovery at block terminators, microsecond timestamps,
indeterminate unknown-duration states, bounded stage percentages and explicit
process/stream failures. A progress `end` block is not publication or success.
Display failure must not decide processing outcome. A throwing progress-display
double is a unit fault; captured redirected stdout/stderr are real redirection
checks. Neither demonstrates graceful handling of an actual console window
close or forced host kill. Test parser/display behavior separately from real
FFmpeg rendering.

Use per-invocation contexts for active cancellation. Exercise Accurate
analysis/render/verification, Fast and preview paths, held binary input,
abnormal native exit and queued `NOT_STARTED` suffixes. An independent native
job must stay alive and complete, with originals, foreign files and completed
exports preserved. Timer or `Request-WacCancellation` injection is labeled as
a controlled request; it is not evidence of an actual console signal.

`tests/fixtures/Invoke-ConsoleCancellationCase.ps1` and the ignored
`.wac-local/WAC-M3-04/check-console.py` harness exercise actual Windows
`CTRL_C_EVENT` and `CTRL_BREAK_EVENT` in separate hidden private consoles on
PS5.1 and PS7. The fixture uses synthetic media, isolated settings and source
copies, adds only input pacing and observation, and delegates native work to
the product helper. A detached sender attaches to the owned console and sends
the event to group 0. Verify exit 130, a persisted cancellation report, removal
of owned partials, an unaffected concurrent survivor and no 100% before held
publication. A second event after `Dispose` must reach a lower-priority test
observer, establishing handler removal without terminating the fixture host.
This is a native signal check, not a UI typing or Explorer-drop claim. It does
not certify console-close/logoff, forced host termination or power-loss
cleanup. Keep readiness PIDs, actual commands, raw log hashes, source/tool
hashes and failed preliminary attempts; publish only sanitized derivatives.

The real-media progress harness records variable-speed rendering, stage
durations, preview assets, independent survivors and same-build PCM parity.
Keep unknown-duration unit states separate from a real live-WebM helper/null-
sink progress check and the application's rejection of unknown media timing
with code 4 before a full render. These scopes do not broaden supported input
timing. Distinguish objective output checks from unperformed listening review.
