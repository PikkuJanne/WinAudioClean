# WAC-M5-01 — Accepted static website draft and release metadata

AC-079..081 pass on 2026-10-04 within the recorded local/browser/fixture scopes.
The implemented isolated page and its draft metadata never enable a committed
stable download. Existing branding and MIT bytes are preserved; application
screenshots and permission-cleared audio remain explicitly pending. Runtime,
launcher, defaults, package allowlist and CI workflow are unchanged.

Both actual clean-source local Full gates passed at `11fe377c5fd05624dcc280d89fd119741c6fde9e`:
ps51: Pester 1483 passed/1 skipped, Python 162 ran/1 skipped; ps7: Pester 1483 passed/1 skipped, Python 162 ran/1 skipped. Versions: Windows build 26300, PS5.1.26100.9444 / 7.6.5,
Python 3.14.6, Pester 5.7.1, PSScriptAnalyzer 1.24.0. All exit 0, zero outside
scope, seven source-group digests match between gates and remain unchanged.
Static analysis passed with these non-gating finding counts: ps51: 285; ps7: 285.
The two suites each retain one local symbolic-link privilege skip per host;
exact names and reasons are recorded in the validation ledger.
The separate website content digest is
`6fe2adfe1b02b148d89bdd07068282b7e762e93d23f8a4a8d31f19e2059c941a` on both gates. CI wrapper
hashes omit website; the supplemental website scope is explicitly separate.

Focused metadata Python 20/20 (zero skips), actual browser 15/15, independent
Node VM 17/17, strict actual package/manifest/sidecars and seven negative metadata
fixtures pass. Keyboard focus/links, desktop/mobile widths and selected contrast
ratios are recorded separately. No real samples/consent, comprehensive
accessibility audit, listening, new candidate build or packet capture is claimed.
The accepted package source/hash and exact physical text/license hash scopes
remain in the [validation ledger](WAC-M5-01-validation.json).

Actual tested-source CI state is **passed** ([observed run](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37187177111)). Final metadata-closure
CI will be observed separately after its push. Metadata checks are recorded below;
explicit staging and scope/privacy review complete the local checkpoint.
All eight broader gaps and both local privilege skip categories remain. Canonical
totals are 27 done / 3 todo and 81 pass / 9 not_run. Next only **WAC-M5-02**.

Implementation SHA was live-synchronized on the feature branch before these
gates, with draft PR #6 stacked on the M4 branch. Final closure SHA/live equality
and PR/CI status will be recorded outside that commit to avoid self-reference.
No release/deployment/merge/main push/tag/settings/bundling/sound promotion.

Final metadata closure checks passed: plan validation (30 tasks / 90 acceptance cases), coverage traceability (81 mapped cases / 43 commands / 10 reviews / 8 retained gaps), next-task selection (only WAC-M5-02 ready; zero blocked), 13 coverage regressions and the one canonical-plan test. Every command exited 0 with no skips in these metadata checks. Exact commands and results are in the validation ledger. The tested website and application source remain unchanged.

## Historical focused implementation checks (superseded by accepted scopes)

# WAC-M5-01 — Static website draft and release metadata

Implementation and validation are in progress on 2026-10-04. Engineering
acceptance AC-079..081 remains not_run until the actual static, package,
browser and cumulative checks are recorded. No publication occurs.

