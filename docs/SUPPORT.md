# Help and troubleshooting

Start with the [first-run guide and command examples](../README.md) and the
[portable package guide](PORTABLE_PACKAGE.md). Keep the complete extracted
package together and run from a user-writable folder. WinAudioClean needs no
administrator installation and downloads no dependencies automatically.

Read the console message immediately before the final result. Early input,
settings, dependency, media-probe and space failures can be console-only;
absence of a report does not mean success. For a processing attempt, inspect
the per-run JSON/text report rather than only `WinAudioClean_Log.txt`. With
`-JobFolder`, audio is under `media` and reports are under `reports` in the new
job directory. Queue results also have a JSONL journal with per-item exits.

## Missing or incompatible dependencies

FFmpeg lookup is an explicit `-FfmpegPath`, a sibling `ffmpeg.exe`, then `PATH`.
ffprobe lookup is an explicit `-FfprobePath`, the resolved FFmpeg directory,
then `PATH`. Inspect the resolved paths and versions printed in the console.
An invalid explicit path or present invalid sibling fails; it does not fall
back to another installation. Move the unintended sibling aside or correct
the explicit path before retrying.

Supply both Windows executables from a trusted build. A file with an `.exe`
name is insufficient: the version response and required filter capabilities
must pass inspection. A missing Raw filter needs a build that contains it;
there is no promised minimum version that substitutes for those checks.
Dependency failure normally returns `3`. Keep the required
`WinAudioClean.IO.ps1` beside the main script, and retain the other package
helpers for settings, previews, lists, folders and launcher features.

If Windows blocks a downloaded file or a machine policy denies execution,
check the file's source and checksum and follow the normal policy/admin
process. Do not disable antivirus, Smart App Control or execution security
globally. The [portable guide](PORTABLE_PACKAGE.md) explains the per-invocation
PowerShell execution-policy choice; it does not override enforced policies.

## Corrupt media, no audio or ambiguous tracks

Check that the source is a readable, nonempty file in a supported local media
format. A familiar extension does not prove that it contains decodable audio.
URLs, playlists, devices and network protocols are not supported inputs.
Probe, metadata and no-audio failures return `4`; an invalid selected stream
or ambiguous unattended selection returns `2`.

One audio track is selected automatically. For several tracks, use the
interactive selector or supply the absolute `-AudioStreamIndex` shown by the
probe. It is the container stream index, not an audio-track ordinal. The
export contains that audio track, without video or the other audio tracks.
Only standard mono/stereo is supported; prepare multichannel material
explicitly rather than expecting an automatic downmix. `-Mono` is an explicit
stereo-to-mono choice.

If a trusted source cannot be decoded, obtain a fresh copy or prepare a
supported mono/stereo file in your editor while preserving the original.
Unknown selected-track duration fails before rendering. Timing validation
allows up to 10 ms difference for PCM and 100 ms for compressed codec padding;
it does not remove silence or compensate the preserved Raw filter delay.
Preview can reject an unsupported timestamp origin or resolution even when a
full render is possible. Its bounded excerpt and comparison measurements do
not certify whole-recording loudness or full-render equivalence.

## Destination, permissions, space and collisions

Choose `-OutputDirectory` in a folder your normal user account can write.
Music is the built-in destination; if it is unavailable or redirected to an
unsupported path, supply a destination explicitly. Use ordinary drive or
relative filesystem paths. UNC/device paths, provider syntax and alternate
data streams are rejected. Mapped drives and redirected folders can still be
network storage.

Keep the extraction folder and output base short. Generated filenames and
`-JobFolder` nesting add to the complete path. Some native file operations can
fail on long paths even when the parent exists: the tested PS7 build failed
on one path that PS5.1 handled. If a journal or output reports "path not found"
or "filename too long", retry from a shorter writable local path. There is no
universal path-length or cross-host compatibility guarantee.

The initial write probe cannot guarantee later access or capacity. Check free
space, user quota and applications holding destination files open. An invalid
destination is normally `2`; allocation, capacity, validation or publication
failure is `5`. Choose another writable folder or close the competing reader
before retrying. Running as administrator is not a required remedy.

RIFF output that is estimated above its conservative 4 GB limit fails before
rendering. Use `-Rf64` only with an editor that supports RF64; the tool never
silently truncates or splits a recording. Large exports and actual disk
exhaustion have not been stress-tested.

Exports use a timestamp and unique job ID, then a rename that refuses an
existing final filename. Existing sources, exports and reports are never
replaced to resolve a collision. A diagnostic export or explicit journal also
requires a new filename and an existing parent folder. Select a fresh name
or destination; do not add an overwrite flag. A native exit of zero alone
does not mean that output validation and publication succeeded.

## Saved preferences

