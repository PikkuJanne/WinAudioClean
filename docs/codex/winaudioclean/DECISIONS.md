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

### 2026-10-02 — WAC-M0-04 baseline gate

D19. Continue the already authorized implementation plan from the verified M0
checkpoint. D01–D08 remain owner constraints; D09–D18 and the audio, process and
data contracts guide their scheduled implementation. This gate records no new
owner approval and does not certify future behavior as implemented. Evidence:
`evidence/WAC-M0-04.md` and `evidence/WAC-M0-04-reconciliation.json`.

The implementation contracts carried into M1 are:

- Keep the original Raw/Zoom filter text and order in `BASELINE.json`, the
  `.ps1 -inputPath` and `.bat` entry points, and Windows PowerShell 5.1 support.
  Continue local processing with no runtime Python or automatic downloads.
- M1-01 validates literal file input and a writable destination before asking
  for a mode. Invalid choices must reprompt; cancellation and unattended
  failure must be explicit. Music remains the default destination. A useful
  no-input usage route is sufficient; a picker is optional. Reject URL input.
  If UNC paths are supported, document them as network shares and test them;
  do not equate filesystem paths with physically offline storage.
- Keep paths as argument data, capture native exits/diagnostics, and verify
  actual Windows argument forwarding in M1-02. Its application exit-code and
  warning/logging-failure policy remains an engineering decision to finalize
  there, using `NATIVE_PROCESS_CONTRACT.md`.
- Preserve originals and prior exports with run-owned temporary output,
  validation and a no-overwrite final move in M1-04. Current collision and
  overwrite characterizations are defects to replace with regression tests.
- Implement D10's explicit 48 kHz PCM16 export and optional PCM24 in M1-05,
  separately from filter tuning. The present application still leaves encoding
  unspecified; M0-03 measured 192 kHz PCM16 and compared 48 kHz PCM16. The future
  export change needs format/timing/channel checks and release notes. RF64 and
  disk-size behavior need their scheduled evidence before acceptance.
- Preserve selected channels and timing. Later optional Accurate processing,
  presets, preview, queues and typed settings follow their own task gates;
  synthetic loudness observations do not establish speech-quality approval.

Pending human decisions and evidence:

| Item | Current status | Effect on continuation |
| --- | --- | --- |
| Permission-cleared speech corpus and listening review | No clips admitted; no review performed. Use `evidence/WAC-M0-03-listening.md`. | M1 reliability work can proceed. Speech-quality claims remain unverified. |
| Change the default sound | No exact settings/revision approved. | Preserve Original; any promotion needs the explicit approval required by D07. |
| Bundle third-party binaries | No redistribution choice approved. | D15's tool-only portable package remains the planned starting point. |
| Merge, tag/release, settings changes or website deployment | No action/revision/target approved in `APPROVALS.md`. | Feature pushes and draft PR updates continue under D17. Publication is a later decision. |

The local full gate and same-build reports support proceeding to **WAC-M1-01**,
not release readiness. `BASELINE.json` and bundle Linux reports remain historical
anchors; the current Windows evidence and its limits are in M0-03/M0-04 records.
No earlier decision is superseded by this entry.
