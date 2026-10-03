# WAC-M3-03 evidence — frozen local folder queues

Date: 2026-10-03. Started clean and live-synchronized at `8d033079dde925abd48c87d9b4f71784756c146d` on
`codex/wac-m3-settings`, exact fetch/push origin
`https://github.com/PikkuJanne/WinAudioClean.git`, open draft PR#4 stacked on
`codex/wac-m2-audio` (draft#3). The source-only original checkout is untouched.
The final local/live/PR SHA is recorded after push outside its own commit.

AC-055: direct InputDirectories selects local supported-extension candidates.
Recursion is off by default; one root-seeded breadth-first traversal is sorted
ordinally within folders. Known generated outputs/temporary names, unsupported
extensions, reparse entries, ordinary nonrecursive subfolders and descendant
destinations have explicit skipped reasons. Real junction-loop/outside-target
and hardlink fixtures run on Windows. Root/ancestor reparses and incomplete or
oversize scans fail globally before media jobs. Extensions are candidates, not
proof of valid media; unchanged native validation remains authoritative.

AC-056: queue membership freezes before jobs, with file-identity deduplication
across repeated/overlapping/case/relative roots and hardlink aliases. A known
generated-name alias found later still excludes the same identity. Same-stem
inputs retain existing unique output transactions. Destination subtrees and
files created after selection cannot enter a running queue. Capture identity,
size and UTC modification time; compare and retain ordinary ancestor/source
handles through each child. Changed/unavailable sources fail2 per item and
others continue. Explicit lists retain repeat order and schema1.

AC-057: ordinary failures continue and earlier exports/detailed reports survive.
Schema2 journals add folder selection/source snapshot, reasons and skipped
counts to the existing CreateNew/flush contract. Cancelled children stop pending
starts; static skips/preflight failures stay recorded. Folder aggregate is
cancel130, otherwise anyfailed6, warning7, success/empty/allskipped0. Journal
failure5 stops later starts and discloses incomplete reporting while preserving
earlier audio/records. Empty/allskipped snapshots require no mode/native work.

Required final Targeted (new FolderQueue plus unchanged Batch suite):
156 Pester passed, 1 skipped per host; exit0.
Required Full: 1330 Pester passed, 1 skipped per host;
62 Python discovered per host,61 passed and one Windows symlink-privilege skip.
Parser/static/plan gates passed with visible non-gating analyzer advisories.
PS7 Full records all advisories. Exact commands, source hashes, durations,
counts and log hashes are in [source manifest](WAC-M3-03-source.json).
Maintained source/test bytes remain unchanged across final captured gates.
After successful gates/media, one comment-help line clarifies that the single
exit-code exception belongs to explicit lists. [Help correction proof](WAC-M3-03-help-correction.json)
records tested/final file hashes, exact one-line substitution and both-host
parser/executable-token equality. No parameters, dispatch or processing code
changed. The manifest distinguishes physical captured source from final bytes;
this documentation-only correction does not require suite/media rerendering.
Full is cumulative; the separately captured real-media matrix is independent.

Both Windows PowerShell5.1.26100.9444 and PowerShell7.6.5, Python3.14.6,
Pester5.7.1, PSScriptAnalyzer1.24.0 and pinned FFmpeg/ffprobe9.0.2 were used.
No install/security setting changed. Python children strip inherited PSMODULEPATH.
Tests use isolated SettingsPath or IgnoreSavedSettings; the default user settings
file remains absent and was never written. [Media scope](WAC-M3-03-media.json)
records exact synthetic cases, commands, comparisons, hashes and cancellation
seams. Preliminary captures/corrections remain distinct from final source.
The [focused ledger](WAC-M3-03-folder-focused.json) preserves initial65-case
selection and the PS7 date-object/string assertion failure, then corrected80
selected/79passed/one file-symlink privilege skip per host. A parsed-date test
normalization fixed that assertion; report wire strings and runtime stayed
unchanged. This Pester skip is separate from the existing Python privilege skip.

Existing main helper bodies and the entire processing suffix match the M3-02
baseline. IO/Settings/Preview/BAT/Launcher and all prior tests remain unchanged.
Original1.0.0/Fast remains default; Gentle0.1.0 is opt-in Raw experimental.
Application2.3/report1, Accurate, encoding, report ownership and preview remain.
No human speech listening/default promotion was performed. Returned-exit130
cancellation checks do not certify active-render Ctrl+C; progress/cancellation
implementation belongs to M3-04. Arbitrarily renamed outputs without known
aliases, adversarial metadata restoration, crash/power-loss, disk exhaustion,
>4GB, long-file memory and codec-seek/listening limits remain scoped separately.
No merge, release, repository/security change, default promotion or deployment.

Canonical completion is limited to M3-03/AC055..057. Existing M1-02
policy/resumption and prior M2/M3 failures/limits remain intact. Post-canonical
validate-plan/next evidence is captured separately. Next: WAC-M3-04.
