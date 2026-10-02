# Native-process and file-safety contract

Use small PowerShell helpers; do not build a new application framework. Maintain Windows PowerShell 5.1 and supported PowerShell 7 behavior.

## Arguments and execution [S02]

Treat executable paths and every user path as data. Avoid Invoke-Expression, cmd /c construction from user strings, expression-valued configuration and arbitrary filter strings. Start-Process joins ArgumentList items into a command line; simply changing a string to a string array does not solve quoting. Modern ProcessStartInfo.ArgumentList is not available in the same form on all target runtimes. Isolate and test any compatibility quoting path rather than assume equivalence.

Run only the resolved FFmpeg/ffprobe executable. Verify exact child argv using an argument-echo fixture on Windows. Test spaces, trailing backslashes, brackets, Unicode, apostrophes, parentheses, &, %, ! and path-length boundaries through the actual .bat. CMD/PowerShell -File array expansion is a separate boundary: do not certify it by direct PowerShell tests alone. Reject unrepresentable input with a safe alternative rather than silently corrupt it.

Input paths must resolve to existing local filesystem files; explicit supported UNC paths can still reside on a network share. Do not advertise physical offline storage for them. Reject URLs and block external-media references where supported by an allowlisted protocol/demuxer policy. Disable stdin for unattended child jobs. Never turn repository/user media metadata into commands.

## Lifecycle and output

Drain stdout and stderr concurrently, close handles, handle launch exceptions and observe exit status after process exit. Progress belongs on a dedicated structured stream; error logs are not the progress parser. A probe must have a timeout; long audio renders need user cancellation and a sensible inactivity policy, not an arbitrary short total timeout. Avoid false failure for long normal jobs.

A possible app exit-code contract to finalize at M1: 0 success; 2 invalid input/config; 3 missing/incompatible dependency; 4 probe/processing failure; 5 output-validation/publication failure; 6 batch completed with one or more failed items; 130 cancelled. Explicitly define any warning status and logging-only failure behavior. Native FFmpeg exit codes are included in diagnostics even when mapped to application codes. Preserve the script's exit code before pause in the launcher.

## Files and cancellation

Allocate a unique job directory/temp filename in the final destination volume, explicitly choose WAV even if the filename ends in .partial, and use no-clobber semantics. Only after exit 0 and successful probe/format/duration checks may a no-overwrite move publish the final name. Defend the rename race, not just Test-Path before launch. Timestamp seconds alone are not a concurrency guarantee.

No input/output alias, including normalized paths and supported link/file-identity cases. Cancellation targets the owned process object/ID for that run, not every ffmpeg.exe. Remove only files whose ownership was established by that run. Do not sweep user directories, delete prior exports, or clean unrelated processes. Crash leftovers need explicit identification and optional cleanup, not an unsafe startup purge.
