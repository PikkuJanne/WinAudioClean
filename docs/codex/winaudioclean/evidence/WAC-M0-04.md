# WAC-M0-04 — baseline gate and continuation checkpoint

Date: 2026-10-02. **M0 baseline gate passed: AC-010 through AC-012.**
Next: **WAC-M1-01 in a fresh thread** after verified remote delivery.
Listening remains pending. This gate establishes a recoverable baseline for
reliability work; it does not certify the application for release.

## Checkout and scope

Starting revision: `e1bd07b96dc23ab7d84ac0f236ca599a866c73a3` on
`codex/wac-m0-handoff`. The established Git checkout was clean. Origin inspection,
fetch and live sync succeeded; local HEAD, upstream, live remote and open draft
PR #1 matched. Effective fetch/push target, one of each:
`https://github.com/PikkuJanne/WinAudioClean.git`.

The supplied source-only folder has no Git metadata and was preserved. The
restart guide now supplies a sibling-checkout discovery hint as well as origin
verification, so future threads need not recover the location from chat history.

Changes are limited to DECISIONS.md, STATUS.md, NEXT_MODEL_START_HERE.md,
TASKS.yaml, ACCEPTANCE.json and this task's evidence. D19 records existing
implementation authority, pending human choices and the task boundaries.
No application, launcher, development tool, test, baseline filter, README claim
or output-encoding behavior changed in this task.

`WAC-M0-04-source.json` lists SHA256 identities for all 18 tested runtime and
development source files, unchanged from the starting revision. The historical
baseline revision remains `7dfe43361395908a277d7b513b1c9a4fd3cd192a`.

## AC-010 — evidence reconciled once

| Evidence | Reconciliation result |
| --- | --- |
| M0-01 governance installation and checkpoint | Historical records retained. All seven BASELINE blob IDs and lengths match the original reviewed commit. Its unrun Windows/audio statements describe bundle preparation. |
| M0-02 helper extraction, runner and mutation records | Retained. Current M0-03 source matches; the two older source-record differences are the documented M0-03 test README/helper-test edits. Known invalid-mode, collision, overwrite and exit-status behavior remains scheduled M1 work. |
| M0-03 source record | All 12 hashes match current bytes. Both exact filter comparisons pass again in Quick and Full. |
| M0-03 two complete reports | Both have SHA256 `a187eee1935ab3448eae4a9c8fce78fa050646ba0959a401fb6edd900509e153` and identical bytes. Each records five inputs, 20 outputs and 87 successful native commands. |
| Retained local synthetic assets and tools | All 50 input/output files across both runs and both portable executable hashes match the reports. No audio was rendered again. |
| Format/filter records | All 20 chains per report match BASELINE. Legacy outputs are 192 kHz PCM16, explicit comparisons 48 kHz PCM16; reported channels/durations match inputs. |
| Prior task/acceptance references | All 9 task and 26 acceptance evidence references for M0-01/02/03 exist. |
| Listening/privacy | Checklist explicitly pending; no admitted speech or review. Ignore checks cover private clips and generated audio. No tracked files exist under `.wac-local` or `artifacts/local`. |

Results are in `WAC-M0-04-reconciliation.json`. An independent read-only review
repeated the source/report/asset checks and found no characterization blocker.
Historical BASELINE/AUDIT/Linux evidence was not rewritten as Windows evidence.

The reconciliation command was `python -X utf8 .wac-local/WAC-M0-04-reconcile.py`
(exit 0), a one-off local evidence check rather than a new project tool.
To reproduce its core identity checks in Python from the repository root:

```python
from pathlib import Path
import hashlib, json, subprocess
root = Path.cwd()
plan = root / 'docs/codex/winaudioclean'
ev = plan / 'evidence'
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
for name in ('WAC-M0-03-source.json', 'WAC-M0-04-source.json'):
    for item in read(ev / name)['files']:
        assert sha(root / item['path']) == item['sha256'], item['path']
baseline = read(plan / 'BASELINE.json')
for item in baseline['files']:
    ref = baseline['reviewed_commit'] + ':' + item['path']
    assert subprocess.check_output(['git', 'rev-parse', ref]).decode().strip() == item['git_blob_sha1']
    assert len(subprocess.check_output(['git', 'show', ref])) == item['bytes']
for number, item in enumerate(read(ev / 'WAC-M0-03-comparison.json')['reports'], 1):
    saved = ev / item['file']
    assert sha(saved) == item['sha256']
    report = read(saved)
    local = root / '.wac-local/WAC-M0-03' / f'run-{number}'
    assert saved.read_bytes() == (local / 'characterization.json').read_bytes()
    for asset in [f['input'] for f in report['fixtures']] + [r['output'] for r in report['runs']]:
        assert sha(local / asset['file']) == asset['sha256']
    for run in report['runs']:
        expected = baseline['filters']['level']
        if run['mode'] == 'raw':
            expected = baseline['filters']['raw_clean'] + ',' + expected
        assert run['filter_chain'] == expected
bin_dir = root / '.wac-local/ffmpeg-setup/portable-curl/ffmpeg-9.0.2-essentials_build/bin'
for name in ('ffmpeg', 'ffprobe'):
    tool = report['environment'][name]
    assert sha(bin_dir / tool['binary']) == tool['sha256']
```

