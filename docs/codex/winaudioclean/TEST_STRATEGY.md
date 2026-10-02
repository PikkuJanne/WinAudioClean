# Test strategy: local evidence first

Use the active Codex machine only; temporary clean worktrees/clones on that same machine are allowed. Do not require tests on another personal machine or upload private audio to CI. Tests should advance implementation, not become a repeating full-project audit.

Quick: parsing/static checks, plan consistency and small affected unit tests. Targeted: feature-specific unit/native/FFmpeg checks, including injected failures. Full: one cumulative regression at each meaningful gate. Extended: long recordings, >4 GB exports and stress only when their risks justify the cost; document an unrun full-size scenario honestly.

Pester and PSScriptAnalyzer are development tools [S04,S05]. Provide PowerShell test runners compatible with PS5.1 and available PS7 on Windows. Pin selected versions when implemented; do not invent a “latest” version from memory. Keep the original entry point testable without making dot-sourcing run the application.

The supplied Python helpers/tests validate the handoff and create synthetic audio, not the application. They add no runtime dependency. The supplied Linux direct-FFmpeg characterization is informative only. Actual Windows .bat/PS5.1/PS7 behavior and subjective speech quality must be checked locally during implementation.

## Fixture classes

Use synthetic PCM for silence, very short input, 44.1/48 kHz mono/stereo, separated channels, impulses, changing amplitude, clipping-like saturation and noise. Create tiny test containers with multiple audio tracks/video-only streams through the installed FFmpeg when needed. Fault injection covers no audio, corrupt files, unavailable tool/filter, invalid JSON, unwritable destinations, full disk, rename collisions, partial outputs, process stream flooding and cancellation.

Filename coverage includes spaces, brackets, apostrophes, German/Finnish Unicode, &, %, !, parentheses and supported long/UNC paths. Test decimal cultures de-DE and fi-FI as well as an English culture; build filters and parse JSON invariantly.

Private interview/listening corpus remains outside Git or in explicitly ignored local folders. Store only consent status, anonymized IDs/settings and sanitized review summaries. Missing corpus means pending listening, not fabricated pass. Synthetic mechanics cannot establish speech restoration quality.

## Evidence

Each report identifies task/case IDs, environment, dependency versions, tested code revision/content hash, exact commands, process exits and findings. Report pass/fail/not-run distinctly. Do not accept a source-only test for a real launcher boundary, a header-only RF64 check for full-size reliability, or a cached tracking ref as live synchronization proof.

Use docs/codex/winaudioclean/templates/SESSION_EVIDENCE.md and LISTENING_REVIEW.md. Keep raw diagnostics local by default and commit only sanitized evidence. At gate time reconcile once; fix focused regressions before repeating the required gate.