Starting checkpoint `ea5d53d91ff2c035a50b9808fda18ceba38d3b61` was clean and
matched the live `codex/wac-m4-regression` branch on the exact fetch/push origin
`https://github.com/PikkuJanne/WinAudioClean.git`. All four actual parent PR
jobs succeeded in [run 37182880390](https://github.com/PikkuJanne/WinAudioClean/actions/runs/37182880390).
M5 work starts on `codex/wac-m5-release-readiness` from that checkpoint.

The isolated `website/` package presents the existing local tool. Release
metadata is draft; no published ZIP URL, checksum or release date is invented.
The existing repository icon and MIT notice may be reused; real screenshots
and permission-cleared audio samples remain unavailable. No sample is admitted
and no listening or sound-quality claim is inferred.

Required checks: version/schema and fail-closed download mutations; a temporary
published-like metadata fixture bound to an actual clean package and its
manifest/checksum/provenance; real browser keyboard/layout/request checks;
runtime/launcher/package allowlist preservation; one stable cumulative Full
gate on each supported local PowerShell host. Exact results and source hashes
will be recorded in the validation ledger after execution. All eight broader
coverage gaps remain.

## Completed focused checks before the clean cumulative gate

Python 3.14.6 executed `python -B -X utf8 -m unittest discover -s
docs/codex/winaudioclean/tests -p test_website.py -v`: 20 tests, zero failures
or skips, exit 0. `node --check website/app.js` exited 0. Plan validation
passed 30 tasks / 90 acceptance cases; structural coverage passed 81 mapped
cases / 43 commands / 10 reviews / eight retained gaps. These are structural
checks, not inferred acceptance passes.

`python -B -X utf8 scripts/Test-Website.py --repo . --fixture-package
dist/WAC-M4-04/final-ps51/WinAudioClean-2.3-1f10940ee970-tool-only.zip`
exited 0. Draft version 2.3 agrees with the main script and has no enabled
download. The actual earlier accepted 438904-byte package has SHA256
`d543ab046e9b1c5330552038f4eaa9eea794b2392ced079e620ed2f65cf04bf7`,
source `1f10940ee970ebe719c21ba0e7290830beeb7123` and tree
`c3ca091af76c72b57643f6dd5b7d64d84eeaaa83`. All 17 payload files, 18 ZIP
entries, committed bytes, manifest, checksum sidecar and provenance agree.
Seven independent wrong-field package mutations reject. This old-source
package comparison does not claim a new release candidate was built.

Actual local in-app browser checks pass all 15 served scratch fixtures: ordinary
draft, missing/malformed JSON, populated draft, one actual-package-bound
published-like fixture, wrong name, year zero, unknown schema, duplicate root
and nested keys, and five final-newline corruptions. Only the published-like
scratch route exposes its real local basename/hash; it is not a public release.
The committed page remains draft. An independent Node 24.19.0 VM check passes
17 additional renderer/parser vectors; VM results are separate from browser
observations.

Keyboard Tab/Enter activates Skip to main and reaches main focus. The first-run
guide, release anchor, source-repository link and support guide follow in order;
the disabled/hidden download is skipped. Desktop client width 1265 and mobile
client width 375 (390-pixel viewport with scrollbar) have equal document widths,
with no horizontal overflow. Actual screenshots show readable desktop/mobile
sections. Twelve selected CSS text palette pairs exceed 4.5:1 and three selected
focus pairs exceed 3:1; this is not a comprehensive accessibility certification.

Preview server requests observed from the browser are the document, local CSS,
JavaScript, icon and `release.json`. DOM/source inspection shows no remote asset
declarations, forms/file inputs/audio/iframes or additional request mechanism;
the ordinary draft has no console warnings/errors. The browser's read-only DOM
API did not expose performance-resource entries, so no packet-capture or full
network-instrumentation claim is made.

Independent runtime/BAT/icon/builder content comparisons pass against the parent.
An initial physical-byte-only comparison failed on existing CRLF checkout versus
LF Git blobs; retained corrected comparisons use normalized text and exact
binary bytes. Review also found duplicate-key and final-newline JS acceptance
differences, and fixture-output path traversal. The narrow fixes were verified
by corrupt browser/VM fixtures and a no-write traversal regression. Raw captures
and test fixtures stay local/ignored; source hashes bind final accepted scopes.

Runtime sound, PowerShell/BAT entry points and tool-only packaging remain
unchanged. Feature commits/pushes and draft-PR upkeep are authorized. Merge,
main push, tag/release, third-party bundling, repository setting changes,
deployment and default-sound promotion retain their existing boundaries.
