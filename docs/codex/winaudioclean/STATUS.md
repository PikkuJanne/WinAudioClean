# Current status

Date: 2026-10-02. **WAC-M2-01 is complete.** M0, M1 and the first M2 task are
done. AC-001 through AC-036 pass. Twelve tasks are done; 18 remain todo.

**Next: WAC-M2-02 — Add measured loudness without changing the default fast path.**
Start separately after fresh synchronization verification.

## Original preset and accurate claims

Both existing Raw/Zoom choices select Original, stable ID `original`, preset
version `1.0.0`. Their exact baseline filters/order remain intact. Local
JSON/text/summary reports record that identity separately from application
version `2.3` and schema `1`. Redacted exports still omit version/identity text.
README, working Get-Help and menu wording now use accurate parameter meanings;
-12 LUFS/-1.5 dBTP remain chosen targets with NOT_MEASURED compliance.
No optional Accurate pipeline, new cleaning preset or saved setting exists yet.

- Each supported shell passed **552 Pester tests and 61 Python tests** in one
  Full gate, with one Python symlink-privilege skip and no failed tests.
- Final focused preset checks pass **9/9 per shell**; help rendering is checked
  in both shells. Real unmodified PTY menus exercised Raw/PS5.1 and Zoom/PS7,
  with published audio and persisted identity. No Explorer render is claimed.
- **20/20 real application comparisons and 10/10 baseline references pass**:
  exact decoded PCM bytes at zero lag on the same FFmpeg build/settings.
  Includes mono/stereo, short, silence and PCM16/24. Harness timeout cleanup
  separately terminates an owned parent/child and preserves a sentinel.
- The initial PS5.1 targeted environment failure is retained with its fix.
  Full had 117 analyzer advisories; a test-only variable rename reduces the
  final focused count to 116. No suppression or application change was needed.

[Evidence, exact commands and limits](evidence/WAC-M2-01.md),
[source/evidence manifest](evidence/WAC-M2-01-source.json), and
[claims/runtime review](evidence/WAC-M2-01-claims-review.md).
All earlier evidence, including M1-02 policy/resumption records, stays intact.

## Preserved contracts and limits

M1 validation, selected-track processing, owned partials, held-object no-replace
publication, complete PCM verification and reporting failure semantics remain.
48 kHz PCM16 is default; PCM24, explicit mono and RF64 remain optional. IO,
launcher and existing tests/harnesses are unchanged. Filters are unchanged;
legacy Raw delay (~25 ms) remains. Encoder settings are separate from preset
identity and do not imply identical output across builds/formats.

Speech listening, independent final loudness, full >4 GB rendering, real disk
exhaustion, long-file/memory stress and running-render Ctrl+C remain unverified.
Native capture remains in memory; available capacity is not reserved; reports
have no multi-file atomicity or power-loss guarantee. Early failures stay
console-only. No default-sound change or quality certification is approved.

## Checkout and delivery

Use WinAudioClean-governance on `codex/wac-m2-audio`; preserve the original
source-only folder. Exact effective fetch/push origin:
`https://github.com/PikkuJanne/WinAudioClean.git`.
M2 is stacked on `codex/wac-m1-reliability` while draft PR #2 is unmerged;
PR #2 is stacked on `codex/wac-m0-handoff`, with draft PR #1 unmerged.
The M2 draft URL, completion SHA and clean local/live/PR verification are
recorded in the PR/final response after push. No CI workflow/checks exist.
No merge, release, repository-setting change or website deployment occurred.
