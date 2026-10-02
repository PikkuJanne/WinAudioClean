# Decisions and constraints

## Frozen by the owner request

D01. Incremental improvement of the existing WinAudioClean repository, not a rewrite.
D02. Local PowerShell + FFmpeg processing; the website only presents/distributes downloads.
D03. Preserve .ps1/.bat entry points, simple Raw and Zoom choices, and Windows PowerShell 5.1 support.
D04. Preserve originals, prior exports and recording timing; no automatic silence removal/downmix.
D05. Work locally on the active Codex machine; GitHub holds the pushed continuity checkpoints. Do not require another hardware test setup.
D06. One task-oriented thread per coherent slice, staged testing, checkpoint pushes and exact next-thread handoff.
D07. No default-sound retuning without explicit listening/evidence-based owner approval.
D08. No automatic uploads, cloud audio processing, telemetry, credential collection or silent dependency/self-update downloads.

## Engineering choices proposed by the reviewed improvements

D09. Name Original/Legacy presets retaining exact baseline filter strings. Fast remains the default; Accurate is opt-in.
D10. Explicit 48 kHz / 16-bit PCM WAV is the proposed standard export; offer 24-bit. This changes encoder output, not the filter settings, and must be release-noted and tested. Do not claim bit-identical legacy files after this change.
D11. Preserve the selected track's channels; mono is explicit. Ambiguous multi-track unattended input fails unless a stream was specified.
D12. Unique same-volume temporary WAV, validation, no-clobber rename and run-owned cleanup. No deleting originals or global temp sweeps.
D13. Sequential queues first. No job server, background service, multi-machine agent or needless parallelism.
D14. Versioned typed JSON config/report data; invariant numeric filter serialization. CLI > saved > built-in.
D15. Start with a tool-only portable release. Third-party bundling, default-sound promotion, merges/releases/settings/deployment require specific approval.
D16. One canonical TASKS.yaml (JSON syntax); 90 acceptance contracts are tracked in ACCEPTANCE.json. Machine-readable IDs may not be silently dropped.
D17. Ordinary feature commits, verified pushes and draft PRs are authorized. Main is not automatically the delivery branch. Use stacked PRs where needed until merges are approved.
D18. Claims of “exact -12 LUFS”, “-12 dB RMS”, “85% leveling”, “95% success” and universal broadcast compliance must not be recycled as evidence or marketing.

## Changes to decisions

Add dated entries with task ID, rationale, evidence and owner approval where required. Preserve earlier entries and record supersession; do not silently edit away history. Numeric audio tolerances are engineering acceptance proposals in AUDIO_CONTRACT.md, not universal standards.
