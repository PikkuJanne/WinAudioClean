# Structured progress and cancellation fixture

This benign executable emits controlled structured stdout, independent stderr,
and optional stdin reads. It starts no subprocesses, uses no network, and writes
only explicitly supplied test-owned PID, ready and partial paths. The factory
compiles its fixed C# source using the Windows-installed .NET Framework compiler
into a fresh TestDrive path; generated executables are not committed.

Restore all `WAC_PROGRESS_TEST_*` process environment variables after each case.

| Suffix | Meaning |
| --- | --- |
| `TEXT` | Exact stdout text; default has two complete progress blocks. |
| `TEXT_PATH` | Read oversized stdout text from a test-owned UTF-8 file. |
| `CHUNK_SIZE` / `CHUNK_DELAY_MS` | Write fragmented/paced stdout. |
| `STDERR` / `DIAGNOSTIC_BYTES` | Marker and independent diagnostic flood. |
| `READ_STDIN` | `1` reads bytes until EOF and records the byte count on stderr. |
| `PID_PATH` / `READY_PATH` | Record the owned child identity/readiness. |
| `PARTIAL_PATH` | Write three synthetic bytes to a test-owned partial path. |
| `SLEEP_MS` / `EXIT_CODE` | Controlled wait and native exit status. |
| `MODE` | `survivor` waits without streams or other side effects. |

Unexpected fixture errors return 97 with `PROGRESS_FIXTURE_ERROR` on stderr.
Application-control rejection is a validation block. Preserve the diagnostic;
do not alter trust settings, rename or relocate a rejected fixture to bypass it.
