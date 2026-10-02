# Primary references

Checked during bundle preparation on 2026-10-02. Implementers should recheck installed-version behavior and any changed guidance rather than blindly pin a remembered “latest” version.

Technical definitions are cited by source ID in the contracts; most requirements here are proposed engineering decisions, not claims that the source already implements them.

## S01 — FFmpeg filter reference

https://ffmpeg.org/ffmpeg-filters.html

loudnorm, dynaudnorm, afftdn and agate definitions; verify installed-build support locally.

## S02 — Microsoft Start-Process reference

https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process

ArgumentList joining/quoting and process behavior; PS5.1 compatibility must be tested.

## S03 — FFprobe reference

https://ffmpeg.org/ffprobe.html

Machine-readable stream/format inspection.

## S04 — Pester quick start

https://pester.dev/docs/quick-start

PowerShell development testing.

## S05 — PSScriptAnalyzer overview

https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview

Static analysis for PowerShell scripts.

## S06 — Git push documentation

https://git-scm.com/docs/git-push

Explicit refspecs and checking push failures.

## S07 — Git ls-remote documentation

https://git-scm.com/docs/git-ls-remote

Read exact live refs; --exit-code for no matching ref.

## S08 — OpenAI Codex AGENTS.md guide

https://developers.openai.com/codex/guides/agents-md/

Repository instructions and layered guidance; official entry redirected to learn.chatgpt.com when checked.

## S09 — FFmpeg formats documentation

https://ffmpeg.org/ffmpeg-formats.html

WAV/RF64 behavior and output-container options.

## S10 — FFmpeg legal guidance

https://ffmpeg.org/legal.html

Selected-build license review; not replaced by the script MIT license.

## S11 — GitHub secure Actions reference

https://docs.github.com/en/actions/reference/security/secure-use

Least privilege, trusted actions and PR workflow boundaries.

## Repository evidence

https://github.com/PikkuJanne/WinAudioClean/tree/7dfe43361395908a277d7b513b1c9a4fd3cd192a

https://api.github.com/repos/PikkuJanne/WinAudioClean/git/trees/7dfe43361395908a277d7b513b1c9a4fd3cd192a?recursive=1

Pinned file URLs and Git blob identities are listed in BASELINE.json. No unpublished Windows test result is implied.
