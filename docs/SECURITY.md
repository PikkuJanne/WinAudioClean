# Security and privacy

WinAudioClean processes recordings locally with PowerShell, FFmpeg and ffprobe.
It does not upload audio or reports, collect telemetry or credentials, download
dependencies, or update itself silently. Any future website is for presentation and distribution;
local processing needs no website. Mapped drives, redirected
folders, junctions and user-configured synchronization can still place files
on network/cloud storage, so choose storage appropriate to your recording.

## Install and run with your normal account

Extract the complete tool-only package into a user-writable directory. No
installer, administrator rights, server, Python runtime or test modules are
required for normal use. Keep the sibling scripts together. Supply your own
trusted Windows FFmpeg/ffprobe build; third-party binaries are not included.

Use the [portable package verification guide](PORTABLE_PACKAGE.md) before
running a download. Compare the ZIP SHA256 with its matching expected checksum
obtained through a trusted channel. The package manifest identifies source
commit/tree and payload hashes. A checksum checks bytes against that expected
value; it is not a signature or proof that the source is safe.

The launcher and documented PowerShell invocation choose execution policy only
for their process. They do not change machine-wide policy or override enforced
organization policy. Do not disable antivirus, Smart App Control or security
controls globally to make a blocked script or executable run. Verify the
download and use the normal policy/admin process for an execution restriction.
Use a destination writable by your ordinary account instead of elevating the
application to solve an output-permission failure.

## Inputs and executable dependencies

Dependency lookup and capability checks are documented in the [README](../README.md)
and [troubleshooting guide](SUPPORT.md). Explicit paths or sibling executables
are deliberate trust choices: capability checks do not authenticate a binary.
Use a trusted application directory and PATH, and check the resolved executable
paths before processing sensitive media.

Only local filesystem media through FFmpeg's `file` protocol and the selected
container allowlist is accepted. URLs, playlists, concat lists, device inputs,
UNC/device paths and arbitrary FFmpeg options/filter text are not accepted.
Typed settings and manifests are data rather than executable configuration.
Folder queues skip reparse entries and do not traverse their targets.

These restrictions reduce unintended input behavior; they are not a sandbox
for PowerShell, native binaries or hostile media. FFmpeg runs with your user
account's permissions. Native diagnostic capture is in memory and very large
inputs/diagnostic streams have not been stress-tested. Keep independently
supplied dependencies maintained through a source you trust.

## Originals, output and local records

The source is held read-only through processing/reporting. Rendering uses a
run-owned temporary file, validates it and publishes it without overwriting
existing files. Normal failure cleanup removes only the run's owned partial;
later runs do not sweep crash leftovers. No guarantee of crash recovery,
power-loss durability or a multi-file atomic commit is made. Preserve your
own backups and inspect incomplete artifacts after a stopped job.

New audio exports omit source metadata/chapters, but the sound itself can
identify people or contain confidential information. Detailed reports,
summaries, journals and saved preferences can retain paths, filenames, stream
labels, selected settings and diagnostic text. They remain local and inherit
the destination's existing permissions; the application does not encrypt them
or establish a private storage policy for you.

Use the explicit ordinary-report diagnostic export described in
[SUPPORT.md](SUPPORT.md) to produce a separate minimized JSON copy. It omits
free-form source text and retains an allowlist of typed values/fixed labels;
review it before sharing. Preview reports and batch/folder journals have
separate schemas and are not accepted by that exporter. Redact those details
manually if needed. No sharing action requires uploading private audio or an
unredacted report.

If describing a security concern, provide the affected application/dependency
versions, the operation and a minimal synthetic reproduction where possible.
Avoid putting private recordings, raw reports, personal paths, credentials or
unreviewed native diagnostics into a public issue or repository. These docs
do not promise a particular response time or supported-build lifetime.
