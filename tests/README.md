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
