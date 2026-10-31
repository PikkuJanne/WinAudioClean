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

Implementation and validation are in progress. Exact final test counts, source
identity and publication/download facts are recorded only once observed; the
commit cannot contain its own future identity. Local fixture media, paths and
raw logs stay ignored and are not uploaded.
