# WAC-HOTFIX-1.0.1

Date: 2026-10-31. Baseline main: 3b7a6033949f450612e7d20acef79f4023e76644.

The owner explicitly requested both attached hotfixes, automated Windows testing,
ordinary tested merge, next available patch tag and public stable release, then
verification/conversion from the public ZIP. This supersedes historical release
approval deferrals for this patch only. No website or repository-setting change.

The supplied workspace was a source snapshot without .git. Work uses a separate
fresh clone of the exact PikkuJanne/WinAudioClean origin; the snapshot is preserved.
Live release/tag inspection found v1.0.0 latest and v1.0.1 free.

Before modification, the old shared resolver failed with process PATH restricted
to System32 and FFMPEG identifying an existing local FFmpeg pair. The process
environment was restored afterward. No owner persisted environment is changed.

Implementation is frozen for final Full/CI/release gates. Observed local checks:

- Media: 142/142 tests pass in PS5.1 and PS7, including 45 added cases.
- Console: 21 cases covered in each host, including eight actual classic-console
  captures at 80/32 columns for menu/stages/success/warning/dependency failure and
  the late mono-pan capability failure. No premature READY or failed output.
- Original audio regression: 20/20 same-build decoded-PCM comparisons pass;
  fixtures and runtime sources remained unchanged during that run.
- Initial clean-source candidate dc7904c096448cf8c5c3c6869a151e852a818d2b passed
  nine actual positive package routes, including Raw/Zoom BAT in each host,
  direct PS5.1/PS7, real shell-link activation in both hosts and process-PATH.
  Both selected executable paths match staged copies of the existing pair.
  Independent FFprobe verifies stereo 48 kHz PCM16 and eight-second duration;
  source hashes stay unchanged and decoded PCM matches public v1.0.0.
- That candidate also passed ten actual packaged dependency-failure runs and
  four controlled-source packaged-resolver absence cases. The latter explicitly
  simulate machine/environment reads and do not claim BAT-launcher coverage.

Existing-engine SHA256 identities: FFmpeg
`54474e51fd3612a9e6654fed5a0b746cfe51984cc055ea0075195c1cc786ad2b`;
FFprobe `ff735e9bf07ec6ccd6aeb2005a727f49f36a96ee9664a8d9d7deca7628544f20`.
The exact pair is copied and hashed, selected paths are asserted for every
positive route, and output is independently inspected; runner copies cannot
silently substitute for it. CI uses a separately checksum-pinned trusted pair.

The first shortcut harness attempt used mode-only saved preferences; positional
launches correctly retained the default destination. The harness now binds its
isolated destination in saved settings. Exactly its owned synthetic files and
proven appended summary suffix were removed; prior summary bytes were preserved.
Initial Full attempts exposed an older missing-tool test assumption: empty
process PATH no longer implies empty persisted lookup sources. The scratch-copy
fixture now controls only the environment-reader adapter, asserts all other
source text unchanged, and retains notfound/exit3/no-output assertions. Its four
dependency cases pass under both Pester hosts. Initial interrupted Full runs
are not claimed passing; final complete reruns remain required.

Final exact source/CI/package/public-download identities and results are recorded
externally in [PR 11](https://github.com/PikkuJanne/WinAudioClean/pull/11) and the
[stable release](https://github.com/PikkuJanne/WinAudioClean/releases/tag/v1.0.1)
only after observation. A commit cannot contain its own future identity. Local
fixture media, paths, raw diagnostics and owner environment values stay ignored
and are not uploaded. Publication requires successful final gates and a fresh
package check; delivery includes a new public-asset download and conversion.
