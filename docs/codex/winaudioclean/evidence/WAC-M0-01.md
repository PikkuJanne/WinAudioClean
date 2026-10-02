# WAC-M0-01 — governance installation evidence

Date: 2026-10-02. Scope: governance import and developer helper tests only.
Runtime implementation has not started.

## Reconciliation and source identity

- The supplied workspace was a source folder with no `.git`. It was preserved.
  A separate checkout of the existing repository was created for this task.
- No applicable ancestor or existing repository `AGENTS.md` was found before
  import. No existing governance, task history or PR needed merging.
- Exact effective origin fetch and push URL, one of each:
  `https://github.com/PikkuJanne/WinAudioClean.git`.
  `git config --show-origin --get-regexp` inspection found no URL rewrites or
  alternate push destination. Effective `core.autocrlf` is true (system config).
- Initial branch: `main`, clean. Reviewed and live main HEAD:
  `7dfe43361395908a277d7b513b1c9a4fd3cd192a`.
  `git fetch --prune origin` and the reviewed-to-origin/main diff returned 0;
  GitHub comparison was identical, zero ahead/behind. All-state PR listing was
  empty. A new `codex/wac-m0-handoff` branch was created from that HEAD.
- All seven supplied source files were compared with the checkout. Six were
  byte-identical; LICENSE differed only by Git checkout line endings, confirmed
  by `git diff --no-index --ignore-space-at-eol` (exit 0).
- Bundle ZIP SHA-256:
  `4347d4a897579ab351b161b936d4d6d923f50b7e008ffc20ba7a61ce1e96a990`.
  Manifest SHA-256:
  `c594ef91e01016d7301ac07dd465661ec9264ff8b8b10fea3cae6c06a0aa4937`.
  Imported `tools/handoff.py` SHA-256:
  `39af80c3e4398dc6420ac89c2e1e6e165791e577dcb40551fa44cbcb0f7c2c4a`.
  The immutable extracted bundle is preserved separately.

## Active machine

Windows NT 10.0.26300.0; PowerShell 7.6.5; Windows PowerShell 5.1.26100.9444;
Python 3.14.6; Git 2.56.0.windows.1; GitHub CLI 2.97.0.
`ffmpeg` and `ffprobe` were not found on PATH. No dependencies were installed.
Shell versions were queried; the application and launcher were not executed.

## Checks actually executed

Command placeholders below denote the verified checkout (`$REPO`) and extracted
bundle (`$BUNDLE`); local user-profile paths are deliberately omitted.

1. `python "$BUNDLE/payload/docs/codex/winaudioclean/tools/handoff.py" verify --bundle "$BUNDLE"`
   — exit 0, 65 manifest-listed files verified, valid plan.
2. `python "$BUNDLE/payload/docs/codex/winaudioclean/tools/handoff.py" install --bundle "$BUNDLE" --repo "$REPO"`
   — exit 0, read-only preview: 61 creates, zero identical files, zero conflicts,
   clean feature branch and no baseline drift. Subsequent Git status stayed clean.
3. `python -X utf8 -m unittest discover -s "$BUNDLE/payload/docs/codex/winaudioclean/tests" -v`
   — exit 0, 53 tests in 19.826 seconds: 52 passed, one skipped
   (`test_symlink_rejected`: symlink privileges unavailable).
   These were helper, fixture and local bare-repository tests on Windows.
4. `python "$BUNDLE/payload/docs/codex/winaudioclean/tools/handoff.py" install --bundle "$BUNDLE" --repo "$REPO" --apply --expected-head 7dfe43361395908a277d7b513b1c9a4fd3cd192a --ack-reviewed-head 7dfe43361395908a277d7b513b1c9a4fd3cd192a`
   — exit 0, 61 governance files created exclusively; zero conflicts.
5. `git diff --exit-code -- LICENSE README.md WinAudioClean.ps1 WinAudioClean.bat WinAudioClean.ico WinAudioClean_icon.png WinAudioClean_poster.png`
   — exit 0 after import. Original product files and default filters are unchanged.
6. `git check-ignore .wac-local/check.txt artifacts/local/check.json dist/example.zip docs/codex/winaudioclean/tools/__pycache__/handoff.pyc`
   — exit 0, all four generated paths covered by narrowly scoped ignores.

## Helper test corrections

The imported suite copied mutable task state into tests that assume an initial
plan. Temporary fixtures are normalized to initial state, and the live canonical
plan is validated separately. This preserves actual task history as it advances.
Wrong-origin, dirty-tree and detached-HEAD tests exercise apply refusal and check
preserved files/branch/HEAD. Preservation fixtures cover the product README and
both entry points. Only governance tests are changed; the importer is unchanged.

## Acceptance and delivery

