# WinAudioClean project instructions

Improve the existing local PowerShell + FFmpeg tool. Do not rewrite it, replace the launcher, require a server, or upload users' audio. The website is presentation and distribution only. Preserve the default Raw/Zoom filter sound unless a measured/listened change is explicitly approved.

Before work read `docs/codex/winaudioclean/NEXT_MODEL_START_HERE.md`, `STATUS.md`, `DECISIONS.md`, `TASKS.yaml` and `SYNC_PROTOCOL.md`, then the selected task brief. Reconcile newer existing guidance rather than overwrite it. Respect all higher-priority applicable AGENTS.md instructions.

Use the active Codex machine only. The user's local checkout path is not known in advance. Inspect current branch, worktree and exact fetch/push origin for PikkuJanne/WinAudioClean. Preserve uncommitted work; never reset/clean/stash it automatically or replace the checkout with this bundle's reviewed baseline.

One thread-sized task at a time. Extract small testable helpers only when needed. Retain the original .ps1/.bat entry points and Windows PowerShell 5.1 compatibility. No mandatory GUI, Python runtime, AI cloud service, telemetry, automatic dependency download, or silent updater. No private recordings, logs, credentials or personal paths in GitHub/CI.

Run relevant local tests, stabilize regressions before continuing, and record exact evidence. CI supplements local validation; do not claim Windows/launcher/listening checks based on Linux or synthetic tones. Keep original filters as a regression baseline and separate output-encoding changes from sound retuning.

At every meaningful checkpoint update task state and the next-model handoff, stage only intended files, inspect the staged diff, commit and push the matching feature branch, and verify local HEAD equals the live GitHub branch HEAD. Authentication/network failure means synchronization is blocked, not complete. Do not advance until the checkpoint is recoverable remotely.

The request authorizes planned local work, feature-branch commits/pushes and draft-PR creation/updates. It does not authorize direct main pushes, merges, tags/releases, repository setting/permission changes, branch deletion, history rewriting, default-sound promotion or website deployment. Obtain explicit approval for the exact consequential action/revision/target.

Governance import WAC-M0-01 is a separate first checkpoint. End that session before runtime implementation. When existing files conflict, merge governance additively and preserve canonical task/history records.

At task end give changed files, tests actually run, unresolved issues, local/remote checkpoint verification, PR status and the exact next task. Repository state—not chat memory—is the continuity record.
