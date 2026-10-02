# Current status

Programme created: 2026-10-02. Reviewed remote baseline:
`7dfe43361395908a277d7b513b1c9a4fd3cd192a`.

Completed: **WAC-M0-01 through WAC-M0-03**. AC-001 through AC-009 pass with evidence.
The remaining 27 tasks are todo; AC-010 through AC-090 remain not_run.
Next: **WAC-M0-04 in a fresh thread**, baseline gate and continuation checkpoint.

## Latest changes

The development characterizer now reuses all five deterministic synthetic
fixtures and records 20 Raw/Zoom output variants per run, including binary/build
identity, argument arrays, exit codes, fixture/output hashes, probe data and
independent final-file sample/loudness metrics. Reports from two Windows runs
are byte-identical. AC-007 adds exact BASELINE comparisons for both built chains.
The private-listening checklist is ready; speech listening remains **pending**.

The application, launcher, baseline filters and fixture generator are unchanged
from WAC-M0-02. The explicit 48 kHz PCM16 files are comparison exports only.
Actual legacy exports were 192 kHz PCM16 for every fixture/mode. Both variants
preserved channel counts and reported duration. Silence and very short input
have undefined integrated loudness, recorded as null with a reason.

The source-only starting folder is preserved. Use the established separate Git
checkout after verifying it. Branch: `codex/wac-m0-handoff`.
Origin fetch/push: `https://github.com/PikkuJanne/WinAudioClean.git`.

## Actual validation

Windows NT 10.0.26300.0; PowerShell 7.6.5; Windows PowerShell 5.1.26100.9444;
Python 3.14.6; Pester 5.7.1; PSScriptAnalyzer 1.24.0.
Portable FFmpeg/ffprobe 9.0.2-essentials_build-www.gyan.dev, verified against the
provider archive checksum; retained only in ignored `.wac-local/ffmpeg-setup/`.
No global install or PATH change. Tests/runners install no dependencies.

- Targeted helpers: 13 Pester passed.
- Characterizer unit tests: 8 passed.
- Two complete characterization runs: 20 renders each; all reported file hashes,
  formats, metrics and commands match. Full report hash:
  `a187eee1935ab3448eae4a9c8fce78fa050646ba0959a401fb6edd900509e153`.
- Full: 29 Pester passed in each shell. Each run also passed 61 Python tests,
  skipping one for unavailable Windows symlink privileges.
- Parser/static/plan gates passed. 49 analyzer advisories remain visible; the
  new one is a Pester setup variable consumed across scopes. No rule suppressed.

Evidence: `evidence/WAC-M0-03.md`, source hashes, both complete reports,
comparison record, download provenance, sanitized test logs and listening record.

## Delivery and remaining limits

Previous synchronized checkpoint: `7291ce86535e9c689befbdb60563ed9eb4b1b2a6`.
At session start, clean local tree, upstream, live GitHub branch and
[open draft PR #1](https://github.com/PikkuJanne/WinAudioClean/pull/1) matched;
fetch succeeded. This M0-03 completion update is committed/pushed and freshly
verified before handoff. Its exact SHA is recorded in the PR/final response.
Derive live synchronization again in the next session.

No WAC-M0-03 engineering blocker remains. Real FFmpeg synthetic processing is
now evidenced; the matrix does not test the application/launcher. Full includes
existing controlled entry-point checks. Real speech listening, alignment,
channel isolation, long recordings and >4 GB exports remain unrun. Default-sound
promotion remains unapproved. Input/overwrite/process-status fixes belong to M1.
No CI exists yet; local tests are the evidence.

Feature pushes can use the existing command-scoped GitHub CLI credential helper
if the default helper stalls. Done records engineering acceptance; live sync is
required before advancing. Merge/release/deployment approvals remain separate.
