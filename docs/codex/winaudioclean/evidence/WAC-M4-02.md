# WAC-M4-02 — Windows CI and local parity

Implementation checkpoint in progress, 2026-10-03. Parent is freshly verified
clean local/upstream/live `codex/wac-m4-regression`
`42cf8f24a9b1886b5a807bb74e7b299d9de9cb29`, on draft PR #5 stacked on
`codex/wac-m3-settings`. Only the maintained governance checkout is used.

The workflow adds four Windows OS/shell combinations, exact verified Action
commits, checksum-verified portable Python 3.14.6 and PowerShell 7.6.5, and
existing pinned Gallery modules. It calls the same local Full runner. Read-only
permissions, no persisted checkout credentials/secrets/caches/publication,
ordinary PR/push events and one sanitized JSON artifact with seven-day retention
establish the reviewed boundaries. [CI instructions](../CI.md) record parity,
provenance and result semantics. That initial CI checkpoint changed no runtime,
BAT, sound/default or setting. The later necessary runtime correction is scoped below.

Focused setup tests passed 5/5 on PS7; policy 9/9, status-reader 20/20 and wrapper
controlled-process tests 24/24 passed. Actual Quick on both shells passed
1075 Pester / 0 failed / 1 privilege skip / 386 outside scope, with observed
Pester 5.7.1/PSScriptAnalyzer 1.24.0 and Python 3.14.6. PS5.1 is 5.1.26100.9444;
PS7 is 7.6.5; active Windows build26300. The later Full-only outside-scope
guard refinement passed the focused Python suite; the Quick source hashes
retain their pre-refinement identity. Quick was not repeated for that guard.
Official archive bytes downloaded/extracted
locally match committed SHA256 pins. Unsupported shell/API simulations are
covered explicitly and cannot become passes. An actual nonexistent-shell
invocation returned nonzero/not_run/shell_unavailable. Live reading the parent
SHA correctly returned not_run/exit3, with no GitHub workflow run. The initial
capture redirection failed before invoking gh because its ignored destination
was absent; after explicit directory creation the actual reader ran. No failed
capture was claimed as evidence. The initial status lookup's
default-branch filename restriction was corrected before remote validation.

## Initial committed Full and PR results

Both local Full gates at clean `fd56b84c56b30575bd744d84751b88cad69333f9`
passed with stable pre/post source hashes: 1461 Pester passed, one file-symlink
privilege skip, zero outside scope; Python 128 ran with one privilege skip.
PS7 elapsed 1073.29 seconds and PS5.1 elapsed 1088.41 seconds, both exit 0.
These are local Windows build26300 results, not hosted CI evidence.

[Initial actual PR run](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37143282084)
at the same SHA completed **failed**. Both Windows Server 2022/2025 PS7 jobs
passed 1462 Pester and 128 Python cases with no skips. Both PS5.1 jobs failed
the Full step, exit 1. Their setup completed, exact Python/module pins were
observed, and source remained clean/unchanged. PS5.1 versions were
5.1.20348.5622 and 5.1.26100.33438. All four fixed JSON artifacts were retained
for seven days. Initial reports expose no assertion location, so the next
checkpoint adds bounded sanitized diagnostics before another actual CI run.
The failure is not waived or represented as a passed gate.

The diagnostic refinement passed all 59 focused CI policy/wrapper/status Python
cases, including six new privacy/location cases. Independent review found no
actionable issue; plan and coverage gates pass. It exports only fixed enums,
counts and at most 32 Git-listed source locations. Runtime and the existing
Full runner remain unchanged. The preceding local Full evidence is retained
at its original SHA; focused tests cover this developer-only refinement.

## Diagnostic CI and reproduced native-input defect

[Diagnostic PR run](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37144796506)
at clean `8af62ffe02aa3d7111ff1edbf39324f2eb73a241` completed failed.
Both PS7 hosts passed 1462 Pester and 134 Python cases with no skips. Each
PS5.1 host passed 1459 and failed exactly three Pester assertions, with no
skips/outside scope: Native.Tests line99 and NativeInput.Tests lines71/94.
They assert stdin EOF/payload lengths and drained stdout. Startup, exit status,
error and timeout assertions before those locations passed. Additional stack
references in the reports come from deliberately handled batch/journal errors;
source locations and heuristic categories are informational, not a failed-case
inventory. All four sanitized artifacts and their seven-day metadata are retained.

