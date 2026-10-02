# WAC-M0-04 independent restart review

Date: 2026-10-02. Case: AC-012.

## Scope

An independent reviewer with no prior chat context read AGENTS.md,
NEXT_MODEL_START_HERE.md, STATUS.md, DECISIONS.md, SYNC_PROTOCOL.md, TASKS.yaml,
ACCEPTANCE.json, the M0-04 and M1-01 briefs, the M0-04 gate record and
tests/README.md. This was a context-limited review within the fresh M0-04 chat,
not a separately created user-owned chat. It supports restart-guide usability;
it does not claim another user-owned chat was opened or implementation tests
were repeated.

## Commands and observations

The reviewer ran these read-only commands from the repository root:

```powershell
git rev-parse --show-toplevel
git remote -v
git remote get-url --all origin
git remote get-url --push --all origin
git worktree list --porcelain
git status --porcelain=v1 --branch
git log -5 --oneline
git diff --name-only
python -X utf8 docs/codex/winaudioclean/tools/handoff.py inspect --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -X utf8 docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python -X utf8 docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
```

Git inspection succeeded. The active branch was `codex/wac-m0-handoff` at
`e1bd07b96dc23ab7d84ac0f236ca599a866c73a3`, with one effective fetch URL and one
push URL, both `https://github.com/PikkuJanne/WinAudioClean.git`. The worktree
contained the pending M0-04 governance/evidence changes. No Git mutation was
performed by this reviewer.

`inspect` exited 0 and reported that branch/head with `clean: false`.
`sync-check` exited 1: `Worktree is dirty. NOT SYNCHRONIZED as a complete
checkpoint.` This is the expected precommit state, not evidence of remote
delivery. The reviewer did not fetch or independently inspect live PR/CI state.
The initial `validate-plan` and `next` each exited 1 while final evidence files
were still being assembled: `Done task needs existing evidence: WAC-M0-04`.

After the evidence paths existed, the reviewer reran both commands:
`validate-plan` exited 0 with 30 tasks, 90 acceptance cases and 20 improvement
groups; `next` exited 0 with only WAC-M1-01 ready, no blocked tasks and
`approval_needed: false`. The plan had four done tasks and 26 todo; acceptance
had 12 pass and 78 not_run. The temporary missing-evidence condition was resolved.

## Derived continuation

The exact next implementation task is **WAC-M1-01**, limited to AC-013 through
AC-015: literal filename handling; file/destination preflight before prompts;
and invalid, cancel and unattended menu behavior. Preserve the existing entry
points, PS5.1 compatibility, Music destination default and exact Raw/Zoom
filters. Resolve the UNC policy explicitly. Media probing, the process wrapper
and export changes belong to later tasks. WAC-M1-02 follows accepted,
synchronized M1-01.

Before starting M1, inspect the current checkout and effective origin, preserve
changes, fetch with `git fetch --prune origin`, then run the four handoff
commands above. Check live PR/CI state separately. Successful plan selection
does not replace clean-worktree and live-head verification.

After verifying M0 delivery, create `codex/wac-m1-reliability` from the M0
completion tip. The guide identifies draft PR #1 targeting main; while that PR
is unmerged, the M1 draft PR base is `codex/wac-m0-handoff`. If an approved merge
occurred, inspect the resulting history before choosing the base. Feature
commits/pushes and draft PR updates are authorized; merge/publication authority
is not implied.

The guide gives these local test commands; they were read, not run in this review:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Quick
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Targeted -Tag EntryPoint
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts/Invoke-Tests.ps1 -Level Full
```

## Unverified checks and finding

The handoff clearly leaves speech listening, default-sound approval, real audio
through the launcher, full special-character forwarding, native fault handling,
stream selection, channel isolation, impulse alignment, long recordings and
exports over 4 GB unverified. It distinguishes direct synthetic FFmpeg evidence
from launcher/listening evidence, and identifies that CI does not exist yet.
AC-013 through AC-090 remain `not_run` in the plan.

No substantive restart-guide ambiguity was found. The sibling-checkout hint,
identity checks, next task, commands, branch strategy and remaining checks can
be recovered without reconstructing prior chat or repeating the baseline audit.
Final plan validation passed in this review; remote delivery remains the
enclosing task's gate.
