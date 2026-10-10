# Website-only material cleanup — 10 October 2026

The owner requested this cleanup in the final v2 multi-tool website handoff.
The prior engineering task graph/acceptance records remain historical evidence.
The inspected public main anchor is `75fed6188f5c5dde13029ebc9426fc210d44d52f`. Work uses an isolated clone and
focused branch; no existing user tool checkout is changed.

The former `website/README.md` explicitly described a portable presentation
package to copy into the future multi-tool website, with no runtime consumer.
The final website uses WordPress and supplied project artwork instead. Each
obsolete path was individually allowlisted: `website/LICENSE`, `website/README.md`,
`website/WinAudioClean_icon.png`, `website/app.js`, `website/assets.json`,
`website/index.html`, `website/release.json`, `website/release.schema.json`,
`website/styles.css`, `scripts/Test-Website.py`, and its dedicated
`docs/codex/winaudioclean/tests/test_website.py` regression suite.

Only direct stale current references were updated in README, DATA_FORMATS,
RECONSTRUCTION and the COVERAGE command witness. All 90 acceptance IDs and their
dated reports remain. The retired website command is explicitly historical;
package reconstruction now uses the maintained independent tool-only inspector.

The root `WinAudioClean.ico` and `WinAudioClean_icon.png` remain application/shared
branding. The owner explicitly confirmed retaining `WinAudioClean_poster.png`
during this cleanup on 10 October 2026. It remains in the tool repository and
is not a source for the separate website. That disposition is resolved.

Local checks: coverage/plan validators pass; package inspector 8/8 and version
identity 5/5 pass. Full Python governance ran 147 tests successfully (one explicit skip). GitHub Windows workflow
are checked separately at their observed revision; pending is not passed.

Runtime scripts, launchers, runtime artwork, release builders and existing
release/tag/history identities are preserved. Normal removal affects the current
tree only; no historical-erasure or release replacement is claimed. Repository
artwork is not a source or visual reference for the new website.

PR/check/merged-main identities are recorded in the external website audit after
actual GitHub observations. This record cannot claim its own future commit SHA.
