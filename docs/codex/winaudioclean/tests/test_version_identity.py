"""Current application identity and explicit legacy report recipe compatibility."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[4]


def load_check(name):
    spec = importlib.util.spec_from_file_location(name, REPO / "scripts" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    previous_bytecode_flag = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = previous_bytecode_flag
    return module


original = load_check("Test-OriginalPreset")
reproduction = load_check("Test-AudioReproduction")


def report(version, mode="Raw", gentle=False):
    return {
        "schemaVersion": 1, "toolVersion": version,
        "presetId": "gentle" if gentle else "original",
        "presetName": "Gentle (experimental)" if gentle else "Original",
        "presetVersion": "0.1.0" if gentle else "1.0.0",
        "presetExperimental": gentle, "presetCustomized": False,
        "settings": {"mode": mode, "loudnessMode": "Fast", "mono": False, "rf64": False,
                     "cleaning": None if mode == "Zoom" else {
                         "schemaVersion": 1, "Declip": not gentle, "Declick": not gentle,
                         "Denoise": True, "Gate": not gentle, "HighpassHz": 60 if gentle else 80,
                         "NoiseFloorDb": -35 if gentle else -25, "NoiseReductionDb": 6 if gentle else 12,
                         "GateThresholdDb": -45, "GateRangeDb": -25}},
    }


class VersionIdentityTests(unittest.TestCase):
    def test_current_application_and_original_versions_are_independent_even_when_equal(self):
        self.assertEqual(original.source_application_version(REPO / "WinAudioClean.ps1"), "1.0.0")
        self.assertEqual((original.PRESET_ID, original.PRESET_VERSION), ("original", "1.0.0"))
        self.assertTrue(reproduction.profile_from_report(report("1.0.0")))

    def test_version_reader_preserves_legacy_literals_and_rejects_computed_or_duplicate_versions(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "WinAudioClean.ps1"
            for version in ("2.3", "1.0.0"):
                with self.subTest(version=version):
                    source.write_text('$scriptVersion = "' + version + '"\n', encoding="utf-8")
                    self.assertEqual(original.source_application_version(source), version)
            for text, code in (('$scriptVersion = ("1." + "0.0")\n', "invalid_source_version"),
                               ('$scriptVersion = "2.3"\n$scriptVersion = "1.0.0"\n', "ambiguous_source_version")):
                with self.subTest(code=code):
                    source.write_text(text, encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "^" + code + "$"):
                        original.source_application_version(source)

    def test_legacy_and_public_reports_reproduce_the_same_raw_zoom_and_gentle_recipes(self):
        baseline = json.loads((REPO / "docs/codex/winaudioclean/BASELINE.json").read_text(encoding="utf-8-sig"))
        for mode, gentle in (("Raw", False), ("Zoom", False), ("Raw", True)):
            with self.subTest(mode=mode, gentle=gentle):
                legacy = reproduction.profile_from_report(report("2.3", mode, gentle))
                public = reproduction.profile_from_report(report("1.0.0", mode, gentle))
                self.assertEqual(public, legacy)
                if not gentle:
                    expected = baseline["filters"]["level"]
                    if mode == "Raw":
                        expected = baseline["filters"]["raw_clean"] + "," + expected
                    self.assertEqual(public, expected)

    def test_unknown_application_recipes_still_fail_closed(self):
        for version in ("1.0", "1.0.1", "2.4", None, 1):
            with self.subTest(version=version):
                with self.assertRaisesRegex(ValueError, "^Unsupported report/application version$"):
                    reproduction.profile_from_report(report(version))

    def test_public_application_version_does_not_override_preset_identity(self):
        changed = copy.deepcopy(report("1.0.0"))
        changed["presetVersion"] = "0.1.0"
        with self.assertRaisesRegex(ValueError, "^Unsupported preset version$"):
            reproduction.profile_from_report(changed)


if __name__ == "__main__":
    unittest.main()
