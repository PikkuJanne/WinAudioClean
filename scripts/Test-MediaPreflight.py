#!/usr/bin/env python3
"""Optional Windows development checks using existing FFmpeg and Python stdlib.

No tools are downloaded. All media, logs and the sanitized evidence JSON stay
under .wac-local. This checks synthetic stream selection and local-media policy;
it does not establish speech quality or replace the Pester regression gate.
"""

from __future__ import annotations

import argparse
import array
import datetime as dt
import hashlib
import http.server
import json
import math
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import threading
import urllib.request
import wave


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--ffprobe", type=Path, required=True)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    source = repo / "WinAudioClean.ps1"
    ffmpeg, ffprobe = args.ffmpeg.resolve(strict=True), args.ffprobe.resolve(strict=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = (args.output or repo / ".wac-local" / "WAC-M1-03" / stamp).resolve()
    private_root = (repo / ".wac-local").resolve()
    if not output.is_relative_to(private_root):
        parser.error("--output must be inside this repository's .wac-local folder")
    output.mkdir(parents=True, exist_ok=False)
    fixture_dir = output / "fixtures"
    fixture_dir.mkdir()
    replacements = [(str(repo), "<repo>"), (str(Path.home()), "<user-profile>")]

    def sanitize(value):
        if isinstance(value, str):
            for original, replacement in replacements:
                value = value.replace(original, replacement)
                value = value.replace(original.replace("\\", "/"), replacement)
                value = value.replace(original.replace("\\", "\\\\"), replacement)
            return value
        if isinstance(value, list):
            return [sanitize(item) for item in value]
        if isinstance(value, dict):
            return {key: sanitize(item) for key, item in value.items()}
        return value

    commands = []

    def run(label, command, timeout=120, env=None):
        command = [str(item) for item in command]
        start = dt.datetime.now(dt.timezone.utc)
        try:
            result = subprocess.run(
                command, cwd=repo, stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                encoding="utf-8", errors="replace", timeout=timeout,
                env=env, check=False,
            )
            record = {"id": label, "command": command, "exit_code": result.returncode,
                      "timed_out": False, "stdout": result.stdout, "stderr": result.stderr}
        except subprocess.TimeoutExpired as error:
            def decode(value):
                return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value or ""
            record = {"id": label, "command": command, "exit_code": None,
                      "timed_out": True, "stdout": decode(error.stdout), "stderr": decode(error.stderr)}
        record["elapsed_seconds"] = round((dt.datetime.now(dt.timezone.utc) - start).total_seconds(), 3)
        for stream in ("stdout", "stderr"):
            log = output / f"{label}-{stream}.txt"
            log.write_text(sanitize(record[stream]), encoding="utf-8")
            record[f"{stream}_log"] = str(log.relative_to(repo))
            record[f"{stream}_sha256"] = sha256(log)
        commands.append({key: value for key, value in record.items() if key not in ("stdout", "stderr")})
        return record

    def require_success(record):
        if record["exit_code"] != 0:
            raise RuntimeError(f"{record['id']} failed: {record['stderr']}")
        return record

    summary = {
        "task": "WAC-M1-03", "created_utc": stamp,
        "notice": "Synthetic Windows mechanics checks; no speech listening, channel-isolation, encoding promotion or decoder sandbox claim.",
        "environment": {"platform": platform.platform(), "python": platform.python_version()},
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "source_sha256_before": sha256(source), "harness_sha256": sha256(Path(__file__)),
        "tool_paths": {"ffmpeg": str(ffmpeg), "ffprobe": str(ffprobe)},
        "tool_sha256": {"ffmpeg": sha256(ffmpeg), "ffprobe": sha256(ffprobe)},
        "fixtures": [], "cases": [], "commands": commands,
    }
    server = None
    try:
        for name, tool in (("ffmpeg", ffmpeg), ("ffprobe", ffprobe)):
            result = require_success(run(f"{name}-version", [tool, "-version"], 30))
            summary.setdefault("tool_versions", {})[name] = result["stdout"].splitlines()[0]

        multi = fixture_dir / "video + two tracks [synthetic].mkv"
        video_only = fixture_dir / "video-only.mkv"
        require_success(run("generate-multi", [
            ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error",
            "-f", "lavfi", "-i", "color=c=black:s=16x16:r=10",
            "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
            "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000",
            "-map", "0:v:0", "-map", "1:a:0", "-map", "2:a:0",
            "-c:v", "ffv1", "-c:a", "pcm_s16le", "-ac:a:1", "2", "-t", "3", multi,
        ]))
        require_success(run("generate-video-only", [
            ffmpeg, "-nostdin", "-hide_banner", "-loglevel", "error", "-i", multi,
            "-map", "0:v:0", "-c", "copy", video_only,
        ]))
        for name, path in (("multi", multi), ("video-only", video_only)):
            result = require_success(run(f"probe-fixture-{name}", [
                ffprobe, "-v", "error", "-show_streams", "-show_format", "-of", "json", path,
            ]))
            metadata = json.loads(result["stdout"])
            summary["fixtures"].append({"id": name, "path": str(path.relative_to(repo)),
                                        "sha256": sha256(path), "metadata": metadata})
        stream_facts = [(stream["index"], stream["codec_type"], stream.get("channels"))
                        for stream in summary["fixtures"][0]["metadata"]["streams"]]
        if stream_facts != [(0, "video", None), (1, "audio", 1), (2, "audio", 2)]:
            raise RuntimeError(f"Unexpected generated fixture layout: {stream_facts!r}")
        if args.prepare_only:
            summary["status"] = "fixtures-prepared; application checks not run"
            return 0

        requests = []

        class Listener(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"local test listener")

            def log_message(self, _format, *_args):
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Listener)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base_url = f"http://127.0.0.1:{server.server_port}"
        with urllib.request.urlopen(base_url + "/control", timeout=5) as response:
            response.read()
        summary["loopback_control_requests"] = list(requests)
        if requests != ["/control"]:
            raise RuntimeError("The local request-count listener failed its control check")
        requests.clear()
        playlists = []
        for name, content in (
            ("external.m3u8", f"#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:3\n#EXTINF:3,\n{base_url}/segment.ts\n#EXT-X-ENDLIST\n"),
            ("renamed-hls.wav", f"#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:3\n#EXTINF:3,\n{base_url}/segment.ts\n#EXT-X-ENDLIST\n"),
            ("external.ffconcat", f"ffconcat version 1.0\nfile '{base_url}/track.wav'\n"),
            ("renamed-concat.mkv", f"ffconcat version 1.0\nfile '{base_url}/track.wav'\n"),
        ):
            path = fixture_dir / name
            path.write_text(content, encoding="ascii")
            playlists.append(path)
            summary["fixtures"].append({"id": name, "path": str(path.relative_to(repo)), "sha256": sha256(path)})

        def measure_audio(path, expected_frequency, expected_channels):
            with wave.open(str(path), "rb") as wav:
                channels, rate, width = wav.getnchannels(), wav.getframerate(), wav.getsampwidth()
                total = wav.getnframes()
                wav.setpos(min(rate, total // 3))
                samples = array.array("h", wav.readframes(min(rate // 2, total // 3)))
            if width != 2:
                raise RuntimeError(f"Measurement expects the preserved PCM16 output; got {width} bytes")
            if sys.byteorder != "little":
                samples.byteswap()
            channel_results = []
            for channel in range(channels):
                values = samples[channel::channels]
                powers = {}
                for frequency in (440, 880):
                    coefficient = 2.0 * math.cos(2.0 * math.pi * frequency / rate)
                    previous = before_previous = 0.0
                    for value in values:
                        current = value + coefficient * previous - before_previous
                        before_previous, previous = previous, current
                    powers[str(frequency)] = max(0.0, previous**2 + before_previous**2 - coefficient * previous * before_previous)
                dominant = int(max(powers, key=powers.get))
                other = 880 if expected_frequency == 440 else 440
                ratio = powers[str(expected_frequency)] / max(powers[str(other)], 1.0)
                channel_results.append({"channel": channel, "dominant_hz": dominant,
                                        "expected_to_other_power_ratio": round(ratio, 3)})
            return {"channels": channels, "sample_rate": rate, "sample_width_bytes": width,
                    "duration_seconds": total / rate, "frequencies": channel_results,
                    "passed": channels == expected_channels and all(
                        item["dominant_hz"] == expected_frequency and item["expected_to_other_power_ratio"] > 100
                        for item in channel_results)}

        for shell_name in ("powershell.exe", "pwsh.exe"):
            shell = shutil.which(shell_name)
            if shell is None:
                raise RuntimeError(f"Required Windows shell not found: {shell_name}")
            prefix = "ps51" if shell_name == "powershell.exe" else "ps7"
            result = require_success(run(prefix + "-version", [
                shell, "-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()",
            ]))
            summary["environment"][prefix] = result["stdout"].strip()
            cases = [(f"{mode.lower()}-track-{index}", multi, mode, index, 0)
                     for mode in ("Raw", "Zoom") for index in (1, 2)]
            cases += [("ambiguity", multi, "Zoom", None, 2),
                      ("video-index", multi, "Zoom", 0, 2),
                      ("missing-index", multi, "Zoom", 9, 2),
                      ("video-only", video_only, "Zoom", None, 4)]
            cases += [("probe-" + path.name.replace(".", "-"), path, "Zoom", None, 4) for path in playlists]
            for name, input_path, mode, index, expected_exit in cases:
                label = prefix + "-" + name
                destination = output / label
                destination.mkdir()
                before_requests = len(requests)
                before_hash = sha256(input_path)
                command = [shell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", source,
                           "-inputPath", input_path, "-Mode", mode, "-NonInteractive", "-OutputDirectory", destination,
                           "-FfmpegPath", ffmpeg, "-FfprobePath", ffprobe]
                if index is not None:
                    command += ["-AudioStreamIndex", index]
                result = run(label, command)
                wavs = list(destination.glob("*.wav"))
                reports = list(destination.glob("*.txt")) + list(destination.glob("*.log"))
                case = {"id": label, "expected_exit": expected_exit, "actual_exit": result["exit_code"],
                        "input_unchanged": sha256(input_path) == before_hash,
                        "wav_count": len(wavs), "report_count": len(reports),
                        "network_requests": len(requests) - before_requests,
                        "passed": result["exit_code"] == expected_exit and sha256(input_path) == before_hash
                                  and len(requests) == before_requests}
                if expected_exit == 0:
                    case["passed"] &= len(wavs) == 1 and len(reports) == 1
                    if len(wavs) == 1:
                        case["output_path"] = str(wavs[0].relative_to(repo))
                        case["output_sha256"] = sha256(wavs[0])
                        case["audio"] = measure_audio(wavs[0], 440 if index == 1 else 880, index)
                        case["passed"] &= case["audio"]["passed"]
                else:
                    case["passed"] &= len(wavs) == 0 and len(reports) == 0
                summary["cases"].append(case)
                print(f"{label}: {'PASS' if case['passed'] else 'FAIL'} (exit {result['exit_code']})", flush=True)

            # Exercise the render helper separately: application probing rejects
            # playlists first, so application-only checks cannot prove render safety.
            helper = output / (prefix + "-render-policy.ps1")
            helper.write_text(
                "param([string]$Source, [string]$Tool, [string]$InputFile, [string]$OutputFile)\n"
                "$ErrorActionPreference = 'Stop'\n"
                ". $Source\n"
                "$arguments = @(Get-WacFfmpegArguments -InputPath $InputFile -FilterChain 'anull' -OutputFile $OutputFile -AudioStreamIndex 0)\n"
                "$result = Invoke-WacNativeProcess -FilePath $Tool -ArgumentList $arguments -TimeoutMilliseconds 10000\n"
                "[pscustomobject]@{ Arguments = $arguments; Result = $result } | ConvertTo-Json -Depth 5\n",
                encoding="utf-8",
            )
            for playlist in playlists:
                label = prefix + "-render-" + playlist.name.replace(".", "-")
                destination = output / label
                destination.mkdir()
                before_requests = len(requests)
                result = run(label, [shell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", helper,
                                     "-Source", source, "-Tool", ffmpeg, "-InputFile", playlist,
                                     "-OutputFile", destination / "rejected.wav"])
                case = {"id": label, "actual_exit": result["exit_code"],
                        "network_requests": len(requests) - before_requests, "passed": False}
                if result["exit_code"] == 0:
                    data = json.loads(result["stdout"])
                    native = data["Result"]
                    case.update({"arguments": data["Arguments"], "native_exit": native["ExitCode"],
                                 "native_timed_out": native["TimedOut"], "native_started": native["Started"],
                                 "native_stderr": native["StandardError"]})
                    case["passed"] = (native["Started"] and native["ExitCode"] != 0 and not native["TimedOut"]
                                      and len(requests) == before_requests and not list(destination.glob("*.wav")))
                summary["cases"].append(case)
                print(f"{label}: {'PASS' if case['passed'] else 'FAIL'}", flush=True)

        summary["loopback_media_requests"] = list(requests)
        if sha256(source) != summary["source_sha256_before"]:
            raise RuntimeError("Runtime changed during validation; rerun on stable source")
        summary["status"] = "pass" if all(case["passed"] for case in summary["cases"]) and not requests else "fail"
        return 0 if summary["status"] == "pass" else 1
    except Exception as error:
        summary["status"] = "error"
        summary["error"] = str(error)
        print(sanitize(str(error)), file=sys.stderr)
        return 1
    finally:
        if server is not None:
            server.shutdown()
            server.server_close()
        summary["source_sha256_after"] = sha256(source)
        summary["source_unchanged_during_run"] = summary["source_sha256_before"] == summary["source_sha256_after"]
        if not summary["source_unchanged_during_run"] and not args.prepare_only:
            summary["status"] = "invalid: runtime changed during validation"
        evidence = output / "summary.json"
        evidence.write_text(json.dumps(sanitize(summary), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"Evidence: {sanitize(str(evidence))}", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
