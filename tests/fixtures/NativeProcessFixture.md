# Native process fixture

`NativeProcessFixture.cs` is a benign argv recorder and fault fixture. Its
synthetic output bytes are not audio. `New-NativeProcessFixture.ps1` exposes
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

| Variable | Behavior |
| --- | --- |
| `WAC_TEST_ARGV_PATH` | Write actual argv as a UTF-8 JSON string array. |
| `WAC_TEST_PID_PATH` | Write the child PID before output or sleep. |
| `WAC_TEST_EXIT_CODE` | Return this integer; default 0. |
| `WAC_TEST_STDOUT` / `WAC_TEST_STDERR` | Emit these exact strings. |
| `WAC_TEST_STREAM_BYTES` | Concurrently emit this many `O` / `E` characters to the respective streams, followed by `STDOUT_END` / `STDERR_END`. |
| `WAC_TEST_SLEEP_MS` | Sleep after emitting output, before returning. |
| `WAC_TEST_READ_STDIN` | When `1`, read stdin to EOF and emit `STDIN_EOF:` followed by the received character count. |
| `WAC_TEST_FFMPEG_OUTPUT` | When `1`, select the last `.wav` argument excluding the argument after `-i`; on exit 0 write synthetic bytes there. |
| `WAC_TEST_OUTPUT_PATH` | Explicit output path, overriding argument selection; on exit 0 write synthetic bytes there. |
| `WAC_TEST_BLOCK_LOG` | When `1`, create a directory named `WinAudioClean_Log.txt` beside the selected output, so application reporting fails. This also applies to configured nonzero native exits. |

Unexpected fixture errors return 97 and include `NATIVE_FIXTURE_ERROR` on stderr.
It has no network behavior and starts no further processes.