Explicit CLI choices override saved preferences, which override built-ins.
The default settings file is the current user's Windows ApplicationData folder
plus `WinAudioClean\settings.json`; `-SettingsPath` selects another local file.
Unknown versions/keys, malformed JSON and invalid combinations fail with `2`
even when CLI options would hide them. There is no implicit migration.

Use `-IgnoreSavedSettings` with explicit input/mode choices to recover a run
without changing the saved file. To inspect an isolated example file, use
`-SettingsPath '.\example-settings.json' -ShowSettings` as shown in the
[README](../README.md). If you want to discard that file's preferences,
`-SettingsPath '.\example-settings.json' -ResetSettings -ShowSettings` writes
an empty supported settings object. Substitute the intended file deliberately
and keep a copy first if its values matter. Omit `-SettingsPath` only when you
intend to inspect or reset your normal per-user preferences. Reading/processing
never saves automatically; only `-SaveSettings` or `-ResetSettings` writes.

## BAT filename and command-line limits

CMD can expand percent/exclamation names before the BAT receives them. The
launcher rejects observable `%`/`!` in positional input and a command frame it
cannot verify. Unquoted punctuation such as parentheses can also make a
drag-and-drop command fail; universal punctuation support is not promised.
An existing or nested CMD session cannot establish the positional handoff.

Use a quoted direct PowerShell call or the PowerShell-set environment/manifest
routes in the [README](../README.md) for literal names. Positional BAT commands
must be shorter than 7,600 characters and have at most 1,024 inputs. Long lists
belong in the bounded JSON manifest, not CMD text. Clear the unused
`WAC_LAUNCH_INPUT` or `WAC_LAUNCH_INPUT_LIST_PATH` value, and remove environment
values when done so a later launch cannot reuse unintended choices. The BAT
preserves the script result across its interactive pause; `/unattended Raw|Zoom`
skips the pause.

## Warnings, cancellation and unfinished files

The [README exit-code table](../README.md) is the complete reference. `0`
means the requested action completed successfully; it is not a promise of
perceived sound quality. `7` means valid audio was published with loudness or
reporting warnings. Listen to that retained output and inspect `warningCodes`,
`loudnessCompliance` and `reporting.complete` separately. Fast intentionally
uses `NOT_MEASURED`; Accurate can warn about fallback, unavailable measurements
or values outside its declared tolerances. A complete report can still describe
a loudness warning. A reporting failure preserves an earlier processing
failure code.

For a multi-item explicit list or folder queue, `6` means at least one entry
failed; inspect each journal entry rather than assuming all inputs failed.
A journal persistence failure is `5` and stops new jobs. A complete journal
requires its terminal summary. `130` is cancellation; earlier exports remain
and pending queued jobs become `NOT_STARTED`. Use `Q` at a selection prompt
or Ctrl+C/Ctrl+Break during processing in an attached Windows console.

An abrupt console close, killed process or power loss may leave
`.wac-<job-id>.partial`, incomplete reports or an empty job directory. A partial
is not a published export. Once the corresponding job has stopped, inspect
that specific leftover and remove it manually if no longer needed. Later runs
preserve old partials; do not perform a global sweep. Cleanup/rollback can also
fail on storage or sharing errors, so resolve the console diagnostics before
treating a report as complete. Crash recovery and power-loss durability are
not guaranteed.

## Share diagnostics without private audio

Detailed reports, summaries and journals can contain personal paths, filenames,
stream metadata and native diagnostic text. Keep them local by default. For an
ordinary full-run schema-1 JSON report, the explicit `-ExportDiagnostic` and
`-DiagnosticOutputPath` action creates a separate allowlisted support copy;
follow the [README example](../README.md). It needs no FFmpeg, accepts at most
16 MiB, requires an existing destination parent and refuses an existing output
filename. The original report is unchanged and no file is uploaded.

The export keeps typed numbers/booleans and fixed labels. It omits paths,
filenames, stream titles, timestamps, job IDs, version/dependency banners,
preset identity, cleaning settings, exact filters and raw diagnostics. Review
the new JSON before sharing; durations and measurements can still reveal
details of a recording. See the [implemented data formats](codex/winaudioclean/DATA_FORMATS.md).

Preview JSON is a separate schema-1 record with `reportType: "preview"` and
asset-level measurements; it lacks the ordinary `processingStatus` required by
the current exporter and is rejected. Batch/folder JSONL journals are also not
export inputs. For those failures or a console-only error, share a manually
redacted description: application/dependency versions, mode/options, exit code,
fixed warning/reason labels and the smallest synthetic reproduction you can
make. Inspect copied commands and diagnostics for personal paths, metadata and
credentials. Private audio or an unredacted report is not required for support.