`python -X utf8 -m unittest discover -s docs/codex/winaudioclean/tests -v`
ran against the installed plan with WAC-M0-01 `in_progress`: exit 0, 54 tests
in 19.899 seconds, 53 passed and the symlink test skipped for unavailable
privileges. Log: `WAC-M0-01-helper-tests.txt` in this evidence directory.
Test source SHA-256:
`dadaa4a33106fecc547adfb7fe5c69d096f1be4b13c622184b57ee73d822422a`.

AC-001 passes: wrong-origin, dirty-tree and detached-HEAD apply attempts were
refused with exact pre/post file bytes, directories, branch, HEAD and status
unchanged in disposable fixtures. AC-002 passes: read-only preview, clean-branch
apply, committed repeat idempotence and refusal to overwrite differing AGENTS
were verified in fixtures; the real checkout preview/apply also passed.

`python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean`
returned exit 0: 30 tasks, 90 acceptance cases, 20 improvement groups.
The corresponding `next` command returned only WAC-M0-01 while it is in progress.

AC-003 was pending when the first local checkpoint was committed. The delivery
verification below completes that case; its state is now pass.

## Verified delivery

- Commit `8163feb35401096cb260693c02b8e5eb0886b78d` contains the additive
  governance checkpoint: 64 new files, no existing product file changes.
- `git diff --cached --check` and the explicit staged product-file preservation
  diff returned 0 before commit. Staged names and content were reviewed; only
  `.gitignore`, `AGENTS.md` and `docs/codex/winaudioclean/` were included.
- The first default-credential `git push` stalled and was interrupted. GitHub
  reported the feature branch absent before the retry. The orphaned credential
  helper from this attempt was stopped. No success was inferred from that attempt.
- With `GIT_TERMINAL_PROMPT=0` and `GCM_INTERACTIVE=never`,
  `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push --set-upstream origin HEAD:refs/heads/codex/wac-m0-handoff`
  returned 0 using existing GitHub CLI authentication. This invocation did not
  change Git credential configuration.
- `python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .`
  returned 0 at 2026-10-02 09:35:10 UTC: clean tree, matching local/upstream/live
  HEAD `8163feb35401096cb260693c02b8e5eb0886b78d`.
- The matching PR search was empty before creation.
  `gh pr create --repo PikkuJanne/WinAudioClean --base main --head codex/wac-m0-handoff --draft --title 'WAC-M0-01: install governance and verify safe handoff' --body-file .wac-local/pr-body.md`
  returned 0 and created [draft PR #1](https://github.com/PikkuJanne/WinAudioClean/pull/1).
- `gh pr view 1 --repo PikkuJanne/WinAudioClean --json number,url,state,isDraft,headRefName,headRefOid,baseRefName,statusCheckRollup`
  confirmed OPEN, draft, base main and the matching head. Checks were empty.
  `gh run list --repo PikkuJanne/WinAudioClean --branch codex/wac-m0-handoff --limit 10 --json databaseId,headSha,status,conclusion,url`
  returned 0 with no workflow runs. No CI pass is claimed.
- A repeated successful sync/PR snapshot is stored in
  `WAC-M0-01-checkpoint.json`. AC-003 passes on these actual delivery observations.

This completion update records the preceding verified checkpoint. After it is
committed and pushed, its exact final SHA and fresh live verification belong in
the PR and end-of-thread report, avoiding a recursive evidence commit.

## Completion-state validation

After marking WAC-M0-01 done and AC-001–003 pass, the same installed-suite command
ran again: exit 0, 54 tests in 20.920 seconds, 53 passed and one symlink privilege
skip. Log: `WAC-M0-01-completion-tests.txt`. Test source remains at the SHA-256
recorded above; the source checkpoint is `8163feb35401096cb260693c02b8e5eb0886b78d`
plus the completion-state documentation changes.

`validate-plan` returned exit 0 with 30 tasks, 90 cases and 20 improvement groups.
`next` returned only WAC-M0-02, with no approval needed and no blocked tasks.
State inventory confirmed one done task, 29 todo tasks, three passed cases and
87 not_run cases. The diff against the reviewed baseline for all seven original
product files again returned exit 0. No runtime implementation was performed.

## Explicitly unrun and unavailable checks

- Windows application execution, `.bat` drag/drop, speech listening, Pester,
  PSScriptAnalyzer, large-file/stress/audio acceptance and release packaging:
  not run; outside WAC-M0-01. AC-004 through AC-090 remain `not_run`.
- Direct FFmpeg characterization: not rerun; FFmpeg/ffprobe are unavailable on
  PATH. Historical `bundle-*` evidence remains identified as preparation evidence.
- Symlink fixture: skipped because Windows symlink privileges are unavailable.
- No existing GitHub workflows were present. CI is not counted as passed.

Next task after verified delivery: **WAC-M0-02 in a fresh thread**.
