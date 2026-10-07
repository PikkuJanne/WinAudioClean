# WAC-M5-04 — First public v1.0.0 release

Owner date: 2026-10-07. Publication preparation is in progress.

The owner requested: “The project is ready, please update everything to reflect
that v1.0.0 is in fact pubished.” A live check found no tag or release, so scope
was clarified. The owner answered **“Publish v1.0.0 here”** for
`PikkuJanne/WinAudioClean`. This authorizes first public `v1.0.0` publication and
its required version, integration and metadata work. Website hosting remains
deferred to the separate future multi-tool project.

Starting main is `944aaa1c57ae192237f0fee057dd672db4be22d9`, tree
`c30db586d2c170b089e69a1ab2c4c287a4290167`. All seven prior PRs are integrated.
Its CI run `37201715232` failed on attempt 1 in one PS5.1 media-test marker case;
unchanged-source attempt 2 passed all four jobs. The possible startup/marker race
remains unconfirmed. Preserve the earlier failure and
[delivery checkpoint](https://github.com/PikkuJanne/WinAudioClean/pull/7#issuecomment-5980181550).

Public application numbering starts at `1.0.0`. Previous internal `2.3` source,
reports and candidate hashes stay historical. Original preset `1.0.0`, Gentle
`0.1.0`, configuration/report schema `1`, filters/defaults and runtime/BAT entry
routes stay unchanged. Legacy `2.3` replay remains supported explicitly.

Release assets must be newly built from the final clean merged source, twice per
PowerShell host, inspected against exact committed bytes, then downloaded and
hashed after actual GitHub publication. No earlier candidate is relabeled.
Actual test/build/source/tag/asset/publication identities will be recorded in
[the supplemental ledger](WAC-M5-04-v1.0.0.json) as observed.

The 30-task/90-case prior engineering and merge acceptance remains historical.
The eight broader coverage gaps remain unrun/unwaived; privilege skips, absent
listening/media consent and platform limits remain explicit. No website hosting,
default-sound promotion, settings/security change, dependency bundling, branch
deletion, direct main push or history rewriting is included.

Preparation checks passed: targeted Preset/Preview/Release Pester **184 passed,
0 skipped** per actual PS5.1/PS7 host; Python version/replay **5**, package inspector
**8**, website **21** passed. Actual metadata remains draft `1.0.0` with download
disabled. Plan validates 30 tasks/90 cases/20 groups. The PS5.1 ignored collector
initially rejected three identical CLIXML summaries despite actual exit 0; retain
that receipt and the create-only corrected parse from the same raw log, without
rerunning or disguising a product failure. Required Full gates and actual release
publication remain pending at this preparation commit.
