# Release and website boundary

## Runtime package

Build a portable tool-only ZIP from a clean explicit revision. Include the existing .ps1/.bat, required small helper files when introduced, icons, user documentation and MIT license. Exclude tests, developer handoff tools, private audio, generated logs, .git, local settings and development-only assets. An icon/poster already in the repo is not a reason to require a new branding system.

Do not ship or auto-download FFmpeg/ffprobe until the selected-build provenance, architecture, checksum and applicable license/source/notice requirements have been reviewed [S10]. Tool-only instructions should show sibling/PATH/explicit dependency resolution with official provenance, optional downloads by consent and no requirement for administrator privileges. Checksum publication is an integrity aid, not an antivirus guarantee or a digital-signature substitute.

Use one source for the application version, release filenames, changelog and website metadata. Pin development/build inputs. Reproducibility claims must be demonstrated: a repeatable file set does not automatically mean byte-identical ZIP timestamps or executable builds. Define the exact level actually achieved.

## GitHub

Use draft milestone PRs during development. Configure CI in the branch with least privilege and pinned verified action SHAs [S11], but do not change repository settings or default branch automatically. Produce local candidate artifacts without publishing. Owner approval is required for merge, tag, release and each deployment action. Recheck exact artifact/source identity after merge; a new merge commit can change contents and require rebuilding.

## Website

Prepare static product content and validated release metadata. No account system, upload form, hosted processing, online audio cleaner, background service or browser-based DAW. Do not couple this repository to another tools repo/site without inspecting and receiving scope for that repo. A self-contained static draft/content package is sufficient here; deployment remains a separate approved step.

Content should describe local processing, supported inputs/outputs, tested requirements, the two default modes, optional features, limitations, release notes, source/license, installation and support. Use real screenshots of the tested application. Before/after audio requires rights/consent and useful level-matched examples; leave explicitly pending when unavailable rather than synthesize a fake testimonial or screenshot.

A draft metadata record must not have a working-looking invented stable release link/checksum. Only populate published data from the actual approved release. The local application must still work when the website/GitHub is offline after dependencies are installed. No app auto-updater is requested.

## Approval record

Use APPROVALS.md. Record action, exact commit/artifact hash, target, owner approval reference/date and result. “Build a Codex bundle” is not release or deployment consent. Publishing is not necessary to complete the engineering handoff at WAC-M5-03.
