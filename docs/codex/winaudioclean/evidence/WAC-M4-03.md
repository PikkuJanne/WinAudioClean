# WAC-M4-03 — Portable release package evidence

Implementation and validation are in progress. WAC-M4-03 remains todo and
AC-073..075 remain not_run until actual clean-revision builds, extracted-package
use and the cumulative local gates are reconciled. Parent checkpoint:
`f32cf1591a288ff356f69aa3a2320adf62959808`.

The tool-only payload retains the existing application version `2.3`, all eight
PowerShell components, the BAT launcher, the repository icon, MIT LICENSE and
the necessary user documentation. FFmpeg is supplied separately. No package
publication, dependency bundling, default-sound change or runtime refactor is
part of this task. The source-only original and all eight broader gaps remain
preserved.

The in-memory ZIP probe found that Framework and Core emit different ZIP
methods/flags for NoCompression. The builder will use canonical stored entries;
actual same-host and cross-host byte equality still require clean-source builds.
Real launcher checks and builtin-module-only PowerShell checks have distinct
scope: PowerShell startup adds shared module search locations on this development
machine, so a restricted bootstrap must not be labeled a direct -File launch.

Parent metadata-only PR run37148623973 has now completed successfully in all
four Windows2022/2025 PS5.1/PS7 jobs. That result is separate from the upcoming
M4-03 build and test evidence.

## Smallest local gate

The exact-path Targeted runner passed all16 release fixtures on Windows
PowerShell5.1.26100.9444 and pinned PowerShell7.6.5, with zero failures/skips/
outside-scope cases. Parser/analyzer, plan and75-case coverage checks passed.
The source was the in-progress working contents over parent f32cf159; each
host's before/after seven source-tree digests matched. Pester5.7.1 and
PSScriptAnalyzer1.24.0 were the observed pinned development modules; Python3.14.6
ran the governance checks. Exact commands/digests are retained in the
[validation ledger](WAC-M4-03-validation.json). This gate does not claim that
a deliverable ZIP or extracted application has passed yet.
