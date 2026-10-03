# Package and external dependency notices

WinAudioClean's included scripts, launcher, icon and documentation are supplied
with the repository's MIT [LICENSE](LICENSE), including its unchanged
copyright and permission notice. Keep that notice with copies of the tool.

This tool-only package contains no FFmpeg/ffprobe, PowerShell, Python, test
modules or other third-party binaries. Windows/.NET and a supported PowerShell
host are supplied by the user's system. Git, Python and test modules are
development tools, not application dependencies.

FFmpeg and ffprobe are user-supplied local dependencies. The application does
not download or redistribute them. Consult the notices, licensing information
and source for the exact build you obtain; build options can affect its
obligations. [FFmpeg's official licensing page](https://ffmpeg.org/legal.html)
describes that distinction. This package does not label every external build
as having the same license.

Bundling FFmpeg remains unapproved. It requires a separate decision for the
exact binaries, license/build configuration, corresponding source and required
notices before any redistribution. This task creates local tool-only archives
and does not publish, tag or release them.
