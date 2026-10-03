"""Coverage metadata catches missing evidence and stale references; no app execution."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[4]
SPEC = importlib.util.spec_from_file_location("wac_coverage", REPO / "scripts/Test-Coverage.py")
coverage = importlib.util.module_from_spec(SPEC)
previous_bytecode_flag = sys.dont_write_bytecode
sys.dont_write_bytecode = True
try:
    SPEC.loader.exec_module(coverage)
finally:
    sys.dont_write_bytecode = previous_bytecode_flag
DOC = Path("docs/codex/winaudioclean")


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        (self.repo / DOC).mkdir(parents=True)
        self.acceptance = {"cases": [
            {"id": "AC-001", "task_id": "WAC-M0-01", "title": "Completed behavior", "status": "pass"},
            {"id": "AC-002", "task_id": "WAC-M4-01", "title": "Current behavior", "status": "not_run"}]}
        self.tasks = {"tasks": [
            {"id": "WAC-M0-01", "status": "done"},
            {"id": "WAC-M4-01", "status": "in_progress"}]}
        self.map = {"schema_version": 1, "active_task": "WAC-M4-01",
            "commands": [{"id": "targeted", "command": "Run the disposable test", "files": ["tests/check.ps1"]}],
            "reviews": [{"id": "manual", "status": "scope_limited", "scope": "Record only",
                         "reports": ["review.md"]}],
            "gaps": [{"id": "listening", "status": "not_run", "required_for": "Sound promotion",
                      "reason": "No audition", "cases": ["AC-001"], "reports": ["review.md"]}],
            "cases": [
                {"id": "AC-001", "task_id": "WAC-M0-01", "title": "Completed behavior",
                 "scope": "Engineering test only", "commands": ["targeted"], "reports": [],
                 "reviews": [], "gaps": ["listening"]},
                {"id": "AC-002", "task_id": "WAC-M4-01", "title": "Current behavior",
                 "scope": "Named bounded review", "commands": [], "reports": [],
                 "reviews": ["manual"], "gaps": []}]}
        (self.repo / "tests").mkdir()
        (self.repo / "tests/check.ps1").write_text("# synthetic", encoding="utf-8")
        (self.repo / "review.md").write_text("Listening unperformed", encoding="utf-8")

    def write(self):
        for name, value in [("ACCEPTANCE.json", self.acceptance), ("TASKS.yaml", self.tasks),
                            ("COVERAGE.json", self.map)]:
            (self.repo / DOC / name).write_text(json.dumps(value), encoding="utf-8")

    def check(self):
        self.write()
        return coverage.validate(self.repo)

    def test_valid_map_is_read_only_and_keeps_execution_separate(self):
        self.write()
        before = {path.relative_to(self.repo): path.read_bytes()
                  for path in self.repo.rglob("*") if path.is_file()}
        result = coverage.validate(self.repo)
        self.assertEqual(result["required_cases"], 2)
        self.assertEqual(result["retained_gaps"], 1)
        self.assertIn("not execution results", result["scope"])
        after = {path.relative_to(self.repo): path.read_bytes()
                 for path in self.repo.rglob("*") if path.is_file()}
        self.assertEqual(before, after)

    def test_missing_implemented_or_current_case_fails(self):
        for removed in (0, 1):
            with self.subTest(removed=removed):
                original = self.map["cases"]
                self.map["cases"] = [row for index, row in enumerate(original) if index != removed]
                with self.assertRaisesRegex(coverage.CoverageError, "Unmapped"):
                    self.check()
                self.map["cases"] = original

    def test_new_completed_task_requires_mapping(self):
        self.tasks["tasks"].append({"id": "WAC-M4-02", "status": "done"})
        self.acceptance["cases"].append({"id": "AC-003", "task_id": "WAC-M4-02", "title": "New behavior"})
        with self.assertRaisesRegex(coverage.CoverageError, "AC-003"):
            self.check()

    def test_checkbox_without_command_report_or_review_fails(self):
        row = self.map["cases"][0]
        row["commands"] = []
        with self.assertRaisesRegex(coverage.CoverageError, "No evidence or command"):
            self.check()

    def test_missing_command_file_or_report_fails(self):
        for field in ("command", "report"):
            with self.subTest(field=field):
                if field == "command":
                    self.map["commands"][0]["files"] = ["tests/missing.ps1"]
                else:
                    self.map["commands"][0]["files"] = ["tests/check.ps1"]
                    self.map["cases"][0]["reports"] = ["missing.json"]
                with self.assertRaisesRegex(coverage.CoverageError, "Missing coverage reference"):
                    self.check()

    def test_stale_title_and_task_fail(self):
        row = self.map["cases"][0]
        for key, bad, pattern in [("title", "Old title", "Stale acceptance title"),
                                  ("task_id", "WAC-M9-01", "Stale task")]:
            with self.subTest(key=key):
                original = row[key]
                row[key] = bad
                with self.assertRaisesRegex(coverage.CoverageError, pattern):
                    self.check()
                row[key] = original

    def test_duplicate_or_unknown_case_fails(self):
        self.map["cases"].append(dict(self.map["cases"][0]))
        with self.assertRaisesRegex(coverage.CoverageError, "Duplicate"):
            self.check()
        self.map["cases"][-1]["id"] = "AC-099"
        with self.assertRaisesRegex(coverage.CoverageError, "Unknown acceptance"):
            self.check()

    def test_unknown_command_or_review_fails(self):
        for key, bad, pattern in [("commands", "missing", "Unknown command"),
                                  ("reviews", "missing", "Unknown review")]:
            with self.subTest(key=key):
                row = self.map["cases"][0]
                original = row[key]
                row[key] = [bad]
                with self.assertRaisesRegex(coverage.CoverageError, pattern):
                    self.check()
                row[key] = original

    def test_manual_review_without_scope_or_status_fails(self):
        for key in ("scope", "status"):
            with self.subTest(key=key):
                review = self.map["reviews"][0]
                original = review[key]
                review[key] = ""
                with self.assertRaises(coverage.CoverageError):
                    self.check()
                review[key] = original

    def test_gap_cannot_be_hidden_or_relabelled_pass(self):
        self.map["cases"][0]["gaps"] = []
        with self.assertRaisesRegex(coverage.CoverageError, "omits its declared gap"):
            self.check()
        self.map["cases"][0]["gaps"] = ["listening"]
        self.map["gaps"][0]["status"] = "pass"
        with self.assertRaisesRegex(coverage.CoverageError, "explicitly not_run"):
            self.check()

    def test_unsafe_reference_fails_without_reading_outside_repo(self):
        for path in ("../private.txt", "C:/private.txt", "/private.txt", ".git/config",
                     ".wac-local/private.json", "tests\\check.ps1"):
            with self.subTest(path=path):
                self.map["cases"][0]["reports"] = [path]
                with self.assertRaises(coverage.CoverageError):
                    self.check()

    def test_malformed_json_returns_nonzero_cli(self):
        self.write()
        (self.repo / DOC / "COVERAGE.json").write_text("{broken", encoding="utf-8")
        result = subprocess.run([sys.executable, str(REPO / "scripts/Test-Coverage.py"),
                                 "--repo", str(self.repo)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Coverage check failed", result.stderr)

    def test_repository_mapping_is_current(self):
        result = coverage.validate(REPO)
        self.assertGreaterEqual(result["mapped_cases"], result["required_cases"])


if __name__ == "__main__":
    unittest.main()