The local-asset portion needs the retained ignored files. A clean checkout can
regenerate them with tests/README.md's characterizer commands and new directory
names; unavailable local assets are not evidence of successful reproduction.

## Active environment and tests actually run

Windows NT 10.0.26300.0, AMD64; PowerShell 7.6.5;
Windows PowerShell 5.1.26100.9444; Python 3.14.6; Git 2.56.0.windows.1;
GitHub CLI 2.97.0; Pester 5.7.1; PSScriptAnalyzer 1.24.0.
Versions were queried locally or printed by the runners. Existing portable
FFmpeg/ffprobe 9.0.2 essentials identities match M0-03; neither is on PATH.
The full tool build/configuration remains in the M0-03 reports.

From the repository root, smallest checks preceded the cumulative gate:

```powershell
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

All exited **0**. Quick and Full ran with M0-04 `in_progress`; final metadata was
validated separately after marking it done. Full ran once per shell; both use
independent temporary fixtures. Process-only Bypass changed no persistent policy.
No dependency installation or download was needed.

| Gate | Actual result | Sanitized log |
| --- | --- | --- |
| Quick, PS7 | 13 Pester passed; 16 outside Quick scope | `WAC-M0-04-quick.txt` |
| Full, PS7 | 29 Pester passed; 61 Python passed, 1 skipped | `WAC-M0-04-full-ps7.txt` |
| Full, PS5.1 | 29 Pester passed; 61 Python passed, 1 skipped | `WAC-M0-04-full-ps51.txt` |

The Python suite reports 62 total, including the skip for unavailable Windows
symlink privileges. There are no Pester skips or failures. Parser checks covered
11 PowerShell files; static/plan gates passed. The same 49 analyzer advisories
remain visible, including legacy UI and shared Pester setup variables. No
suppression, tolerance change or product fix was needed.

Full reran real `.ps1`/`.bat` boundaries under controlled missing-input preflight
and separate runtime tests with native/filesystem doubles. The `.bat` starts
Windows PowerShell even when its outer shell is PS7. These checks do not process
real audio through the launcher. M0-03's successful audio matrix invokes FFmpeg
directly, and has a different scope.

## AC-011 — final plan consistency

After updating task/acceptance state, `validate-plan` and `next` above exited 0.
`WAC-M0-04-plan.txt` records 30 tasks, 90 cases and 20 improvement groups, with
only WAC-M1-01 ready and no blocked task or approval needed for that next task.
Four tasks are done and 26 remain todo. AC-001–012 pass; AC-013–090 stay not_run.
Existing IDs, dependencies, previous evidence and approval requirements remain.

## AC-012 — restart and continuation

This fresh task read the M0-03 restart record and Git state before changing the
project. They identified M0-04 and its unverified checks. The checkout discovery
gap is now explicit in NEXT_MODEL_START_HERE.md. An independent reviewer with
no prior chat context checked the final restart guide against Git and the plan;
`WAC-M0-04-restart.md` records that review and its limits.

The final handoff selects WAC-M1-01 and its AC-013–015 scope. It gives exact
local commands, tooling paths, the expected M0 branch/origin and a live sync
check before creating `codex/wac-m1-reliability`. If PR #1 is still unmerged,
the M1 draft PR should be stacked on `codex/wac-m0-handoff`; inspect actual
history first if an approved merge has occurred. No M1 code was started here.

## Pending checks and decisions

- No permission-cleared speech listening or voice-quality evaluation occurred.
  The existing listening checklist remains ready; no default-sound change is
  approved. Missing speech does not block the next reliability task.
- Full filename/CMD forwarding, native stream flooding/timeouts/cancellation,
  corrupt/multistream media, collisions, disk-full handling and transactional
  exports require their scheduled M1 and later tests.
- Real audio through the application/launcher, impulse alignment, channel
  isolation, long recordings and >4 GB output remain unverified.
- Explicit 48 kHz output remains a comparison, with implementation scheduled
  for M1-05. The proposed audio tolerances and exit-code map are not claims of
  current product behavior. Finalize engineering details in their owning tasks.
- CI is scheduled for M4-02; current local tests do not imply CI passed.
  Human publication and third-party-bundling choices remain in D19/APPROVALS.

## Delivery

The staged review covered 13 intended text files: five governance records and
eight evidence files. No audio, binaries, archives, personal paths, credentials
or unrelated changes are staged. `git diff --cached --check` passed with the
repository's CRLF handling, and `git diff --exit-code` confirmed no unstaged
changes. All 18 tested source hashes still match; only the intended task and
three acceptance records changed. This final evidence paragraph was then
restaged and checked.

Commit with the task ID, push the explicit feature branch and run live
sync-check. Update the existing draft PR with the exact completion SHA and
current CI state. The post-push SHA belongs in that PR/final response rather
than a self-referential evidence commit.

After verified delivery, the exact next task is **WAC-M1-01**, separately.
