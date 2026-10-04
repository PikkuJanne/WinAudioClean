# Audit anchor and evidence boundaries

Reviewed on 2026-10-02: public repository main at `7dfe43361395908a277d7b513b1c9a4fd3cd192a`, script version 2.3. The GitHub connector re-read the branch, pinned tree and relevant pinned source. BASELINE.json records observed Git blob identities. This is not a copy of the application and must never overwrite a newer working tree.

The reviewed tree contains the script, launcher, README, MIT license and three image/icon assets. No test or workflow files appear in that tree. The previously reviewed releases response was empty; Codex must recheck actual current releases/PRs during M0 rather than assume they remain empty. Branch protection is not part of the runtime implementation scope and may not be changed without approval.

## Source-observed issues (not Windows execution results)

The script uses minute-resolution output timestamps and FFmpeg -y, exposing prior-export collisions. It treats every mode input other than 1 as Zoom. Input checks occur after the menu. Test-Path/Get-Item lack literal path handling. Output rate/PCM codec/audio mapping are not explicit. The command is assembled as one quoted string. It waits for a child and reads its exit code, but lacks a consistent application-exit contract and transactional output validation. The log's DURATION is processing wall time. Reports share one text log. The launcher forwards the first dropped argument only and pauses. The script already falls back to PATH for FFmpeg.

The source contains inaccurate audio terminology. Retain working filter values while correcting claims and evaluating optional improvements. See AUDIO_CONTRACT.md and official references; source presence alone does not prove subjective audio quality.

## What is actually tested in this handoff

The bundle validation report lists helper unit tests and direct-FFmpeg synthetic characterization executed in the preparation environment. Those checks are not execution of WinAudioClean.ps1, the Windows .bat, Windows PowerShell 5.1/7 or a listening test. All 90 application acceptance cases remain initially not_run. Reproduce relevant checks on the active Windows machine before claiming application acceptance.

Do not turn prior chat statements into verified evidence. The authoritative evidence is the current source, recorded executable commands/results, actual listening review and GitHub checkpoint state.
