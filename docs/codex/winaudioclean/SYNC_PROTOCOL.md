# Local and GitHub synchronization protocol

## Scope and authorization

The target repository is exactly `PikkuJanne/WinAudioClean`. Both fetch and push destinations must resolve to it. Accepted normal forms are the HTTPS GitHub URL, `git@github.com:PikkuJanne/WinAudioClean.git`, or the equivalent ssh:// form. Resolve URL rewrites and multiple push URLs; do not push when any effective destination is unknown or different. Never print embedded credentials.

Feature-branch commits/pushes and draft-PR updates are in scope. Merge, direct main push, history rewrite, branch deletion, settings/permissions changes, tags/releases and live deployment require explicit action-specific approval. Do not auto-enable branch protection or alter visibility.

## Session start (read, then reconcile)

Use the current workspace as a candidate, not an assumed C:\projects path. Inspect `git rev-parse --show-toplevel`, applicable AGENTS.md files, `git status --short`, branch, HEAD, all effective origin fetch/push URLs and current PR. Preserve unrelated edits and any interrupted work. Never run `git reset --hard`, `git clean`, automatic stash or a blanket checkout.

Run `git fetch --prune origin` once authentication and origin are verified. Compare the current branch/upstream and live branch. A reviewed baseline SHA is an audit anchor, not a mandate to reset. Inspect only changed areas since the last recorded checkpoint. Fetch/PR access failure must be explicit; no fabricated remote state.

## Branches and draft PRs

The suggested first branch is `codex/wac-m0-handoff`. Do not reuse an unrelated branch with the same prefix. Subsequent milestone branches may start from the verified preceding milestone tip, with stacked draft PRs based on the preceding work branch. Do not merge merely to unlock the next task. After approved merges, inspect and adjust PR bases without force-pushing shared commits.

A CLI example for a NEW governance branch (only after inspecting current state):

```powershell
git switch -c codex/wac-m0-handoff
```

Use authenticated `gh` or the available GitHub connector to find/reuse the relevant draft PR. Do not duplicate PRs or create dozens of issues by default. Optional tracker issues are useful only when they improve continuity.

## Per-task checkpoint

Complete the narrow task and stabilize relevant tests. Update TASKS.yaml, ACCEPTANCE.json, STATUS.md, NEXT_MODEL_START_HERE.md and a sanitized evidence file. `done` describes engineering acceptance, not a claim of live remote delivery.

Inspect `git diff`, `git diff --check`, and the explicit paths to stage. Do not use `git add .`/`git add -A` in a working repository. Review `git diff --cached --stat` and `git diff --cached` for secrets, user recordings, logs and unrelated work.

Commit only intended files with a task-ID-bearing message. After verifying branch and remote, push explicitly:

```powershell
$branch = git branch --show-current
# Review the value first; it must be the intended feature branch, never main/master.
git push --set-upstream origin "HEAD:refs/heads/$branch"
# Check $LASTEXITCODE immediately; do not continue on a nonzero result.
python docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
```

The helper is read-only and requires a clean worktree, matching upstream, and local HEAD equal to `git ls-remote` for the exact live branch. It is not a push helper. A cached `origin/branch`, a green local test, or exit code 0 with no matching remote ref is insufficient evidence. [S06, S07]

Also inspect live PR/CI state at that SHA. CI is supplementary; pending CI is not “passed”. Post/update a concise PR checkpoint comment including the exact SHA, local test evidence, live sync outcome and next task. A transient PR API problem can be reported separately, but a failed source push blocks advancement.

## Avoid recursive evidence commits

The pushed commit can contain its tests/settings/content hashes and the preceding verified checkpoint. It cannot contain its own future SHA. After pushing commit H, verify H and record H in the PR/final response or in the next session's evidence. Do not endlessly amend/push simply to place H inside H.

## Failure and interruption

On push rejection inspect/fetch first; never force-push. Resolve legitimate remote changes using a reviewed non-rewriting integration, or stop with the precise conflict. On authentication/network failure preserve the local coherent commit, report NOT SYNCHRONIZED with retry command and next action, and do not advance to another milestone.

When interrupted, checkpoint coherent safe work if possible, label incomplete items honestly, and push before handoff. Do not mark incomplete work accepted just to leave a green checklist.

## End-of-thread report

State task/outcome, changed areas, tests actually run, failures/skips/approvals, local branch/HEAD, live remote HEAD/verification, clean/dirty status, PR/CI state and exact next task. Never imply main or a website was updated when only a feature branch was pushed.
