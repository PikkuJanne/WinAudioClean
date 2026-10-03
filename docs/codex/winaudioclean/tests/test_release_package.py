"""Offline package-controller regressions; no Windows host/tool/network required."""
from __future__ import annotations

import hashlib
import importlib.util
import io
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import wave
import zipfile

REPO = Path(__file__).resolve().parents[4]
SPEC = importlib.util.spec_from_file_location("release_package", REPO / "scripts/Test-ReleasePackage.py")
package = importlib.util.module_from_spec(SPEC)
_previous_bytecode = sys.dont_write_bytecode
try:
    sys.dont_write_bytecode = True
    SPEC.loader.exec_module(package)
finally:
    sys.dont_write_bytecode = _previous_bytecode


def sha256(data):
    return hashlib.sha256(data).hexdigest()


class PackageInspectionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="wac-package-fixture-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.blobs = {name: ("Synthetic committed blob: " + name + "\n").encode("ascii")
                      for name in package.PAYLOAD}
        self.blobs["WinAudioClean.ps1"] = b'$scriptVersion = "2.3"\n'
        self.blobs["LICENSE"] = b"Synthetic license bytes\r\nPreserve exact CRLF and binary: \x00\xff\n"
        self.manifest = {"schema_version": 1, "application": "WinAudioClean", "version": "2.3",
                         "source_commit": "a" * 40, "source_tree": "b" * 40,
                         "payload": [{"path": name, "bytes": len(self.blobs[name]),
                                      "sha256": sha256(self.blobs[name])} for name in package.PAYLOAD]}
        self.contents = dict(self.blobs, **{"PACKAGE-MANIFEST.json": package.manifest_bytes(self.manifest)})
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, "w", compression=zipfile.ZIP_STORED) as archive:
            for name in package.ENTRIES:
                item = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                item.create_system = 0
                # Python supplies Unix permissions for zero attributes; construct
                # ordinary records then clear that central-directory field to
                # reproduce the builder's explicit zero-attribute contract.
                item.external_attr = 32
                archive.writestr(item, self.contents[name])
        data = bytearray(stream.getvalue())
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            position = archive.start_dir
            names = archive.namelist()
        for name in names:
            struct.pack_into("<I", data, position + 38, 0)
            position += 46 + len(name.encode("ascii"))
        self.canonical = bytes(data)

    def inspect(self, data):
        archive = self.root / "WinAudioClean-2.3-aaaaaaaaaaaa-tool-only.zip"
        archive.write_bytes(data)
        checksum = sha256(data)
        archive.with_suffix(".sha256").write_bytes((checksum + "  " + archive.name + "\n").encode("ascii"))
        archive.with_suffix(".provenance.json").write_bytes(package.manifest_bytes(self.manifest, checksum))
        # Corrupt fixtures still have matching whole-file sidecars. They must
        # fail structural/content inspection rather than just a stale checksum.
        return package.inspect_archive(archive, self.manifest, self.blobs)

    def test_canonical_archive_preserves_binary_and_license_bytes(self):
        actual, facts = self.inspect(self.canonical)
        self.assertEqual(actual, self.contents)
        self.assertEqual(actual["LICENSE"], self.blobs["LICENSE"])
        self.assertEqual(facts["license_sha256"], sha256(self.blobs["LICENSE"]))
        self.assertEqual(facts["payload_count"], 15)
        self.assertEqual(facts["entry_count"], 16)

    def test_trailing_bytes_rejected_even_with_matching_sidecars(self):
        with self.assertRaisesRegex(package.CheckError, "^zip_end_record$"):
            self.inspect(self.canonical + b"HIDDEN DEVELOPMENT DATA")

    def test_prepended_bytes_rejected_even_with_matching_sidecars(self):
        with self.assertRaisesRegex(package.CheckError, "^zip_directory_layout$"):
            self.inspect(b"HIDDEN DEVELOPMENT DATA" + self.canonical)

    def test_local_extra_field_cannot_hide_behind_clean_central_directory(self):
        data = bytearray(self.canonical)
        struct.pack_into("<H", data, 28, 1)
        with self.assertRaisesRegex(package.CheckError, "^zip_local_metadata$"):
            self.inspect(data)

    def test_local_filename_must_match_the_allowlisted_central_name(self):
        data = bytearray(self.canonical)
        data[30] = ord("X")
        with self.assertRaisesRegex(package.CheckError, "^zip_local_name$"):
            self.inspect(data)

    def test_local_timestamp_must_match_fixed_central_timestamp(self):
        data = bytearray(self.canonical)
        struct.pack_into("<H", data, 10, 1)
        with self.assertRaisesRegex(package.CheckError, "^zip_local_metadata$"):
            self.inspect(data)

    def test_extracted_inventory_rejects_added_files_and_directories(self):
        extracted = self.root / "Portable package äö"
        extracted.mkdir()
        for name, data in self.contents.items():
            target = extracted.joinpath(*name.split("/"))
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        self.assertTrue(package.package_unchanged(extracted, self.contents))
        added = extracted / "private-development.log"
        added.write_bytes(b"synthetic private marker")
        self.assertFalse(package.package_unchanged(extracted, self.contents))
        added.unlink()
        (extracted / "unexpected directory").mkdir()
        self.assertFalse(package.package_unchanged(extracted, self.contents))

    def test_wave_policy_rejects_wrong_channels_rate_bits_and_duration(self):
        stream = io.BytesIO()
        with wave.open(stream, "wb") as output:
            output.setnchannels(2)
            output.setsampwidth(2)
            output.setframerate(48000)
            output.writeframes(b"\x00" * (8 * 48000 * 4))
        data = stream.getvalue()
        target = self.root / "synthetic.wav"
        target.write_bytes(data)
        self.assertEqual(package.inspect_wave(target)["duration_seconds"], 8.0)
        for offset, fmt, value in ((22, "<H", 1), (24, "<I", 44100), (34, "<H", 24)):
            with self.subTest(offset=offset):
                altered = bytearray(data)
                struct.pack_into(fmt, altered, offset, value)
                target.write_bytes(altered)
                with self.assertRaisesRegex(package.CheckError, "^wave_pcm_policy$"):
                    package.inspect_wave(target)
        shortened = bytearray(data[:-4])
        struct.pack_into("<I", shortened, 4, len(shortened) - 8)
        struct.pack_into("<I", shortened, 40, len(shortened) - 44)
        target.write_bytes(shortened)
        with self.assertRaisesRegex(package.CheckError, "^wave_duration$"):
            package.inspect_wave(target)


if __name__ == "__main__":
    unittest.main()
