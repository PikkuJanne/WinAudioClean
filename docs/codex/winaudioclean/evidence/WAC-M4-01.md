# WAC-M4-01 — regression and fault-injection coverage

2026-10-03. **WAC-M4-01 is complete.** Work began from freshly verified clean
local/upstream/live `codex/wac-m3-settings` checkpoint `c2ad4de8fd1258a474ad0ba424bc8f6ee53a2ed3`.
This task uses `codex/wac-m4-regression`, stacked on that preceding milestone.
The source-only original remains untouched. Canonical: **23 done / 7 todo /
0 blocked; 69 AC pass / 21 not run. Next: WAC-M4-02 only.**

## Acceptance established

- **AC-067:** [COVERAGE.json](../COVERAGE.json) maps AC-001..069 to 35 concrete
  command scopes, existing reports and eight named reviews. Eight mandatory
  broader-scope gaps remain explicit. The read-only validator runs in Quick,
  Targeted and Full; its 13 negative/read-only unit cases join Full. Inventory
  command syntax was checked on both hosts, and seven media/two handoff CLI
  flag sets were checked against help. Inventory is available coverage, not a
  claim that every listed command or human review ran during M4.
- **AC-068:** [fault ledger](WAC-M4-01-faultchecks.json) records three unmutated
  baseline passes and three intended mutant failures on each host, with exact
  assertions, source/copy/test/tool hashes and application-free scratch scope.
  Mutations replace CreateNew with truncating Create on partial allocation,
  erase the real native exit 7, and change encoder argv from 48000 to 44100.
  The wrong-rate check is an argv contract test, not an FFmpeg render. Five
  cleanup-safety cases pass per host, including outside sentinel preservation,
  pre-delete junction refusal, pinned ancestors and no recursive path fallback.
- **AC-069:** [gates](WAC-M4-01-gates.json) certify the existing reusable runner:
  Quick, seven selected Targeted suites, then one Full gate per host on the
  final unchanged code/coverage tree. [source ledger](WAC-M4-01-source.json)
  records 74 physical code/map files, LF content comparisons, source-map
  digest, host/tool hashes and the parent checkpoint separately from tested
  uncommitted content. Full was not repeated to collect another green capture.

## Actual Windows gate results

Windows 11 build 26300 on this active machine only. PS5.1 `5.1.26100.9444` and
PS7 `7.6.5`; pinned Pester `5.7.1`, PSScriptAnalyzer `1.24.0`.

| Gate | PS5.1 | PS7 |
| --- | --- | --- |
| Quick | 1070 pass / 0 fail / 1 skip / 386 outside scope | 1070 pass / 0 fail / 1 skip / 386 outside scope |
| Targeted | 290 pass / 0 fail / 0 skip | 290 pass / 0 fail / 0 skip |
| Full Pester | 1456 pass / 0 fail / 1 skip | 1456 pass / 0 fail / 1 skip |
| Full Python discovery | 75 discovered, successful; one privilege skip | 75 discovered, successful; one privilege skip |

Each accepted command exits 0; parser, static safety gate, plan and coverage
validation pass. Non-gating analyzer advisories remain visible in the ledger.
The file-symlink privilege skips remain unperformed cases; junction/identity
coverage does not convert them into passes. Full does not run the standalone
real-FFmpeg/media matrices. Their historical recorded scopes remain unchanged.

## Narrow production fix and regression proof

Only Preview reporting changed: close each writer independently, issue
nonterminating release advisories, retain a primary write/open error and preserve
already durably flushed terminal outcomes. No other runtime/BAT LF content,
filter, Original/Fast default, encoding, preference or cancellation contract
changed. A real FileStream subclass preserves native ownership/write/delete
checks, releases its actual handle, then throws a deterministic disposal error.
Nine focused cases pass per host; the frozen inherited loop fails the same nine
corrected cases per host. SUCCESS/0, FAILED/4 and CANCELLED/130 remain consistent
across returned and persisted results; foreign input/partial/report bytes survive.
[Focused proof and corrections](WAC-M4-01-preview-close.md).

The existing partial-collision test now registers an unexpectedly returned
transaction before its assertion fails, allowing normal teardown to release
mutant handles. This is test-fixture cleanup, not weakened product expectations.
An independent read-only review found no actionable code/cleanup defect; it did
not rerun completed suites.

## Preserved failures and limits

The first PS5.1 Quick stopped before tests because Python inherited PS7's module
path; child-only environment reconstruction fixes the capture. Only that failed
Quick host was repeated. Its exact failed log/hash remains in the gate ledger.
Fault-ledger history preserves the initial correctly detected overwrite's fixture
handle leak, a discarded native-rename candidate that survived, and the corrected
run before final tool-hash enrichment. Preview history preserves the initial
untyped-stream fixture and evidence-publisher corrections. Final accepted source
guards and all referenced final hashes are checked; failures were not removed or
silently promoted. No production change followed publication-only corrections. A pre-write evidence
guard initially compared normalized worktree content with raw CRLF parent blobs;
both sides now normalize for content while raw hashes remain recorded. No
canonical/evidence writes occurred before that guard aborted. Final whitespace
review removed terminal blank lines from two Python files and the coverage JSON;
Python AST/JSON values are unchanged. The source ledger keeps actual tested hashes
and final formatting hashes separately; no Full rerun was needed for whitespace.

Formal speech listening/default-sound promotion, the larger Explorer punctuation
matrix, picker/open-folder gestures, broad storage/memory/>4 GB/UNC stress,
host crash/console close/power loss, privileged file-symlink creation, broader
meter/seek/cross-build reproduction and actual unreleased OS writer recovery
remain explicit required gates before those broader claims. This task's close
double releases the OS handle before throwing. Default saved settings remain
absent; no private audio/reports, personal paths or credentials are published.

Only M4-01/AC-067..069 advance. No CI workflow, package, merge, release,
repository security/settings change, default-sound promotion or deployment is
performed. WAC-M4-02 is the next unlocked task after live synchronization.