An owned CREATE_NO_WINDOW local PS5.1 child reproduced the actual wire defect:
UTF-8 with a BOM sends `EFBBBF` for empty stdin and prefixes 32 ASCII bytes
with those three bytes. OEM437 and BOM-free UTF-8 controls transmit exactly
their supplied bytes. The .NET Framework Process creates StandardInput with
Console.InputEncoding and AutoFlush, causing StreamWriter's preamble to be
written during Start. Local PS5.1 input encoding was OEM437/no preamble;
the hosted input encoding was not exported or directly observed. The owned
UTF-8-with-BOM reproduction establishes the matching failure mechanism, and
unchanged hosted assertions must corroborate the correction. This is a real binary-input defect exposed by CI,
not a reason to waive the assertions or normalize the hosted console globally.
Primary implementation sources: [Process](https://raw.githubusercontent.com/microsoft/referencesource/main/System/services/monitoring/system/diagnosticts/Process.cs)
and [StreamWriter](https://raw.githubusercontent.com/microsoft/referencesource/main/mscorlib/system/io/streamwriter.cs).

A minimal native-start correction selects a child-specific BOM-free stdin
encoding where available, or scopes the same-code-page input encoding change
to PS5.1 startup and restores it in finally. Pipe handles are owned before
restoration so a restoration error still permits cleanup. Six owned fresh-child
cases compare raw SHA256/lengths for empty, binary and intended leading-BOM data,
plus no-BOM/OEM controls and startup failure. All six passed on both shells.
The corrected local eight-case wire probe transmits the exact supplied bytes.
Physical bytes outside Invoke-WacNativeProcess and LF contents of the other
eight runtime files match the diagnostic parent. Filters/defaults are unchanged.

The first Targeted command selected the broader Native/NativeInput tag set:
18 suites, 203 cases. PS7 passed 203/0/0 with 1265 outside scope, exit0 in
434.24 seconds. PS5.1 passed202/failed1/skipped0 with 1265 outside scope, exit1
in 434.27 seconds. Both pre/post source hashes were unchanged. The PS5.1 failure
was Progress.Tests line346, reading a missing owned fixture PID file; started,
cancelled, no-timeout and timer-requested assertions had already passed.
The timer was armed 750ms before child startup, so under concurrent load it
could cancel before PID publication. An unchanged, exact-path PS5.1 Cancellation
recovery passed7/0/0 with41 outside scope in18.438 seconds. This recovery does
not replace the failed broader result or remove the startup readiness race.

The three active-stage cancellation fixtures are stabilized with a
bounded complete/live PID handshake before cancellation, and a synthetic
1000ms pre-PID delay to exercise that handshake deterministically. Existing
ownership, survivor, cleanup and deadline assertions remain. Independent review
caught a missing fixture helper default argument and new timer-teardown paths
that could bypass disposal; both were corrected before the next test run.
Timer/context/survivor/input cleanup now receives independent finally attempts.

Exact Native.Tests, NativeInput.Tests and Progress.Tests paths with
Native/NativeInput/Cancellation tags passed63/failed0/skipped0,20 outside scope,
on each shell: PS5.1 elapsed37.589 seconds, PS7 elapsed38.300 seconds, exit0.
Runtime/test source hashes stayed unchanged throughout both gates. The test
tree differs from the preserved broader/recovery captures; these scopes are
recorded separately. Fresh local and hosted Full evidence remain required.

The first forced gh-credential push was rejected for the OAuth workflow scope.
The existing default Git credential successfully pushed the feature checkpoint
noninteractively; no permissions, repository settings or credentials changed.

At this implementation checkpoint WAC-M4-02 remains todo; AC-070..072 remain not_run.
Coverage availability is not execution evidence. No packaging, merge, release,
repository setting, default promotion or deployment is performed.
