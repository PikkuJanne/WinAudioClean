"""Static website release/consent gates. No runtime processing or network use."""
from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[4]
SPEC = importlib.util.spec_from_file_location("wac_website", REPO / "scripts/Test-Website.py")
website = importlib.util.module_from_spec(SPEC)
previous_bytecode_flag = sys.dont_write_bytecode
sys.dont_write_bytecode = True
try:
    SPEC.loader.exec_module(website)
finally:
    sys.dont_write_bytecode = previous_bytecode_flag


class WebsiteTests(unittest.TestCase):
    def setUp(self):
        self.schema = website.read_json((REPO / "website/release.schema.json").read_bytes())
        self.draft = website.read_json((REPO / "website/release.json").read_bytes())
        self.registry = website.read_json((REPO / "website/assets.json").read_bytes())

    def rejects(self, value, code="metadata_schema"):
        with self.assertRaisesRegex(website.WebsiteError, "^" + code + "$" ):
            website.validate_release(value, self.schema)

    def test_draft_version_matches_authoritative_script_and_disables_download(self):
        package = website.package_module(REPO)
        version = package.source_version((REPO / "WinAudioClean.ps1").read_bytes())
        self.assertEqual(website.validate_release(self.draft, self.schema, version),
                         {"status": "draft", "download_enabled": False, "version": version})

    def test_draft_cannot_claim_any_release_artifact_field(self):
        for section, key in (("download", "url"), ("download", "fileName"), ("download", "sha256"),
                             ("download", "bytes"), ("source", "commit"), ("source", "tree")):
            with self.subTest(section=section, key=key):
                changed = copy.deepcopy(self.draft)
                changed[section][key] = 1 if key == "bytes" else "unexpected"
                self.rejects(changed)

    def test_draft_cannot_claim_release_date(self):
        self.draft["date"] = "2026-10-04"
        self.rejects(self.draft)

    def test_published_without_all_artifact_identity_is_rejected(self):
        self.draft["status"] = "published"
        self.rejects(self.draft)

    def test_unknown_status_and_schema_version_are_rejected(self):
        for key, value in (("status", "stable"), ("schemaVersion", 2), ("schemaVersion", True)):
            with self.subTest(key=key, value=value):
                changed = copy.deepcopy(self.draft)
                changed[key] = value
                self.rejects(changed)

    def test_extra_metadata_fields_are_rejected_at_every_level(self):
        for section in (None, "download", "source", "requirements"):
            with self.subTest(section=section):
                changed = copy.deepcopy(self.draft)
                (changed if section is None else changed[section])["upload"] = "unexpected"
                self.rejects(changed)

    def test_missing_required_fields_are_rejected_at_every_level(self):
        for section in (None, "download", "source", "requirements"):
            target = self.draft if section is None else self.draft[section]
            for key in target:
                with self.subTest(section=section, key=key):
                    changed = copy.deepcopy(self.draft)
                    del (changed if section is None else changed[section])[key]
                    self.rejects(changed)

    def test_version_shape_length_and_source_authority_are_enforced(self):
        for value in ("2", "2.3-beta", "2.3\n", "1." + "2" * 33, 2.3):
            with self.subTest(value=value):
                changed = copy.deepcopy(self.draft)
                changed["version"] = value
                self.rejects(changed)
        with self.assertRaisesRegex(website.WebsiteError, "^source_version_mismatch$"):
            website.validate_release(self.draft, self.schema, self.draft["version"] + ".1")

    def test_requirements_cannot_be_missing_blank_or_duplicates(self):
        for key, value, code in (("platforms", [], "metadata_schema"),
                                 ("platforms", ["Windows", "Windows"], "metadata_schema"),
                                 ("platforms", [" "], "empty_requirements"),
                                 ("powershell", ["7"], "metadata_schema"),
                                 ("ffmpeg", "", "metadata_schema"),
                                 ("installation", " ", "empty_requirements"),
                                 ("privacy", True, "metadata_schema")):
            with self.subTest(key=key, value=value):
                changed = copy.deepcopy(self.draft)
                changed["requirements"][key] = value
                self.rejects(changed, code)

    def test_nonfinite_and_duplicate_json_are_rejected(self):
        for data, code in ((b'{"status":"draft","status":"published"}', "duplicate_json_field"),
                           (b'{"bytes":NaN}', "nonfinite_json"), (b'{"bytes":Infinity}', "nonfinite_json"),
                           (b'{"bytes":-Infinity}', "nonfinite_json"), (b'\xff', "invalid_json"),
                           (b'{', "invalid_json")):
            with self.subTest(data=data):
                with self.assertRaisesRegex(website.WebsiteError, "^" + code + "$"):
                    website.read_json(data)

    def test_unsupported_schema_keyword_fails_closed(self):
        self.schema["oneOf"] = [{"type": "string"}]
        with self.assertRaisesRegex(website.WebsiteError, "^unsupported_schema$"):
            website.validate_release(self.draft, self.schema)

    def test_boolean_cannot_impersonate_checksum_size_or_schema_integer(self):
        for schema in ({"type": "integer"}, {"const": 1}, {"enum": [1]}):
            with self.subTest(schema=schema):
                with self.assertRaisesRegex(website.WebsiteError, "^metadata_schema$"):
                    website.validate_schema(True, schema)

    def test_real_repository_branding_license_and_pending_consent_registry(self):
        facts = website.validate_assets(self.registry, REPO / "website", REPO)
        self.assertEqual(facts["branding_sha256"], website.digest((REPO / "WinAudioClean_icon.png").read_bytes()))
        self.assertEqual((facts["screenshots"], facts["audio"], facts["consent_required"]), ("pending", "pending", True))

    def test_registry_rejects_unreviewed_screenshot_or_audio_items(self):
        for key in ("screenshots", "audio"):
            for field, value in (("status", "available"), ("items", [{"path": "uncleared.wav"}]), ("reason", " ")):
                with self.subTest(key=key, field=field):
                    changed = copy.deepcopy(self.registry)
                    changed[key][field] = value
                    with self.assertRaisesRegex(website.WebsiteError, "^uncleared_asset$"):
                        website.validate_assets(changed, REPO / "website", REPO)

    def test_registry_requires_explicit_audio_consent_fields(self):
        for value in ({"requiredBeforePublication": False, "recordFields": website.CONSENT_FIELDS},
                      {"requiredBeforePublication": 1, "recordFields": website.CONSENT_FIELDS},
                      {"requiredBeforePublication": True, "recordFields": ["ownerPermission"]}):
            with self.subTest(value=value):
                changed = copy.deepcopy(self.registry)
                changed["audio"]["consent"] = value
                with self.assertRaisesRegex(website.WebsiteError, "^audio_consent_policy$"):
                    website.validate_assets(changed, REPO / "website", REPO)

    def test_registry_rejects_branding_path_or_rights_changes(self):
        for key, value in (("path", "../WinAudioClean_icon.png"), ("source", "other.png"),
                           ("license", "other-license"), ("rights", "unknown")):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.registry)
                changed["branding"][key] = value
                with self.assertRaisesRegex(website.WebsiteError, "^branding_rights$"):
                    website.validate_assets(changed, REPO / "website", REPO)

    def test_changed_branding_or_license_bytes_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            local = Path(temporary)
            (local / "WinAudioClean_icon.png").write_bytes((REPO / "WinAudioClean_icon.png").read_bytes())
            (local / "LICENSE").write_bytes((REPO / "LICENSE").read_bytes())
            website.validate_assets(self.registry, local, REPO)
            (local / "LICENSE").write_bytes(b"changed license")
            with self.assertRaisesRegex(website.WebsiteError, "^branding_license_mismatch$"):
                website.validate_assets(self.registry, local, REPO)
            (local / "LICENSE").write_bytes((REPO / "LICENSE").read_bytes())
            (local / "WinAudioClean_icon.png").write_bytes(b"changed icon")
            with self.assertRaisesRegex(website.WebsiteError, "^branding_bytes_mismatch$"):
                website.validate_assets(self.registry, local, REPO)

    def test_draft_is_never_accepted_as_published_package(self):
        with self.assertRaisesRegex(website.WebsiteError, "^package_requires_published_metadata$"):
            website.inspect_package(self.draft, Path("unused.zip"), REPO, self.schema)

    def test_fixture_output_cannot_write_into_website(self):
        with self.assertRaisesRegex(website.WebsiteError, "^fixture_output_scope$"):
            website.write_fixture(self.draft, REPO / "website/unsafe-fixture.json", REPO)

    def test_fixture_output_parent_traversal_cannot_escape_local_task_folder(self):
        target = REPO / "website/unsafe-traversal-fixture.json"
        self.assertFalse(target.exists())
        escaped = REPO / ".wac-local/WAC-M5-01/../../website/unsafe-traversal-fixture.json"
        with self.assertRaisesRegex(website.WebsiteError, "^fixture_output_scope$"):
            website.write_fixture(self.draft, escaped, REPO)
        self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
