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

AC-003 additionally requires a committed clean tree, a live matching remote HEAD
and a real draft PR. Those delivery checks remain pending at this first checkpoint.
The final state update will reference the first verified pushed checkpoint;
the final commit's own SHA belongs in the PR and end-of-thread report.

## Explicitly unrun and unavailable checks

- Windows application execution, `.bat` drag/drop, speech listening, Pester,
  PSScriptAnalyzer, large-file/stress/audio acceptance and release packaging:
  not run; outside WAC-M0-01. AC-004 through AC-090 remain `not_run`.
- Direct FFmpeg characterization: not rerun; FFmpeg/ffprobe are unavailable on
  PATH. Historical `bundle-*` evidence remains identified as preparation evidence.
- Symlink fixture: skipped because Windows symlink privileges are unavailable.
- No existing GitHub workflows were present. CI is not counted as passed.

Next task after verified delivery: **WAC-M0-02 in a fresh thread**.
