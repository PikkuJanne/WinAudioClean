# Native process fixture

`NativeProcessFixture.cs` is a benign argv recorder and fault fixture. Its
default output is three seconds of synthetic mono PCM16 silence at 48 kHz.
`New-NativeProcessFixture.ps1` exposes
`New-WacTestNativeExecutable -OutputPath <fresh absolute .exe>` and uses the
Windows-installed .NET Framework compiler. It does not install tools or replace
an existing output executable. Generated executables stay in test-owned folders.

Windows application-control policies can reject these unsigned fixtures even
when compilation succeeds. Preserve the startup diagnostic and report the
validation as blocked by that policy. Do not retry, recompile, rename or relocate
fixtures to get around a rejection, or change signing/trust/security settings.
Successful real-FFmpeg checks provide separate evidence and do not replace the
argv-recorder or fault-injection cases.

During the initial Windows validation on 2026-10-02, CodeIntegrity Operational events 3033
and 3077 reported signing-level/policy rejections for generated fixture copies.
The Full runs encountered 44 blocked launcher copies and seven blocked reporting
copies, producing 83 events of each type. All 23 direct native-wrapper tests
passed in both Full runs; those passes do not establish acceptance of the
blocked integration cases. No signing or security policy was changed by Codex.

The owner subsequently reported Smart App Control Off and authorized a rerun.
Read-only checks confirmed state 0; both Full gates passed on unchanged source:
227 Pester cases and 61 Python cases, with one Python symlink-privilege skip per
shell. This resolves that validation block; it does not certify unsigned-fixture
execution with Smart App Control On. See
[resumption evidence](../../docs/codex/winaudioclean/evidence/WAC-M1-02-resume.md).

The child records its original arguments without consuming configuration flags.
Configure it with inherited environment variables; callers must restore them.

When the executable is named `ffmpeg.exe` or `ffprobe.exe`, dependency inspection
commands have separate behavior. `-version` emits a fixture version; FFmpeg
`-filters` lists all original Raw/Zoom filters; ffprobe `-show_entries` emits one
valid mono PCM audio stream with absolute index 0 at 48 kHz and duration 3 seconds. These calls do not
write a render argv record, output bytes or blocked-log directory, and do not
consume generic render faults. Other executable names keep generic behavior.

Inspection can be configured using the `WAC_TEST_VERSION_`, `WAC_TEST_FILTERS_`
or `WAC_TEST_PROBE_` prefix followed by `STDOUT`, `STDERR`, `EXIT_CODE`, `SLEEP_MS`,
`ARGV_PATH` or `PID_PATH`. These controls use the same meanings as the generic
variables below; an absent inspection stdout uses the corresponding default.

Probing a `.partial` output instead uses `WAC_TEST_OUTPUT_PROBE_` with those same
suffixes. Its default metadata comes from the generated WAV header and actual
payload size, independently of input-probe overrides. Reads and writes allow the
transaction's held file handles. Output fault modes test invalid exit-zero data;
these fixtures are mechanics tests and provide no sound-quality evidence.

| Variable | Behavior |
| --- | --- |
| `WAC_TEST_ARGV_PATH` | Write actual argv as a UTF-8 JSON string array. |
| `WAC_TEST_PID_PATH` | Write the child PID before output or sleep. |
| `WAC_TEST_EXIT_CODE` | Return this integer; default 0. |
| `WAC_TEST_STDOUT` / `WAC_TEST_STDERR` | Emit these exact strings. |
| `WAC_TEST_STREAM_BYTES` | Concurrently emit this many `O` / `E` characters to the respective streams, followed by `STDOUT_END` / `STDERR_END`. |
| `WAC_TEST_SLEEP_MS` | Sleep after emitting output, before returning. |
| `WAC_TEST_READ_STDIN` | When `1`, read stdin to EOF and emit `STDIN_EOF:` followed by the received character count. |
| `WAC_TEST_FFMPEG_OUTPUT` | When `1`, select the last `.wav` or `.partial` argument excluding the argument after `-i`; on exit 0 write synthetic WAV data there. |
| `WAC_TEST_OUTPUT_PATH` | Explicit output path, overriding argument selection; on exit 0 write synthetic WAV data there. |
| `WAC_TEST_OUTPUT_MODE` | Default `valid`; `empty` writes zero bytes, `header` writes a WAV header with no samples, `truncated` declares three seconds but writes half, and `short` writes a valid quarter-second WAV. |
| `WAC_TEST_BLOCK_LOG` | When `1`, create a directory named `WinAudioClean_Log.txt` beside the selected output, so application reporting fails. This also applies to configured nonzero native exits. |

Unexpected fixture errors return 97 and include `NATIVE_FIXTURE_ERROR` on stderr.
It has no network behavior and starts no further processes.
