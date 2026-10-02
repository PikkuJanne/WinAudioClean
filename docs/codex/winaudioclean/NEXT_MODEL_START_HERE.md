# Next model starts here

Completed task: **WAC-M0-01**, governance installation and acceptance AC-001–003.
Next task: **WAC-M0-02 in a fresh thread**. Work branch:
`codex/wac-m0-handoff`; [draft PR #1](https://github.com/PikkuJanne/WinAudioClean/pull/1)
targets main. Continue from the verified feature-branch tip, including the
completion evidence commit, without repeating the import.

Last recorded verified checkpoint: `8163feb35401096cb260693c02b8e5eb0886b78d`.
The clean local tree, upstream and live GitHub branch matched, and the PR was
open/draft at that SHA. See `evidence/WAC-M0-01-checkpoint.json` for its timestamp.
The subsequent completion commit's exact SHA is recorded in the PR/final response.
Derive current HEAD and live synchronization afresh before WAC-M0-02.

The supplied source folder had no Git metadata; a separate checkout was created.
Discover and verify the actual Git root rather than treating that source folder
as an installed checkout. Do not reimport the bundle. See `evidence/WAC-M0-01.md`
for the reconciliation, current machine and actual validations. Product files
are unchanged; runtime, launcher and listening checks are unrun. FFmpeg/ffprobe
were not found on PATH. No dependency setup was performed.

Read the applicable AGENTS.md files, STATUS.md, DECISIONS.md, SYNC_PROTOCOL.md and TASKS.yaml. Inspect the actual checkout, branch, worktree, current remote HEAD and any existing PR. Do not reset to BASELINE.json or recopy this handoff over newer work.

If governance is already installed, reconcile current TASKS.yaml and git history rather than repeat import. Select the first dependency-ready unfinished task. Work only that task in this thread, adding a smaller continuation task when genuinely needed rather than stretching context across a milestone.

Read `tasks/WAC-M0-02.md` for the next scope: minimal test seams and local
PowerShell test runners. Do not repeat the baseline audit unless live drift or a
failure requires it. The installed helper suite ran 54 tests, 53 passed and one
symlink test skipped for missing Windows privileges; all 30 tasks and 90 cases
remain valid. No WAC-M0-01 blocker remains. Git pushes may need the existing
GitHub CLI credential helper for this command only; no configuration change is
required. All publication/merge approval boundaries remain in force.

## Required next-thread handoff fields

Current branch; task completed or blocked; changed files; tests and evidence actually produced; last verified remote checkpoint; unresolved issues/approvals; exact next task and read set. Derive live sync afresh.

Do not repeat the full historical audit unless new drift or a failing test justifies it. No owner question is needed for ordinary planned feature-branch work; genuinely destructive/publication actions remain approval-gated.
