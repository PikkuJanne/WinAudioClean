# Next model starts here

Current task: **WAC-M0-01**, governance imported; final validation and remote
checkpoint pending. Work branch: `codex/wac-m0-handoff`. Once its delivery is
verified, the next task is **WAC-M0-02 in a fresh thread**.

The supplied source folder had no Git metadata; a separate checkout was created.
Discover and verify the actual Git root rather than treating that source folder
as an installed checkout. Do not reimport the bundle. See `evidence/WAC-M0-01.md`
for the reconciliation, current machine and actual validations. Product files
are unchanged; runtime, launcher and listening checks are unrun. FFmpeg/ffprobe
were not found on PATH. No dependency setup was performed.

Read the applicable AGENTS.md files, STATUS.md, DECISIONS.md, SYNC_PROTOCOL.md and TASKS.yaml. Inspect the actual checkout, branch, worktree, current remote HEAD and any existing PR. Do not reset to BASELINE.json or recopy this handoff over newer work.

If governance is already installed, reconcile current TASKS.yaml and git history rather than repeat import. Select the first dependency-ready unfinished task. Work only that task in this thread, adding a smaller continuation task when genuinely needed rather than stretching context across a milestone.

After WAC-M0-01, create the committed/pushed governance checkpoint and end the thread. Start runtime/test-seam work as WAC-M0-02 in a fresh thread.

## Required next-thread handoff fields

Current branch; task completed or blocked; changed files; tests and evidence actually produced; last verified remote checkpoint; unresolved issues/approvals; exact next task and read set. Derive live sync afresh.

Do not repeat the full historical audit unless new drift or a failing test justifies it. No owner question is needed for ordinary planned feature-branch work; genuinely destructive/publication actions remain approval-gated.
