# WinAudioClean incremental improvement programme

This directory is a Codex working handoff, not a replacement application. Keep `WinAudioClean.ps1`, `WinAudioClean.bat`, FFmpeg, local processing and the two familiar modes.

Start with `NEXT_MODEL_START_HERE.md`. Canonical task state is `TASKS.yaml`; it deliberately uses JSON syntax (a YAML 1.2 subset) so the supplied Python 3.10+ developer helper requires no YAML package. Do not create a second task-state file.

`ROADMAP.md` explains six milestones and 30 thread-sized tasks. `TRACEABILITY.md` maps all 20 requested improvements. `ACCEPTANCE.json` carries 90 initially unrun acceptance cases. `tasks/` contains the implementation briefs.

The runtime must not acquire a Python requirement. Python helpers here are optional development/handoff utilities only. Future product tests and release scripts are PowerShell. Never include this whole handoff directory in the end-user release ZIP.

## Developer helpers

From the repository root, after installation:

```powershell
python docs/codex/winaudioclean/tools/handoff.py validate-plan --plan-root docs/codex/winaudioclean
python docs/codex/winaudioclean/tools/handoff.py next --plan-root docs/codex/winaudioclean
python docs/codex/winaudioclean/tools/handoff.py sync-check --repo .
python -m unittest discover -s docs/codex/winaudioclean/tests -v
```

`py -3` can replace `python` when that is the local Python launcher. Do not install Python as a runtime dependency of WinAudioClean. When Python is unavailable to the Codex development environment, reproduce the documented checks using existing tools rather than weaken them.

`sync-check` is read-only: it verifies the actual live remote branch, not just a cached tracking ref. It never commits, pushes, merges or fixes drift. Follow `SYNC_PROTOCOL.md` for the explicit write steps.

Bundle verification checks the immutable extracted bundle; after Codex edits installed task state, use `validate-plan`, not the original bundle hashes, on the live handoff.

## Synthetic mechanics fixtures

`tools/generate_fixtures.py --output <NEW_DIRECTORY>` creates five small synthetic PCM inputs. `tools/characterize_filters.py --output <ANOTHER_NEW_DIRECTORY> --ffmpeg <EXE> --ffprobe <EXE>` exercises the two exact legacy filter strings with implicit and explicit output formats. Run these scripts with Python in the developer environment, not as product commands. Both refuse existing output directories. Keep generated audio outside Git and never confuse tones with speech acceptance.

The initial preparation evidence in `evidence/bundle-*` is immutable historical context, not a completed application test. New implementation reports should use task-specific names and actual Windows environment information.
